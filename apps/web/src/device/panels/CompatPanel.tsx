import { Link } from "@tanstack/react-router";
import { Check, Cloud, Copy, RefreshCw } from "lucide-react";
import { useId, useState } from "react";
import { Tag } from "../../components/ui/badge";
import { Button } from "../../components/ui/button";
import { EmptyState } from "../../components/ui/empty-state";
import { SearchField } from "../../components/ui/search-field";
import { Segmented, SegmentedItem } from "../../components/ui/segmented";
import { cn } from "../../lib/utils";
import { type CompatBehavior, kedaiCompat, type UnsupportedApi } from "../../mocks/device/compat";

const BEHAVIORS: Record<CompatBehavior, { label: string; title: string; hint: string; dot: string; badge: string }> = {
  pause: {
    label: "Pauses app",
    title: "Pauses the app",
    hint: "Run these on a cloud simulator",
    dot: "bg-warning",
    badge: "bg-warning/14 text-warning",
  },
  stub: {
    label: "Stubbed",
    title: "Stubbed",
    hint: "Return a safe “unavailable” value",
    dot: "bg-info",
    badge: "bg-info/14 text-info",
  },
  ignore: {
    label: "Ignored",
    title: "Ignored",
    hint: "Run silently with no effect",
    dot: "bg-muted-foreground",
    badge: "bg-muted text-muted-foreground",
  },
};
const KINDS = Object.keys(BEHAVIORS) as CompatBehavior[];
const COLUMNS = "grid grid-cols-[20px_minmax(0,1.6fr)_104px_128px_minmax(0,1.1fr)] items-center gap-2.5 px-3";
const fileLink = "h-auto min-w-0 shrink justify-start px-0 font-normal";

/** The report as a Markdown table, for an issue or a chat. */
function toMarkdown(apis: UnsupportedApi[]) {
  return [
    "| API | Framework | Runs locally as | Called from |",
    "| --- | --- | --- | --- |",
    ...apis.map(
      ({ api, framework, behavior, sites }) =>
        `| \`${api}\` | ${framework} | ${BEHAVIORS[behavior].label} | ${sites.map(({ file }) => file).join(", ")} |`,
    ),
  ].join("\n");
}

/** The Compatibility panel: iOS APIs the app calls that the local runtime doesn't have. `state` `all-clear` means none. */
export function CompatPanel({ state }: { state?: string }) {
  const { apis, files, scanned } = kedaiCompat;
  const [query, setQuery] = useState("");
  const [behavior, setBehavior] = useState<CompatBehavior | "all">("all");
  const [open, setOpen] = useState(() => new Set(apis.slice(0, 1).map(({ api }) => api)));
  const [copied, setCopied] = useState(false);
  const id = useId();

  if (state === "all-clear") {
    return (
      <EmptyState
        className="flex-1"
        tone="success"
        icon={<Check strokeWidth={2.4} />}
        title="Everything runs locally"
        description={`Every iOS API your app calls is supported by the local runtime. Scanned ${files} Swift files.`}
        actions={
          <Button variant="outline" size="xs" className="font-normal">
            Rescan
          </Button>
        }
      />
    );
  }

  const needle = query.trim().toLowerCase();
  const shown = apis.filter(
    ({ api, framework, behavior: kind, sites }) =>
      (behavior === "all" || kind === behavior) &&
      [api, framework, ...sites.map(({ file }) => file)].some((text) => text.toLowerCase().includes(needle)),
  );
  const count = (kind: CompatBehavior) => apis.filter((api) => api.behavior === kind).length;
  const toggle = (api: string) => {
    const next = new Set(open);
    if (!next.delete(api)) next.add(api);
    setOpen(next);
  };
  const copy = () =>
    navigator.clipboard?.writeText(toMarkdown(apis)).then(
      () => {
        setCopied(true);
        setTimeout(() => setCopied(false), 2000);
      },
      () => {},
    );

  return (
    <div className="min-h-0 flex-1 overflow-auto p-4">
      <div className="mb-3.5 flex flex-wrap items-start gap-3">
        <div className="min-w-0 flex-[1_1_280px]">
          <h2 className="text-base font-semibold tracking-[-0.01em]">Compatibility report</h2>
          <p className="mt-0.5 text-muted-foreground">
            {apis.length} APIs your app calls aren’t in the local iOS runtime yet. Everything else runs locally.
          </p>
        </div>
        <Button variant="outline" size="sm" className="px-2.5 text-xs">
          <RefreshCw className="size-3.5" />
          Rescan
        </Button>
        <Button variant="outline" size="sm" className="px-2.5 text-xs" onClick={copy}>
          {copied ? <Check className="size-3.5" /> : <Copy className="size-3.5" />}
          {copied ? "Copied" : "Copy as Markdown"}
        </Button>
      </div>

      <div className="mb-3.5 grid grid-cols-3 gap-2">
        {KINDS.map((kind) => (
          <div key={kind} className="rounded-lg border px-3 py-2.5">
            <div className="flex items-center gap-1.5 text-xs text-muted-foreground">
              <span className={cn("size-2 rounded-[2px]", BEHAVIORS[kind].dot)} />
              {BEHAVIORS[kind].title}
            </div>
            <div className="mt-0.5 text-xl font-semibold">{count(kind)}</div>
            <div className="text-[11px] text-muted-foreground">{BEHAVIORS[kind].hint}</div>
          </div>
        ))}
      </div>

      <div className="mb-2.5 flex flex-wrap items-center gap-2">
        <SearchField
          aria-label="Filter APIs or files"
          placeholder="Filter by API, framework or file"
          value={query}
          onChange={(event) => setQuery(event.target.value)}
          className="flex-[1_1_220px] text-xs"
        />
        <Segmented aria-label="Filter by behavior" value={behavior} onValueChange={(value) => setBehavior(value as CompatBehavior | "all")}>
          <SegmentedItem value="all" className="h-6 rounded-[5px] px-[9px]">
            All {apis.length}
          </SegmentedItem>
          {KINDS.map((kind) => (
            <SegmentedItem key={kind} value={kind} className="h-6 rounded-[5px] px-[9px]">
              {BEHAVIORS[kind].label} {count(kind)}
            </SegmentedItem>
          ))}
        </Segmented>
      </div>

      <div role="table" aria-label="Unsupported APIs" className="overflow-hidden rounded-lg border">
        <div role="row" className={cn(COLUMNS, "h-[34px] bg-muted text-[11.5px] font-medium text-muted-foreground")}>
          <span role="columnheader" />
          <span role="columnheader">API</span>
          <span role="columnheader">Framework</span>
          <span role="columnheader">Runs locally as</span>
          <span role="columnheader">Called from</span>
        </div>
        {shown.map(({ api, framework, behavior: kind, note, sites }, index) => {
          const expanded = open.has(api);
          const [first, ...more] = sites;
          return (
            <div key={api} role="rowgroup" className={cn("border-t", expanded && "bg-muted/60")}>
              <div
                role="row"
                className={cn(COLUMNS, "min-h-10 cursor-pointer")}
                onClick={(event) => {
                  // The chevron and the file links handle their own clicks.
                  if (!(event.target as Element).closest("a, button")) toggle(api);
                }}
              >
                <span role="cell">
                  <button
                    type="button"
                    aria-label={api}
                    aria-expanded={expanded}
                    aria-controls={`${id}-${index}`}
                    className="flex size-5 cursor-pointer items-center rounded-sm text-[10px] text-muted-foreground hover:text-foreground"
                    onClick={() => toggle(api)}
                  >
                    {expanded ? "▾" : "▸"}
                  </button>
                </span>
                <span role="cell" title={api} className="truncate font-mono text-xs">
                  {api}
                </span>
                <span role="cell">
                  <Tag className="px-[7px]">{framework}</Tag>
                </span>
                <span role="cell">
                  <span className={cn("inline-flex h-5 items-center gap-[5px] rounded-sm px-[7px] text-[11px] font-medium", BEHAVIORS[kind].badge)}>
                    <span className="size-1.5 rounded-[2px] bg-current" />
                    {BEHAVIORS[kind].label}
                  </span>
                </span>
                <span role="cell" className="flex min-w-0 items-center gap-1.5 font-mono text-xs">
                  <Button variant="link" className={cn(fileLink, "text-xs")}>
                    <span className="truncate">{first?.file}</span>
                  </Button>
                  {more.length > 0 && <span className="whitespace-nowrap text-muted-foreground">+{more.length}</span>}
                </span>
              </div>
              {expanded && (
                <div role="row">
                  <div role="cell" id={`${id}-${index}`} className="pr-3 pb-3 pl-[42px]">
                    <p className="mb-2 text-xs text-muted-foreground">{note}</p>
                    <div className="overflow-hidden rounded-md border bg-background font-mono text-[11.5px] leading-5">
                      {sites.map(({ file, code }) => (
                        <div key={file} className="grid grid-cols-[170px_minmax(0,1fr)] gap-3 border-b px-2.5 py-1">
                          <Button variant="link" className={cn(fileLink, "text-[11.5px]")}>
                            {file}
                          </Button>
                          <span className="truncate whitespace-pre text-muted-foreground">{code}</span>
                        </div>
                      ))}
                    </div>
                    <div className="mt-2.5 flex flex-wrap gap-2">
                      <Button size="sm" className="text-xs">
                        <Cloud className="size-3.5" />
                        Run on cloud simulator
                      </Button>
                      <Button variant="outline" size="sm" className="text-xs">
                        {kind === "pause" ? "Stub it and keep going locally" : "Pause here instead"}
                      </Button>
                      <Button variant="ghost" size="sm" className="text-xs text-muted-foreground">
                        Open in editor
                      </Button>
                    </div>
                  </div>
                </div>
              )}
            </div>
          );
        })}
        {shown.length === 0 && (
          <div role="row" className="border-t px-3 py-6 text-center text-muted-foreground">
            <span role="cell">No APIs match these filters.</span>
          </div>
        )}
      </div>

      <div className="mt-3 flex flex-wrap gap-4 text-xs text-muted-foreground">
        <span>
          Scanned {files} Swift files · {scanned}
        </span>
        <Link to="." search hash="request" className="no-underline">
          Request support for an API
        </Link>
        <Link to="." search hash="docs" className="no-underline">
          What runs locally
        </Link>
      </div>
    </div>
  );
}
