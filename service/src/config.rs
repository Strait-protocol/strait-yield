pub struct Config {
    /// Strait's GraphQL API endpoint (position lookups, on-demand collateral verification).
    pub strait_graphql_url: String,
    /// Address this service's webhook listener binds to, for Strait's event push
    /// (collateral-lock / popAnchored events).
    pub listen_addr: String,
}

impl Config {
    pub fn from_env() -> Self {
        Self {
            strait_graphql_url: std::env::var("STRAIT_GRAPHQL_URL")
                .unwrap_or_else(|_| "http://localhost:8080/graphql".to_string()),
            listen_addr: std::env::var("LISTEN_ADDR")
                .unwrap_or_else(|_| "0.0.0.0:3001".to_string()),
        }
    }
}
