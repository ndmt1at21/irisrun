import { Heart, House, Search, ShoppingBag, UserRound, Wifi } from "lucide-react";
import { cn } from "../../lib/utils";
import type { ViewNode } from "../device/inspector";

const PRODUCTS = [
  {
    id: "p_1042",
    name: "Linen Shirt",
    price: "$24.00",
    tint: "#fde8da",
    ink: "#9a4a1c",
    icon: "M20.38 3.46 16 2a4 4 0 0 1-8 0L3.62 3.46a2 2 0 0 0-1.34 2.23l.58 3.47a1 1 0 0 0 .99.84H6v10c0 1.1.9 2 2 2h8a2 2 0 0 0 2-2V10h2.15a1 1 0 0 0 .99-.84l.58-3.47a2 2 0 0 0-1.34-2.23z",
  },
  {
    id: "p_2187",
    name: "Wireless Earbuds",
    price: "$59.00",
    tint: "#dde8fb",
    ink: "#24489a",
    icon: "M3 14h3a2 2 0 0 1 2 2v3a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-7a9 9 0 0 1 18 0v7a2 2 0 0 1-2 2h-1a2 2 0 0 1-2-2v-3a2 2 0 0 1 2-2h3",
  },
  {
    id: "p_0318",
    name: "Steel Bottle",
    price: "$18.50",
    tint: "#ddf2e3",
    ink: "#1d6a3a",
    icon: "M10 2h4v3l1.5 2.5V20a2 2 0 0 1-2 2h-3a2 2 0 0 1-2-2V7.5L10 5zM8.5 11h7",
  },
  {
    id: "p_0907",
    name: "Travel Backpack",
    price: "$42.00",
    tint: "#f1e3f6",
    ink: "#7a3590",
    icon: "M4 10a4 4 0 0 1 4-4h8a4 4 0 0 1 4 4v10a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2ZM8 10h8M8 18h8M8 22v-6a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v6M9 6V4a2 2 0 0 1 2-2h2a2 2 0 0 1 2 2v2",
  },
];

const CHIPS = ["All", "Apparel", "Audio", "Home", "Outdoor"];

/** The root of a mock iOS screen: white, in the system font. */
export const iosScreen = "relative h-full overflow-hidden bg-white text-black font-[-apple-system,'SF_Pro_Text',system-ui,sans-serif]";

export function IosStatusBar() {
  return (
    <div className="flex h-12 items-center justify-between pt-1 pr-7 pl-[30px] text-sm font-semibold">
      <span>9:41</span>
      <span className="inline-flex items-center gap-[5px]">
        <Wifi className="size-[15px]" strokeWidth={2.4} />
        <span className="inline-block h-[11px] w-[22px] rounded-[3px] border-[1.5px] border-black/45 p-px">
          <span className="block h-full w-4/5 rounded-[1px] bg-black" />
        </span>
      </span>
    </div>
  );
}

export function HomeIndicator({ className }: { className?: string }) {
  return <span aria-hidden="true" className={cn("absolute bottom-2 left-[101px] h-[5px] w-[122px] rounded-[3px] bg-black", className)} />;
}

/** The Inspector's outlines on a view: dashed while its row is under the pointer, solid with its size when selected. */
function Marks({ id, selected, hovered, className }: { id: string; selected?: ViewNode; hovered?: string; className: string }) {
  return (
    <>
      {hovered === id && (
        <span
          aria-hidden="true"
          className={cn("pointer-events-none absolute -inset-[3px] border-[1.5px] border-dashed border-primary", className)}
        />
      )}
      {selected?.id === id && (
        <>
          <span aria-hidden="true" className={cn("pointer-events-none absolute -inset-1 border-2 border-primary bg-primary/10", className)} />
          <span
            aria-hidden="true"
            className="pointer-events-none absolute -top-6 -left-1 h-[18px] rounded-sm bg-primary px-1.5 font-mono text-[10px] leading-[18px] whitespace-nowrap text-white"
          >
            {selected.type} · {selected.frame[2]} × {selected.frame[3]}
          </span>
        </>
      )}
    </>
  );
}

/** Kedai's Discover screen on an iPhone (IosRunning), with the Inspector's outlines on the selected and hovered views. */
export function IosDiscover({ selected, hovered }: { selected?: ViewNode; hovered?: string }) {
  const marks = { selected, hovered };
  return (
    <div className={iosScreen}>
      <IosStatusBar />
      <div className="relative flex items-center justify-between px-4 pt-1.5 pb-2.5">
        <span className="text-[30px] font-bold tracking-[-0.02em]">Discover</span>
        <span className="inline-flex size-[34px] items-center justify-center rounded-full bg-[#0a7a6f] text-[13px] font-semibold text-white">
          MA
        </span>
        <Marks id="header" {...marks} className="rounded-lg" />
      </div>
      <div className="relative mx-4">
        <div className="flex h-9 items-center gap-1.5 rounded-[10px] bg-[#eeeef0] px-2.5 text-[15px] text-[#8a8a8e]">
          <Search className="size-4" strokeWidth={2.2} />
          Search products
        </div>
        <Marks id="search" {...marks} className="rounded-xl" />
      </div>
      <div className="relative mx-4 mt-3.5">
        <div className="flex gap-2 overflow-hidden whitespace-nowrap">
          {CHIPS.map((chip, index) => (
            <span
              key={chip}
              className={cn(
                "inline-flex h-[30px] items-center rounded-[15px] px-3.5 text-[13px] font-medium",
                index === 0 ? "bg-[#1c1c1e] text-white" : "bg-[#f2f2f4] text-[#1c1c1e]",
              )}
            >
              {chip}
            </span>
          ))}
        </div>
        <Marks id="chips" {...marks} className="rounded-[18px]" />
      </div>
      <div className="mx-4 mt-5 mb-2.5 flex items-baseline justify-between">
        <span className="text-[19px] font-bold tracking-[-0.01em]">Trending now</span>
        <span className="text-sm text-[#0a7a6f]">See all</span>
      </div>
      <div className="relative mx-4 grid grid-cols-2 gap-3">
        {PRODUCTS.map((product) => (
          <div key={product.id} className="relative">
            <div
              className="relative flex h-32 items-center justify-center rounded-[14px]"
              style={{ background: product.tint, color: product.ink }}
            >
              <svg aria-hidden="true" viewBox="0 0 24 24" className="size-11" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
                <path d={product.icon} />
              </svg>
              <span className="absolute top-2 right-2 inline-flex size-7 items-center justify-center rounded-full bg-white/85 text-[#1c1c1e]">
                <Heart className="size-[15px]" />
              </span>
            </div>
            <div className="mt-2 text-[13px] text-[#3c3c43]">{product.name}</div>
            <div className="mt-0.5 text-[15px] font-semibold">{product.price}</div>
            <Marks id={product.id} {...marks} className="rounded-2xl" />
          </div>
        ))}
        <Marks id="grid" {...marks} className="rounded-2xl" />
      </div>
      <nav
        aria-label="App tabs"
        className="absolute inset-x-0 bottom-0 grid h-20 grid-cols-4 border-t border-black/8 bg-[rgba(249,249,250,.96)] pt-[7px] text-[10px] font-medium text-[#8a8a8e]"
      >
        <span className="flex flex-col items-center gap-[3px] text-[#0a7a6f]">
          <House className="size-[22px]" fill="currentColor" strokeWidth={1.6} />
          Home
        </span>
        <span className="flex flex-col items-center gap-[3px]">
          <Search className="size-[22px]" />
          Search
        </span>
        <span className="relative flex flex-col items-center gap-[3px]">
          <ShoppingBag className="size-[22px]" />
          <span className="absolute -top-[3px] left-1/2 ml-[5px] inline-flex h-[17px] min-w-[17px] items-center justify-center rounded-[9px] bg-[#ff3b30] text-[11px] font-semibold text-white">
            2
          </span>
          Bag
        </span>
        <span className="flex flex-col items-center gap-[3px]">
          <UserRound className="size-[22px]" />
          Profile
        </span>
        <HomeIndicator />
        <Marks id="tabbar" {...marks} className="rounded-none" />
      </nav>
    </div>
  );
}
