// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/access/Ownable.sol";
import {IPriceOracle} from "./interfaces/IPriceOracle.sol";

/// @title StraitYieldVault
/// @notice Single-asset peer-to-pool lending vault, BTC-collateralized.
/// @dev README §6: USDC and VUSD are distinct assets, never bridged/converted
/// within the vault — deploy one instance of this contract per pool asset
/// (two separate pools), rather than one contract handling both.
///
/// Collateral (BTC) is not an on-chain balance here — it's locked in Hemi's
/// existing BitcoinTunnelManager and verified off-chain by the strait-yield
/// service, which relays `popAnchored: true` confirmations into
/// `registerCollateral`. This contract never re-derives that correctness work.
contract StraitYieldVault is ERC20, Ownable {
    using SafeERC20 for IERC20;

    /// README §8 — subject to change as the project develops.
    uint256 public constant MAX_LTV_BPS = 6_000; // 60%
    uint256 public constant LIQUIDATION_THRESHOLD_BPS = 8_000; // 80%
    uint256 public constant BPS_DENOMINATOR = 10_000;

    IERC20 public immutable poolAsset;
    IPriceOracle public priceOracle;

    /// The strait-yield service address authorized to register verified
    /// collateral (i.e. the consumer of Strait's popAnchored webhook) and to
    /// call liquidation hooks once StraitLiquidator (Phase 2) is wired up.
    address public collateralOracle;

    struct Position {
        address borrower;
        uint256 btcAmountSats;
        uint256 principal;
        uint256 accruedInterest;
        uint64 lastAccrualTimestamp;
        bool active;
    }

    /// Keyed by the Hemi tunnel transaction id backing the collateral.
    mapping(bytes32 => Position) public positions;

    uint256 public totalBorrowed;

    event Deposited(address indexed depositor, uint256 assets, uint256 shares);
    event Withdrawn(address indexed depositor, uint256 assets, uint256 shares);
    event CollateralRegistered(bytes32 indexed tunnelTxId, address indexed borrower, uint256 btcAmountSats);
    event Borrowed(bytes32 indexed tunnelTxId, address indexed borrower, uint256 amount);
    event Repaid(bytes32 indexed tunnelTxId, address indexed borrower, uint256 amount, bool closed);

    error InsufficientLiquidity();
    error ExceedsMaxLtv();
    error PositionNotActive();
    error NotCollateralOracle();
    error DebtNotFullyRepaid();

    modifier onlyCollateralOracle() {
        if (msg.sender != collateralOracle) revert NotCollateralOracle();
        _;
    }

    constructor(IERC20 _poolAsset, string memory _name, string memory _symbol, address _owner)
        ERC20(_name, _symbol)
        Ownable(_owner)
    {
        poolAsset = _poolAsset;
    }

    function setCollateralOracle(address _collateralOracle) external onlyOwner {
        collateralOracle = _collateralOracle;
    }

    function setPriceOracle(IPriceOracle _priceOracle) external onlyOwner {
        priceOracle = _priceOracle;
    }

    // ---------------------------------------------------------------------
    // Depositor flow (README §3)
    // ---------------------------------------------------------------------

    function deposit(uint256 assets) external returns (uint256 shares) {
        uint256 supply = totalSupply();
        uint256 pooled = totalAssets();

        shares = supply == 0 ? assets : (assets * supply) / pooled;

        poolAsset.safeTransferFrom(msg.sender, address(this), assets);
        _mint(msg.sender, shares);

        emit Deposited(msg.sender, assets, shares);
    }

    function withdraw(uint256 shares) external returns (uint256 assets) {
        uint256 supply = totalSupply();
        assets = (shares * totalAssets()) / supply;

        if (assets > poolAsset.balanceOf(address(this))) revert InsufficientLiquidity();

        _burn(msg.sender, shares);
        poolAsset.safeTransfer(msg.sender, assets);

        emit Withdrawn(msg.sender, assets, shares);
    }

    /// Pool assets available for borrowing/withdrawal, plus what's out on loan.
    /// TODO: this treats principal as fully collectible; once interest accrual
    /// is finalized, accrued (uncollected) interest should also count here.
    function totalAssets() public view returns (uint256) {
        return poolAsset.balanceOf(address(this)) + totalBorrowed;
    }

    // ---------------------------------------------------------------------
    // Borrower flow (README §3)
    // ---------------------------------------------------------------------

    /// Called by the strait-yield service once it has confirmed
    /// `popAnchored: true` for the borrower's tunnel transaction. Opens a
    /// position but does not draw a loan yet.
    function registerCollateral(bytes32 tunnelTxId, address borrower, uint256 btcAmountSats)
        external
        onlyCollateralOracle
    {
        positions[tunnelTxId] = Position({
            borrower: borrower,
            btcAmountSats: btcAmountSats,
            principal: 0,
            accruedInterest: 0,
            lastAccrualTimestamp: uint64(block.timestamp),
            active: true
        });

        emit CollateralRegistered(tunnelTxId, borrower, btcAmountSats);
    }

    function borrow(bytes32 tunnelTxId, uint256 amount) external {
        Position storage position = positions[tunnelTxId];
        if (!position.active || position.borrower != msg.sender) revert PositionNotActive();
        if (amount > poolAsset.balanceOf(address(this))) revert InsufficientLiquidity();

        position.principal += amount;

        uint256 ltvBps = _ltvBps(position);
        if (ltvBps > MAX_LTV_BPS) revert ExceedsMaxLtv();

        totalBorrowed += amount;
        poolAsset.safeTransfer(msg.sender, amount);

        emit Borrowed(tunnelTxId, msg.sender, amount);
    }

    /// Debt must be repaid in full before collateral is released (README §3) —
    /// no partial-unlock in v1. Actual BTC release back through the Hemi
    /// tunnel is triggered by the strait-yield service once `Repaid(closed:
    /// true)` is observed; it is not performed by this contract directly.
    function repay(bytes32 tunnelTxId, uint256 amount) external {
        Position storage position = positions[tunnelTxId];
        if (!position.active) revert PositionNotActive();

        poolAsset.safeTransferFrom(msg.sender, address(this), amount);

        uint256 totalDebt = position.principal + position.accruedInterest;
        uint256 applied = amount > totalDebt ? totalDebt : amount;

        if (applied <= position.accruedInterest) {
            position.accruedInterest -= applied;
        } else {
            uint256 towardPrincipal = applied - position.accruedInterest;
            position.accruedInterest = 0;
            position.principal -= towardPrincipal;
            totalBorrowed -= towardPrincipal;
        }

        bool closed = position.principal == 0 && position.accruedInterest == 0;
        if (closed) {
            position.active = false;
        }

        emit Repaid(tunnelTxId, msg.sender, applied, closed);
    }

    /// Current LTV in basis points for a position. Reverts if no price oracle
    /// is set — wire up `setPriceOracle` before borrowing goes live.
    function positionLtvBps(bytes32 tunnelTxId) external view returns (uint256) {
        return _ltvBps(positions[tunnelTxId]);
    }

    function _ltvBps(Position storage position) internal view returns (uint256) {
        (uint256 btcUsdPrice,) = priceOracle.btcUsdPrice();
        // btcAmountSats (1e8 sats/BTC) * price (1e8) -> collateral value scaled 1e8;
        // normalize against principal + interest, both assumed pool-asset-decimals (1e6, USDC/VUSD).
        // TODO: revisit scaling once VUSD decimals are confirmed and interest accrual is implemented.
        uint256 collateralValueUsd = (position.btcAmountSats * btcUsdPrice) / 1e10;
        if (collateralValueUsd == 0) return type(uint256).max;

        uint256 debt = position.principal + position.accruedInterest;
        return (debt * BPS_DENOMINATOR) / collateralValueUsd;
    }

    // ---------------------------------------------------------------------
    // Liquidation hook (Phase 2 — StraitLiquidator not wired up yet)
    // ---------------------------------------------------------------------

    /// TODO(Phase 2): expose a seize/settle function callable only by
    /// StraitLiquidator once a position crosses LIQUIDATION_THRESHOLD_BPS,
    /// per the Dutch auction mechanism in README §5/§8. Bad debt shortfall
    /// (README §6) is protocol-absorbed, not socialized to depositors — that
    /// accounting also lands here in Phase 2.
}
