import { Cloud, Cpu, RefreshCw } from "lucide-react";
import { useState } from "react";
import { Alert, AlertDescription, AlertTitle } from "../../components/ui/alert";
import { Badge, type BadgeTone } from "../../components/ui/badge";
import { Button } from "../../components/ui/button";
import { Segmented, SegmentedItem } from "../../components/ui/segmented";
import { cn } from "../../lib/utils";
import { type BinaryStatus, binaryReport, type NativeBinary } from "../../mocks/device/binaries";
import { PageLayout } from "./PageLayout";

const STATUSES: Record<BinaryStatus, { badge: string; filter: string; tone: BadgeTone }> = {
  ok: { badge: "✓ OK", filter: "OK", tone: "success" },
  slow: { badge: "◐ Runs slower", filter: "Slow", tone: "warning" },
  "wont-run": { badge: "✕ Won’t run", filter: "Won’t run", tone: "destructive" },
};

// Library, CPU architectures, how it runs here, status, size. The artboard has no
// box-sizing reset, so `box-content` below keeps its widths and row heights.
const COLUMNS = "grid grid-cols-[minmax(0,1.5fr)_minmax(0,1fr)_minmax(0,1.25fr)_128px_72px] items-center gap-3.5 px-4";

/** Route `/binaries`: how each native library of the build runs on this computer. */
export function BinaryDoctorPage() {
  const { project, target, host, libraries, ios } = binaryReport;
  const [filter, setFilter] = useState("all");
  const shown = filter === "all" ? libraries : libraries.filter((lib) => lib.status === filter);
  const blocked = libraries.filter((lib) => lib.status === "wont-run");
  const [first] = blocked;

  return (
    <PageLayout project={project} target={target}>
      <div className="mx-auto box-content flex max-w-[1180px] flex-col gap-[18px] px-6 py-7">
        <div className="flex flex-wrap items-end gap-3">
          <div className="flex-[1_1_320px]">
            <div className="flex items-center gap-2 text-xs text-muted-foreground">
              <Cpu className="size-3.5" />
              Binary Doctor
            </div>
            <h1 className="mt-1 text-[22px] font-semibold tracking-[-0.02em]">Native libraries</h1>
            <p className="mt-0.5 text-muted-foreground">
              Checked on every build. Shows how each .so or .xcframework runs on this computer’s CPU.
            </p>
          </div>
          <Button variant="outline" className="text-[12.5px]">
            <RefreshCw className="size-3.5" />
            Re-check
          </Button>
        </div>

        {first && (
          <Alert className="flex-wrap items-center gap-3.5 rounded-[10px] px-4 py-3.5">
            <span className="inline-flex size-9 items-center justify-center rounded-[9px] bg-primary/22 text-link">
              <Cloud className="size-[18px]" />
            </span>
            <div className="min-w-0 flex-[1_1_360px]">
              <AlertTitle>
                {blocked.length} {blocked.length === 1 ? "library" : "libraries"} can’t run on this computer
              </AlertTitle>
              <AlertDescription className="text-[13px]">
                <span className="font-mono text-foreground">{first.name}</span> {first.reason}
              </AlertDescription>
            </div>
            <Button size="lg">Run on cloud</Button>
            <Button size="lg" variant="outline" className="px-3">
              Pick a real device
            </Button>
          </Alert>
        )}

        <div className="flex flex-wrap items-center gap-2">
          <Segmented aria-label="Filter by status" value={filter} onValueChange={setFilter}>
            <SegmentedItem value="all">All {libraries.length}</SegmentedItem>
            {(Object.keys(STATUSES) as BinaryStatus[]).map((status) => (
              <SegmentedItem key={status} value={status}>
                {STATUSES[status].filter} {libraries.filter((lib) => lib.status === status).length}
              </SegmentedItem>
            ))}
          </Segmented>
          <div className="flex-1" />
          <span className="text-xs text-muted-foreground">
            This computer: <span className="font-mono text-foreground">{host.arch}</span> · {host.os}
          </span>
        </div>

        <div className="overflow-x-auto rounded-[10px] border">
          <div role="table" aria-label="Native libraries" className="min-w-[900px]">
            <div role="row" className={cn(COLUMNS, "h-9 bg-muted text-[11.5px] font-medium text-muted-foreground")}>
              <span role="columnheader">Library</span>
              <span role="columnheader">CPU architectures</span>
              <span role="columnheader">How it runs here</span>
              <span role="columnheader">Status</span>
              <span role="columnheader" className="text-right">
                Size
              </span>
            </div>
            {shown.map((lib) => (
              <BinaryRow
                key={lib.name}
                binary={lib}
                className={cn("box-content min-h-[52px] border-t py-1.5", lib.status === "wont-run" && "bg-destructive/6")}
              />
            ))}
          </div>
        </div>

        <div className="rounded-[10px] border">
          <div className="flex items-center gap-2 border-b px-4 py-3">
            <span className="font-semibold">{ios.project}</span>
            <span className="text-xs text-muted-foreground">
              · {ios.frameworks.length} .xcframework · checked {ios.checked}
            </span>
          </div>
          <div className="overflow-x-auto">
            <div role="table" aria-label="iOS frameworks" className="min-w-[900px] text-[12.5px]">
              {ios.frameworks.map((framework) => (
                <BinaryRow key={framework.name} binary={framework} className="box-content min-h-11 border-t first:border-t-0" />
              ))}
            </div>
          </div>
        </div>
      </div>
    </PageLayout>
  );
}

function BinaryRow({ binary, className }: { binary: NativeBinary; className: string }) {
  const { badge, tone } = STATUSES[binary.status];
  return (
    <div role="row" className={cn(COLUMNS, className)}>
      <span role="cell" className="min-w-0">
        <span className="block font-mono text-[12.5px] font-medium">{binary.name}</span>
        {binary.source && <span className="block truncate text-[11.5px] text-muted-foreground">{binary.source}</span>}
      </span>
      <span role="cell" className="font-mono text-xs text-muted-foreground">
        {binary.abis}
      </span>
      <span role="cell" className="text-[12.5px]">
        {binary.how}
      </span>
      <span role="cell">
        <Badge tone={tone} className="text-[11.5px]">
          {badge}
        </Badge>
      </span>
      <span role="cell" className="text-right font-mono text-xs text-muted-foreground">
        {binary.size}
      </span>
    </div>
  );
}
