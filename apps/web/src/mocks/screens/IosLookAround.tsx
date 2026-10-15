// [left, width, height, color] of the buildings in the Look Around placeholder.
const BUILDINGS = [
  [0, 90, 120, "#e8d9c4"],
  [96, 70, 150, "#f1ece4"],
  [172, 80, 104, "#d9c7b0"],
  [258, 70, 136, "#ece3d6"],
] as const;

const action = "flex h-11 flex-1 items-center justify-center rounded-xl text-[15px] font-semibold";

/** Kedai's store page on an iPhone 15 Pro, with a Look Around scene placeholder (CloudSession). */
export function IosLookAround() {
  return (
    <div className="relative h-full bg-white text-black" style={{ fontFamily: "-apple-system, 'SF Pro Text', system-ui, sans-serif" }}>
      <div className="flex h-12 items-center px-[30px] pt-1 text-sm font-semibold">9:46</div>
      <div className="px-3 pt-1 pb-2 text-base text-[#0a7a6f]">‹ Stores</div>
      <div className="relative h-[250px] overflow-hidden bg-[#cfe3f5]">
        <div aria-hidden="true" className="absolute inset-x-0 bottom-0 h-[70px] bg-[#8d939b]" />
        {BUILDINGS.map(([left, width, height, color]) => (
          <div key={left} aria-hidden="true" className="absolute bottom-[70px]" style={{ left, width, height, background: color }} />
        ))}
        <span className="absolute top-2.5 left-2.5 inline-flex h-6 items-center rounded-xl bg-black/55 px-2.5 text-xs font-semibold text-white">
          Look Around
        </span>
      </div>
      <div className="p-4">
        <div className="text-[22px] font-bold">Kedai Nguyen Hue</div>
        <div className="mt-0.5 text-sm text-[#6e6e73]">12 Nguyen Hue, District 1 · Open until 22:00</div>
        <div className="mt-[18px] flex gap-2.5">
          <span className={`${action} bg-[#0a7a6f] text-white`}>Directions</span>
          <span className={`${action} bg-[#e6f4f2] text-[#0a7a6f]`}>Call store</span>
        </div>
      </div>
      <span aria-hidden="true" className="absolute bottom-2 left-[101px] h-[5px] w-[122px] rounded-[3px] bg-black" />
    </div>
  );
}
