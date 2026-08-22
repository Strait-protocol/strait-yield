//! Listens for Strait's collateral-lock / popAnchored event push.
//! Primary path for collateral recognition; `strait_client` GraphQL polling
//! is the fallback if a push is missed.

use axum::{routing::post, Json, Router};
use serde::Deserialize;

use crate::strait_client::StraitClient;

#[derive(Debug, Deserialize)]
pub struct CollateralLockedEvent {
    pub tunnel_tx_id: String,
    pub pop_anchored: bool,
    pub btc_amount_sats: u64,
    pub borrower_address: String,
}

pub fn router(strait: StraitClient) -> Router {
    Router::new()
        .route("/webhooks/strait/collateral-locked", post(handle_collateral_locked))
        .with_state(strait)
}

async fn handle_collateral_locked(
    axum::extract::State(_strait): axum::extract::State<StraitClient>,
    Json(event): Json<CollateralLockedEvent>,
) -> &'static str {
    if !event.pop_anchored {
        // Not yet finalized on the Bitcoin side — ignore until popAnchored: true.
        return "ignored: not popAnchored";
    }

    // TODO: hand off to the loan module once collateral is confirmed
    // (open the borrower's position for a loan request).
    tracing::info!(tunnel_tx_id = %event.tunnel_tx_id, "collateral locked and popAnchored");
    "ok"
}
