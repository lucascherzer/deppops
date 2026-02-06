use actix_web::{get, HttpResponse, Responder};
use tracing::{info, trace};

#[get("/")]
#[tracing::instrument]
pub async fn hello() -> impl Responder {
    info!("Hello endpoint called");
    HttpResponse::Ok().body("Hello!")
}

#[get("/health/live")]
#[tracing::instrument]
pub async fn liveness() -> impl Responder {
    trace!("Liveness check called");
    HttpResponse::Ok().json(serde_json::json!({
        "status": "alive"
    }))
}

#[get("/health/ready")]
#[tracing::instrument]
pub async fn readiness() -> impl Responder {
    trace!("Readiness check called");
    // Add any additional checks here (database, external services, etc.)
    HttpResponse::Ok().json(serde_json::json!({
        "status": "ready"
    }))
}

#[cfg(test)]
mod tests {
    use super::*;
    use actix_web::{test, web, App};

    #[actix_web::test]
    async fn test_hello() {
        let app = test::init_service(App::new().service(hello)).await;
        let req = test::TestRequest::get().uri("/").to_request();
        let resp = test::call_service(&app, req).await;
        assert!(resp.status().is_success());
        let body = test::read_body(resp).await;
        assert_eq!(body, web::Bytes::from_static(b"Hello!"));
    }

    #[actix_web::test]
    async fn test_liveness() {
        let app = test::init_service(App::new().service(liveness)).await;
        let req = test::TestRequest::get().uri("/health/live").to_request();
        let resp = test::call_service(&app, req).await;
        assert!(resp.status().is_success());
    }

    #[actix_web::test]
    async fn test_readiness() {
        let app = test::init_service(App::new().service(readiness)).await;
        let req = test::TestRequest::get().uri("/health/ready").to_request();
        let resp = test::call_service(&app, req).await;
        assert!(resp.status().is_success());
    }
}
