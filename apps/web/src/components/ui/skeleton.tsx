import type { ComponentProps } from "react";
import { cn } from "../../lib/utils";

/** A loading bar; set its size with classes, e.g. `h-[9px] w-16`. */
function Skeleton({ className, ...props }: ComponentProps<"span">) {
  return (
    <span
      data-slot="skeleton"
      aria-hidden="true"
      className={cn("block animate-pulse rounded-sm bg-skeleton", className)}
      {...props}
    />
  );
}

export { Skeleton };
