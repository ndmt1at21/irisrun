import { Tabs as TabsPrimitive } from "radix-ui";
import { type ComponentProps, createContext, use } from "react";
import { cn } from "../../lib/utils";

type TabsVariant = "segmented" | "underline";

const LIST: Record<TabsVariant, string> = {
  segmented: "inline-flex h-8 w-fit items-center gap-0.5 rounded-lg bg-muted p-[3px]",
  underline: "flex w-full items-center gap-5 border-b",
};
const TRIGGER: Record<TabsVariant, string> = {
  segmented:
    "h-[26px] rounded-md px-2.5 text-xs font-medium data-[state=active]:bg-background data-[state=active]:shadow-xs",
  underline: "h-9 gap-1 border-b-2 border-transparent data-[state=active]:border-foreground data-[state=active]:font-medium",
};
const VariantContext = createContext<TabsVariant>("segmented");

function Tabs({ className, ...props }: ComponentProps<typeof TabsPrimitive.Root>) {
  return <TabsPrimitive.Root data-slot="tabs" className={className} {...props} />;
}

/** `segmented` is the pill bar of the device panels; `underline` is the row of the Members page. */
function TabsList({
  className,
  variant = "segmented",
  ...props
}: ComponentProps<typeof TabsPrimitive.List> & { variant?: TabsVariant }) {
  return (
    <VariantContext value={variant}>
      <TabsPrimitive.List data-slot="tabs-list" className={cn(LIST[variant], className)} {...props} />
    </VariantContext>
  );
}

function TabsTrigger({ className, onMouseDown, ...props }: ComponentProps<typeof TabsPrimitive.Trigger>) {
  return (
    <TabsPrimitive.Trigger
      data-slot="tabs-trigger"
      className={cn(
        "inline-flex cursor-pointer items-center justify-center gap-1.5 whitespace-nowrap text-muted-foreground transition-colors hover:text-foreground disabled:pointer-events-none disabled:opacity-50 data-[state=active]:text-foreground [&_svg]:size-3.5 [&_svg]:shrink-0",
        TRIGGER[use(VariantContext)],
        className,
      )}
      onMouseDown={(event) => {
        onMouseDown?.(event);
        // Radix focuses the tab from script on mousedown, which Chrome rings like keyboard focus on a
        // page's first click. Focusing it first, without the ring, turns that call into a no-op.
        if (!event.defaultPrevented && event.button === 0 && !event.ctrlKey) {
          event.currentTarget.focus({ focusVisible: false });
        }
      }}
      {...props}
    />
  );
}

function TabsContent({ className, ...props }: ComponentProps<typeof TabsPrimitive.Content>) {
  return <TabsPrimitive.Content data-slot="tabs-content" className={className} {...props} />;
}

export { Tabs, TabsContent, TabsList, TabsTrigger };
