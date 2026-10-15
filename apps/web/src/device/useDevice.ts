import { useCallback, useEffect, useRef, useState } from "react";
import type { AppStatus, DeviceInfo } from "../gen/irisrun/device/v1alpha1/device_pb";
import type { Frame } from "../gen/irisrun/device/v1alpha1/frame_pb";
import type { LogEntry } from "../gen/irisrun/device/v1alpha1/log_pb";
import { type ConnectionEvents, DeviceConnection, type HostPayload } from "./connection";
import { WebRtcConnection } from "./webrtc";

const MAX_LOGS = 500;

export interface DeviceState {
  connected: boolean;
  info?: DeviceInfo;
  status?: AppStatus;
  logs: LogEntry[];
  /** The screen as video, from a cloud device. */
  stream?: MediaStream;
}

/**
 * Connects to the device at `url`: the CLI's WebSocket, or an irisrun-gateway
 * over WebRTC. Frames go to subscribers, not React state.
 */
export function useDevice(url: string, transport: "websocket" | "webrtc" = "websocket") {
  const [state, setState] = useState<DeviceState>({ connected: false, logs: [] });
  const connection = useRef<DeviceConnection | WebRtcConnection | undefined>(undefined);
  const frameSinks = useRef(new Set<(frame: Frame) => void>());

  useEffect(() => {
    const events: ConnectionEvents = {
      onConnectedChange: (connected) => setState((state) => ({ ...state, connected })),
      onMessage: ({ payload }) => {
        switch (payload.case) {
          case "frame":
            for (const sink of frameSinks.current) sink(payload.value);
            break;
          case "deviceInfo":
            setState((state) => ({ ...state, info: payload.value }));
            break;
          case "appStatus":
            setState((state) => ({ ...state, status: payload.value }));
            break;
          case "log":
            setState((state) => ({ ...state, logs: [...state.logs.slice(1 - MAX_LOGS), payload.value] }));
            break;
          case "adapterRequest":
          case undefined:
            break;
        }
      },
    };
    const device =
      transport === "webrtc"
        ? new WebRtcConnection(url, { ...events, onStream: (stream) => setState((state) => ({ ...state, stream })) })
        : new DeviceConnection(url, events);
    connection.current = device;
    return () => device.close();
  }, [url, transport]);

  const send = useCallback((payload: HostPayload) => connection.current?.send(payload), []);
  const subscribeFrames = useCallback((sink: (frame: Frame) => void) => {
    frameSinks.current.add(sink);
    return () => {
      frameSinks.current.delete(sink);
    };
  }, []);

  return { state, send, subscribeFrames };
}
