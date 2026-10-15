import type { LevelCode } from "../../components/LevelChip";

/**
 * A row of the Logs panel. A `stack` row continues the line above it (a stack
 * frame) and shows or hides with it; a `separator` is a note across the list.
 */
export type LogRow =
  | { kind?: "line"; time: string; level: LevelCode; tag: string; message: string }
  | { kind: "stack"; message: string }
  | { kind: "separator"; message: string };

/** Counts for the whole stream when the rows are only part of it. */
export interface LogCounts {
  lines: number;
  /** Lines that pass the package and level filters. */
  shown: number;
  warnings: number;
  errors: number;
  /** Lines that arrived while auto-scroll was paused. */
  unseen: number;
}

/** Kedai on Android, from the Main artboard. */
export const kedaiLogs: LogRow[] = [
  { time: "21:04:11.902", level: "I", tag: "ActivityManager", message: "Start proc 18244:com.kedai.shop/u0a191 for top-activity {com.kedai.shop/.MainActivity}" },
  { time: "21:04:12.118", level: "D", tag: "kedai.App", message: "Koin started · 42 definitions in 18 ms" },
  { time: "21:04:12.240", level: "I", tag: "iris", message: "App ready · cold start 1.18 s" },
  { time: "21:04:12.377", level: "D", tag: "OkHttp", message: "--> GET https://api.kedai.example/v2/home?locale=vi-VN" },
  { time: "21:04:12.611", level: "D", tag: "OkHttp", message: "<-- 200 OK https://api.kedai.example/v2/home (234ms, 18.2 kB)" },
  { time: "21:04:12.640", level: "I", tag: "Choreographer", message: "Skipped 3 frames! The application may be doing too much work on its main thread." },
  { time: "21:04:12.702", level: "D", tag: "kedai.Home", message: "Rendered 24 products · 2 sections" },
  { time: "21:04:13.015", level: "D", tag: "Glide", message: "Loaded 8/8 thumbnails from memory cache" },
  { time: "21:04:15.230", level: "I", tag: "kedai.Cart", message: "addItem(sku=TS-2041, qty=1) → cart size 2" },
  { time: "21:04:15.233", level: "W", tag: "kedai.Cart", message: "Coupon KEDAI30 not applicable to sale items; skipping" },
  { time: "21:04:15.481", level: "D", tag: "OkHttp", message: "--> POST https://api.kedai.example/v2/cart/items (96-byte body)" },
  { time: "21:04:25.486", level: "E", tag: "OkHttp", message: "<-- HTTP FAILED: java.net.SocketTimeoutException: timeout" },
  { kind: "stack", message: "    at okhttp3.internal.http2.Http2Stream$StreamTimeout.newTimeoutException(Http2Stream.kt:677)" },
  { kind: "stack", message: "    at com.kedai.shop.data.CartRepository.add(CartRepository.kt:58)" },
  { kind: "stack", message: "    at com.kedai.shop.ui.cart.CartViewModel$addItem$1.invokeSuspend(CartViewModel.kt:41)" },
  { time: "21:04:25.490", level: "W", tag: "kedai.Cart", message: "Retrying addItem in 2s (attempt 2/3)" },
  { time: "21:04:27.512", level: "D", tag: "OkHttp", message: "<-- 201 Created https://api.kedai.example/v2/cart/items (188ms)" },
  { time: "21:04:31.004", level: "I", tag: "iris", message: "File changed · ui/cart/CartViewModel.kt" },
  { time: "21:04:31.416", level: "I", tag: "iris", message: "Hot reload applied · 1 class swapped in 412 ms" },
  { time: "21:04:31.420", level: "D", tag: "kedai.Cart", message: "CartViewModel restored state · 2 items" },
  { time: "21:04:33.871", level: "I", tag: "kedai.Analytics", message: "event=view_item item_id=HP-118 list=best_sellers" },
  { time: "21:04:34.102", level: "D", tag: "OkHttp", message: "--> GET https://api.kedai.example/v2/products/HP-118" },
  { time: "21:04:34.297", level: "D", tag: "OkHttp", message: "<-- 200 OK https://api.kedai.example/v2/products/HP-118 (195ms, 6.4 kB)" },
  { time: "21:04:36.550", level: "W", tag: "StrictMode", message: "DiskReadViolation at com.kedai.shop.data.Prefs.load(Prefs.kt:22)" },
  { time: "21:04:38.009", level: "I", tag: "kedai.Push", message: "Push token registered · via Iris Push adapter" },
  { time: "21:04:40.212", level: "D", tag: "kedai.Home", message: "Pull-to-refresh · 24 products" },
];

/** The whole stream as the Main artboard counts it; `kedaiLogs` are its first lines. */
export const kedaiLogCounts: LogCounts = { lines: 12481, shown: 2304, warnings: 18, errors: 3, unseen: 214 };

export const kedaiPackages = ["com.kedai.shop", "com.kedai.shop:push", "All packages"];
