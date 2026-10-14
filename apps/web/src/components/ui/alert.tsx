import { cva, type VariantProps } from "class-variance-authority";
import type { ComponentProps } from "react";
import { cn } from "../../lib/utils";

const alertVariants = cva(
  "flex gap-2.5 rounded-lg border p-3 text-foreground [&>svg]:mt-0.5 [&>svg]:size-4 [&>svg]:shrink-0",
  {
    variants: {
      variant: {
        info: "border-[color-mix(in_srgb,var(--primary)_45%,var(--border))] bg-selection [&>svg]:text-link",
        warning:
          "border-warning/45 bg-[color-mix(in_srgb,var(--warning)_9%,var(--background))] [&>svg]:text-warning",
        destructive:
          "border-destructive/40 bg-[color-mix(in_srgb,var(--destructive)_6%,var(--background))] [&>svg]:text-destructive",
      },
    },
    defaultVariants: { variant: "info" },
  },
);

/** A callout: an optional icon, then AlertTitle, AlertDescription and actions in a div. */
function Alert({ className, variant, ...props }: ComponentProps<"div"> & VariantProps<typeof alertVariants>) {
  return <div data-slot="alert" role="alert" className={cn(alertVariants({ variant }), className)} {...props} />;
}

function AlertTitle({ className, ...props }: ComponentProps<"div">) {
  return <div data-slot="alert-title" className={cn("font-semibold", className)} {...props} />;
}

function AlertDescription({ className, ...props }: ComponentProps<"div">) {
  return <div data-slot="alert-description" className={cn("text-[12.5px] text-muted-foreground", className)} {...props} />;
}

export { Alert, AlertDescription, AlertTitle };
