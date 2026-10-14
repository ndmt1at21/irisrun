import { create, fromBinary, type MessageInitShape, toBinary } from "@bufbuild/protobuf";
import { type DeviceMessage, DeviceMessageSchema, HostMessageSchema } from "../gen/irisrun/device/v1alpha1/device_pb";

export type HostPayload = MessageInitShape<typeof HostMessageSchema>["payload"];

export interface ConnectionEvents {
  onMessage(message: DeviceMessage): void;
  onConnectedChange(connected: boolean): void;
}

/**
 * The Device Protocol over a WebSocket, one envelope per binary message.
 * Reconnects every second until closed, since the CLI may restart.
 */
export class DeviceConnection {
  readonly #url: string;
  readonly #events: ConnectionEvents;
  #socket: WebSocket | undefined;
  #closed = false;

  constructor(url: string, events: ConnectionEvents) {
    this.#url = url;
    this.#events = events;
    this.#connect();
  }

  send(payload: HostPayload): void {
    if (this.#socket?.readyState !== WebSocket.OPEN) return;
    this.#socket.send(toBinary(HostMessageSchema, create(HostMessageSchema, { payload })));
  }

  close(): void {
    this.#closed = true;
    this.#socket?.close();
  }

  #connect(): void {
    const socket = new WebSocket(this.#url);
    socket.binaryType = "arraybuffer";
    socket.onopen = () => this.#events.onConnectedChange(true);
    socket.onmessage = (event: MessageEvent<ArrayBuffer>) => {
      this.#events.onMessage(fromBinary(DeviceMessageSchema, new Uint8Array(event.data)));
    };
    socket.onclose = () => {
      this.#events.onConnectedChange(false);
      if (!this.#closed) setTimeout(() => this.#connect(), 1000);
    };
    this.#socket = socket;
  }
}

/** The CLI serves the UI and the device socket from the same origin. */
export function deviceUrl(location: Location): string {
  const scheme = location.protocol === "https:" ? "wss:" : "ws:";
  return `${scheme}//${location.host}/device`;
}
