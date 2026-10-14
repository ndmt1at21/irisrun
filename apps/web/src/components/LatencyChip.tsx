import { cn } from "../lib/utils";

/** Round-trip time to a cloud device; without a number it shows the offline chip. */
export function LatencyChip({ ms, className }: { ms?: number; className?: string }) {
  const base = "inline-flex h-7 shrink-0 items-center gap-1.5 rounded-md border px-2.5 font-mono text-xs whitespace-nowrap";
  if (ms === undefined) {
    return <span className={cn(base, "border-dashed border-input text-muted-foreground", className)}>— ms</span>;
  }
  const dot = ms < 80 ? "bg-success" : ms <= 200 ? "bg-warning" : "bg-destructive";
  return (
    <span className={cn(base, "border-border", className)}>
      <span aria-hidden="true" className={cn("size-[7px] rounded-full", dot)} />
      {ms} ms
    </span>
  );
}
