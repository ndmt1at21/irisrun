import type { ComponentProps } from "react";
import { cn } from "../../lib/utils";

/** Initials in a 28 px circle; `color` fills it and turns the text white. */
function Avatar({ className, color, style, ...props }: ComponentProps<"span"> & { color?: string }) {
  return (
    <span
      data-slot="avatar"
      className={cn(
        "inline-flex size-7 shrink-0 items-center justify-center rounded-full text-[11px] font-semibold",
        color ? "text-white" : "bg-muted text-foreground",
        className,
      )}
      style={color ? { background: color, ...style } : style}
      {...props}
    />
  );
}

export { Avatar };
