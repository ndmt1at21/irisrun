/** A card on the Projects page. */
export interface Project {
  name: string;
  repo: string;
  /** The letter on the tile and the tile color. */
  initial: string;
  tint: string;
  platform: "Android" | "iOS";
  framework: string;
  /** Sessions running now; above 0 the card shows "N running". */
  running: number;
  sessions7d: number;
  /** Null shows "Not set". */
  defaultDevice: string | null;
  /** Already formatted; null means nobody has opened the project, which marks it New. */
  lastActive: string | null;
}

/** Most recently active first, the order the API returns them in. */
export const projects: Project[] = [
  {
    name: "kedai-ios",
    repo: "github.com/acme/kedai-ios",
    initial: "K",
    tint: "#0a7a6f",
    platform: "iOS",
    framework: "SwiftUI",
    running: 2,
    sessions7d: 31,
    defaultDevice: "iPhone 15 Pro",
    lastActive: "Now · 2 live",
  },
  {
    name: "kedai-android",
    repo: "github.com/acme/kedai-android",
    initial: "K",
    tint: "#006a60",
    platform: "Android",
    framework: "Kotlin",
    running: 0,
    sessions7d: 46,
    defaultDevice: "Pixel 8",
    lastActive: "12 min ago",
  },
  {
    name: "kedai-seller-android",
    repo: "github.com/acme/kedai-seller",
    initial: "S",
    tint: "#9a4a1c",
    platform: "Android",
    framework: "Java",
    running: 0,
    sessions7d: 8,
    defaultDevice: "Galaxy A55",
    lastActive: "Yesterday",
  },
  {
    name: "paygate-sample-ios",
    repo: "github.com/acme/paygate-sample",
    initial: "P",
    tint: "#5b5bd6",
    platform: "iOS",
    framework: "UIKit",
    running: 0,
    sessions7d: 0,
    defaultDevice: null,
    lastActive: null,
  },
];
