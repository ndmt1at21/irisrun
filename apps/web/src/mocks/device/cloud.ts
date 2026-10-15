import type { RemoteSession } from "../../device/shell/DeviceHeader";
import type { LogRow } from "./logs";

/** Kedai on a cloud iPhone 15 Pro in Singapore, with the session details open (CloudSession). */
export const cloudSession: RemoteSession = {
  latency: 38,
  region: "Singapore",
  endsIn: "24:12",
  recordingForReplay: true,
  details: {
    defaultOpen: true,
    duration: "30:00",
    facts: [
      { label: "Latency", value: "38 ms · jitter 4 ms", mono: true },
      { label: "Host", value: "sg-m2-01 · Apple M2" },
      { label: "Simulator", value: "iPhone 15 Pro · iOS 18.0" },
      { label: "Video", value: "60 fps · adaptive", mono: true },
      { label: "Started", value: "21:08 · by Minh Tran" },
    ],
  },
};

export const cloudLogs: LogRow[] = [
  { time: "21:08:14.020", level: "I", tag: "iris", message: "Cloud session started · sg-m2-01 · iPhone 15 Pro" },
  { time: "21:08:21.388", level: "I", tag: "iris", message: "Installed Kedai.app (Debug) · 41.2 MB uploaded" },
  { time: "21:08:23.904", level: "I", tag: "Kedai · App", message: "Launched · cold start 1.42 s" },
  { time: "21:08:24.310", level: "D", tag: "Kedai · Network", message: "GET /v2/home → 200 (212 ms)" },
  { time: "21:09:02.551", level: "I", tag: "Kedai · Stores", message: "Tapped “Look Around” · store=Nguyen Hue" },
  { time: "21:09:02.574", level: "D", tag: "Kedai · Stores", message: "Requesting Look Around scene…" },
  { time: "21:09:03.118", level: "I", tag: "Kedai · Stores", message: "Look Around scene ready" },
  { time: "21:09:03.120", level: "D", tag: "MapKit", message: "Loaded 14 imagery tiles" },
  { time: "21:09:11.007", level: "W", tag: "Kedai · Analytics", message: "Batch upload deferred · network constrained" },
  { time: "21:09:14.662", level: "D", tag: "Kedai · Stores", message: "Look Around pan · heading 212°" },
];

/** Kedai on a Galaxy A55 in Jakarta, up to the moment the connection dropped (CloudReconnecting). */
export const reconnectingLogs: LogRow[] = [
  { time: "21:13:41.220", level: "I", tag: "ActivityManager", message: "Displayed com.kedai.shop/.MainActivity: +612ms" },
  { time: "21:13:41.508", level: "D", tag: "OkHttp", message: "--> GET https://api.kedai.example/v2/home?locale=id-ID" },
  { time: "21:13:41.790", level: "D", tag: "OkHttp", message: "<-- 200 OK (282ms, 17.9 kB)" },
  { time: "21:13:42.004", level: "D", tag: "kedai.Home", message: "Rendered 24 products · 2 sections" },
  { time: "21:13:58.316", level: "I", tag: "kedai.Analytics", message: "event=view_home locale=id-ID" },
  { time: "21:14:03.871", level: "D", tag: "Glide", message: "Loaded 8/8 thumbnails" },
  { time: "21:14:07.902", level: "W", tag: "kedai.Net", message: "Slow response from /v2/recommendations (2.4 s)" },
  { time: "21:14:08.115", level: "D", tag: "kedai.Home", message: "Scroll offset 0 → 412" },
  { kind: "separator", message: "Connection lost at 21:14:08 · buffering on device" },
];
