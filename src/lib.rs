use actix_web::{get, HttpResponse, Responder};

#[get("/")]
pub async fn hello() -> impl Responder {
    HttpResponse::Ok().body("Hello!")
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
}
