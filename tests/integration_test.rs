use actix_web::{test, App};

#[actix_web::test]
async fn test_hello_integration() {
    let app = test::init_service(App::new().service(deppops::hello)).await;

    // Create a request
    let req = test::TestRequest::get().uri("/").to_request();

    // Send the request and get the response
    let resp = test::call_service(&app, req).await;

    assert!(resp.status().is_success());

    let body = test::read_body(resp).await;
    assert_eq!(body, "Hello!");
}

#[actix_web::test]
async fn test_liveness_integration() {
    let app = test::init_service(App::new().service(deppops::liveness)).await;

    let req = test::TestRequest::get().uri("/health/live").to_request();
    let resp = test::call_service(&app, req).await;

    assert!(resp.status().is_success());

    let body = test::read_body(resp).await;
    let json: serde_json::Value = serde_json::from_slice(&body).unwrap();
    assert_eq!(json["status"], "alive");
}

#[actix_web::test]
async fn test_readiness_integration() {
    let app = test::init_service(App::new().service(deppops::readiness)).await;

    let req = test::TestRequest::get().uri("/health/ready").to_request();
    let resp = test::call_service(&app, req).await;

    assert!(resp.status().is_success());

    let body = test::read_body(resp).await;
    let json: serde_json::Value = serde_json::from_slice(&body).unwrap();
    assert_eq!(json["status"], "ready");
}
