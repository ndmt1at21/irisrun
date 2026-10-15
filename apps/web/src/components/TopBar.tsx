import type { ComponentProps } from "react";
import { cn } from "../lib/utils";

/** The header bar of the Device UI and other full pages: 49 px with its border, as the design renders it. */
export function TopBar({ className, ...props }: ComponentProps<"header">) {
  return (
    <header
      className={cn(
        "flex min-h-[49px] shrink-0 flex-wrap items-center gap-2.5 border-b border-border bg-background px-3",
        className,
      )}
      {...props}
    />
  );
}
