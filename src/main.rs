use actix_web::{App, HttpServer};
use deppops::{hello, liveness, readiness};
use tracing::info;
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    // Initialize tracing
    tracing_subscriber::registry()
        .with(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "deppops=debug,actix_web=info,tracing_actix_web=info".into()),
        )
        .with(tracing_subscriber::fmt::layer())
        .init();

    info!("Starting server at http://0.0.0.0:8080");

    HttpServer::new(|| {
        App::new()
            .service(hello)
            .service(liveness)
            .service(readiness)
    })
    .bind(("0.0.0.0", 8080))?
    .run()
    .await
}
