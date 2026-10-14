import type { ComponentProps } from "react";
import { cn } from "../lib/utils";

/** The 26 px status bar at the bottom of the Device UI. */
export function StatusFooter({ className, ...props }: ComponentProps<"footer">) {
  return (
    <footer
      className={cn(
        "flex min-h-[26px] shrink-0 flex-wrap items-center gap-4 border-t border-border px-3 font-mono text-[11px] text-muted-foreground",
        className,
      )}
      {...props}
    />
  );
}
