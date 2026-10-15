import { House, Power, Volume1, Volume2 } from "lucide-react";
import { Toolbar } from "radix-ui";
import type { ReactNode } from "react";
import { buttonVariants } from "../../components/ui/button";
import { cn } from "../../lib/utils";

export type Platform = "android" | "ios";

/** Outer size of each frame; the workspace scales the frame down to fit the stage. */
export const FRAME_SIZE: Record<Platform, { width: number; height: number }> = {
  android: { width: 340, height: 716 },
  ios: { width: 342, height: 720 },
};

/** A Pixel-style phone with a hole-punch camera; `children` fill its 324 × 700 screen. */
export function AndroidFrame({ children }: { children: ReactNode }) {
  return (
    <div className="relative h-[716px] w-[340px] shrink-0 rounded-[40px] bg-[#1b1b1f] p-2 shadow-[0_0_0_1px_#3a3a42,0_30px_60px_-20px_rgba(0,0,0,.55)]">
      <span aria-hidden="true" className="absolute top-[132px] -right-[3px] h-[52px] w-[3px] rounded-r-[2px] bg-[#3a3a42]" />
      <span aria-hidden="true" className="absolute top-[208px] -right-[3px] h-[88px] w-[3px] rounded-r-[2px] bg-[#3a3a42]" />
      <div className="relative h-full overflow-hidden rounded-[32px] bg-black">
        {children}
        <span aria-hidden="true" className="absolute top-[9px] left-[156px] size-3 rounded-full bg-[#0b0b0d]" />
      </div>
    </div>
  );
}

/** An iPhone 15 Pro-style phone; `children` fill its 324 × 702 screen, under the Dynamic Island. */
export function IPhoneFrame({ children }: { children: ReactNode }) {
  const key = "absolute w-[3px] bg-[#6e6c72]";
  return (
    <div className="relative h-[720px] w-[342px] shrink-0 rounded-[54px] bg-[#2b2a2e] p-[9px] shadow-[0_0_0_1px_#8e8c92,0_0_0_3px_#3b3a3f,0_30px_60px_-20px_rgba(0,0,0,.35)]">
      <span aria-hidden="true" className={cn(key, "top-[120px] -left-1 h-7 rounded-l-[2px]")} />
      <span aria-hidden="true" className={cn(key, "top-[168px] -left-1 h-[54px] rounded-l-[2px]")} />
      <span aria-hidden="true" className={cn(key, "top-[232px] -left-1 h-[54px] rounded-l-[2px]")} />
      <span aria-hidden="true" className={cn(key, "top-[190px] -right-1 h-[86px] rounded-r-[2px]")} />
      <div className="relative h-full overflow-hidden rounded-[46px] bg-black">
        {children}
        {/* z-3 as in the design, so an overlay on the screen (z-4) can cover it. */}
        <span aria-hidden="true" className="absolute top-2.5 left-[116px] z-[3] h-[27px] w-[92px] rounded-[14px] bg-black" />
      </div>
    </div>
  );
}

const navIcon = {
  "aria-hidden": true,
  className: "size-[15px]",
  viewBox: "0 0 24 24",
  fill: "none",
  stroke: "currentColor",
  strokeWidth: 2,
};

// [accessible name, tooltip, icon]
type Key = [string, string, ReactNode];
const volume: Key[] = [
  ["Volume up", "Volume up", <Volume2 />],
  ["Volume down", "Volume down", <Volume1 />],
];
const KEYS: Record<Platform, [side: Key[], nav: Key[]]> = {
  android: [
    [["Power", "Power", <Power />], ...volume],
    [
      ["Back", "Back", <svg {...navIcon} strokeLinejoin="round"><path d="M17 4 6 12l11 8z" /></svg>],
      ["Home", "Home", <svg {...navIcon}><circle cx="12" cy="12" r="8" /></svg>],
      ["Recent apps", "Recents", <svg {...navIcon}><rect x="5" y="5" width="14" height="14" rx="2" /></svg>],
    ],
  ],
  ios: [[["Side button", "Side button (lock)", <Power />], ...volume], [["Home", "Home (swipe up)", <House />]]],
};

/** The phone's physical keys as a vertical toolbar beside the frame. */
export function HardwareButtons({ platform }: { platform: Platform }) {
  const button = (keys: Key[]) =>
    keys.map(([label, title, icon]) => (
      <Toolbar.Button
        key={label}
        aria-label={label}
        title={title}
        className={cn(buttonVariants({ variant: "ghost", size: "icon" }), "size-[34px] text-foreground")}
      >
        {icon}
      </Toolbar.Button>
    ));
  const [side, nav] = KEYS[platform];
  return (
    <Toolbar.Root
      orientation="vertical"
      aria-label="Hardware buttons"
      className="flex shrink-0 flex-col gap-0.5 rounded-[10px] border bg-card p-1 shadow-xs"
    >
      {button(side)}
      <Toolbar.Separator className="mx-1.5 my-1 h-px bg-border" />
      {button(nav)}
    </Toolbar.Root>
  );
}
