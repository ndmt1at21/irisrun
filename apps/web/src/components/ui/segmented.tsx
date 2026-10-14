import { ToggleGroup as ToggleGroupPrimitive } from "radix-ui";
import { type ComponentProps, useState } from "react";
import { cn } from "../../lib/utils";

/**
 * One choice out of a few, drawn like the tab list (Run target, Retention).
 * Unlike a plain single toggle group, clicking the chosen item keeps it chosen.
 */
function Segmented({
  className,
  value,
  defaultValue,
  onValueChange,
  ...props
}: Omit<ToggleGroupPrimitive.ToggleGroupSingleProps, "type">) {
  const [own, setOwn] = useState(defaultValue);
  return (
    <ToggleGroupPrimitive.Root
      data-slot="segmented"
      type="single"
      value={value ?? own}
      onValueChange={(next) => {
        if (!next) return;
        setOwn(next);
        onValueChange?.(next);
      }}
      className={cn("inline-flex w-fit items-center gap-0.5 rounded-lg bg-muted p-[3px]", className)}
      {...props}
    />
  );
}

function SegmentedItem({ className, ...props }: ComponentProps<typeof ToggleGroupPrimitive.Item>) {
  return (
    <ToggleGroupPrimitive.Item
      data-slot="segmented-item"
      className={cn(
        "inline-flex h-[26px] cursor-pointer items-center justify-center gap-1.5 whitespace-nowrap rounded-md px-2.5 text-xs font-medium text-muted-foreground transition-colors hover:text-foreground disabled:pointer-events-none disabled:opacity-50 data-[state=on]:bg-background data-[state=on]:text-foreground data-[state=on]:shadow-xs [&_svg]:size-3.5 [&_svg]:shrink-0",
        className,
      )}
      {...props}
    />
  );
}

export { Segmented, SegmentedItem };
