import { ChevronLeft, Heart, MapPin, Share, Shirt } from "lucide-react";
import { cn } from "../../lib/utils";
import { HomeIndicator, IosStatusBar, iosScreen } from "./IosDiscover";

/** Kedai's product detail for the Linen Shirt on an iPhone (IosCompat). */
export function IosProduct() {
  return (
    <div className={iosScreen}>
      <IosStatusBar />
      <div className="flex items-center justify-between px-3 pt-1 pb-2 text-base text-[#0a7a6f]">
        <span className="inline-flex items-center gap-0.5">
          <ChevronLeft className="size-5" strokeWidth={2.4} />
          Discover
        </span>
        <span className="inline-flex gap-4">
          <Heart className="size-5" />
          <Share className="size-5" />
        </span>
      </div>
      <div className="flex h-[268px] flex-col items-center justify-center gap-[18px] bg-[#fde8da] text-[#9a4a1c]">
        <Shirt className="size-[104px]" strokeWidth={1.2} />
        <span className="inline-flex gap-1.5">
          <span className="size-[7px] rounded-full bg-[#9a4a1c]" />
          <span className="size-[7px] rounded-full bg-[#9a4a1c]/30" />
          <span className="size-[7px] rounded-full bg-[#9a4a1c]/30" />
        </span>
      </div>
      <div className="p-4">
        <div className="text-[22px] font-bold tracking-[-0.01em]">Linen Shirt</div>
        <div className="mt-0.5 flex items-baseline gap-2.5">
          <span className="text-[19px] font-semibold">$24.00</span>
          <span className="text-[13px] text-[#6e6e73]">★ 4.8 · 1.2k reviews</span>
        </div>
        <div className="mt-4 mb-2 text-[13px] font-semibold">Size</div>
        <div className="flex gap-2">
          {["S", "M", "L", "XL"].map((size) => (
            <span
              key={size}
              className={cn(
                "inline-flex h-9 w-12 items-center justify-center rounded-[10px] text-sm",
                // As the design renders them: only the selected chip keeps its border inside its size.
                size === "M" ? "border-2 border-[#0a7a6f] bg-[#e6f4f2] font-semibold" : "box-content border border-[#d1d1d6]",
              )}
            >
              {size}
            </span>
          ))}
        </div>
        <div className="mt-[22px] flex flex-col gap-2.5 text-[15px] font-semibold">
          <span className="box-content flex h-[46px] items-center justify-center gap-2 rounded-xl border-[1.5px] border-[#0a7a6f] text-[#0a7a6f]">
            <MapPin className="size-[18px]" />
            Find in a store
          </span>
          <span className="flex h-[46px] items-center justify-center rounded-xl bg-[#0a7a6f] text-white">Add to Bag</span>
        </div>
      </div>
      <HomeIndicator />
    </div>
  );
}
