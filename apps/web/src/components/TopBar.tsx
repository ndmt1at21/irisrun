import type { ComponentProps } from "react";
import { cn } from "../lib/utils";

/** The 48 px header bar of the Device UI and other full pages. */
export function TopBar({ className, ...props }: ComponentProps<"header">) {
  return (
    <header
      className={cn(
        "flex min-h-12 shrink-0 flex-wrap items-center gap-2.5 border-b border-border bg-background px-3",
        className,
      )}
      {...props}
    />
  );
}
