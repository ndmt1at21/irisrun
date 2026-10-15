import { create, fromBinary, toBinary } from "@bufbuild/protobuf";
import { DeviceMessageSchema, HostMessageSchema } from "../gen/irisrun/device/v1alpha1/device_pb";
import type { ConnectionEvents, HostPayload } from "./connection";

export interface WebRtcEvents extends ConnectionEvents {
  /** The device's screen, as a video track. */
  onStream(stream: MediaStream): void;
}

/**
 * The Device Protocol over WebRTC, as irisrun-gateway serves cloud devices:
 * the screen arrives as an H.264 video track and envelopes travel on a data
 * channel, one per message. Reconnects every second until closed.
 */
export class WebRtcConnection {
  readonly #gateway: string;
  readonly #events: WebRtcEvents;
  #peer: RTCPeerConnection | undefined;
  #channel: RTCDataChannel | undefined;
  #closed = false;

  constructor(gateway: string, events: WebRtcEvents) {
    this.#gateway = gateway;
    this.#events = events;
    void this.#connect();
  }

  send(payload: HostPayload): void {
    if (this.#channel?.readyState !== "open") return;
    this.#channel.send(toBinary(HostMessageSchema, create(HostMessageSchema, { payload })));
  }

  close(): void {
    this.#closed = true;
    this.#peer?.close();
  }

  async #connect(): Promise<void> {
    const peer = new RTCPeerConnection();
    this.#peer = peer;
    peer.addTransceiver("video", { direction: "recvonly" });
    peer.ontrack = (event) => this.#events.onStream(new MediaStream([event.track]));
    peer.onconnectionstatechange = () => {
      if (["failed", "disconnected", "closed"].includes(peer.connectionState)) this.#retry(peer);
    };
    const channel = peer.createDataChannel("device");
    channel.binaryType = "arraybuffer";
    channel.onopen = () => this.#events.onConnectedChange(true);
    channel.onmessage = (event: MessageEvent<ArrayBuffer>) => {
      this.#events.onMessage(fromBinary(DeviceMessageSchema, new Uint8Array(event.data)));
    };
    this.#channel = channel;

    try {
      await peer.setLocalDescription(await peer.createOffer());
      // text/plain keeps the cross-origin POST a simple request, without a preflight.
      const response = await fetch(new URL("offer", this.#gateway), {
        method: "POST",
        headers: { "Content-Type": "text/plain" },
        body: JSON.stringify(peer.localDescription),
      });
      if (!response.ok) throw new Error(await response.text());
      await peer.setRemoteDescription((await response.json()) as RTCSessionDescriptionInit);
    } catch {
      this.#retry(peer);
    }
  }

  #retry(peer: RTCPeerConnection): void {
    if (peer !== this.#peer) return;
    this.#peer = undefined;
    peer.close();
    this.#events.onConnectedChange(false);
    if (!this.#closed) setTimeout(() => void this.#connect(), 1000);
  }
}
