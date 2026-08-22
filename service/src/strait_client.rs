//! GraphQL client to the existing Strait indexer (`strait-api`).
//!
//! Fallback/reconciliation path for when a webhook push is missed or delayed,
//! and for on-demand lookups (e.g. displaying position status in a UI).

use serde::Deserialize;

#[derive(Clone)]
pub struct StraitClient {
    http: reqwest::Client,
    graphql_url: String,
}

#[derive(Debug, Deserialize)]
pub struct CollateralPosition {
    pub tunnel_tx_id: String,
    pub pop_anchored: bool,
    pub btc_amount_sats: u64,
}

impl StraitClient {
    pub fn new(graphql_url: &str) -> Self {
        Self {
            http: reqwest::Client::new(),
            graphql_url: graphql_url.to_string(),
        }
    }

    /// Queries Strait for a collateral position's current status.
    /// Collateral is only recognized once `pop_anchored: true` is confirmed.
    pub async fn get_collateral_position(
        &self,
        _tunnel_tx_id: &str,
    ) -> Result<CollateralPosition, reqwest::Error> {
        // TODO: wire up the actual GraphQL query against strait-api once its
        // schema for collateral positions is finalized.
        todo!("query {} for collateral position", self.graphql_url)
    }
}
