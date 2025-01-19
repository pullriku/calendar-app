use std::{env, net::Ipv4Addr};

use axum::{
    body::Body,
    debug_handler,
    extract::{DefaultBodyLimit, Multipart},
    response::IntoResponse,
    routing::post,
    Router,
};
use log::{debug, info};
use tokio::net::TcpListener;
use tower_http::services::ServeDir;
use typst::{
    foundations::{Bytes, Dict, Str, Value},
    text::Font,
};
use typst_as_lib::TypstTemplate;

const DEFAULT_PORT: u16 = 8080;
const CONTENT: &str = include_str!("./typst/lib.typ");
const FONT_BOLD: &[u8] = include_bytes!("./fonts/NotoSansJP-Bold.otf");
const FONT_MEDIUM: &[u8] = include_bytes!("./fonts/NotoSansJP-Medium.otf");

#[tokio::main]
async fn main() {
    env::set_var("RUST_LOG", "debug");
    env_logger::init();
    info!("starting server");

    let serve_dir: ServeDir = ServeDir::new("./dist/").append_index_html_on_directories(true);
    let app = Router::new()
        .route("/make", post(make))
        .nest_service("/", serve_dir)
        .layer(DefaultBodyLimit::max(1024 * 1024 * 1024 * 30));

    let env_var = env::var("PORT");
    let port: u16 = env_var
        .map(|s| s.parse().unwrap_or(DEFAULT_PORT))
        .unwrap_or(DEFAULT_PORT);

    let listener = TcpListener::bind((Ipv4Addr::UNSPECIFIED, port))
        .await
        .expect("failed to bind address");

    info!("listening on http://0.0.0.0:{}", port);

    axum::serve(listener, app)
        .await
        .expect("server failed to start");
}

#[debug_handler]
async fn make(mut multipart: Multipart) -> impl IntoResponse {
    info!("make");

    let font_bold = Font::new(Bytes::from(FONT_BOLD), 0).expect("Failed to load bold font");
    let font_medium = Font::new(Bytes::from(FONT_MEDIUM), 0).expect("Failed to load medium font");

    let Ok(tempdir) = tempdir::TempDir::new(&format!("photos-{}", uuid::Uuid::new_v4())) else {
        return response(500, "Failed to receive file".to_string());
    };

    let template = TypstTemplate::new([font_bold, font_medium], CONTENT)
        .with_file_system_resolver(".")
        .with_file_system_resolver(tempdir.path());

    let mut dict = Dict::new();

    while let Some(field) = multipart.next_field().await.ok().flatten() {
        if field.file_name() == Some("") {
            continue;
        }

        let month = field.name().unwrap_or_default().to_string();

        // dbg!(&month);
        let Ok(photo) = field.bytes().await else {
            continue;
        };

        debug!("photo size: {} bytes", photo.len());

        if photo.is_empty() {
            continue;
        }

        if tokio::fs::write(tempdir.path().join(&month), photo)
            .await
            .is_err()
        {
            return response(500, "Failed to receive file".to_string());
        };

        dict.insert(Str::from(month.clone()), Value::Str(Str::from(month)));
    }

    let doc = match template.compile_with_input(dict).output {
        Ok(doc) => doc,
        Err(e) => return response(500, format!("Failed to compile document: {:?}", e)),
    };

    let options: typst_pdf::PdfOptions<'_> = Default::default();
    let pdf = typst_pdf::pdf(&doc, &options).unwrap_or_default();

    drop(tempdir);

    axum::http::Response::builder()
        .header("Content-Type", "application/pdf")
        .body(Body::from(pdf))
        .expect("failed to build pdf response")

}

fn response(code: u16, message: String) -> axum::http::Response<Body> {
    axum::http::Response::builder()
        .status(code)
        .body(Body::from(message))
        .expect("failed to build response")
}
