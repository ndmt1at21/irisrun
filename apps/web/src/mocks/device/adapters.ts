/** How a test payment ends; Iris answers the app's payment request with it. */
export type PaymentResult = "success" | "declined" | "pending" | "cancelled";

export const paymentResults: { value: PaymentResult; label: string; detail: string }[] = [
  { value: "success", label: "Success", detail: ".success" },
  { value: "declined", label: "Declined", detail: "insufficient funds" },
  { value: "pending", label: "Pending", detail: "resolves in 30 s" },
  { value: "cancelled", label: "Cancelled", detail: "user closed sheet" },
];

/** The payment request the app is waiting on. */
export interface PaymentRequest {
  api: string;
  merchant: string;
  merchantId: string;
  amount: string;
  /** Where the app asked, file:line. */
  source: string;
}

/** A place the app keeps data, in the Storage adapter. */
export interface StorageArea {
  name: string;
  detail: string;
  /** Caches can only be cleared; the rest can be opened. */
  action: "view" | "clear";
}

/** Kedai's checkout on iOS, from the Adapters artboard. */
export const kedaiAdapters = {
  payment: {
    api: "PKPaymentRequest",
    merchant: "Kedai",
    merchantId: "merchant.com.kedai",
    amount: "$83.00",
    source: "CheckoutView.swift:132",
  } satisfies PaymentRequest,
  cameras: ["Integrated Camera", "FaceTime HD Camera", "OBS Virtual Camera"],
  location: { latitude: "10.7743", longitude: "106.7038" },
  push: {
    title: "Your order is on the way",
    body: "KD-20931 arrives today, 14:00–16:00",
    payload: `{ "orderId": "KD-20931",
  "deeplink": "kedai://orders/KD-20931" }`,
  },
  storage: {
    total: "22.4 MB",
    areas: [
      { name: "UserDefaults", detail: "14 keys", action: "view" },
      { name: "Keychain", detail: "3 items", action: "view" },
      { name: "Documents", detail: "4 files · 2.1 MB", action: "view" },
      { name: "Caches", detail: "20.3 MB", action: "clear" },
    ] satisfies StorageArea[],
  },
  deepLink: "kedai://product/p_1042",
  recentLinks: ["kedai://orders/KD-20931", "https://kedai.example/p/1042"],
};
