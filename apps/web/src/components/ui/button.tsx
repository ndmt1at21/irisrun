import { cva, type VariantProps } from "class-variance-authority";
import { Slot } from "radix-ui";
import type { ComponentProps } from "react";
import { cn } from "../../lib/utils";

const buttonVariants = cva(
  "inline-flex shrink-0 cursor-pointer items-center justify-center gap-1.5 whitespace-nowrap rounded-md font-medium transition-colors disabled:pointer-events-none disabled:opacity-50 [&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4",
  {
    variants: {
      variant: {
        default: "bg-primary text-primary-foreground hover:bg-primary/90",
        outline: "border border-input bg-transparent text-foreground hover:bg-accent",
        secondary: "bg-accent text-foreground hover:bg-accent/70",
        ghost: "bg-transparent text-foreground hover:bg-accent aria-expanded:bg-accent aria-pressed:bg-accent",
        destructive: "border border-destructive/50 bg-transparent text-destructive hover:bg-destructive/10",
        link: "h-auto px-0 text-link underline-offset-4 hover:text-foreground hover:underline",
      },
      size: {
        xs: "h-7 px-2.5 text-xs",
        sm: "h-[30px] px-3 text-[12.5px]",
        default: "h-8 px-3 text-[13px]",
        lg: "h-[34px] px-3.5 text-[13px]",
        xl: "h-10 rounded-lg px-4 text-[13px]",
        "icon-xs": "size-7",
        "icon-sm": "size-[30px]",
        icon: "size-8",
      },
    },
    compoundVariants: [
      // Toolbar icons are muted until hovered or pressed, as in the design.
      {
        variant: "ghost",
        size: ["icon-xs", "icon-sm", "icon"],
        className: "text-muted-foreground hover:text-foreground aria-expanded:text-foreground aria-pressed:text-foreground",
      },
    ],
    defaultVariants: { variant: "default", size: "default" },
  },
);

function Button({
  className,
  variant,
  size,
  asChild = false,
  type = "button",
  ...props
}: ComponentProps<"button"> & VariantProps<typeof buttonVariants> & { asChild?: boolean }) {
  const Comp = asChild ? Slot.Root : "button";
  return (
    <Comp
      data-slot="button"
      type={asChild ? undefined : type}
      className={cn(buttonVariants({ variant, size }), className)}
      {...props}
    />
  );
}

export { Button, buttonVariants };
