/** A card under "Running now" on the Sessions page. */
export interface LiveSession {
  id: string;
  device: string;
  /** e.g. "Cloud simulator · Singapore". */
  where: string;
  project: string;
  user: string;
  /** Already formatted, e.g. "23:12". */
  elapsed: string;
  /** Time left before the session limit ends it, e.g. "6:48". */
  endsIn: string;
  latencyMs: number;
  /** The thumbnail's screen color, until it shows a real frame. */
  screen: string;
}

export type EndReason = "user" | "time-limit" | "connection-lost";

/** A row of the Ended table. */
export interface EndedSession {
  id: string;
  /** Already formatted, e.g. "Today 20:41". */
  started: string;
  project: string;
  device: string;
  /** The city the device or cloud region is in. */
  where: string;
  user: string;
  /** Already formatted, e.g. "18m". */
  length: string;
  endReason: EndReason;
  /** False once the recording is older than the 30 days it is kept. */
  hasRecording: boolean;
}

/** Ended sessions in the period, of which the table shows the latest. */
export const endedTotal = 128;

export const liveSessions: LiveSession[] = [
  {
    id: "ses_7f2c91", device: "iPhone 15 Pro", where: "Cloud simulator · Singapore", project: "kedai-ios",
    user: "Minh Tran", elapsed: "23:12", endsIn: "6:48", latencyMs: 38, screen: "#cfe3f5",
  },
  {
    id: "ses_91ab3e", device: "Galaxy S24", where: "Real device · Ho Chi Minh City", project: "kedai-android",
    user: "Linh Pham", elapsed: "11:05", endsIn: "18:55", latencyMs: 21, screen: "#fbf8fd",
  },
  {
    id: "ses_c4d802", device: "iPhone 15", where: "Cloud simulator · Singapore", project: "kedai-ios",
    user: "Arjun Mehta", elapsed: "04:31", endsIn: "25:29", latencyMs: 64, screen: "#fde8da",
  },
];

/** Newest first. */
export const endedSessions: EndedSession[] = [
  {
    id: "ses_5e10a4", started: "Today 20:41", project: "kedai-android", device: "Galaxy A55", where: "Jakarta",
    user: "Rizky Pratama", length: "18m", endReason: "user", hasRecording: true,
  },
  {
    id: "ses_4b7f19", started: "Today 19:02", project: "kedai-ios", device: "iPhone 15 Pro", where: "Singapore",
    user: "Minh Tran", length: "30m", endReason: "time-limit", hasRecording: true,
  },
  {
    id: "ses_39c2e7", started: "Today 16:20", project: "kedai-seller-android", device: "Redmi Note 13",
    where: "Ho Chi Minh City", user: "Linh Pham", length: "9m", endReason: "connection-lost", hasRecording: true,
  },
  {
    id: "ses_2a8d50", started: "Oct 13, 11:47", project: "kedai-android", device: "Reno11 F", where: "Bangkok",
    user: "Somchai K.", length: "26m", endReason: "user", hasRecording: true,
  },
  {
    id: "ses_1f64bb", started: "Oct 12, 09:15", project: "kedai-ios", device: "iPhone 13", where: "Tokyo",
    user: "Yuki Sato", length: "14m", endReason: "user", hasRecording: true,
  },
  {
    id: "ses_0d93c6", started: "Sep 10, 15:03", project: "kedai-android", device: "Pixel 8", where: "Singapore",
    user: "Minh Tran", length: "22m", endReason: "user", hasRecording: false,
  },
];
