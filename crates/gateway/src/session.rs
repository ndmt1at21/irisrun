//! One browser's WebRTC session: the device's H.264 goes out on a video
//! track as it is, without decoding or encoding again; Device Protocol
//! envelopes travel both ways on a data channel.

use std::net::IpAddr;
use std::sync::Arc;
use std::time::Instant;

use anyhow::Result;
use irisrun_protocol::device::v1alpha1::{
    DeviceInfo, DeviceMessage, Display, HostMessage, device_message, host_message,
};
use prost::Message as _;
use str0m::change::{SdpAnswer, SdpOffer};
use str0m::format::Codec;
use str0m::media::{Frequency, MediaKind, MediaTime, Mid, Pt};
use str0m::net::{Protocol, Receive};
use str0m::{Candidate, Event, IceConnectionState, Input, Output, Rtc};
use tokio::net::UdpSocket;
use tokio::sync::{broadcast, mpsc, watch};

use crate::scrcpy::control;

/// One encoded frame, ready for every session.
pub struct Frame {
    pub key: bool,
    /// Annex B, with SPS and PPS in front of key frames.
    pub data: Arc<[u8]>,
}

/// What every session shares with the device.
pub struct Device {
    pub frames: broadcast::Sender<Arc<Frame>>,
    /// Messages for scrcpy's control socket.
    pub control: mpsc::Sender<Vec<u8>>,
    /// The video size, which touch positions refer to.
    pub size: watch::Receiver<(u32, u32)>,
    /// Without the display, which comes from the video size.
    pub info: DeviceInfo,
}

/// Answers a browser's offer and runs the session until the browser leaves.
pub async fn accept(offer: SdpOffer, media_ip: IpAddr, device: Arc<Device>) -> Result<SdpAnswer> {
    let mut rtc = Rtc::builder().build(Instant::now());
    let socket = UdpSocket::bind((media_ip, 0)).await?;
    rtc.add_local_candidate(Candidate::host(socket.local_addr()?, "udp")?);
    let answer = rtc.sdp_api().accept_offer(offer)?;
    tokio::spawn(async move {
        match run(rtc, socket, &device).await {
            Ok(()) => eprintln!("gateway: a browser left"),
            Err(error) => eprintln!("gateway: a session failed: {error:#}"),
        }
    });
    Ok(answer)
}

async fn run(mut rtc: Rtc, socket: UdpSocket, device: &Device) -> Result<()> {
    let local = socket.local_addr()?;
    let mut frames = device.frames.subscribe();
    let mut video: Option<(Mid, Pt)> = None;
    // Frames before the first key frame cannot be decoded.
    let mut waiting_for_key_frame = true;
    let started = Instant::now();
    let mut buffer = vec![0; 2000];
    loop {
        let deadline = loop {
            match rtc.poll_output()? {
                Output::Timeout(deadline) => break deadline,
                Output::Transmit(transmit) => {
                    socket
                        .send_to(&transmit.contents, transmit.destination)
                        .await?;
                }
                Output::Event(event) => match event {
                    Event::IceConnectionStateChange(IceConnectionState::Disconnected) => {
                        return Ok(());
                    }
                    Event::MediaAdded(media) if media.kind == MediaKind::Video => {
                        video = rtc.writer(media.mid).and_then(|writer| {
                            writer
                                .payload_params()
                                .find(|params| {
                                    params.spec().codec == Codec::H264
                                        && params.spec().format.packetization_mode == Some(1)
                                })
                                .map(|params| (media.mid, params.pt()))
                        });
                        if video.is_none() {
                            anyhow::bail!("the browser cannot receive H.264");
                        }
                        device.control.send(control::reset_video()).await?;
                    }
                    Event::ChannelOpen(id, _) => {
                        let (width, height) = *device.size.borrow();
                        let info = DeviceInfo {
                            display: Some(Display {
                                width_px: width,
                                height_px: height,
                                scale: 0.0,
                            }),
                            ..device.info.clone()
                        };
                        let info = DeviceMessage {
                            payload: Some(device_message::Payload::DeviceInfo(info)),
                        };
                        if let Some(mut channel) = rtc.channel(id) {
                            channel.write(true, &info.encode_to_vec())?;
                        }
                    }
                    Event::ChannelData(data) => {
                        if let Ok(HostMessage {
                            payload: Some(host_message::Payload::Input(input)),
                        }) = HostMessage::decode(data.data.as_slice())
                        {
                            let size = *device.size.borrow();
                            for message in crate::input::controls(&input, size) {
                                device.control.send(message).await?;
                            }
                        }
                    }
                    Event::KeyframeRequest(_) => {
                        device.control.send(control::reset_video()).await?
                    }
                    _ => {}
                },
            }
        };

        tokio::select! {
            received = socket.recv_from(&mut buffer) => {
                let (length, source) = received?;
                let receive = Receive {
                    proto: Protocol::Udp,
                    source,
                    destination: local,
                    contents: buffer[..length].try_into()?,
                };
                rtc.handle_input(Input::Receive(Instant::now(), receive))?;
            }
            frame = frames.recv() => match frame {
                Ok(frame) => {
                    waiting_for_key_frame &= !frame.key;
                    if let (Some((mid, pt)), false) = (video, waiting_for_key_frame)
                        && let Some(writer) = rtc.writer(mid)
                    {
                        // Timestamps from the arrival clock: the device's own restart with
                        // every encoder reset, which would make them jump back.
                        let now = Instant::now();
                        let ticks = (now - started).as_micros() as u64 * 9 / 100;
                        writer.write(pt, now, MediaTime::new(ticks, Frequency::NINETY_KHZ), frame.data.clone())?;
                    }
                }
                Err(broadcast::error::RecvError::Lagged(_)) => {
                    waiting_for_key_frame = true;
                    device.control.send(control::reset_video()).await?;
                }
                Err(broadcast::error::RecvError::Closed) => return Ok(()),
            },
            () = tokio::time::sleep_until(deadline.into()) => {
                rtc.handle_input(Input::Timeout(Instant::now()))?;
            }
        }
    }
}
