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
