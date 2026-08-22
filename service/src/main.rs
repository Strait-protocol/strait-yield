mod config;
mod loan;
mod strait_client;
mod webhook;

#[tokio::main]
async fn main() {
    tracing_subscriber::fmt::init();

    let config = config::Config::from_env();
    let strait = strait_client::StraitClient::new(&config.strait_graphql_url);

    let app = webhook::router(strait);

    let listener = tokio::net::TcpListener::bind(&config.listen_addr)
        .await
        .expect("failed to bind webhook listener");

    tracing::info!("strait-yield-service listening on {}", config.listen_addr);
    axum::serve(listener, app).await.expect("server error");
}
