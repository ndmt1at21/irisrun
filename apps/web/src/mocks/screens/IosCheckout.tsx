import { useId } from "react";
import { RadioGroup, RadioGroupItem } from "../../components/ui/radio-group";
import { kedaiAdapters, type PaymentResult, paymentResults } from "../device/adapters";

// The sheet is drawn on the phone, so it keeps iOS's light colors in both themes.
const DOTS: Record<PaymentResult, string> = {
  success: "bg-[#15803d]",
  declined: "bg-[#dc2626]",
  pending: "bg-[#b45309]",
  cancelled: "bg-[#a1a1aa]",
};

const ITEMS = [
  ["Linen Shirt · M", "$24.00"],
  ["Wireless Earbuds", "$59.00"],
];

/**
 * Kedai's checkout on an iPhone with Iris's test payment sheet over it (Adapters artboard).
 * The chosen result is shared with the Payment adapter in the tools panel.
 */
export function IosCheckout({ result, onResult }: { result: PaymentResult; onResult: (result: PaymentResult) => void }) {
  const titleId = useId();
  const { payment } = kedaiAdapters;
  return (
    <div className="relative h-full bg-[#f2f2f7] text-black" style={{ fontFamily: "-apple-system, 'SF Pro Text', system-ui, sans-serif" }}>
      <div className="flex h-12 items-center px-[30px] pt-1 text-sm font-semibold">9:44</div>
      <div className="flex items-center px-3 pt-1 pb-2.5 text-base">
        <span className="text-[#0a7a6f]">‹ Bag</span>
        <span className="mr-10 flex-1 text-center font-semibold">Checkout</span>
      </div>
      <div className="mx-4 rounded-xl bg-white px-3.5 py-3 text-[13px]">
        <div className="text-xs text-[#6e6e73]">Deliver to</div>
        <div className="mt-0.5 font-semibold">Minh Anh</div>
        <div className="text-[#3c3c43]">12 Nguyen Hue, District 1, Ho Chi Minh City</div>
      </div>
      <div className="mx-4 mt-3 rounded-xl bg-white px-3.5 py-1 text-[13px]">
        {ITEMS.map(([name, price]) => (
          <div key={name} className="flex justify-between border-b border-[#e5e5ea] py-2">
            <span>{name}</span>
            <span>{price}</span>
          </div>
        ))}
        <div className="flex justify-between py-2 font-semibold">
          <span>Total</span>
          <span>{payment.amount}</span>
        </div>
      </div>

      <div aria-hidden="true" className="absolute inset-0 z-[4] bg-black/35" />
      {/* Not aria-modal: the sheet only blocks the app on the phone, not the page around it. */}
      <div
        role="dialog"
        aria-labelledby={titleId}
        className="absolute inset-x-0 bottom-0 z-[5] rounded-t-[22px] bg-white px-4 pt-2 pb-[30px] font-sans text-[#09090b]"
      >
        <div aria-hidden="true" className="mx-auto mb-2.5 h-[5px] w-9 rounded-[3px] bg-[#d4d4d8]" />
        <div className="flex items-center gap-2">
          <h2 id={titleId} className="text-base font-semibold">
            Test payment
          </h2>
          <span className="inline-flex h-5 items-center rounded-full bg-[#ebebfd] px-[7px] text-[11px] font-semibold text-[#4f4cc4]">
            Iris
          </span>
          <span className="flex-1" />
          <span className="text-xs text-[#63636b]">No real charge</span>
        </div>
        <div className="mt-2.5 flex items-baseline justify-between rounded-[10px] bg-[#f4f4f5] px-3 py-2.5">
          <span className="text-xs text-[#52525b]">
            {payment.merchant} · {payment.merchantId}
          </span>
          <span className="text-lg font-semibold">{payment.amount}</span>
        </div>
        <RadioGroup
          aria-label="Payment result"
          value={result}
          onValueChange={(value) => onResult(value as PaymentResult)}
          className="mt-3 flex flex-col gap-1.5"
        >
          {paymentResults.map(({ value, label, detail }) => (
            <RadioGroupItem
              key={value}
              value={value}
              className="flex items-center gap-2.5 rounded-[10px] border-[#e4e4e7] bg-white px-3 py-[9px] text-[#09090b] data-[state=checked]:border-[#5b5bd6] data-[state=checked]:bg-[#f5f5ff]"
            >
              <span className={`size-2 rounded-full ${DOTS[value]}`} />
              <span className="flex-1 font-medium">{label}</span>
              <span className="text-[11.5px] text-[#63636b]">{detail}</span>
            </RadioGroupItem>
          ))}
        </RadioGroup>
        <button type="button" className="mt-3 h-[42px] w-full cursor-pointer rounded-[10px] bg-[#09090b] font-medium text-white">
          Return result to app
        </button>
      </div>
      <span aria-hidden="true" className="absolute bottom-2 left-[101px] z-[6] h-[5px] w-[122px] rounded-[3px] bg-black" />
    </div>
  );
}
