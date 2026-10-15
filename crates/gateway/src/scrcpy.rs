//! Mirrors and controls an Android device through scrcpy-server
//! (github.com/Genymobile/scrcpy, Apache-2.0), which the gateway pushes over
//! adb. The server streams H.264 straight from the device's MediaCodec
//! encoder and injects input through InputManager, far faster than
//! `adb shell input`, which starts a JVM per event. The wire format follows
//! scrcpy v5.0.1: big-endian, as Java's DataInputStream reads it.

use std::path::{Path, PathBuf};
use std::time::{Duration, Instant};

use anyhow::{Context, Result, bail, ensure};
use tokio::io::AsyncReadExt;
use tokio::net::TcpStream;
use tokio::process::{Child, Command};

/// The version the pushed server must have; scrcpy refuses any other.
pub const SERVER_VERSION: &str = "5.0.1";

const DEVICE_JAR: &str = "/data/local/tmp/irisrun-scrcpy-server.jar";
const PACKET_FLAG_CONFIG: u64 = 1 << 62;
const PACKET_FLAG_KEY_FRAME: u64 = 1 << 61;

pub struct Options {
    /// The longest side of the video, in pixels; the device scales down to it.
    pub max_size: u32,
    pub bit_rate: u32,
}

/// A running scrcpy-server. Dropping it stops the server.
pub struct Server {
    pub name: String,
    pub video: VideoStream,
    pub control: TcpStream,
    /// The `adb shell` running the server; dropping it stops the server.
    pub process: Child,
}

impl Server {
    pub async fn start(adb: &Path, serial: &str, jar: &Path, options: &Options) -> Result<Server> {
        let adb = Adb {
            path: adb.to_owned(),
            serial: serial.to_owned(),
        };
        adb.run(&["push", &jar.display().to_string(), DEVICE_JAR])
            .await?;
        // Any 31-bit id; it only has to differ between servers on one device.
        let scid = format!("{:08x}", std::process::id() & 0x7fff_ffff);
        let port = std::net::TcpListener::bind("127.0.0.1:0")?
            .local_addr()?
            .port();
        adb.run(&[
            "forward",
            &format!("tcp:{port}"),
            &format!("localabstract:scrcpy_{scid}"),
        ])
        .await?;

        let process = adb
            .command()
            .args([
                "shell",
                &format!("CLASSPATH={DEVICE_JAR}"),
                "app_process",
                "/",
                "com.genymobile.scrcpy.Server",
                SERVER_VERSION,
                &format!("scid={scid}"),
                "tunnel_forward=true",
                "audio=false",
                "control=true",
                "video_codec=h264",
                &format!("max_size={}", options.max_size),
                &format!("video_bit_rate={}", options.bit_rate),
                "max_fps=60",
                // Clipboard sync would send messages back on the control socket.
                "clipboard_autosync=false",
            ])
            .kill_on_drop(true)
            .spawn()
            .context("cannot start scrcpy-server")?;

        // The video socket comes first. Until the server listens, adb accepts
        // the connection and closes it at once, so wait for the dummy byte.
        let deadline = Instant::now() + Duration::from_secs(15);
        let mut video = loop {
            if let Ok(mut socket) = TcpStream::connect(("127.0.0.1", port)).await
                && socket.read_u8().await.is_ok()
            {
                break socket;
            }
            ensure!(Instant::now() < deadline, "scrcpy-server did not start");
            tokio::time::sleep(Duration::from_millis(100)).await;
        };
        let control = TcpStream::connect(("127.0.0.1", port)).await?;

        let mut name = [0u8; 64];
        video.read_exact(&mut name).await?;
        let name = String::from_utf8_lossy(&name)
            .trim_end_matches('\0')
            .to_owned();
        let codec = video.read_u32().await?;
        ensure!(
            codec == u32::from_be_bytes(*b"h264"),
            "the device sent codec {codec:#x}, not H.264"
        );
        Ok(Server {
            name,
            video: VideoStream { socket: video },
            control,
            process,
        })
    }
}

pub enum Packet {
    /// A new video session began, at this size: after start, rotation or a
    /// reset. Touch positions are in this size.
    Session { width: u32, height: u32 },
    /// SPS and PPS, which decoders need before the next key frame.
    Config(Vec<u8>),
    /// One encoded frame, as an Annex B byte stream. Its device timestamp
    /// restarts with every encoder reset, so it is left out.
    Frame { key: bool, data: Vec<u8> },
}

pub struct VideoStream {
    socket: TcpStream,
}

impl VideoStream {
    pub async fn next(&mut self) -> Result<Packet> {
        let mut header = [0u8; 12];
        self.socket.read_exact(&mut header).await?;
        if header[0] & 0x80 != 0 {
            let width = u32::from_be_bytes(header[4..8].try_into()?);
            let height = u32::from_be_bytes(header[8..12].try_into()?);
            return Ok(Packet::Session { width, height });
        }
        let pts_and_flags = u64::from_be_bytes(header[..8].try_into()?);
        let size = u32::from_be_bytes(header[8..12].try_into()?);
        if size > 16 << 20 {
            bail!("a {size}-byte video packet: the stream is corrupt");
        }
        let mut data = vec![0; size as usize];
        self.socket.read_exact(&mut data).await?;
        Ok(if pts_and_flags & PACKET_FLAG_CONFIG != 0 {
            Packet::Config(data)
        } else {
            Packet::Frame {
                key: pts_and_flags & PACKET_FLAG_KEY_FRAME != 0,
                data,
            }
        })
    }
}

/// Messages for the control socket.
pub mod control {
    /// Android's MotionEvent actions.
    pub const ACTION_DOWN: u8 = 0;
    pub const ACTION_UP: u8 = 1;
    pub const ACTION_MOVE: u8 = 2;
    pub const ACTION_CANCEL: u8 = 3;

    pub struct Touch {
        pub action: u8,
        pub pointer_id: u64,
        pub x: i32,
        pub y: i32,
        /// The video size the position refers to; the server drops touches
        /// meant for another size.
        pub width: u16,
        pub height: u16,
    }

    pub fn touch(touch: &Touch) -> Vec<u8> {
        let pressure: u16 = if touch.action == ACTION_UP {
            0
        } else {
            u16::MAX
        };
        let mut message = vec![2, touch.action];
        message.extend(touch.pointer_id.to_be_bytes());
        message.extend(touch.x.to_be_bytes());
        message.extend(touch.y.to_be_bytes());
        message.extend(touch.width.to_be_bytes());
        message.extend(touch.height.to_be_bytes());
        message.extend(pressure.to_be_bytes());
        message.extend(0u32.to_be_bytes()); // action button
        message.extend(0u32.to_be_bytes()); // buttons
        message
    }

    /// `down` is a KeyEvent ACTION_DOWN, otherwise ACTION_UP.
    pub fn key(down: bool, keycode: i32, meta_state: i32) -> Vec<u8> {
        let mut message = vec![0, u8::from(!down)];
        message.extend(keycode.to_be_bytes());
        message.extend(0i32.to_be_bytes()); // repeat
        message.extend(meta_state.to_be_bytes());
        message
    }

    /// Types ASCII text as key events, which keep their order.
    pub fn text(text: &str) -> Vec<u8> {
        let mut message = vec![1];
        message.extend((text.len() as u32).to_be_bytes());
        message.extend(text.as_bytes());
        message
    }

    /// Types any text into the focused field through the clipboard and a
    /// paste, since key events only reach ASCII on a stock keyboard map. The
    /// app reads the clipboard when it handles the paste, so a second paste
    /// sent before that wins the race.
    pub fn paste(text: &str) -> Vec<u8> {
        let mut message = vec![9];
        message.extend(0u64.to_be_bytes()); // sequence: 0 asks for no acknowledgement
        message.push(1); // paste
        message.extend((text.len() as u32).to_be_bytes());
        message.extend(text.as_bytes());
        message
    }

    /// Restarts the encoder, so that a key frame comes next.
    pub fn reset_video() -> Vec<u8> {
        vec![17]
    }
}

struct Adb {
    path: PathBuf,
    serial: String,
}

impl Adb {
    fn command(&self) -> Command {
        let mut command = Command::new(&self.path);
        command.args(["-s", &self.serial]);
        command
    }

    async fn run(&self, args: &[&str]) -> Result<()> {
        let output = self
            .command()
            .args(args)
            .output()
            .await
            .with_context(|| format!("cannot run {}", self.path.display()))?;
        ensure!(
            output.status.success(),
            "adb {} failed: {}",
            args.join(" "),
            String::from_utf8_lossy(&output.stderr).trim()
        );
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::control::*;

    #[test]
    fn touch_messages_match_scrcpy_layout() {
        let message = touch(&Touch {
            action: ACTION_DOWN,
            pointer_id: 1,
            x: 100,
            y: 200,
            width: 576,
            height: 1280,
        });
        // type, action, pointer id, x, y, width, height, pressure, buttons.
        assert_eq!(message.len(), 32);
        assert_eq!(&message[..2], &[2, 0]);
        assert_eq!(&message[10..14], &100i32.to_be_bytes());
        assert_eq!(&message[18..20], &576u16.to_be_bytes());
        assert_eq!(&message[22..24], &[0xff, 0xff]);
        assert_eq!(key(true, 4, 0).len(), 14);
        assert_eq!(paste("Việt")[..10], [9, 0, 0, 0, 0, 0, 0, 0, 0, 1]);
    }
}
