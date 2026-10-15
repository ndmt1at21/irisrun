//! irisrun-gateway puts one Android device on WebRTC: the media gateway of
//! the cloud tier, as tried in P0-10. It mirrors and controls the device
//! with scrcpy-server over adb, and serves a test player at `/`.
//!
//!   irisrun-gateway --serial 127.0.0.1:15556 --server scrcpy-server-v5.0.1

mod input;
mod scrcpy;
mod session;

use std::net::{IpAddr, SocketAddr};
use std::path::PathBuf;
use std::sync::Arc;
use std::time::{Duration, Instant};

use anyhow::{Context, Result, ensure};
use axum::extract::State;
use axum::http::{HeaderMap, HeaderValue, StatusCode, header};
use axum::response::{Html, IntoResponse, Response};
use axum::routing::{get, post};
use axum::{Json, Router};
use clap::Parser;
use irisrun_protocol::device::v1alpha1::{DeviceInfo, DeviceKind, Platform};
use str0m::change::SdpOffer;
use tokio::io::AsyncWriteExt;
use tokio::process::Command;
use tokio::sync::{broadcast, mpsc, watch};

use scrcpy::{Packet, Server};
use session::{Device, Frame};

/// Stream an Android device to browsers over WebRTC.
#[derive(Parser)]
#[command(name = "irisrun-gateway", version)]
struct Args {
    /// The device's adb serial; host:port for an emulator in a container.
    #[arg(long)]
    serial: String,
    #[arg(long, default_value = "adb")]
    adb: PathBuf,
    /// scrcpy-server, of the version in scrcpy::SERVER_VERSION.
    #[arg(long)]
    server: PathBuf,
    /// Where browsers load the player and post their offer.
    #[arg(long, default_value = "127.0.0.1:7780")]
    listen: SocketAddr,
    /// The address media flows on; browsers must reach it over UDP.
    #[arg(long, default_value = "127.0.0.1")]
    media_ip: IpAddr,
    /// The longest side of the video, in pixels.
    #[arg(long, default_value_t = 1280)]
    max_size: u32,
    #[arg(long, default_value_t = 4_000_000)]
    bit_rate: u32,
    /// Origins whose pages may post offers, such as the Device UI at
    /// http://127.0.0.1:7777. The built-in player needs none.
    #[arg(long)]
    allow_origin: Vec<String>,
}

#[tokio::main]
async fn main() -> Result<()> {
    let args = Args::parse();
    let started = Instant::now();
    wait_for_boot(&args).await?;
    eprintln!(
        "gateway: the device booted in {:.1}s",
        started.elapsed().as_secs_f64()
    );

    let options = scrcpy::Options {
        max_size: args.max_size,
        bit_rate: args.bit_rate,
    };
    let Server {
        name,
        mut video,
        mut control,
        process: _server,
    } = Server::start(&args.adb, &args.serial, &args.server, &options).await?;
    eprintln!("gateway: mirroring {name}");

    let (control_sender, mut control_receiver) = mpsc::channel::<Vec<u8>>(256);
    tokio::spawn(async move {
        while let Some(message) = control_receiver.recv().await {
            if control.write_all(&message).await.is_err() {
                break;
            }
        }
    });
    let (size_sender, size) = watch::channel((0, 0));
    let (frames, _) = broadcast::channel(16);
    let device = Arc::new(Device {
        frames: frames.clone(),
        control: control_sender,
        size,
        info: DeviceInfo {
            platform: Platform::Android.into(),
            kind: DeviceKind::Emulator.into(),
            model: name,
            os_version: getprop(&args, "ro.build.version.release").await?,
            display: None,
        },
    });

    let mirror = async move {
        let mut config = Vec::new();
        loop {
            match video.next().await? {
                Packet::Session { width, height } => {
                    size_sender.send_replace((width, height));
                }
                Packet::Config(data) => config = data,
                Packet::Frame { key, data } => {
                    let data = if key {
                        [config.as_slice(), &data].concat()
                    } else {
                        data
                    };
                    // Having no browser is fine.
                    let _ = frames.send(Arc::new(Frame {
                        key,
                        data: data.into(),
                    }));
                }
            }
        }
    };

    let app = Router::new()
        .route("/", get(|| async { Html(include_str!("player.html")) }))
        .route("/offer", post(offer))
        .with_state(Arc::new(Offers {
            device,
            media_ip: args.media_ip,
            allowed_origins: args.allow_origin.clone(),
        }));
    let listener = tokio::net::TcpListener::bind(args.listen)
        .await
        .with_context(|| format!("cannot listen on {}", args.listen))?;
    eprintln!("gateway: open http://{} in a browser", args.listen);
    tokio::select! {
        result = axum::serve(listener, app) => result?,
        result = mirror => return result,
    }
    Ok(())
}

struct Offers {
    device: Arc<Device>,
    media_ip: IpAddr,
    allowed_origins: Vec<String>,
}

/// Takes the offer as JSON in any content type, so that a page on another
/// origin can post it as text/plain without a preflight. Only allowed
/// origins get to read the answer.
async fn offer(State(offers): State<Arc<Offers>>, headers: HeaderMap, body: String) -> Response {
    let mut response = match serde_json::from_str::<SdpOffer>(&body) {
        Ok(offer) => match session::accept(offer, offers.media_ip, offers.device.clone()).await {
            Ok(answer) => Json(answer).into_response(),
            Err(error) => (StatusCode::BAD_REQUEST, format!("{error:#}")).into_response(),
        },
        Err(error) => (
            StatusCode::BAD_REQUEST,
            format!("not an SDP offer: {error}"),
        )
            .into_response(),
    };
    if let Some(origin) = headers.get(header::ORIGIN)
        && offers
            .allowed_origins
            .iter()
            .any(|allowed| origin == allowed.as_str())
    {
        response
            .headers_mut()
            .insert(header::ACCESS_CONTROL_ALLOW_ORIGIN, origin.clone());
        response
            .headers_mut()
            .insert(header::VARY, HeaderValue::from_static("Origin"));
    }
    response
}

/// Connects to a device that adb reaches over TCP and waits until Android
/// finished booting.
async fn wait_for_boot(args: &Args) -> Result<()> {
    let deadline = Instant::now() + Duration::from_secs(300);
    loop {
        if args.serial.contains(':') {
            Command::new(&args.adb)
                .args(["connect", &args.serial])
                .output()
                .await?;
        }
        if getprop(args, "sys.boot_completed")
            .await
            .is_ok_and(|value| value == "1")
        {
            return Ok(());
        }
        ensure!(Instant::now() < deadline, "{} did not boot", args.serial);
        tokio::time::sleep(Duration::from_secs(1)).await;
    }
}

async fn getprop(args: &Args, name: &str) -> Result<String> {
    let output = Command::new(&args.adb)
        .args(["-s", &args.serial, "shell", "getprop", name])
        .output()
        .await
        .with_context(|| format!("cannot run {}", args.adb.display()))?;
    ensure!(output.status.success(), "{} is not reachable", args.serial);
    Ok(String::from_utf8_lossy(&output.stdout).trim().to_owned())
}
