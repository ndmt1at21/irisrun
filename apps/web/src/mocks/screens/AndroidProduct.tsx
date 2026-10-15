import { ArrowLeft, Headphones, Heart, ShoppingCart } from "lucide-react";

const icon = "inline-flex size-10 items-center justify-center";

/** Kedai's product page on a Pixel 8, just after adding the earbuds to the cart (AndroidNetwork artboard). */
export function AndroidProduct() {
  return (
    <div
      className="relative h-full bg-[#fbf8fd] text-[#1b1b1f]"
      style={{ fontFamily: "system-ui, -apple-system, 'Segoe UI', sans-serif" }}
    >
      <div className="flex h-[30px] items-center px-[22px] text-xs font-medium">9:42</div>
      <div className="flex items-center justify-between px-2 py-1">
        <span className={icon}>
          <ArrowLeft className="size-[22px]" />
        </span>
        <span className="inline-flex">
          <span className={icon}>
            <Heart className="size-5" />
          </span>
          <span className={icon}>
            <ShoppingCart className="size-5" />
          </span>
        </span>
      </div>
      <div className="mx-4 flex h-[232px] items-center justify-center rounded-[20px] bg-[#dde8fb] text-[#24489a]">
        <Headphones className="size-24" strokeWidth={1.2} />
      </div>
      <div className="p-4">
        <div className="text-xs text-[#47464f]">Âm thanh · Kedai Audio</div>
        <div className="mt-0.5 text-xl font-semibold">Tai nghe không dây ANC</div>
        <div className="mt-1.5 flex items-baseline gap-2.5">
          <span className="text-xl font-bold text-[#006a60]">459.000 ₫</span>
          <span className="text-[13px] text-[#78767f] line-through">590.000 ₫</span>
        </div>
        <div className="mt-1 text-xs text-[#47464f]">★ 4.7 · 980 đánh giá · Còn 12 sản phẩm</div>
        <div className="mt-4 flex gap-2.5">
          <span className="size-[30px] rounded-full bg-[#1b1b1f] shadow-[0_0_0_2px_#fbf8fd,0_0_0_4px_#006a60]" />
          <span className="size-[30px] rounded-full border border-[#c8c5d0] bg-[#e8e2d6]" />
          <span className="size-[30px] rounded-full bg-[#3b5bdb]" />
        </div>
      </div>
      <div className="absolute inset-x-3 bottom-24 flex items-center justify-between rounded-lg bg-[#313034] py-3 pr-2 pl-4 text-[13px] text-[#f4eff4]">
        Đã thêm vào giỏ hàng
        <span className="px-2 font-semibold text-[#84d6ca]">Xem giỏ</span>
      </div>
      <div className="absolute inset-x-0 bottom-0 flex gap-2.5 border-t border-[#e7e4ec] bg-[#fbf8fd] px-4 pt-3 pb-[26px] text-sm font-medium">
        <span className="box-content inline-flex h-12 items-center rounded-3xl border border-[#78767f] px-[18px] text-[#006a60]">Mua ngay</span>
        <span className="inline-flex h-12 flex-1 items-center justify-center rounded-3xl bg-[#006a60] text-white">Thêm vào giỏ</span>
        <span aria-hidden="true" className="absolute bottom-[7px] left-[108px] h-1 w-[108px] rounded-xs bg-[#1b1b1f]/45" />
      </div>
    </div>
  );
}
