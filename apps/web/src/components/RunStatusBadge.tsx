import { LoaderCircle, Pause } from "lucide-react";
import { Badge, type BadgeTone } from "./ui/badge";

export type RunStatus = "running" | "paused" | "setting-up" | "building" | "waiting" | "reconnecting" | "build-failed";

const STATUSES: Record<RunStatus, { label: string; tone: BadgeTone; mark?: "dot" | "spinner" | "pause" }> = {
  running: { label: "Running", tone: "success", mark: "dot" },
  paused: { label: "Paused", tone: "primary", mark: "pause" },
  "setting-up": { label: "Setting up", tone: "primary", mark: "spinner" },
  building: { label: "Building", tone: "primary", mark: "spinner" },
  waiting: { label: "Waiting for you", tone: "warning" },
  reconnecting: { label: "Reconnecting", tone: "warning", mark: "spinner" },
  "build-failed": { label: "Build failed", tone: "destructive", mark: "dot" },
};

/** What the app is doing, next to the project name in the header. */
export function RunStatusBadge({ status, className }: { status: RunStatus; className?: string }) {
  const { label, tone, mark } = STATUSES[status];
  return (
    <Badge tone={tone} dot={mark === "dot"} className={className}>
      {mark === "spinner" && <LoaderCircle aria-hidden="true" className="size-[11px] animate-spin" strokeWidth={3} />}
      {mark === "pause" && <Pause aria-hidden="true" className="size-2.5" fill="currentColor" strokeWidth={0} />}
      {label}
    </Badge>
  );
}
