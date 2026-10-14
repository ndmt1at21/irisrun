import type { ComponentProps } from "react";
import { cn } from "../../lib/utils";

/** The native checkbox in the primary color. */
function Checkbox({ className, ...props }: Omit<ComponentProps<"input">, "type">) {
  return (
    <input
      type="checkbox"
      data-slot="checkbox"
      className={cn("size-4 shrink-0 cursor-pointer accent-primary disabled:cursor-not-allowed", className)}
      {...props}
    />
  );
}

export { Checkbox };
