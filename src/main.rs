use std::{env, net::Ipv4Addr};

use axum::{
    body::Body, debug_handler, extract::{DefaultBodyLimit, Multipart}, response::IntoResponse, routing::post, Router,
};
use log::info;
use tokio::net::TcpListener;
use tower_http::services::ServeDir;
use typst::{
    foundations::{Bytes, Dict, Str, Value},
    text::Font,
};
use typst_as_lib::TypstTemplate;

#[tokio::main]
async fn main() {
    env::set_var("RUST_LOG", "debug");
    env_logger::init();
    info!("starting server");
    // set path of contents files directory as service
    let serve_dir: ServeDir = ServeDir::new("./dist/").append_index_html_on_directories(true);
    // set router path of the service
    let app = Router::new()
        .route("/make", post(make))
        .nest_service("/", serve_dir)
        .layer(DefaultBodyLimit::max(1024 * 1024 * 1024 * 30));

    let port = env::var("PORT").unwrap_or("8080".to_string());

    let listener = TcpListener::bind((Ipv4Addr::UNSPECIFIED, port.parse().unwrap()))
        .await
        .unwrap();

    axum::serve(listener, app).await.unwrap();
}

#[debug_handler]
async fn make(mut multipart: Multipart) -> impl IntoResponse {
    info!("make");
    let content = include_str!("./typst/lib.typ");
    let font: &[u8] = include_bytes!("./fonts/NotoSansJP-Medium.otf");
    let font = Font::new(Bytes::from(font), 0).unwrap();

    let Ok(tempdir) = tempdir::TempDir::new("photos") else {
        return axum::http::Response::builder()
            .status(500)
            .body(Body::from("Failed to create tempdir"))
            .unwrap();
    };

    let template = TypstTemplate::new(vec![font], content)
        .with_file_system_resolver(".")
        .with_file_system_resolver(tempdir.path());

    // dbg!(tempdir.path());

    let mut dict = Dict::new();

    while let Some(field) = multipart.next_field().await.ok().flatten() {
        if field.file_name() == Some("")
        {
            continue;
        }

        let month = field.name().unwrap_or_default().to_string();
        let Ok(photo) = field.bytes().await else {
            continue;
        };

        if photo.is_empty() {
            continue;
        }


        let Ok(_) = tokio::fs::write(tempdir.path().join(&month), photo).await else {
            return axum::http::Response::builder()
                .status(500)
                .body(Body::from("Failed to write photo"))
                .unwrap();
        };

        dict.insert(Str::from(month.clone()), Value::Str(Str::from(month)));
    }

    // let start = time::Instant::now();
    let doc = template.compile_with_input(dict).output.unwrap();

    // dbg!(format!("compile ended in {} ms", start.elapsed().as_millis()));

    let options: typst_pdf::PdfOptions<'_> = Default::default();
    let pdf = typst_pdf::pdf(&doc, &options).unwrap_or_default();

    // std::thread::sleep(std::time::Duration::from_secs(5));

    axum::http::Response::builder()
        .header("Content-Type", "application/pdf")
        .body(Body::from(pdf))
        .unwrap()
}
