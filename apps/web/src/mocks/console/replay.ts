import type { LevelCode } from "../../components/LevelChip";

/** A log line, request or event in the synced panel; `at` is seconds into the recording. */
export interface ReplayRow {
  at: number;
  level: LevelCode;
  tag: string;
  message: string;
}

/** A tap the recording captured, at a point of the 324 × 702 screen. */
export interface ReplayTap {
  at: number;
  x: number;
  y: number;
}

export type MarkTone = "foreground" | "primary" | "muted" | "info" | "success" | "warning" | "destructive";

/** A mark on a timeline track: a span when it has a `length` in seconds, a 3 px tick otherwise. */
export interface ReplayMark {
  at: number;
  length?: number;
  tone: MarkTone;
}

export interface SessionReplay {
  /** The header line: project, device, region, when and who. */
  meta: string;
  /** Seconds. */
  duration: number;
  /** Where playback starts, in seconds. */
  start: number;
  logs: ReplayRow[];
  network: ReplayRow[];
  events: ReplayRow[];
  /** The Taps track and the rings "Show taps" draws on the video. */
  taps: ReplayTap[];
  /** The tracks under Taps. */
  tracks: { label: string; marks: ReplayMark[] }[];
}

export const sessionReplay: SessionReplay = {
  meta: "kedai-ios · iPhone 15 Pro · cloud simulator · Singapore · Oct 14, 21:08–21:31 · Minh Tran",
  duration: 1385,
  start: 54.6,
  logs: [
    { at: 6, level: "I", tag: "iris", message: "Cloud session started · sg-m2-01" },
    { at: 13.3, level: "I", tag: "iris", message: "Installed Kedai.app (Debug)" },
    { at: 15.9, level: "I", tag: "Kedai · App", message: "Launched · cold start 1.42 s" },
    { at: 16.3, level: "D", tag: "Kedai · Network", message: "GET /v2/home → 200 (212 ms)" },
    { at: 31.8, level: "I", tag: "Kedai · Stores", message: "Opened store list · 6 stores nearby" },
    { at: 48.5, level: "D", tag: "Kedai · Stores", message: "Selected store=Nguyen Hue" },
    { at: 54.5, level: "I", tag: "Kedai · Stores", message: "Tapped “Look Around”" },
    { at: 54.6, level: "D", tag: "Kedai · Stores", message: "Requesting Look Around scene…" },
    { at: 55.1, level: "I", tag: "Kedai · Stores", message: "Look Around scene ready" },
    { at: 69, level: "W", tag: "Kedai · Analytics", message: "Batch upload deferred · network constrained" },
    { at: 222.7, level: "E", tag: "Kedai · Checkout", message: "Payment sheet dismissed with error .cancelled" },
    { at: 435.2, level: "I", tag: "iris", message: "Hot reload · CheckoutView.swift" },
  ],
  network: [
    { at: 16.1, level: "D", tag: "GET 200", message: "/v2/home · 212 ms · 18.2 kB" },
    { at: 31.6, level: "D", tag: "GET 200", message: "/v2/stores?near=10.77,106.70 · 164 ms" },
    { at: 48.6, level: "D", tag: "GET 200", message: "/v2/stores/nguyen-hue · 98 ms · 4.1 kB" },
    { at: 54.6, level: "D", tag: "GET 200", message: "MapKit · Look Around scene · 512 ms" },
    { at: 220.4, level: "D", tag: "POST 201", message: "/v2/checkout/intent · 344 ms" },
    { at: 222.7, level: "E", tag: "POST —", message: "/v2/checkout/confirm · cancelled" },
    { at: 431, level: "D", tag: "GET 200", message: "/v2/cart · 141 ms · 2.3 kB" },
    { at: 860.2, level: "D", tag: "GET 200", message: "/v2/home · 188 ms · 18.1 kB" },
    { at: 872.9, level: "D", tag: "POST 201", message: "/v2/orders · 402 ms" },
  ],
  events: [
    { at: 15.9, level: "I", tag: "App", message: "Launched · cold start 1.42 s" },
    { at: 16.6, level: "D", tag: "Tap", message: "“Allow While Using App”" },
    { at: 31.8, level: "D", tag: "Tap", message: "Tab bar · Stores" },
    { at: 48.5, level: "D", tag: "Tap", message: "Store row · Kedai Nguyen Hue" },
    { at: 54.5, level: "D", tag: "Tap", message: "“Look Around”" },
    { at: 221.6, level: "D", tag: "Tap", message: "“Pay with Apple Pay”" },
    { at: 227.1, level: "D", tag: "Tap", message: "“Pay with Apple Pay”" },
    { at: 435.2, level: "I", tag: "Hot reload", message: "CheckoutView.swift" },
    { at: 567.9, level: "D", tag: "Tap", message: "“Pay with card”" },
    { at: 803.3, level: "I", tag: "Hot reload", message: "PaymentForm.swift" },
    { at: 872.6, level: "D", tag: "Tap", message: "“Place order”" },
    { at: 1385, level: "I", tag: "Session", message: "Ended by Minh Tran" },
  ],
  taps: [
    { at: 16.6, x: 162, y: 452 },
    { at: 31.8, x: 120, y: 668 },
    { at: 48.5, x: 162, y: 300 },
    { at: 54.5, x: 180, y: 206 },
    { at: 221.6, x: 162, y: 630 },
    { at: 227.1, x: 162, y: 630 },
    { at: 567.9, x: 162, y: 640 },
    { at: 872.6, x: 162, y: 640 },
  ],
  tracks: [
    {
      label: "Logs",
      marks: [
        { at: 0, length: 83.1, tone: "muted" },
        { at: 207.8, length: 55.4, tone: "muted" },
        { at: 554, length: 124.7, tone: "muted" },
        { at: 69, tone: "warning" },
        { at: 222.7, tone: "destructive" },
        { at: 664.8, tone: "warning" },
      ],
    },
    {
      label: "Network",
      marks: [
        { at: 15.2, length: 19.4, tone: "info" },
        { at: 44.3, length: 11.1, tone: "info" },
        { at: 218.8, length: 16.6, tone: "info" },
        { at: 429.4, length: 8.3, tone: "info" },
        { at: 858.7, length: 27.7, tone: "info" },
      ],
    },
    {
      label: "App",
      marks: [
        { at: 15.9, tone: "success" },
        { at: 435.2, tone: "primary" },
        { at: 803.3, tone: "primary" },
      ],
    },
  ],
};
