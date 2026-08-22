/// Risk parameters from README §8 — subject to change as the project develops.
pub const MAX_LTV_BPS: u64 = 6_000; // 60%
pub const LIQUIDATION_THRESHOLD_BPS: u64 = 8_000; // 80%

/// Current LTV in basis points, given outstanding debt (in USD, 1e6-scaled)
/// and BTC collateral value (in USD, 1e6-scaled).
pub fn calculate_ltv(debt_usd: u64, collateral_value_usd: u64) -> u64 {
    if collateral_value_usd == 0 {
        return u64::MAX;
    }
    debt_usd.saturating_mul(10_000) / collateral_value_usd
}

pub fn is_liquidatable(ltv_bps: u64) -> bool {
    ltv_bps >= LIQUIDATION_THRESHOLD_BPS
}
