/** Where a `#Preview` stands: open on the device, rendered, needing a cloud simulator, or still rendering. */
export type PreviewStatus = "on-device" | "ready" | "cloud-only" | "rendering";

/** What the thumbnail shows. Mock renders stand in for the image the preview compiler will send. */
export type PreviewThumb =
  | { kind: "product-card"; title: string; price: string; tint: string; sale?: string }
  | { kind: "home" | "detail" | "empty-bag" | "add-to-bag" | "rendering" }
  /** `api` is the framework that only a cloud simulator has. */
  | { kind: "needs-cloud"; api: string };

/** One `#Preview` in the project. */
export interface Preview {
  name: string;
  /** The file and line of the `#Preview`. */
  file: string;
  status: PreviewStatus;
  thumb: PreviewThumb;
}

export interface PreviewGallery {
  project: string;
  target: string;
  /** Devices the previews can render on; the first is the default. */
  devices: string[];
  previews: Preview[];
}

export const previewGallery: PreviewGallery = {
  project: "kedai-ios",
  target: "Kedai · Debug",
  devices: ["iPhone 15 Pro", "iPhone SE (3rd generation)", "iPad Air 11-inch (M2)"],
  previews: [
    {
      name: "Product card",
      file: "ProductCard.swift:58",
      status: "on-device",
      thumb: { kind: "product-card", title: "Linen Shirt", price: "$24.00", tint: "#fde8da" },
    },
    {
      name: "Product card · On sale",
      file: "ProductCard.swift:66",
      status: "ready",
      thumb: { kind: "product-card", title: "Wireless Earbuds", price: "$44.25", tint: "#dde8fb", sale: "−25%" },
    },
    { name: "Home", file: "HomeView.swift:120", status: "ready", thumb: { kind: "home" } },
    { name: "Detail · Linen Shirt", file: "ProductDetailView.swift:210", status: "ready", thumb: { kind: "detail" } },
    { name: "Checkout · Empty bag", file: "CheckoutView.swift:188", status: "ready", thumb: { kind: "empty-bag" } },
    { name: "Add to Bag · States", file: "AddToBagButton.swift:31", status: "ready", thumb: { kind: "add-to-bag" } },
    {
      name: "Order Live Activity",
      file: "OrderTracker.swift:96",
      status: "cloud-only",
      thumb: { kind: "needs-cloud", api: "ActivityKit" },
    },
    { name: "Reviews", file: "ReviewsList.swift:74", status: "rendering", thumb: { kind: "rendering" } },
  ],
};
