import { Progress as ProgressPrimitive } from "radix-ui";
import type { ComponentProps } from "react";
import { cn } from "../../lib/utils";

/** An 8 px bar; `value` is a percentage. */
function Progress({ className, value, ...props }: ComponentProps<typeof ProgressPrimitive.Root>) {
  return (
    <ProgressPrimitive.Root
      data-slot="progress"
      value={value}
      className={cn("relative h-2 w-full overflow-hidden rounded-full bg-muted", className)}
      {...props}
    >
      <ProgressPrimitive.Indicator className="h-full bg-primary transition-[width]" style={{ width: `${value ?? 0}%` }} />
    </ProgressPrimitive.Root>
  );
}

export { Progress };
