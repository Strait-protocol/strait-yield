// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {StraitYieldVault} from "../src/StraitYieldVault.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockPriceOracle} from "./mocks/MockPriceOracle.sol";

contract StraitYieldVaultTest is Test {
    StraitYieldVault vault;
    MockERC20 usdc;
    MockPriceOracle oracle;

    address owner = makeAddr("owner");
    address collateralOracle = makeAddr("collateralOracle");
    address depositor = makeAddr("depositor");
    address borrower = makeAddr("borrower");

    bytes32 constant TUNNEL_TX_ID = keccak256("tunnel-tx-1");
    uint256 constant ONE_BTC_SATS = 1e8;
    uint256 constant BTC_PRICE_USD_1E8 = 100_000e8; // $100,000, Chainlink-style 1e8 scaling

    function setUp() public {
        usdc = new MockERC20("USD Coin", "USDC");
        oracle = new MockPriceOracle(BTC_PRICE_USD_1E8);
        vault = new StraitYieldVault(usdc, "Strait Yield USDC", "syUSDC", owner);

        vm.startPrank(owner);
        vault.setCollateralOracle(collateralOracle);
        vault.setPriceOracle(oracle);
        vm.stopPrank();

        usdc.mint(depositor, 200_000e6);
        vm.prank(depositor);
        usdc.approve(address(vault), type(uint256).max);

        usdc.mint(borrower, 100_000e6); // for repayment later
        vm.prank(borrower);
        usdc.approve(address(vault), type(uint256).max);
    }

    function test_depositMintsShares1to1OnFirstDeposit() public {
        vm.prank(depositor);
        uint256 shares = vault.deposit(200_000e6);

        assertEq(shares, 200_000e6);
        assertEq(vault.balanceOf(depositor), 200_000e6);
        assertEq(vault.totalAssets(), 200_000e6);
    }

    function test_borrowUpToMaxLtvSucceeds() public {
        vm.prank(depositor);
        vault.deposit(200_000e6);

        vm.prank(collateralOracle);
        vault.registerCollateral(TUNNEL_TX_ID, borrower, ONE_BTC_SATS);

        // 1 BTC @ $100k = $100k collateral; 60% max LTV = $60k borrowable.
        vm.prank(borrower);
        vault.borrow(TUNNEL_TX_ID, 60_000e6);

        assertEq(usdc.balanceOf(borrower), 100_000e6 + 60_000e6);
        assertEq(vault.positionLtvBps(TUNNEL_TX_ID), 6_000);
    }

    function test_borrowAboveMaxLtvReverts() public {
        vm.prank(depositor);
        vault.deposit(200_000e6);

        vm.prank(collateralOracle);
        vault.registerCollateral(TUNNEL_TX_ID, borrower, ONE_BTC_SATS);

        vm.prank(borrower);
        vm.expectRevert(StraitYieldVault.ExceedsMaxLtv.selector);
        vault.borrow(TUNNEL_TX_ID, 60_100e6);
    }

    function test_repayInFullClosesPosition() public {
        vm.prank(depositor);
        vault.deposit(200_000e6);

        vm.prank(collateralOracle);
        vault.registerCollateral(TUNNEL_TX_ID, borrower, ONE_BTC_SATS);

        vm.prank(borrower);
        vault.borrow(TUNNEL_TX_ID, 60_000e6);

        vm.prank(borrower);
        vault.repay(TUNNEL_TX_ID, 60_000e6);

        (,, uint256 principal, uint256 accruedInterest,, bool active) = vault.positions(TUNNEL_TX_ID);
        assertEq(principal, 0);
        assertEq(accruedInterest, 0);
        assertFalse(active);
    }

    function test_withdrawRespectsAvailableLiquidity() public {
        vm.prank(depositor);
        vault.deposit(200_000e6);

        vm.prank(collateralOracle);
        vault.registerCollateral(TUNNEL_TX_ID, borrower, ONE_BTC_SATS);

        vm.prank(borrower);
        vault.borrow(TUNNEL_TX_ID, 60_000e6);

        // Only 140,000 USDC left in the pool; depositor can't pull out all 200,000 shares.
        uint256 sharesForFullBalance = vault.balanceOf(depositor);
        vm.prank(depositor);
        vm.expectRevert(StraitYieldVault.InsufficientLiquidity.selector);
        vault.withdraw(sharesForFullBalance);
    }
}
