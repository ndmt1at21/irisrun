import { ArrowDown, Ban, CircleAlert, LoaderCircle, Pause, Play, Terminal } from "lucide-react";
import { useLayoutEffect, useRef, useState } from "react";
import { LevelChip, type LevelCode } from "../../components/LevelChip";
import { Alert, AlertDescription, AlertTitle } from "../../components/ui/alert";
import { Button } from "../../components/ui/button";
import { EmptyState } from "../../components/ui/empty-state";
import { SearchField } from "../../components/ui/search-field";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "../../components/ui/select";
import { Skeleton } from "../../components/ui/skeleton";
import { ToggleGroup, ToggleGroupItem } from "../../components/ui/toggle-group";
import { cn } from "../../lib/utils";
import { kedaiLogCounts, kedaiLogs, kedaiPackages, type LogCounts, type LogRow } from "../../mocks/device/logs";
import { TabBarSlot } from "../shell/tabBar";

type LogLine = Extract<LogRow, { time: string }>;

const LEVELS: [LevelCode, string][] = [
  ["V", "Verbose"],
  ["D", "Debug"],
  ["I", "Info"],
  ["W", "Warn"],
  ["E", "Error"],
];
const TINTS: Partial<Record<LevelCode, string>> = { W: "bg-warning/7", E: "bg-destructive/9", P: "bg-selection" };
const SKELETON_WIDTHS = [78, 52, 90, 64, 70, 84, 46, 72, 60];

const isLine = (row: LogRow): row is LogLine => row.kind === undefined || row.kind === "line";
const format = (count: number) => count.toLocaleString("en-US");
const plural = (count: number, word: string) => `${format(count)} ${word}${count === 1 ? "" : "s"}`;

/** Tests "tag message" against the filter text, or against a regex when the text is /…/. */
function matcher(query: string): (text: string) => boolean {
  const source = /^\/(.+)\/$/.exec(query.trim())?.[1];
  if (source) {
    try {
      const regex = new RegExp(source, "i");
      return (text) => regex.test(text);
    } catch {
      // Not a valid regex yet: match it as text.
    }
  }
  const needle = query.trim().toLowerCase();
  return (text) => text.toLowerCase().includes(needle);
}

/** The rows to show, keyed by position; stack frames go with their line and take its level's tint. */
function filterLogs(rows: LogRow[], query: string, levels?: string[]) {
  const test = matcher(query);
  let keep = true;
  let level: LevelCode | undefined;
  return rows.flatMap((row, key): { row: LogRow; key: number; level?: LevelCode }[] => {
    if (row.kind === "separator") return [{ row, key }];
    if (isLine(row)) {
      level = row.level;
      keep = (!levels || level === "P" || levels.includes(level)) && test(`${row.tag} ${row.message}`);
    }
    return keep ? [{ row, key, level }] : [];
  });
}

/**
 * The Logs panel. `full` is the Main artboard's toolbar, list and status bar;
 * `compact` puts a filter and the auto-scroll switch in the tab bar (IosUnsupported).
 */
export function LogsPanel({
  state,
  logs,
  counts,
  packages = kedaiPackages,
  variant = "full",
  tagWidth = variant === "full" ? 104 : 168,
}: {
  /** A PanelStates state: `empty`, `loading` or `error`; none means streaming. */
  state?: string;
  /** Kedai's Android logs from the Main artboard by default. */
  logs?: LogRow[];
  /** Counts for the whole stream; counted from `logs` without them. */
  counts?: LogCounts;
  packages?: string[];
  variant?: "full" | "compact";
  /** Width of the tag column in px. */
  tagWidth?: number;
}) {
  const stream = counts ?? (logs ? undefined : kedaiLogCounts);
  const [query, setQuery] = useState("");
  const [levels, setLevels] = useState(["D", "I", "W", "E"]);
  const [cleared, setCleared] = useState(false);
  const [unseen, setUnseen] = useState(stream?.unseen ?? 0);
  const [follow, setFollow] = useState(!unseen);
  const list = useRef<HTMLDivElement>(null);
  const full = variant === "full";
  const rows = cleared ? [] : (logs ?? kedaiLogs);
  const visible = filterLogs(rows, query, full ? levels : undefined);

  useLayoutEffect(() => {
    if (follow && list.current) list.current.scrollTop = list.current.scrollHeight;
  }, [follow, visible]);

  if (state === "loading") {
    return (
      <>
        <TabBarSlot>
          <span className="ml-auto inline-flex items-center gap-1.5 text-xs text-muted-foreground">
            <LoaderCircle className="size-3 animate-spin" strokeWidth={3} />
            Connecting to log stream
          </span>
        </TabBarSlot>
        <div aria-busy="true" className="flex flex-col gap-2.5 p-3">
          {SKELETON_WIDTHS.map((width, index) => (
            <div key={index} className="flex items-center gap-2.5">
              <Skeleton className="h-[9px] w-[70px]" />
              <Skeleton className="size-3.5" />
              <Skeleton className="h-[9px]" style={{ width: width * 2.6 }} />
            </div>
          ))}
        </div>
      </>
    );
  }

  if (state === "error") {
    return (
      <>
        <Alert variant="destructive" className="m-3">
          <CircleAlert />
          <div className="flex-1">
            <AlertTitle>Log stream stopped</AlertTitle>
            <AlertDescription>irisrun on localhost:7420 isn’t answering. Is the terminal still open?</AlertDescription>
            <div className="mt-2.5 flex gap-2">
              <Button size="xs">Reconnect</Button>
              <Button
                variant="outline"
                size="xs"
                className="font-normal"
                onClick={() => navigator.clipboard?.writeText("irisrun start").catch(() => {})}
              >
                Copy irisrun start
              </Button>
            </div>
          </div>
        </Alert>
        <div className="px-3 font-mono text-[11.5px] leading-5 text-muted-foreground opacity-60">
          {rows
            .filter(isLine)
            .slice(-2)
            .map(({ time, level, tag, message }, index) => (
              <div key={index} className="truncate">
                {time} {level} {tag} {message}
              </div>
            ))}
        </div>
      </>
    );
  }

  if (state === "empty" || rows.length === 0) {
    return (
      <EmptyState
        className="flex-1"
        icon={<Terminal />}
        title="No logs yet"
        description="Lines from Logcat, OSLog and print() show up here as soon as the app writes them."
      >
        <a href="https://irisrun.dev/docs/logs#filters" target="_blank" rel="noreferrer" className="text-xs no-underline">
          How to add a log tag filter
        </a>
      </EmptyState>
    );
  }

  const lines = rows.filter(isLine);
  const total = stream ?? {
    lines: lines.length,
    shown: visible.filter(({ row }) => isLine(row)).length,
    warnings: lines.filter(({ level }) => level === "W").length,
    errors: lines.filter(({ level }) => level === "E").length,
  };
  const resume = () => {
    setFollow(true);
    setUnseen(0);
  };
  const toggleFollow = follow ? () => setFollow(false) : resume;
  const followAction = follow ? "Pause auto-scroll" : "Resume auto-scroll";
  const FollowIcon = follow ? Pause : Play;
  const followLabel = follow ? "Auto-scroll on" : "Auto-scroll paused";
  const filter = (
    <SearchField
      aria-label="Filter logs"
      placeholder={full ? "Filter by text, tag or /regex/" : "Filter logs"}
      value={query}
      onChange={(event) => setQuery(event.target.value)}
      className={full ? "flex-1 bg-background text-xs" : "h-7 max-w-[260px] flex-1 text-xs"}
    />
  );

  return (
    <>
      {full ? (
        <div className="flex flex-col gap-2 border-b px-3 py-2.5">
          <div className="flex gap-2">
            {filter}
            <Select defaultValue={packages[0]}>
              <SelectTrigger aria-label="Package" className="h-[30px] bg-background pr-2 pl-2.5 text-xs">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {packages.map((name) => (
                  <SelectItem key={name} value={name}>
                    {name}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
          <div className="flex flex-wrap items-center gap-2">
            <ToggleGroup aria-label="Log levels" value={levels} onValueChange={setLevels}>
              {LEVELS.map(([level, label]) => (
                <ToggleGroupItem key={level} value={level}>
                  {label}
                  {level === "W" && <span className="text-warning">{format(total.warnings)}</span>}
                  {level === "E" && <span className="text-destructive">{format(total.errors)}</span>}
                </ToggleGroupItem>
              ))}
            </ToggleGroup>
            <span className="flex-1" />
            <Button variant="outline" size="xs" className={cn(!follow && "bg-accent")} onClick={toggleFollow}>
              <FollowIcon className="size-[13px]" fill="currentColor" strokeWidth={0} />
              {followAction}
            </Button>
            <Button variant="ghost" size="icon-xs" aria-label="Clear logs" title="Clear" onClick={() => setCleared(true)}>
              <Ban className="size-[15px]" />
            </Button>
          </div>
        </div>
      ) : (
        <TabBarSlot>
          {filter}
          <span className="flex-1" />
          <span className="text-[11px] text-muted-foreground">{followLabel}</span>
          <Button variant="outline" size="icon-xs" aria-label={followAction} onClick={toggleFollow}>
            <FollowIcon className="size-3" fill="currentColor" strokeWidth={0} />
          </Button>
        </TabBarSlot>
      )}
      <div className="relative flex min-h-0 flex-1 flex-col">
        <div
          ref={list}
          role="log"
          aria-label="Device logs"
          className="min-h-0 flex-1 overflow-auto py-1 font-mono text-[11.5px] leading-[18px]"
          onScroll={(event) => {
            const { scrollHeight, scrollTop, clientHeight } = event.currentTarget;
            const atEnd = scrollHeight - scrollTop - clientHeight < 4;
            setFollow(atEnd);
            if (atEnd) setUnseen(0);
          }}
        >
          {visible.map(({ row, key, level }) =>
            row.kind === "separator" ? (
              <div
                key={key}
                role="separator"
                aria-label={row.message}
                className="mx-3 my-2 flex items-center gap-2.5 font-sans text-xs text-warning"
              >
                <span className="h-px flex-1 bg-warning/45" />
                {row.message}
                <span className="h-px flex-1 bg-warning/45" />
              </div>
            ) : (
              <div
                key={key}
                style={{ gridTemplateColumns: `82px 16px ${tagWidth}px minmax(0, 1fr)` }}
                // Full rows wrap long messages, as in Main; compact rows keep to one line.
                className={cn("grid gap-2 px-3", full ? "items-start py-px" : "h-[22px] items-center", level && TINTS[level])}
              >
                {isLine(row) && (
                  <>
                    <span className="text-muted-foreground">{row.time}</span>
                    <LevelChip level={row.level} className={cn(full && "mt-px")} />
                    <span className="truncate text-muted-foreground">{row.tag}</span>
                  </>
                )}
                <span
                  title={row.message}
                  className={cn(
                    "col-start-4",
                    full ? "wrap-break-word whitespace-pre-wrap" : "truncate whitespace-pre",
                    !isLine(row)
                      ? "text-muted-foreground"
                      : row.level === "E"
                        ? "text-destructive"
                        : (row.level === "P" || row.tag === "iris") && "text-link",
                  )}
                >
                  {row.message}
                </span>
              </div>
            ),
          )}
        </div>
        {full && !follow && unseen > 0 && (
          <Button
            size="sm"
            className="absolute bottom-3.5 left-1/2 -translate-x-1/2 rounded-full px-3.5 text-xs shadow-[0_6px_16px_-4px_rgba(0,0,0,.45)]"
            onClick={resume}
          >
            <ArrowDown className="size-3.5" />
            {format(unseen)} new lines · Jump to latest
          </Button>
        )}
      </div>
      {full && (
        <div className="flex min-h-7 flex-wrap items-center gap-3 border-t px-3 text-[11px] text-muted-foreground">
          <span>
            Showing {format(total.shown)} of {format(total.lines)} lines
          </span>
          <span className="inline-flex items-center gap-[5px]">
            <span className="size-1.5 rounded-full bg-destructive" />
            {plural(total.errors, "error")}
          </span>
          <span className="inline-flex items-center gap-[5px]">
            <span className="size-1.5 rounded-full bg-warning" />
            {plural(total.warnings, "warning")}
          </span>
          <span className="flex-1" />
          <span>{followLabel}</span>
        </div>
      )}
    </>
  );
}
