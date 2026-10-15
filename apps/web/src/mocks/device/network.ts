/** What the Network panel's type filter calls a request. */
export type RequestType = "api" | "image" | "ws";

/** A request the app made, as the Network panel lists it. */
export interface NetworkRequest {
  id: string;
  method: string;
  /** Path and query; the whole URL when `host` is empty, as for a WebSocket. */
  path: string;
  host: string;
  type: RequestType;
  /** The HTTP status; none when the request failed. */
  status?: number;
  /** Why the request failed. */
  error?: string;
  size: string;
  time: string;
  /** The waterfall bar: where it starts and how wide it is, in percent of the capture. */
  start: number;
  width: number;
  requestHeaders: [name: string, value: string][];
  responseHeaders: [name: string, value: string][];
  /** The request body, pretty-printed JSON. */
  payload?: string;
  /** The response body, pretty-printed JSON. */
  response?: string;
  /** Phases in order, in ms. */
  timing: [phase: string, ms: number][];
}

export interface NetworkCapture {
  /** The latest requests. */
  requests: NetworkRequest[];
  /** Everything captured this session. */
  total: number;
  transferred: string;
  failed: number;
  /** The request whose details are open. */
  selected?: string;
}

const API = "api.kedai.example";
const DATE = "Wed, 15 Oct 2026 02:42:07 GMT";
const JSON_HEADERS: [string, string][] = [
  ["content-type", "application/json; charset=utf-8"],
  ["content-encoding", "gzip"],
  ["cache-control", "no-store"],
  ["date", DATE],
];
const AUTHORIZATION: [string, string] = ["authorization", "Bearer eyJhbGciOiJFUzI1NiJ9.eyJzdWIiOiJ1XzIwNDEifQ.k3"];
const USER_AGENT: [string, string] = ["user-agent", "Kedai/3.8.0 (Android 14; Pixel 8) okhttp/4.12.0"];
const APP_HEADERS: [string, string][] = [["accept", "application/json"], ["accept-language", "vi-VN"], AUTHORIZATION, USER_AGENT];
const POST_HEADERS: [string, string][] = [...APP_HEADERS, ["content-type", "application/json; charset=utf-8"]];

/** Queued, connection setup, request sent, waiting for the server and download, without the empty phases. */
function phases(waiting: number, download: number, connection = 0): [string, number][] {
  const all: [string, number][] = [
    ["Queued", 2],
    ["Connection setup", connection],
    ["Request sent", 1],
    ["Waiting for server", waiting],
    ["Content download", download],
  ];
  return all.filter(([, ms]) => ms > 0);
}

function image(id: string, path: string, size: string, time: string, start: number, timing: [string, number][]): NetworkRequest {
  return {
    id,
    method: "GET",
    path,
    host: "cdn.kedai.example",
    type: "image",
    status: 200,
    size,
    time,
    start,
    width: 8,
    requestHeaders: [["accept", "image/webp,image/*"], USER_AGENT],
    responseHeaders: [
      ["content-type", "image/webp"],
      ["cache-control", "public, max-age=31536000, immutable"],
      ["age", "5120"],
      ["x-cache", "HIT"],
      ["date", DATE],
    ],
    timing,
  };
}

const ADD_TO_CART = `{
  "sku": "HP-118",
  "qty": 1
}`;

/** Kedai on Android after adding the earbuds to the cart, from the AndroidNetwork artboard. */
export const kedaiNetwork: NetworkCapture = {
  total: 48,
  transferred: "412 kB",
  failed: 1,
  selected: "cart-retry",
  requests: [
    {
      id: "home",
      method: "GET",
      path: "/v2/home?locale=vi-VN",
      host: API,
      type: "api",
      status: 200,
      size: "18.2 kB",
      time: "234 ms",
      start: 0,
      width: 18,
      requestHeaders: APP_HEADERS,
      responseHeaders: [...JSON_HEADERS, ["x-request-id", "req_01HZ8K2M4Q"]],
      response: `{
  "greeting": "Chào buổi tối, Minh Anh",
  "promo": { "code": "KEDAI30", "discountPct": 30 },
  "sections": [
    { "id": "flash-sale", "title": "Flash sale", "items": 12 },
    { "id": "for-you", "title": "Dành cho bạn", "items": 24 }
  ],
  "cartCount": 1
}`,
      timing: phases(150, 21, 60),
    },
    image("img-ts", "/img/p/TS-2041@2x.webp", "42 kB", "88 ms", 20, phases(58, 27)),
    image("img-hp", "/img/p/HP-118@2x.webp", "38 kB", "91 ms", 21, phases(60, 28)),
    {
      id: "cart-timeout",
      method: "POST",
      path: "/v2/cart/items",
      host: API,
      type: "api",
      error: "java.net.SocketTimeoutException: timeout. The server didn’t answer within 10.0 s.",
      size: "—",
      time: "10.0 s",
      start: 26,
      width: 52,
      requestHeaders: POST_HEADERS,
      responseHeaders: [],
      payload: ADD_TO_CART,
      timing: phases(9997, 0),
    },
    {
      id: "cart-retry",
      method: "POST",
      path: "/v2/cart/items",
      host: API,
      type: "api",
      status: 201,
      size: "1.1 kB",
      time: "188 ms",
      start: 80,
      width: 10,
      requestHeaders: POST_HEADERS,
      responseHeaders: [...JSON_HEADERS, ["location", "/v2/cart/c_8f21a9"], ["x-request-id", "req_01HZ8K7T2C"]],
      payload: ADD_TO_CART,
      response: `{
  "cartId": "c_8f21a9",
  "items": [
    { "sku": "TS-2041", "qty": 1, "priceVnd": 189000 },
    { "sku": "HP-118", "qty": 1, "priceVnd": 459000 }
  ],
  "subtotalVnd": 648000,
  "coupon": null
}`,
      timing: phases(158, 27),
    },
    {
      id: "product",
      method: "GET",
      path: "/v2/products/HP-118",
      host: API,
      type: "api",
      status: 200,
      size: "6.4 kB",
      time: "195 ms",
      start: 84,
      width: 10,
      requestHeaders: APP_HEADERS,
      responseHeaders: [...JSON_HEADERS, ["x-request-id", "req_01HZ8K7V9D"]],
      response: `{
  "sku": "HP-118",
  "name": "Tai nghe không dây ANC",
  "brand": "Kedai Audio",
  "priceVnd": 459000,
  "listPriceVnd": 590000,
  "rating": 4.7,
  "reviewCount": 980,
  "stock": 12,
  "colors": ["black", "sand", "blue"]
}`,
      timing: phases(170, 22),
    },
    {
      id: "reviews",
      method: "GET",
      path: "/v2/products/HP-118/reviews?page=1",
      host: API,
      type: "api",
      status: 200,
      size: "12.8 kB",
      time: "241 ms",
      start: 86,
      width: 12,
      requestHeaders: APP_HEADERS,
      responseHeaders: [...JSON_HEADERS, ["x-request-id", "req_01HZ8K7W1E"]],
      response: `{
  "page": 1,
  "pageSize": 10,
  "total": 980,
  "reviews": [
    { "id": "rv_5512", "stars": 5, "text": "Chống ồn tốt, pin lâu." },
    { "id": "rv_5498", "stars": 4, "text": "Bass hơi mạnh." }
  ]
}`,
      timing: phases(205, 33),
    },
    {
      id: "events",
      method: "POST",
      path: "/v1/events",
      host: API,
      type: "api",
      status: 204,
      size: "0 B",
      time: "64 ms",
      start: 88,
      width: 4,
      requestHeaders: POST_HEADERS,
      responseHeaders: [["date", DATE]],
      payload: `{
  "events": [
    { "name": "add_to_cart", "sku": "HP-118", "qty": 1 }
  ]
}`,
      timing: phases(61, 0),
    },
    {
      id: "recommendations",
      method: "GET",
      path: "/v2/recommendations?sku=HP-118",
      host: API,
      type: "api",
      status: 304,
      size: "0 B",
      time: "52 ms",
      start: 90,
      width: 3,
      requestHeaders: [...APP_HEADERS, ["if-none-match", 'W/"5f2a-91c"']],
      responseHeaders: [
        ["etag", 'W/"5f2a-91c"'],
        ["cache-control", "private, max-age=60"],
        ["date", DATE],
      ],
      timing: phases(49, 0),
    },
    {
      id: "stock",
      method: "WS",
      path: "wss://rt.kedai.example/stock",
      host: "",
      type: "ws",
      status: 101,
      size: "—",
      time: "live",
      start: 92,
      width: 8,
      requestHeaders: [
        ["upgrade", "websocket"],
        ["sec-websocket-version", "13"],
        AUTHORIZATION,
        USER_AGENT,
      ],
      responseHeaders: [
        ["upgrade", "websocket"],
        ["connection", "Upgrade"],
        ["sec-websocket-accept", "s3pPLMBiTxaQ9kYGzzhZRbK+xOo="],
      ],
      response: `{ "type": "subscribe", "skus": ["HP-118", "TS-2041"] }
{ "type": "stock", "sku": "HP-118", "available": 12 }
{ "type": "stock", "sku": "TS-2041", "available": 54 }`,
      timing: [
        ["Queued", 2],
        ["Connection setup", 38],
        ["Upgrade handshake", 24],
      ],
    },
  ],
};
