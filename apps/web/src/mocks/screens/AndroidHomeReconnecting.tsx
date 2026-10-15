import { LoaderCircle } from "lucide-react";
import { Button } from "../../components/ui/button";

const PRODUCTS = [
  { name: "Kaos katun oversize", price: "Rp 129.000", tint: "#fde8da" },
  { name: "Earbuds nirkabel ANC", price: "Rp 449.000", tint: "#dde8fb" },
];

/** Kedai's home screen in Indonesian on a Galaxy A55, dimmed under the reconnecting alert (CloudReconnecting). */
export function AndroidHomeReconnecting() {
  return (
    <div
      className="relative h-full bg-[#fbf8fd] text-[#1b1b1f]"
      style={{ fontFamily: "system-ui, -apple-system, 'Segoe UI', sans-serif" }}
    >
      <div aria-hidden="true" className="opacity-75 brightness-92 grayscale-70">
        <div className="flex h-[30px] items-center px-5 text-xs font-medium">21:14</div>
        <div className="px-4 pt-1.5 pb-2">
          <div className="text-xs text-[#47464f]">Selamat malam,</div>
          <div className="text-lg font-semibold">Minh Anh</div>
        </div>
        <div className="mx-4 flex h-11 items-center rounded-[22px] bg-[#efedf4] px-4 text-[13px] text-[#5d5c66]">
          Cari produk, merek…
        </div>
        <div className="mx-4 mt-3.5 rounded-2xl bg-[#cdebe5] px-4 py-3.5">
          <div className="text-[11px] font-semibold text-[#00504a]">Khusus pengguna baru</div>
          <div className="text-base font-bold text-[#00201d]">Diskon 30% pesanan pertama</div>
        </div>
        <div className="mx-4 mt-[18px] mb-2.5 flex justify-between">
          <span className="text-[15px] font-semibold">Terlaris</span>
          <span className="text-xs font-semibold text-[#006a60]">Lihat semua</span>
        </div>
        <div className="mx-4 grid grid-cols-2 gap-2.5">
          {PRODUCTS.map(({ name, price, tint }) => (
            <div key={name} className="overflow-hidden rounded-[14px] border border-[#e7e4ec] bg-white">
              <div className="h-[104px]" style={{ background: tint }} />
              <div className="px-2.5 py-2">
                <div className="text-[12.5px]">{name}</div>
                <div className="text-sm font-bold">{price}</div>
              </div>
            </div>
          ))}
        </div>
      </div>
      {/* Iris's own alert over the device screen: light in both themes. */}
      <div role="alert" className="light absolute inset-0 flex items-center justify-center bg-[rgba(250,250,252,.55)] p-5 font-sans text-foreground">
        <div className="w-full rounded-2xl border bg-white px-[18px] py-5 text-center shadow-[0_18px_40px_-16px_rgba(9,9,11,.3)]">
          <span aria-hidden="true" className="mx-auto flex size-11 items-center justify-center rounded-full bg-[#fef3c7] text-[#b45309]">
            <LoaderCircle className="size-[22px] animate-spin" strokeWidth={2.4} />
          </span>
          <div className="mt-3 text-base font-semibold">Reconnecting to Galaxy A55…</div>
          <p className="mt-1.5 text-[12.5px] leading-normal text-[#52525b]">
            Your app keeps running on the device. You’ll pick up right where you left off.
          </p>
          <div className="mt-3.5 flex gap-2">
            <Button className="h-9 flex-1 rounded-lg px-1.5">Retry now</Button>
            <Button variant="outline" className="h-9 flex-1 rounded-lg px-1.5">
              Switch network…
            </Button>
          </div>
          <div className="mt-2.5 text-[11.5px] text-muted-foreground">Session time keeps counting · 12:40 left</div>
        </div>
      </div>
    </div>
  );
}
