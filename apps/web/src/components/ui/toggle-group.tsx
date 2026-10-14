import { ToggleGroup as ToggleGroupPrimitive } from "radix-ui";
import type { ComponentProps } from "react";
import { cn } from "../../lib/utils";

/** Joined, bordered toggles where any number can be on, like the log levels. */
function ToggleGroup({ className, ...props }: Omit<ToggleGroupPrimitive.ToggleGroupMultipleProps, "type">) {
  return (
    <ToggleGroupPrimitive.Root
      data-slot="toggle-group"
      type="multiple"
      className={cn("inline-flex w-fit overflow-hidden rounded-md border border-input", className)}
      {...props}
    />
  );
}

function ToggleGroupItem({ className, ...props }: ComponentProps<typeof ToggleGroupPrimitive.Item>) {
  return (
    <ToggleGroupPrimitive.Item
      data-slot="toggle-group-item"
      className={cn(
        "inline-flex h-[26px] cursor-pointer items-center gap-[5px] whitespace-nowrap border-r border-input px-[9px] text-xs text-muted-foreground transition-colors last:border-r-0 hover:text-foreground disabled:pointer-events-none disabled:opacity-50 data-[state=on]:bg-accent data-[state=on]:font-medium data-[state=on]:text-foreground",
        className,
      )}
      {...props}
    />
  );
}

export { ToggleGroup, ToggleGroupItem };
