/// Which asset a borrower chose to receive their loan in. USDC and VUSD are
/// distinct assets and are never bridged/converted between each other within
/// the vault — see README §6.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum BorrowAsset {
    Usdc,
    Vusd,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum LoanState {
    /// Collateral locked (popAnchored: true) but no loan drawn yet.
    CollateralLocked,
    /// Loan drawn and active.
    Active,
    /// LTV crossed the liquidation threshold; auction in progress.
    Liquidating,
    /// Debt repaid in full, collateral released.
    Closed,
}

#[derive(Debug, Clone)]
pub struct Position {
    pub tunnel_tx_id: String,
    pub borrower_address: String,
    pub btc_amount_sats: u64,
    pub borrow_asset: BorrowAsset,
    pub debt_principal: u64,
    pub debt_accrued_interest: u64,
    pub state: LoanState,
}
