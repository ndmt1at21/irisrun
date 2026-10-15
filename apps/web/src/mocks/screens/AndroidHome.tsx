import { Bell, Check, House, LayoutGrid, Search, ShoppingBag, ShoppingCart, User, Wifi } from "lucide-react";

const PRODUCTS = [
  {
    name: "Áo thun cotton oversize",
    price: "189.000 ₫",
    meta: "★ 4.8 · Đã bán 2,1k",
    tint: "#fde8da",
    ink: "#9a4a1c",
    icon: "M20.38 3.46 16 2a4 4 0 0 1-8 0L3.62 3.46a2 2 0 0 0-1.34 2.23l.58 3.47a1 1 0 0 0 .99.84H6v10c0 1.1.9 2 2 2h8a2 2 0 0 0 2-2V10h2.15a1 1 0 0 0 .99-.84l.58-3.47a2 2 0 0 0-1.34-2.23z",
  },
  {
    name: "Tai nghe không dây ANC",
    price: "459.000 ₫",
    meta: "★ 4.7 · Đã bán 980",
    tint: "#dde8fb",
    ink: "#24489a",
    icon: "M3 14h3a2 2 0 0 1 2 2v3a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-7a9 9 0 0 1 18 0v7a2 2 0 0 1-2 2h-1a2 2 0 0 1-2-2v-3a2 2 0 0 1 2-2h3",
  },
  {
    name: "Bình giữ nhiệt 500 ml",
    price: "249.000 ₫",
    meta: "★ 4.9 · Đã bán 3,4k",
    tint: "#ddf2e3",
    ink: "#1d6a3a",
    icon: "M10 2h4v3l1.5 2.5V20a2 2 0 0 1-2 2h-3a2 2 0 0 1-2-2V7.5L10 5zM8.5 11h7",
  },
  {
    name: "Ba lô du lịch 25 L",
    price: "529.000 ₫",
    meta: "★ 4.6 · Đã bán 640",
    tint: "#f1e3f6",
    ink: "#7a3590",
    icon: "M4 10a4 4 0 0 1 4-4h8a4 4 0 0 1 4 4v10a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2ZM8 10h8M8 18h8M8 22v-6a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v6M9 6V4a2 2 0 0 1 2-2h2a2 2 0 0 1 2 2v2",
  },
];

const chip = "inline-flex h-8 items-center rounded-lg px-3 text-[12.5px] font-medium";

/** Kedai's home screen on a Pixel 8, in Vietnamese (Main artboard). */
export function AndroidHome() {
  return (
    <div
      className="relative h-full bg-[#fbf8fd] text-[#1b1b1f]"
      style={{ fontFamily: "system-ui, -apple-system, 'Segoe UI', sans-serif" }}
    >
      <div className="flex h-[30px] items-center justify-between px-[22px] text-xs font-medium">
        <span>9:41</span>
        <span className="inline-flex items-center gap-1">
          <Wifi className="size-[13px]" strokeWidth={2.4} />
          <span className="inline-block h-[9px] w-[18px] rounded-[2px] border-[1.5px] border-[#1b1b1f] p-px">
            <span className="block h-full w-[70%] rounded-[1px] bg-[#1b1b1f]" />
          </span>
        </span>
      </div>
      <div className="flex items-center justify-between px-4 pt-1.5 pb-2">
        <div>
          <div className="text-xs text-[#47464f]">Chào buổi tối,</div>
          <div className="text-lg font-semibold tracking-[-0.01em]">Minh Anh</div>
        </div>
        <div className="flex items-center gap-2">
          <span className="relative inline-flex size-9 items-center justify-center text-[#47464f]">
            <Bell className="size-5" />
            <span className="absolute top-[7px] right-2 size-[7px] rounded-full bg-[#ba1a1a]" />
          </span>
          <span className="inline-flex size-[34px] items-center justify-center rounded-full bg-[#006a60] text-xs font-semibold text-white">
            MA
          </span>
        </div>
      </div>
      <div className="mx-4 flex h-11 items-center gap-2.5 rounded-[22px] bg-[#efedf4] px-4 text-[13px] text-[#5d5c66]">
        <Search className="size-[18px]" />
        Tìm sản phẩm, thương hiệu…
      </div>
      <div className="mx-4 mt-3.5 flex items-center justify-between gap-3 rounded-2xl bg-[#cdebe5] px-4 py-3.5">
        <div>
          <div className="text-[11px] font-semibold text-[#00504a]">Ưu đãi thành viên mới</div>
          <div className="mt-0.5 text-base font-bold text-[#00201d]">Giảm 30% đơn đầu tiên</div>
          <div className="mt-2 inline-block rounded-md bg-white px-2 py-0.5 font-mono text-[11px] font-semibold text-[#00504a]">
            KEDAI30
          </div>
        </div>
        <span className="inline-flex size-[52px] shrink-0 items-center justify-center rounded-full bg-white text-[#006a60]">
          <ShoppingBag className="size-6" />
        </span>
      </div>
      <div className="mx-4 mt-3.5 flex gap-2 overflow-hidden whitespace-nowrap">
        <span className={`${chip} gap-1.5 bg-[#cce8e2] text-[#051f1c]`}>
          <Check className="size-3.5" strokeWidth={2.4} />
          Tất cả
        </span>
        {["Thời trang", "Âm thanh", "Gia dụng"].map((label) => (
          <span key={label} className={`${chip} border border-[#c8c5d0] text-[#47464f]`}>
            {label}
          </span>
        ))}
      </div>
      <div className="mx-4 mt-[18px] mb-2.5 flex items-baseline justify-between">
        <span className="text-[15px] font-semibold">Bán chạy</span>
        <span className="text-xs font-semibold text-[#006a60]">Xem tất cả</span>
      </div>
      <div className="mx-4 grid grid-cols-2 gap-2.5">
        {PRODUCTS.map((product) => (
          <div key={product.name} className="overflow-hidden rounded-[14px] border border-[#e7e4ec] bg-white">
            <div
              className="flex h-[104px] items-center justify-center"
              style={{ background: product.tint, color: product.ink }}
            >
              <svg aria-hidden="true" viewBox="0 0 24 24" className="size-10" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
                <path d={product.icon} />
              </svg>
            </div>
            <div className="px-2.5 pt-2 pb-2.5">
              <div className="h-[33px] overflow-hidden text-[12.5px] leading-[1.3]">{product.name}</div>
              <div className="mt-1 text-sm font-bold">{product.price}</div>
              <div className="mt-0.5 text-[11px] text-[#5d5c66]">{product.meta}</div>
            </div>
          </div>
        ))}
      </div>
      <nav
        aria-label="App navigation"
        className="absolute inset-x-0 bottom-0 grid h-[82px] grid-cols-4 bg-[#f3f0f7] pt-2.5 text-[11px] text-[#47464f]"
      >
        <span className="flex flex-col items-center gap-1 font-semibold text-[#1b1b1f]">
          <span className="inline-flex h-[30px] w-14 items-center justify-center rounded-[15px] bg-[#cce8e2]">
            <House className="size-5" />
          </span>
          Trang chủ
        </span>
        <span className="flex flex-col items-center gap-1">
          <span className="inline-flex h-[30px] w-14 items-center justify-center">
            <LayoutGrid className="size-5" />
          </span>
          Danh mục
        </span>
        <span className="flex flex-col items-center gap-1">
          <span className="relative inline-flex h-[30px] w-14 items-center justify-center">
            <ShoppingCart className="size-5" />
            <span className="absolute top-0 right-2.5 inline-flex h-4 min-w-4 items-center justify-center rounded-lg bg-[#ba1a1a] px-1 text-[10px] font-semibold text-white">
              2
            </span>
          </span>
          Giỏ hàng
        </span>
        <span className="flex flex-col items-center gap-1">
          <span className="inline-flex h-[30px] w-14 items-center justify-center">
            <User className="size-5" />
          </span>
          Tài khoản
        </span>
        <span className="absolute bottom-[7px] left-[108px] h-1 w-[108px] rounded-sm bg-[#1b1b1f]/45" />
      </nav>
    </div>
  );
}
