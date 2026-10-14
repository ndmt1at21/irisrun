import { RadioGroup as RadioGroupPrimitive } from "radix-ui";
import type { ComponentProps } from "react";
import { cn } from "../../lib/utils";

function RadioGroup({ className, ...props }: ComponentProps<typeof RadioGroupPrimitive.Root>) {
  return <RadioGroupPrimitive.Root data-slot="radio-group" className={cn("grid gap-2.5", className)} {...props} />;
}

/** A selectable card; the chosen one gets the primary border and selection background. */
function RadioGroupItem({ className, ...props }: ComponentProps<typeof RadioGroupPrimitive.Item>) {
  return (
    <RadioGroupPrimitive.Item
      data-slot="radio-group-item"
      className={cn(
        "cursor-pointer rounded-lg border border-border bg-card p-3 text-left text-foreground disabled:cursor-not-allowed disabled:opacity-50 data-[state=checked]:border-[1.5px] data-[state=checked]:border-primary data-[state=checked]:bg-selection",
        className,
      )}
      {...props}
    />
  );
}

export { RadioGroup, RadioGroupItem };
