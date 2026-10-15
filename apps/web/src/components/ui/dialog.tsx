import { Dialog as DialogPrimitive } from "radix-ui";
import type { ComponentProps } from "react";
import { cn } from "../../lib/utils";

const Dialog = DialogPrimitive.Root;
const DialogTrigger = DialogPrimitive.Trigger;
const DialogClose = DialogPrimitive.Close;

const overlayClass = "fixed inset-0 z-50 bg-overlay";
const contentClass =
  "fixed top-1/2 left-1/2 z-50 max-h-[calc(100%-48px)] w-[calc(100%-48px)] max-w-[540px] -translate-x-1/2 -translate-y-1/2 overflow-y-auto rounded-xl border border-border bg-background leading-normal text-foreground shadow-[0_24px_64px_-16px_rgba(0,0,0,.5)] outline-none";

/** The centered panel over the overlay; the design has no close button, so add one when needed.
 *  `leading-normal` because the portal sits in <body>, outside the 1.5 line-height of the pages that open it. */
function DialogContent({ className, ...props }: ComponentProps<typeof DialogPrimitive.Content>) {
  return (
    <DialogPrimitive.Portal>
      <DialogPrimitive.Overlay className={overlayClass} />
      <DialogPrimitive.Content data-slot="dialog-content" className={cn(contentClass, className)} {...props} />
    </DialogPrimitive.Portal>
  );
}

function DialogHeader({ className, ...props }: ComponentProps<"div">) {
  return <div data-slot="dialog-header" className={cn("px-6 pt-[22px]", className)} {...props} />;
}

function DialogFooter({ className, ...props }: ComponentProps<"div">) {
  return (
    <div
      data-slot="dialog-footer"
      className={cn("mt-5 flex flex-wrap items-center justify-end gap-2.5 border-t border-border px-6 py-3.5", className)}
      {...props}
    />
  );
}

function DialogTitle({ className, ...props }: ComponentProps<typeof DialogPrimitive.Title>) {
  return (
    <DialogPrimitive.Title
      data-slot="dialog-title"
      className={cn("text-[17px] font-semibold tracking-[-0.01em]", className)}
      {...props}
    />
  );
}

function DialogDescription({ className, ...props }: ComponentProps<typeof DialogPrimitive.Description>) {
  return (
    <DialogPrimitive.Description
      data-slot="dialog-description"
      className={cn("mt-1.5 text-muted-foreground", className)}
      {...props}
    />
  );
}

export {
  contentClass as dialogContentClass,
  Dialog,
  DialogClose,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
  overlayClass as dialogOverlayClass,
};
