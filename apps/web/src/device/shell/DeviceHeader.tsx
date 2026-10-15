import {
  ChevronDown,
  CircleCheck,
  CircleX,
  Clock,
  Cloud,
  Camera,
  Laptop,
  LoaderCircle,
  PanelBottom,
  PanelRight,
  Settings2,
  Smartphone,
  Wifi,
  WifiOff,
} from "lucide-react";
import { Fragment } from "react";
import { IrisLogo } from "../../components/IrisLogo";
import { type RunStatus, RunStatusBadge } from "../../components/RunStatusBadge";
import { ThemeToggle } from "../../components/ThemeToggle";
import { TopBar } from "../../components/TopBar";
import { Button } from "../../components/ui/button";
import { Popover, PopoverContent, PopoverTrigger } from "../../components/ui/popover";
import { Progress } from "../../components/ui/progress";
import { Segmented, SegmentedItem } from "../../components/ui/segmented";
import { Separator } from "../../components/ui/separator";
import { cn } from "../../lib/utils";

export type RunTarget = "local" | "cloud" | "device";
export type Dock = "right" | "bottom";

/** The hot reload pill of a local run, e.g. updated "CartViewModel.kt · 412 ms · 2s ago". */
export interface HotReload {
  state: "rebuilding" | "updated" | "failed";
  /** The file while rebuilding; what happened otherwise. */
  detail: string;
  /** Percent done while rebuilding. */
  progress?: number;
}

/** A cloud or real-device session, shown at the right of the header. */
export interface RemoteSession {
  /** Round-trip time in ms; undefined while the connection is down. */
  latency?: number;
  region: string;
  /** Time left, "mm:ss". */
  endsIn: string;
  recordingForReplay?: boolean;
  /** The popover behind the latency button; without it the latency is a plain chip. */
  details?: {
    facts: { label: string; value: string; mono?: boolean }[];
    duration: string;
    /** Starts open without taking focus, as the CloudSession artboard shows it. */
    defaultOpen?: boolean;
  };
}

export interface DeviceHeaderProps {
  project: { name: string; detail: string };
  status: RunStatus;
  target: RunTarget;
  /** Local runs only. */
  hotReload?: HotReload;
  /** Local runs only: the elapsed time while recording, e.g. "00:42"; the idle Record button otherwise. */
  recording?: string;
  /** Cloud and real-device runs only. */
  remote?: RemoteSession;
}

const HOT_RELOAD = {
  rebuilding: {
    label: "Rebuilding…",
    icon: <LoaderCircle className="size-3.5 animate-spin text-primary" strokeWidth={2.4} />,
    box: "border-[color-mix(in_srgb,var(--primary)_35%,var(--border))] bg-primary/6",
  },
  updated: { label: "Updated", icon: <CircleCheck className="size-3.5 text-success" />, box: "" },
  failed: { label: "Failed", icon: <CircleX className="size-3.5 text-destructive" />, box: "border-destructive/40" },
};

const QUALITY = {
  good: { label: "Good connection", text: "text-success", pill: "bg-success/14" },
  fair: { label: "Fair connection", text: "text-warning", pill: "bg-warning/14" },
  poor: { label: "Poor connection", text: "text-destructive", pill: "bg-destructive/14" },
  down: { label: "No connection", text: "text-warning", pill: "bg-warning/14" },
};

const seconds = (time: string) => time.split(":").reduce((total, part) => total * 60 + Number(part), 0);

export function DeviceHeader({
  project,
  status,
  target,
  hotReload,
  recording,
  remote,
  dock,
  onDock,
}: DeviceHeaderProps & { dock: Dock; onDock: (dock: Dock) => void }) {
  const local = target === "local";
  return (
    <TopBar>
      <div className="flex items-center gap-2">
        <IrisLogo />
        <span className="text-sm font-semibold tracking-[-0.01em]">Iris</span>
      </div>
      <Separator orientation="vertical" />
      <Button variant="ghost" size="sm" className="gap-1.5 px-2 text-[13px]">
        {project.name}
        <span className="font-normal text-muted-foreground">/ {project.detail}</span>
        <ChevronDown className="size-3.5" />
      </Button>
      <RunStatusBadge status={status} />
      <span className="flex-[1_1_24px]" />
      <Segmented aria-label="Run target" defaultValue={target}>
        <SegmentedItem value="local">
          <Laptop />
          Local
        </SegmentedItem>
        <SegmentedItem value="cloud">
          <Cloud />
          Cloud
        </SegmentedItem>
        <SegmentedItem value="device">
          <Smartphone />
          Real device
        </SegmentedItem>
      </Segmented>
      {local && hotReload && (
        <div
          role="status"
          className={cn(
            "inline-flex h-[30px] items-center gap-2 rounded-full border px-2.5 text-xs",
            HOT_RELOAD[hotReload.state].box,
          )}
        >
          {HOT_RELOAD[hotReload.state].icon}
          <span className="font-medium">Hot reload · {HOT_RELOAD[hotReload.state].label}</span>
          <span className="text-muted-foreground">{hotReload.detail}</span>
          {hotReload.progress !== undefined && (
            <Progress aria-hidden="true" value={hotReload.progress} className="h-1 w-12" />
          )}
        </div>
      )}
      <span className="flex-[1_1_24px]" />
      {!local && remote && <RemoteStatus target={target} {...remote} />}
      <div className="flex items-center gap-1">
        {local && (
          <>
            <Button variant="ghost" size="icon" aria-label="Take screenshot" title="Screenshot">
              <Camera />
            </Button>
            {recording ? (
              <Button
                variant="destructive"
                size="sm"
                aria-label="Stop recording"
                className="gap-2 border-destructive/45 bg-destructive/10 px-2.5 text-xs font-semibold"
              >
                <span className="size-2 rounded-full bg-[#ef4444] shadow-[0_0_0_3px_rgba(239,68,68,.28)]" />
                REC
                <span className="font-mono font-medium">{recording}</span>
                <svg aria-hidden="true" viewBox="0 0 24 24" className="size-3" fill="currentColor">
                  <rect x="5" y="5" width="14" height="14" rx="2" />
                </svg>
              </Button>
            ) : (
              <Button variant="outline" size="sm" className="bg-background px-2.5 text-xs">
                <svg aria-hidden="true" viewBox="0 0 24 24" className="size-3.5" fill="none" stroke="currentColor" strokeWidth="2">
                  <circle cx="12" cy="12" r="9" />
                  <circle cx="12" cy="12" r="3.5" fill="#ef4444" stroke="none" />
                </svg>
                Record
              </Button>
            )}
          </>
        )}
        <Separator orientation="vertical" className="mx-1" />
        {/* Under 768 px the panel is always docked at the bottom. */}
        <div role="group" aria-label="Panel position" className="inline-flex gap-0.5 max-md:hidden">
          <Button variant="ghost" size="icon" aria-label="Dock panel right" aria-pressed={dock === "right"} onClick={() => onDock("right")}>
            <PanelRight />
          </Button>
          <Button variant="ghost" size="icon" aria-label="Dock panel bottom" aria-pressed={dock === "bottom"} onClick={() => onDock("bottom")}>
            <PanelBottom />
          </Button>
        </div>
        <ThemeToggle />
        <Button variant="ghost" size="icon" aria-label="Settings">
          <Settings2 />
        </Button>
      </div>
    </TopBar>
  );
}

function RemoteStatus({ target, latency, region, endsIn, recordingForReplay, details }: RemoteSession & { target: RunTarget }) {
  const quality =
    QUALITY[latency === undefined ? "down" : latency < 80 ? "good" : latency <= 200 ? "fair" : "poor"];
  const chip = cn(
    "inline-flex h-[30px] items-center gap-2.5 rounded-md border border-input px-2.5 text-xs",
    latency === undefined && "border-[color-mix(in_srgb,var(--warning)_45%,var(--border))] bg-warning/8",
  );
  const latencyText = (
    <>
      <span className="inline-flex items-center gap-1.5">
        {latency === undefined ? (
          <WifiOff className="size-3.5 text-warning" strokeWidth={2.2} />
        ) : (
          <Wifi className={cn("size-3.5", quality.text)} strokeWidth={2.2} />
        )}
        <span className="font-mono font-medium">{latency ?? "—"} ms</span>
      </span>
      <span className="text-muted-foreground">{region}</span>
    </>
  );
  return (
    <>
      {details ? (
        <Popover defaultOpen={details.defaultOpen}>
          <PopoverTrigger className={cn(chip, "cursor-pointer hover:bg-accent aria-expanded:bg-accent")}>
            {latencyText}
          </PopoverTrigger>
          <PopoverContent
            aria-label="Session details"
            sideOffset={12}
            // Open on load: leave focus alone. Opened from the trigger: focus moves in as usual.
            onOpenAutoFocus={(event) => details.defaultOpen && document.activeElement === document.body && event.preventDefault()}
          >
            <div className="flex items-center justify-between">
              <span className="font-semibold">{target === "cloud" ? "Cloud session" : "Real device session"}</span>
              <span className={cn("inline-flex h-5 items-center rounded-full px-[7px] text-[11px] font-medium", quality.text, quality.pill)}>
                {quality.label}
              </span>
            </div>
            <dl className="mt-3 grid grid-cols-[auto_minmax(0,1fr)] gap-x-4 gap-y-2 text-[12.5px]">
              {details.facts.map(({ label, value, mono }) => (
                <Fragment key={label}>
                  <dt className="text-muted-foreground">{label}</dt>
                  <dd className={cn("text-right", mono && "font-mono")}>{value}</dd>
                </Fragment>
              ))}
            </dl>
            <div className="mt-3 flex justify-between text-xs text-muted-foreground">
              <span>Time left</span>
              <span>
                <span className="font-mono text-foreground">{endsIn}</span> of {details.duration}
              </span>
            </div>
            <Progress
              aria-label="Time left"
              value={Math.round((seconds(endsIn) / seconds(details.duration)) * 100)}
              className="mt-1.5 h-1.5"
            />
            <div className="mt-3.5 flex gap-2">
              <Button variant="outline" className="flex-1 text-[12.5px]">
                Extend 15 min
              </Button>
              <Button variant="destructive" className="flex-1 text-[12.5px]">
                End session
              </Button>
            </div>
          </PopoverContent>
        </Popover>
      ) : (
        <span className={chip}>{latencyText}</span>
      )}
      <span className="inline-flex h-[30px] items-center gap-1.5 rounded-md border px-2.5 text-xs">
        <Clock className="size-3.5 text-muted-foreground" />
        <span className="text-muted-foreground">Ends in</span>
        <span className="font-mono font-medium">{endsIn}</span>
      </span>
      {recordingForReplay && (
        <span className="inline-flex items-center gap-1.5 text-xs text-muted-foreground">
          <span className="size-[7px] rounded-full bg-[#ef4444]" />
          Recording for replay
        </span>
      )}
      <Button variant="destructive" size="sm" className="text-xs">
        End session
      </Button>
    </>
  );
}
