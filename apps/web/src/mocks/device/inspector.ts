/**
 * A view in the inspected app's hierarchy. The list is depth-first, so a
 * view's children follow it with a greater `depth`.
 */
export interface ViewNode {
  id: string;
  /** 0 for the root. */
  depth: number;
  type: string;
  /** What the tree shows after the type, e.g. `"Linen Shirt"` or `.vertical`. */
  detail?: string;
  /** The tag next to the name; "SwiftUI View" without it. */
  kind?: string;
  /** Where the view is declared, file:line. */
  source?: string;
  /** x, y, width and height in points. */
  frame: [x: number, y: number, width: number, height: number];
  modifiers?: string[];
  /** Live values; a boolean is a switch the panel can flip. */
  state?: { name: string; value: string | boolean }[];
  accessibility?: { label: string; traits?: string };
  /** Starts collapsed in the tree. */
  collapsed?: boolean;
}

const PRODUCTS = [
  ["p_1042", "Linen Shirt", "$24.00"],
  ["p_2187", "Wireless Earbuds", "$59.00"],
  ["p_0318", "Steel Bottle", "$18.50"],
  ["p_0907", "Travel Backpack", "$42.00"],
] as const;

const cards = PRODUCTS.flatMap(([id, name, price], index): ViewNode[] => {
  const x = 16 + (index % 2) * 160;
  const y = 318 + Math.floor(index / 2) * 198;
  return [
    {
      id,
      depth: 8,
      type: "ProductCard",
      detail: `"${name}"`,
      source: "HomeView.swift:64",
      frame: [x, y, 148, 186],
      modifiers: [
        ".background(.background.secondary)",
        ".clipShape(.rect(cornerRadius: 14))",
        ".contentShape(.rect)",
        ".onTapGesture { router.open(product) }",
      ],
      state: [
        { name: "product", value: `Product(id: "${id}", name: "${name}")` },
        { name: "@State isFavorite", value: false },
      ],
      accessibility: { label: `${name}, ${price}`, traits: ".isButton" },
      collapsed: index > 0,
    },
    {
      id: `${id}-image`,
      depth: 9,
      type: "AsyncImage",
      detail: `url: …/${id}.jpg`,
      frame: [x, y, 148, 128],
      modifiers: [".frame(height: 128)", ".clipShape(.rect(cornerRadius: 14))"],
    },
    {
      id: `${id}-name`,
      depth: 9,
      type: "Text",
      detail: `"${name}"`,
      frame: [x, y + 136, 148, 18],
      modifiers: [".font(.subheadline)", ".foregroundStyle(.secondary)"],
    },
    { id: `${id}-price`, depth: 9, type: "Text", detail: `"${price}"`, frame: [x, y + 156, 148, 22], modifiers: [".font(.headline)"] },
  ];
});

const CHIPS: [label: string, x: number, width: number][] = [
  ["All", 16, 44],
  ["Apparel", 68, 76],
  ["Audio", 152, 64],
  ["Home", 224, 62],
  ["Outdoor", 294, 80],
];

const TABS = ["Home", "Search", "Bag", "Profile"];

/** Kedai's Discover screen on iOS, from the IosRunning artboard. */
export const kedaiViews: ViewNode[] = [
  { id: "app", depth: 0, type: "KedaiApp", kind: "App", source: "KedaiApp.swift:4", frame: [0, 0, 393, 852] },
  { id: "window", depth: 1, type: "WindowGroup", kind: "Scene", source: "KedaiApp.swift:8", frame: [0, 0, 393, 852] },
  {
    id: "tabs",
    depth: 2,
    type: "TabView",
    detail: "selection: .home",
    source: "RootView.swift:12",
    frame: [0, 0, 393, 852],
    modifiers: [".tint(.kedaiTeal)"],
    state: [{ name: "@State selection", value: ".home" }],
  },
  { id: "nav", depth: 3, type: "NavigationStack", source: "RootView.swift:14", frame: [0, 0, 393, 772], state: [{ name: "path", value: "[]" }] },
  {
    id: "home",
    depth: 4,
    type: "HomeView",
    source: "HomeView.swift:9",
    frame: [0, 0, 393, 772],
    state: [
      { name: "@State query", value: '""' },
      { name: "@Environment cart", value: "CartStore(items: 2)" },
    ],
  },
  { id: "scroll", depth: 5, type: "ScrollView", detail: ".vertical", source: "HomeView.swift:21", frame: [0, 59, 393, 713], modifiers: [".scrollIndicators(.hidden)"] },
  {
    id: "stack",
    depth: 6,
    type: "VStack",
    detail: "alignment: .leading, spacing: 16",
    source: "HomeView.swift:22",
    frame: [16, 59, 361, 643],
    modifiers: [".padding(.horizontal, 16)"],
  },
  {
    id: "header",
    depth: 7,
    type: "HeaderView",
    detail: '"Discover"',
    source: "HeaderView.swift:7",
    frame: [16, 59, 361, 44],
    accessibility: { label: "Discover", traits: ".isHeader" },
    collapsed: true,
  },
  { id: "header-title", depth: 8, type: "Text", detail: '"Discover"', frame: [16, 63, 148, 36], modifiers: [".font(.largeTitle.bold())"] },
  { id: "header-avatar", depth: 8, type: "AvatarView", detail: '"MA"', frame: [343, 64, 34, 34], accessibility: { label: "Account", traits: ".isButton" } },
  {
    id: "search",
    depth: 7,
    type: "SearchField",
    detail: '"Search products"',
    source: "SearchField.swift:11",
    frame: [16, 111, 361, 36],
    modifiers: [".background(.fill.tertiary, in: .rect(cornerRadius: 10))"],
    state: [{ name: "@Binding text", value: '""' }],
    accessibility: { label: "Search products", traits: ".isSearchField" },
    collapsed: true,
  },
  { id: "search-icon", depth: 8, type: "Image", detail: 'systemName: "magnifyingglass"', frame: [26, 121, 16, 16] },
  { id: "search-text", depth: 8, type: "TextField", detail: '"Search products"', frame: [48, 111, 319, 36] },
  {
    id: "chips",
    depth: 7,
    type: "CategoryChips",
    detail: "5 items",
    source: "CategoryChips.swift:8",
    frame: [16, 161, 361, 30],
    state: [{ name: "@Binding selected", value: ".all" }],
    collapsed: true,
  },
  ...CHIPS.map(([label, x, width]): ViewNode => ({
    id: `chip-${label}`,
    depth: 8,
    type: "Chip",
    detail: `"${label}"`,
    frame: [x, 161, width, 30],
    accessibility: { label, traits: label === "All" ? ".isButton, .isSelected" : ".isButton" },
  })),
  {
    id: "grid",
    depth: 7,
    type: "LazyVGrid",
    detail: "columns: 2, spacing: 12",
    source: "HomeView.swift:58",
    frame: [16, 318, 308, 384],
  },
  ...cards,
  { id: "tabbar", depth: 2, type: "TabBar", detail: "4 tabs", frame: [0, 772, 393, 80], collapsed: true },
  ...TABS.map((label, index): ViewNode => ({
    id: `tab-${label}`,
    depth: 3,
    type: "TabItem",
    detail: `"${label}"`,
    frame: [index * 98, 779, 98, 49],
    accessibility: { label: label === "Bag" ? "Bag, 2 items" : label, traits: index === 0 ? ".isButton, .isSelected" : ".isButton" },
  })),
];

/** The view selected when the panel opens: the Linen Shirt card. */
export const kedaiSelectedView = "p_1042";
