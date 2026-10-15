import { cva, type VariantProps } from "class-variance-authority";
import type { ComponentProps } from "react";
import { cn } from "../../lib/utils";

const badgeVariants = cva(
  "inline-flex h-[22px] shrink-0 items-center gap-1.5 whitespace-nowrap rounded-full px-2 text-xs font-medium [&_svg]:shrink-0",
  {
    variants: {
      tone: {
        success: "bg-success/12 text-success",
        warning: "bg-warning/12 text-warning",
        destructive: "bg-destructive/12 text-destructive",
        info: "bg-info/12 text-info",
        primary: "bg-selection text-link",
        muted: "bg-muted text-muted-foreground",
        outline: "border border-border font-normal text-muted-foreground",
      },
    },
    defaultVariants: { tone: "muted" },
  },
);

type BadgeTone = NonNullable<VariantProps<typeof badgeVariants>["tone"]>;

/** A 22 px pill; `dot` adds the 6 px status dot in the current color. */
function Badge({
  className,
  tone,
  dot = false,
  children,
  ...props
}: ComponentProps<"span"> & VariantProps<typeof badgeVariants> & { dot?: boolean }) {
  return (
    <span data-slot="badge" className={cn(badgeVariants({ tone }), className)} {...props}>
      {dot && <span aria-hidden="true" className="size-1.5 shrink-0 rounded-full bg-current" />}
      {children}
    </span>
  );
}

/** A small bordered label, e.g. a license ID or "Managed by Iris". */
function Tag({ className, ...props }: ComponentProps<"span">) {
  return (
    <span
      data-slot="tag"
      className={cn(
        "inline-flex h-[22px] shrink-0 items-center gap-1 whitespace-nowrap rounded-sm border border-border px-1.5 text-[11px] text-muted-foreground",
        className,
      )}
      {...props}
    />
  );
}

export { Badge, type BadgeTone, Tag };
