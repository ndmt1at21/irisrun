import { cn } from "../lib/utils";

/** Log levels as the design abbreviates them; P marks the line where the app paused. */
export type LevelCode = "V" | "D" | "I" | "W" | "E" | "P";

const COLORS: Record<LevelCode, string> = {
  V: "bg-muted-foreground/18 text-muted-foreground",
  D: "bg-info/18 text-info",
  I: "bg-success/18 text-success",
  W: "bg-warning/18 text-warning",
  E: "bg-destructive/18 text-destructive",
  P: "bg-link/18 text-link",
};

/** The 16 px letter chip of a log row. */
export function LevelChip({ level, className }: { level: LevelCode; className?: string }) {
  return (
    <span
      className={cn(
        "inline-flex size-4 shrink-0 items-center justify-center rounded-sm font-mono text-[10px] leading-none font-semibold",
        COLORS[level],
        className,
      )}
    >
      {level === "P" ? "‖" : level}
    </span>
  );
}
