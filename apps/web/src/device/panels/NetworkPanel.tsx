import { Ban, Globe, X } from "lucide-react";
import { type ReactNode, useState } from "react";
import { Button } from "../../components/ui/button";
import { EmptyState } from "../../components/ui/empty-state";
import { SearchField } from "../../components/ui/search-field";
import { Segmented } from "../../components/ui/segmented";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "../../components/ui/select";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "../../components/ui/tabs";
import { ToggleGroupItem } from "../../components/ui/toggle-group";
import { cn } from "../../lib/utils";
import { kedaiNetwork, type NetworkRequest } from "../../mocks/device/network";

const TYPES = [
  ["all", "All"],
  ["api", "API"],
  ["image", "Images"],
  ["ws", "WS"],
] as const;
const THROTTLING = ["No throttling", "Fast 4G", "Slow 4G", "3G", "Offline"];
const COLUMNS = ["Method", "URL", "Status", "Size", "Time", "Waterfall"];
const REASONS: Record<number, string> = { 101: "Switching Protocols", 200: "OK", 201: "Created", 204: "No Content", 304: "Not Modified" };
const METHODS: Record<string, string> = { GET: "text-success", POST: "text-info" };
const ROW = "box-content grid h-7 grid-cols-[52px_minmax(0,1fr)_56px_56px_64px_104px] items-center gap-2.5 border-b px-3";
const CODE = "min-h-0 flex-1 overflow-auto bg-code px-3.5 py-3 font-mono text-xs leading-[1.65]";
// A string (and the colon when it's a key), a number, or a literal.
const JSON_TOKEN = /("(?:[^"\\]|\\.)*")(\s*:)?|-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?|\b(?:true|false|null)\b/g;

const url = ({ host, path }: NetworkRequest) => (host ? `https://${host}${path}` : path);
const methodColor = ({ method }: NetworkRequest) => METHODS[method] ?? "text-muted-foreground";
const statusColor = ({ status }: NetworkRequest) =>
  !status || status >= 400 ? "text-destructive" : status >= 300 ? "text-muted-foreground" : undefined;
const statusText = ({ status }: NetworkRequest) => (status ? `${status} ${REASONS[status] ?? ""}`.trim() : "Failed");
const duration = (ms: number) => (ms >= 1000 ? `${(ms / 1000).toFixed(1)} s` : `${ms} ms`);
const quote = (text: string) => `'${text.replaceAll("'", `'\\''`)}'`;

/** The request as a curl command, to replay it from a terminal. */
function curl(request: NetworkRequest) {
  return [
    `curl ${quote(url(request))}`,
    ...(request.method === "GET" || request.type === "ws" ? [] : [`-X ${request.method}`]),
    ...request.requestHeaders.map(([name, value]) => `-H ${quote(`${name}: ${value}`)}`),
    // JSON strings can't hold a raw newline, so this only drops the indentation.
    ...(request.payload ? [`--data-raw ${quote(request.payload.replace(/\n\s*/g, ""))}`] : []),
  ].join(" \\\n  ");
}

/** Pretty-printed JSON with keys, strings, numbers and literals colored. */
function Json({ text }: { text: string }) {
  const parts: ReactNode[] = [];
  let end = 0;
  for (const match of text.matchAll(JSON_TOKEN)) {
    const [token, quoted, colon] = match;
    const color = colon ? "text-link" : quoted ? "text-success" : /\d/.test(token) ? "text-warning" : "text-muted-foreground";
    parts.push(
      text.slice(end, match.index),
      <span key={match.index} className={color}>
        {quoted ?? token}
      </span>,
      colon,
    );
    end = match.index + token.length;
  }
  parts.push(text.slice(end));
  return <pre>{parts}</pre>;
}

function Fields({ title, rows }: { title: string; rows: [string, string][] }) {
  return (
    <div className="mb-3 last:mb-0">
      <div className="font-sans font-medium text-muted-foreground">{title}</div>
      {rows.map(([name, value]) => (
        <div key={name} className="break-all">
          <span className="text-link">{name}</span>: {value}
        </div>
      ))}
    </div>
  );
}

/** The selected request: summary, cURL, and its headers, payload, response and timing. */
function RequestDetails({ request, onClose }: { request: NetworkRequest; onClose: () => void }) {
  const [copied, setCopied] = useState(false);
  const query = [...new URLSearchParams(request.path.split("?")[1])];
  const total = request.timing.reduce((sum, [, ms]) => sum + ms, 0);
  const tone =
    !request.status || request.status >= 400
      ? "bg-destructive/14 text-destructive"
      : request.status >= 300
        ? "bg-muted text-muted-foreground"
        : "bg-success/14 text-success";
  const copy = () =>
    navigator.clipboard?.writeText(curl(request)).then(
      () => {
        setCopied(true);
        setTimeout(() => setCopied(false), 2000);
      },
      () => {},
    );

  return (
    // At least the summary, the tabs and a few lines, also when the panel is docked at the bottom.
    <div className="flex min-h-40 flex-auto flex-col overflow-hidden border-t">
      <div className="flex flex-wrap items-center gap-2.5 border-b px-3 py-2.5">
        <span className={cn("font-mono text-xs font-semibold", methodColor(request))}>{request.method}</span>
        <span className="min-w-0 flex-[1_1_200px] truncate font-mono text-xs">{url(request)}</span>
        <span className={cn("inline-flex h-5 items-center rounded-sm px-[7px] text-[11px] font-medium", tone)}>
          {statusText(request)}
        </span>
        <span className="text-xs text-muted-foreground">
          {request.time} · {request.size}
        </span>
        <Button variant="outline" className="h-[26px] px-2 text-xs font-normal" onClick={copy}>
          {copied ? "Copied" : "Copy as cURL"}
        </Button>
        <Button variant="ghost" size="icon" aria-label="Close details" className="size-[26px]" onClick={onClose}>
          <X className="size-3.5" />
        </Button>
      </div>
      <Tabs defaultValue="response" className="flex min-h-0 flex-1 flex-col">
        <TabsList variant="underline" aria-label="Request details" className="gap-4 px-3 text-xs">
          {["Headers", "Payload", "Response", "Timing"].map((name) => (
            <TabsTrigger key={name} value={name.toLowerCase()} className="h-8">
              {name}
            </TabsTrigger>
          ))}
        </TabsList>
        <TabsContent value="headers" className={CODE}>
          <Fields
            title="General"
            rows={[
              ["Request URL", url(request)],
              ["Request method", request.method],
              ["Status code", statusText(request)],
            ]}
          />
          {request.responseHeaders.length > 0 && <Fields title="Response headers" rows={request.responseHeaders} />}
          <Fields title="Request headers" rows={request.requestHeaders} />
        </TabsContent>
        <TabsContent value="payload" className={CODE}>
          {request.payload ? (
            <Json text={request.payload} />
          ) : query.length > 0 ? (
            <Fields title="Query string" rows={query} />
          ) : (
            <p className="text-muted-foreground">No payload</p>
          )}
        </TabsContent>
        <TabsContent value="response" className={CODE}>
          {request.error ? (
            <p className="text-destructive">{request.error}</p>
          ) : request.response ? (
            <Json text={request.response} />
          ) : (
            <p className="text-muted-foreground">{request.type === "image" ? `Image · ${request.size}` : "No response body"}</p>
          )}
        </TabsContent>
        <TabsContent value="timing" className={CODE}>
          {request.timing.map(([phase, ms], index) => {
            const start = request.timing.slice(0, index).reduce((sum, [, before]) => sum + before, 0);
            return (
              <div key={phase} className="grid grid-cols-[136px_minmax(0,1fr)_64px] items-center gap-3">
                <span className="text-muted-foreground">{phase}</span>
                <span className="relative h-2 rounded-xs bg-muted">
                  <span
                    className="absolute inset-y-0 rounded-xs bg-primary"
                    style={{ left: `${(start / total) * 100}%`, width: `max(2px, ${(ms / total) * 100}%)` }}
                  />
                </span>
                <span className="text-right">{duration(ms)}</span>
              </div>
            );
          })}
          <div className="mt-2 flex justify-between border-t pt-2 font-medium">
            <span>Total</span>
            {duration(total)}
          </div>
        </TabsContent>
      </Tabs>
    </div>
  );
}

/**
 * The Network panel: filter, type, throttling and the requests with a waterfall; a row opens its details.
 * `state` is a PanelStates state: `empty`, or `no-results` (a filter that hides every request); none means capturing.
 */
export function NetworkPanel({ state }: { state?: string }) {
  const [query, setQuery] = useState(state === "no-results" ? "/checkout" : "");
  const [type, setType] = useState("all");
  const [cleared, setCleared] = useState(state === "empty");
  const [selected, setSelected] = useState(state ? undefined : kedaiNetwork.selected);

  if (cleared || kedaiNetwork.requests.length === 0) {
    return (
      <EmptyState
        className="flex-1"
        icon={<Globe />}
        title="No requests yet"
        description={
          <span className="inline-block max-w-[300px]">
            Requests from OkHttp, URLSession and WebViews are captured automatically. Use the app to see them here.
          </span>
        }
      />
    );
  }

  const needle = query.trim().toLowerCase();
  const visible = kedaiNetwork.requests.filter(
    (request) =>
      (type === "all" || request.type === type) &&
      `${request.method} ${url(request)} ${request.status ?? "failed"}`.toLowerCase().includes(needle),
  );
  const open = visible.find(({ id }) => id === selected);

  return (
    <>
      <div className="flex flex-wrap items-center gap-2 border-b px-3 py-2">
        <SearchField
          aria-label="Filter requests"
          placeholder="Filter URL, method or status"
          value={query}
          onChange={(event) => setQuery(event.target.value)}
          autoFocus={state === "no-results"}
          className="flex-[1_1_200px] text-xs"
        />
        <Segmented
          aria-label="Request type"
          value={type}
          onValueChange={setType}
          className="gap-0 overflow-hidden rounded-md border border-input bg-transparent p-0"
        >
          {TYPES.map(([value, label]) => (
            <ToggleGroupItem key={value} value={value} className="h-7">
              {label}
            </ToggleGroupItem>
          ))}
        </Segmented>
        <Select defaultValue="No throttling">
          <SelectTrigger aria-label="Throttling" className="h-[30px] text-xs">
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            {THROTTLING.map((option) => (
              <SelectItem key={option} value={option}>
                {option}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
        <Button variant="ghost" size="icon-sm" aria-label="Clear requests" title="Clear" onClick={() => setCleared(true)}>
          <Ban className="size-[15px]" />
        </Button>
      </div>
      {visible.length === 0 ? (
        <EmptyState
          className="flex-1 gap-1.5"
          title={needle ? `No requests match “${query.trim()}”` : "No requests of this type"}
          description={`${kedaiNetwork.total} requests are hidden by this filter.`}
          actions={
            <Button
              variant="outline"
              size="xs"
              className="font-normal"
              onClick={() => {
                setQuery("");
                setType("all");
              }}
            >
              Clear filter
            </Button>
          }
        />
      ) : (
        <div role="table" aria-label="Requests" className={cn("min-h-0 overflow-auto text-xs", !open && "flex-1")}>
          <div role="row" className={cn(ROW, "sticky top-0 z-10 bg-muted text-[11.5px] font-medium text-muted-foreground")}>
            {COLUMNS.map((name) => (
              <span key={name} role="columnheader">
                {name}
              </span>
            ))}
          </div>
          {visible.map((request) => {
            const isSelected = request.id === selected;
            const select = () => setSelected(request.id);
            return (
              <div
                key={request.id}
                role="row"
                aria-selected={isSelected}
                tabIndex={0}
                onClick={select}
                onKeyDown={(event) => {
                  if (event.key !== "Enter" && event.key !== " ") return;
                  event.preventDefault();
                  select();
                }}
                className={cn(
                  ROW,
                  "cursor-pointer font-mono",
                  isSelected ? "bg-selection" : request.status ? "hover:bg-accent" : "bg-destructive/7",
                )}
              >
                <span role="cell" className={cn("font-medium", methodColor(request))}>
                  {request.method}
                </span>
                <span role="cell" className={cn("truncate", !request.status && "text-destructive")}>
                  {request.path}
                  {request.host && <span className="text-muted-foreground"> {request.host}</span>}
                </span>
                <span role="cell" className={statusColor(request)}>
                  {request.status ?? "(failed)"}
                </span>
                <span role="cell" className="text-muted-foreground">
                  {request.size}
                </span>
                <span role="cell" className="text-muted-foreground">
                  {request.time}
                </span>
                <span role="cell" aria-hidden="true" className="relative h-2 rounded-xs bg-muted">
                  <span
                    className={cn(
                      "absolute inset-y-0 rounded-xs",
                      !request.status ? "bg-destructive" : request.type === "ws" ? "bg-muted-foreground" : "bg-primary",
                    )}
                    style={{ left: `${request.start}%`, width: `${request.width}%` }}
                  />
                </span>
              </div>
            );
          })}
        </div>
      )}
      {open && <RequestDetails request={open} onClose={() => setSelected(undefined)} />}
    </>
  );
}
