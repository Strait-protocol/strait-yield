// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title StraitLiquidator
/// @notice Dutch auction liquidation engine for StraitYieldVault positions.
/// @dev Phase 2 (README §9) — intentionally not implemented yet. Phase 1 ships
/// deposit/borrow/repay/withdraw with no liquidation path. Parameters below
/// are current working assumptions (README §8), subject to change:
///   - Liquidation threshold: 80% LTV (StraitYieldVault.LIQUIDATION_THRESHOLD_BPS)
///   - Liquidation penalty: 0.5%
///   - Auction duration: 24h
///   - Auction start price: TBD
///   - Bad debt (uncovered by auction): protocol-absorbed, not socialized to depositors
contract StraitLiquidator {
// TODO(Phase 2): startAuction(vault, tunnelTxId), bid/settle mechanics,
// keeper-triggered entrypoint (self-run bot for v1 per README §6), and the
// protocol bad-debt absorption path.
}
