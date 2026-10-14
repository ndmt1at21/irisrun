import type { ComponentProps } from "react";
import { cn } from "../../lib/utils";

/** A shortcut hint inside a button, e.g. ⌘R. */
function Kbd({ className, ...props }: ComponentProps<"kbd">) {
  return <kbd data-slot="kbd" className={cn("font-mono text-[11px] opacity-75", className)} {...props} />;
}

export { Kbd };
