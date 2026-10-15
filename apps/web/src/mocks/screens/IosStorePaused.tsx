import { MapPin } from "lucide-react";
import { HomeIndicator, IosStatusBar, iosScreen } from "./IosDiscover";

/** Kedai's store screen, frozen where it called Look Around (IosUnsupported); Iris's pause dialog covers it. */
export function IosStorePaused() {
  return (
    <div aria-hidden="true" className={iosScreen}>
      <IosStatusBar />
      <div className="px-3 pt-1 pb-2 text-base text-[#0a7a6f]">‹ Stores</div>
      <div className="flex h-[268px] items-center justify-center bg-[#e3efe9] bg-[linear-gradient(#cfe1d8_2px,transparent_2px),linear-gradient(90deg,#cfe1d8_2px,transparent_2px)] bg-size-[40px_40px] text-[#0a7a6f]">
        <MapPin className="size-12" fill="currentColor" stroke="#ffffff" strokeWidth={1.2} />
      </div>
      <div className="p-4">
        <div className="text-[22px] font-bold">Kedai Nguyen Hue</div>
        <div className="mt-0.5 text-[15px] text-[#6e6e73]">Open · 9:00–22:00</div>
        <div className="mt-[90px] h-[46px] rounded-xl border-[1.5px] border-[#0a7a6f]" />
        <div className="mt-2.5 h-[46px] rounded-xl bg-[#0a7a6f]" />
      </div>
      {/* Above the pause dialog (z-4), as in the design. */}
      <HomeIndicator className="z-[5]" />
    </div>
  );
}
