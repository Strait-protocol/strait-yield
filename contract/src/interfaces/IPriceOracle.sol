// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice BTC/USD price feed consumed by StraitYieldVault for LTV checks.
/// README §6: Chainlink is primary, CoinGecko (via strait-analytics) is the
/// backup/fallback if Chainlink is stale — the failover wrapper implementing
/// that policy is not yet written; this interface is what it (or a direct
/// Chainlink adapter) must satisfy.
interface IPriceOracle {
    /// @return price BTC/USD price, scaled to 1e8 (Chainlink convention).
    /// @return updatedAt Unix timestamp of the last price update, for staleness checks.
    function btcUsdPrice() external view returns (uint256 price, uint256 updatedAt);
}
