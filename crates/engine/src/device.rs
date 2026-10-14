//! Connects a device runtime to the Device UI.
//!
//! The runtime is a child process that speaks the Device Protocol on stdio, as
//! size-delimited envelopes. Browsers load the Device UI from this server and
//! connect to `/device` over WebSocket, one envelope per binary message. The
//! bridge restarts the runtime when the UI asks, and replays the latest device
//! info, app status and frame to clients that join late.

use std::io::ErrorKind;
use std::net::SocketAddr;
use std::process::Stdio;
use std::sync::{Arc, Mutex, PoisonError};
use std::time::{Instant, SystemTime};

use anyhow::{Context, Result, bail, ensure};
use axum::Router;
use axum::extract::State;
use axum::extract::ws::{Message, WebSocket, WebSocketUpgrade};
use axum::http::{StatusCode, Uri, header};
use axum::response::{IntoResponse, Response};
use axum::routing::get;
use bytes::Bytes;
use futures_util::{SinkExt, StreamExt};
use irisrun_protocol::device::v1alpha1::{
    AppControl, AppState, AppStatus, DeviceMessage, HostMessage, LogEntry, LogLevel, app_control,
    device_message, host_message,
};
use prost::Message as _;
use tokio::io::{AsyncBufReadExt, AsyncRead, AsyncReadExt, AsyncWrite, AsyncWriteExt, BufReader};
use tokio::process::Command;
use tokio::sync::{broadcast, mpsc};

/// The largest envelope accepted from a runtime. Anything bigger means its
/// stdout carries something other than the protocol.
const MAX_ENVELOPE: u64 = 64 << 20;

/// Serves the Device UI on `addr` and runs the device that `runtime` starts.
pub async fn serve(addr: SocketAddr, runtime: impl Fn() -> Command) -> Result<()> {
    let (commands, inbox) = mpsc::channel(256);
    let shared = Arc::new(Shared {
        updates: broadcast::channel(256).0,
        commands,
        latest: Mutex::default(),
    });
    let app = Router::new()
        .route("/device", get(device_socket))
        .fallback(device_ui)
        .with_state(shared.clone());
    let listener = tokio::net::TcpListener::bind(addr)
        .await
        .with_context(|| format!("cannot listen on {addr}"))?;
    tokio::select! {
        result = axum::serve(listener, app) => result?,
        result = supervise(runtime, &shared, inbox) => result?,
    }
    Ok(())
}

struct Shared {
    /// Envelopes from the device, for every client.
    updates: broadcast::Sender<Bytes>,
    /// Envelopes from clients, for the device.
    commands: mpsc::Sender<Bytes>,
    latest: Mutex<Latest>,
}

/// What a client that joins late needs to show the device at once.
#[derive(Default)]
struct Latest {
    device_info: Option<Bytes>,
    app_status: Option<(AppState, Bytes)>,
    frame: Option<Bytes>,
}

impl Shared {
    fn publish(&self, envelope: Bytes) {
        if let Ok(DeviceMessage {
            payload: Some(payload),
        }) = DeviceMessage::decode(envelope.clone())
        {
            let mut latest = self.latest.lock().unwrap_or_else(PoisonError::into_inner);
            match payload {
                device_message::Payload::DeviceInfo(_) => {
                    latest.device_info = Some(envelope.clone())
                }
                device_message::Payload::AppStatus(status) => {
                    latest.app_status = Some((status.state(), envelope.clone()));
                }
                device_message::Payload::Frame(_) => latest.frame = Some(envelope.clone()),
                _ => {}
            }
        }
        // Having no clients is fine.
        let _ = self.updates.send(envelope);
    }

    fn replay(&self) -> Vec<Bytes> {
        let latest = self.latest.lock().unwrap_or_else(PoisonError::into_inner);
        let status = latest.app_status.as_ref().map(|(_, envelope)| envelope);
        [latest.device_info.as_ref(), status, latest.frame.as_ref()]
            .into_iter()
            .flatten()
            .cloned()
            .collect()
    }

    fn app_state(&self) -> Option<AppState> {
        let latest = self.latest.lock().unwrap_or_else(PoisonError::into_inner);
        latest.app_status.as_ref().map(|(state, _)| *state)
    }
}

/// Runs the device process, restarting it when a client asks.
async fn supervise(
    runtime: impl Fn() -> Command,
    shared: &Shared,
    mut inbox: mpsc::Receiver<Bytes>,
) -> Result<()> {
    loop {
        let started = Instant::now();
        let mut child = runtime()
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .kill_on_drop(true)
            .spawn()
            .context("cannot start the device runtime")?;
        let (Some(mut stdin), Some(stdout), Some(stderr)) =
            (child.stdin.take(), child.stdout.take(), child.stderr.take())
        else {
            bail!("the device runtime has no stdio");
        };

        let restart = tokio::select! {
            restart = async {
                while let Some(envelope) = inbox.recv().await {
                    if is_restart(&envelope) {
                        return true;
                    }
                    // A runtime that died shows up as its exit below.
                    let _ = write_envelope(&mut stdin, &envelope).await;
                }
                false
            } => restart,
            result = async {
                tokio::try_join!(read_device(stdout, shared, started), read_logs(stderr, shared))?;
                child.wait().await.map_err(anyhow::Error::from)
            } => {
                let status = result?;
                if matches!(shared.app_state(), Some(AppState::Launching | AppState::Foreground)) {
                    shared.publish(app_status(AppState::Crashed, format!("The runtime exited ({status}).")));
                }
                false
            }
        };
        drop(child);
        if !restart && !wait_for_restart(&mut inbox).await {
            return Ok(());
        }
        eprintln!("irisrun: restarting the app");
    }
}

/// Waits until a client asks for a restart; a stopped app takes nothing else.
/// Returns false once every client and the server are gone.
async fn wait_for_restart(inbox: &mut mpsc::Receiver<Bytes>) -> bool {
    while let Some(envelope) = inbox.recv().await {
        if is_restart(&envelope) {
            return true;
        }
    }
    false
}

async fn read_device(
    stdout: impl AsyncRead + Unpin,
    shared: &Shared,
    started: Instant,
) -> Result<()> {
    let mut stdout = BufReader::new(stdout);
    let mut frames = 0u64;
    while let Some(envelope) = read_envelope(&mut stdout).await? {
        if frames == 0 && is_frame(&envelope) {
            eprintln!(
                "irisrun: first frame {:.1}s after start",
                started.elapsed().as_secs_f64()
            );
        }
        frames += u64::from(is_frame(&envelope));
        shared.publish(envelope);
    }
    let seconds = started.elapsed().as_secs_f64();
    eprintln!("irisrun: {frames} frames in {seconds:.0}s");
    Ok(())
}

/// Forwards the runtime's stderr to the terminal and to the UI's log.
async fn read_logs(stderr: impl AsyncRead + Unpin, shared: &Shared) -> Result<()> {
    let mut lines = BufReader::new(stderr).lines();
    while let Some(line) = lines.next_line().await? {
        eprintln!("{line}");
        let log = LogEntry {
            time: Some(SystemTime::now().into()),
            level: LogLevel::Info.into(),
            tag: "stderr".into(),
            message: line,
        };
        shared.publish(envelope(device_message::Payload::Log(log)));
    }
    Ok(())
}

async fn device_socket(socket: WebSocketUpgrade, State(shared): State<Arc<Shared>>) -> Response {
    socket.on_upgrade(|socket| serve_client(socket, shared))
}

async fn serve_client(socket: WebSocket, shared: Arc<Shared>) {
    let (mut sink, mut stream) = socket.split();
    // Subscribe before the replay so nothing falls in between.
    let mut updates = shared.updates.subscribe();
    for envelope in shared.replay() {
        if sink.send(Message::Binary(envelope)).await.is_err() {
            return;
        }
    }
    loop {
        tokio::select! {
            update = updates.recv() => match update {
                Ok(envelope) => if sink.send(Message::Binary(envelope)).await.is_err() { return },
                // A slow client skips what it missed; the next frame is complete anyway.
                Err(broadcast::error::RecvError::Lagged(_)) => {}
                Err(broadcast::error::RecvError::Closed) => return,
            },
            incoming = stream.next() => match incoming {
                Some(Ok(Message::Binary(envelope))) => {
                    if shared.commands.send(envelope).await.is_err() {
                        return;
                    }
                }
                Some(Ok(_)) => {}
                Some(Err(_)) | None => return,
            },
        }
    }
}

/// The Device UI from apps/web/dist. Debug builds read it from disk, so
/// `pnpm build` is enough to update it; release builds embed it.
#[derive(rust_embed::Embed)]
#[folder = "../../apps/web/dist"]
#[allow_missing = true]
struct DeviceUi;

async fn device_ui(uri: Uri) -> Response {
    let path = match uri.path().trim_start_matches('/') {
        "" => "index.html",
        path => path,
    };
    match DeviceUi::get(path) {
        Some(file) => (
            [(header::CONTENT_TYPE, file.metadata.mimetype())],
            file.data,
        )
            .into_response(),
        None if path == "index.html" => (
            StatusCode::NOT_FOUND,
            "The Device UI is not built: run `pnpm build` first.",
        )
            .into_response(),
        None => StatusCode::NOT_FOUND.into_response(),
    }
}

/// Reads one size-delimited envelope, or `None` where the stream ends.
async fn read_envelope(reader: &mut (impl AsyncRead + Unpin)) -> Result<Option<Bytes>> {
    let mut len = 0u64;
    for shift in (0..64).step_by(7) {
        let byte = match reader.read_u8().await {
            Ok(byte) => byte,
            Err(error) if error.kind() == ErrorKind::UnexpectedEof && shift == 0 => {
                return Ok(None);
            }
            Err(error) => return Err(error.into()),
        };
        len |= u64::from(byte & 0x7f) << shift;
        if byte & 0x80 == 0 {
            ensure!(
                len <= MAX_ENVELOPE,
                "the runtime sent a {len}-byte envelope; is something else printing to its stdout?"
            );
            let mut envelope = vec![0; usize::try_from(len)?];
            reader.read_exact(&mut envelope).await?;
            return Ok(Some(envelope.into()));
        }
    }
    bail!("an envelope length is not a valid varint")
}

async fn write_envelope(writer: &mut (impl AsyncWrite + Unpin), envelope: &[u8]) -> Result<()> {
    let mut delimited = Vec::with_capacity(envelope.len() + 10);
    prost::encoding::encode_varint(envelope.len() as u64, &mut delimited);
    delimited.extend_from_slice(envelope);
    writer.write_all(&delimited).await?;
    Ok(writer.flush().await?)
}

fn is_restart(envelope: &[u8]) -> bool {
    matches!(
        HostMessage::decode(envelope),
        Ok(HostMessage {
            payload: Some(host_message::Payload::AppControl(AppControl {
                action: Some(app_control::Action::Restart(_))
            }))
        })
    )
}

fn is_frame(envelope: &[u8]) -> bool {
    matches!(
        DeviceMessage::decode(envelope),
        Ok(DeviceMessage {
            payload: Some(device_message::Payload::Frame(_))
        })
    )
}

fn app_status(state: AppState, crash_report: String) -> Bytes {
    envelope(device_message::Payload::AppStatus(AppStatus {
        state: state.into(),
        app_id: String::new(),
        crash_report,
    }))
}

fn envelope(payload: device_message::Payload) -> Bytes {
    DeviceMessage {
        payload: Some(payload),
    }
    .encode_to_vec()
    .into()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn envelopes_survive_a_byte_stream() {
        let big = vec![7; 300]; // needs a two-byte length
        let mut stream = Vec::new();
        write_envelope(&mut stream, b"hi").await.unwrap();
        write_envelope(&mut stream, &big).await.unwrap();

        let mut reader = stream.as_slice();
        assert_eq!(
            read_envelope(&mut reader).await.unwrap().as_deref(),
            Some(&b"hi"[..])
        );
        assert_eq!(
            read_envelope(&mut reader).await.unwrap().as_deref(),
            Some(&big[..])
        );
        assert!(read_envelope(&mut reader).await.unwrap().is_none());
    }
}
