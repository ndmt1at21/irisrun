import { cva, type VariantProps } from "class-variance-authority";
import type { ComponentProps, ReactNode } from "react";
import { cn } from "../../lib/utils";

const iconVariants = cva(
  "inline-flex size-10 shrink-0 items-center justify-center rounded-[10px] [&_svg:not([class*='size-'])]:size-[18px]",
  {
    variants: {
      tone: {
        muted: "bg-muted text-muted-foreground",
        warning: "bg-warning/14 text-warning",
        success: "bg-success/14 text-success",
      },
    },
    defaultVariants: { tone: "muted" },
  },
);

/** The centered "nothing here" block; children go between the description and the actions. */
function EmptyState({
  className,
  icon,
  tone,
  title,
  description,
  actions,
  children,
  ...props
}: Omit<ComponentProps<"div">, "title"> &
  VariantProps<typeof iconVariants> & {
    icon?: ReactNode;
    title: ReactNode;
    description?: ReactNode;
    actions?: ReactNode;
  }) {
  return (
    <div
      data-slot="empty-state"
      className={cn("flex flex-col items-center justify-center gap-2 p-6 text-center", className)}
      {...props}
    >
      {icon && <span className={iconVariants({ tone })}>{icon}</span>}
      <div className="font-semibold">{title}</div>
      {description && <div className="max-w-[320px] text-[12.5px] text-muted-foreground">{description}</div>}
      {children}
      {actions && <div className="mt-1 flex flex-wrap justify-center gap-2">{actions}</div>}
    </div>
  );
}

export { EmptyState };
