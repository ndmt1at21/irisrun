import { Download } from "lucide-react";
import { Fragment, useState } from "react";
import { Avatar } from "../../components/ui/avatar";
import { Button } from "../../components/ui/button";
import { EmptyState } from "../../components/ui/empty-state";
import { SearchField } from "../../components/ui/search-field";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "../../components/ui/select";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "../../components/ui/table";
import { useMock } from "../../lib/mock";
import { cn } from "../../lib/utils";
import {
  type AuditChange,
  type AuditEvent,
  auditActors,
  auditCategories,
  auditEvents,
  auditTotal,
} from "../../mocks/console/audit";
import { FacetFilter } from "../FacetFilter";

const DOT: Record<AuditEvent["kind"], string> = {
  create: "bg-success",
  change: "bg-info",
  remove: "bg-destructive",
  warn: "bg-warning",
};

// The mock page only holds the last 7 days, so the longer ranges show the same events.
const RANGES: Record<string, string> = { "7": "Last 7 days", "30": "Last 30 days", "90": "Last 90 days" };

// Action and Target get 24% and 26% so the middle columns split about 1.1 : 1.2 : 1.3 at full width, as in the design.
const COLUMNS = [
  ["Time (GMT+7)", "w-[130px]"],
  ["Actor", ""],
  ["Action", "w-[24%]"],
  ["Target", "w-[26%]"],
  ["From", "w-[190px]"],
];

export function AuditLogPage() {
  const noMatches = useMock() === "no-matches";
  const [query, setQuery] = useState("");
  const [actors, setActors] = useState(noMatches ? ["Hana Kim"] : []);
  const [categories, setCategories] = useState<string[]>(noMatches ? ["Keys"] : ["Hosts", "Keys", "Members"]);
  const [range, setRange] = useState("7");
  // The artboard opens the role change.
  const [open, setOpen] = useState<string | null>("evt_01JA8Q2M7K");
  const q = query.trim().toLowerCase();
  const rows = auditEvents.filter(
    (e) =>
      (actors.length === 0 || actors.includes(e.actor.name)) &&
      (categories.length === 0 || categories.includes(e.category)) &&
      `${e.target} ${e.from} ${e.id}`.toLowerCase().includes(q),
  );
  const summary = [
    q && `“${query.trim()}”`,
    actors.length > 0 && `Actor: ${actors.join(", ")}`,
    categories.length > 0 && `Category: ${categories.join(", ")}`,
    RANGES[range],
  ]
    .filter(Boolean)
    .join(" · ");

  return (
    <div className="flex w-full max-w-[1200px] flex-col gap-4 p-7">
      <div className="flex flex-wrap items-end gap-3">
        <div className="flex-[1_1_300px]">
          <h1 className="text-[22px] font-semibold tracking-[-0.02em]">Audit log</h1>
          <p className="mt-1 text-muted-foreground">
            Every change to sessions, hosts, keys, members and settings. Kept for 1 year.
          </p>
        </div>
        <Button variant="outline" className="text-[12.5px]">
          <Download className="size-3.5" />
          Export CSV
        </Button>
      </div>

      <div className="flex flex-wrap gap-2">
        <SearchField
          aria-label="Search audit log"
          placeholder="Search target, IP or ID"
          className="box-content flex-[0_1_280px]"
          value={query}
          onChange={(event) => setQuery(event.target.value)}
        />
        <FacetFilter label="Actor" options={auditActors.map((a) => a.name)} value={actors} onChange={setActors} />
        <FacetFilter label="Category" options={auditCategories} value={categories} onChange={setCategories} />
        <Select value={range} onValueChange={setRange}>
          <SelectTrigger aria-label="Time range">
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            {Object.entries(RANGES).map(([value, label]) => (
              <SelectItem key={value} value={value}>
                {label}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
      </div>

      {rows.length === 0 ? (
        <EmptyState
          className="h-[280px] gap-1.5 rounded-[10px] border"
          title="No events match these filters"
          description={summary}
          actions={
            <Button
              variant="outline"
              size="xs"
              className="font-normal"
              onClick={() => {
                setQuery("");
                setActors([]);
                setCategories([]);
              }}
            >
              Clear filters
            </Button>
          }
        />
      ) : (
        <>
          <div className="overflow-hidden rounded-[10px] border">
            <Table aria-label="Audit events" className="min-w-[880px] table-fixed text-[12.5px]">
              <TableHeader>
                <TableRow>
                  {COLUMNS.map(([label, width]) => (
                    <TableHead key={label} className={cn("text-xs", width)}>
                      {label}
                    </TableHead>
                  ))}
                </TableRow>
              </TableHeader>
              {rows.map((e) => {
                const expanded = open === e.id;
                return (
                  // One row group per event, so its details sit under it with no rule between.
                  <TableBody key={e.id} className={cn("border-t [&>tr]:border-t-0", expanded && "bg-muted/55")}>
                    <TableRow className="h-[45px] cursor-pointer" onClick={() => setOpen(expanded ? null : e.id)}>
                      <TableCell className="font-mono text-xs text-muted-foreground">{e.time}</TableCell>
                      <TableCell>
                        <span className="flex min-w-0 items-center gap-2">
                          <Avatar
                            color={e.actor.color}
                            className={cn("size-[22px] text-[9.5px]", !e.actor.person && "rounded-md")}
                          >
                            {e.actor.initials}
                          </Avatar>
                          <span className="truncate">{e.actor.name}</span>
                        </span>
                      </TableCell>
                      <TableCell>
                        {/* The row toggles on click; this button gives keyboards and screen readers the same. */}
                        <button type="button" aria-expanded={expanded} className="flex cursor-pointer items-center gap-2 text-left">
                          <span className={cn("size-1.5 shrink-0 rounded-full", DOT[e.kind])} />
                          {e.action}
                        </button>
                      </TableCell>
                      <TableCell className="truncate font-mono text-xs">{e.target}</TableCell>
                      <TableCell className="text-xs text-muted-foreground">{e.from}</TableCell>
                    </TableRow>
                    {expanded && (
                      <TableRow>
                        <TableCell />
                        <TableCell colSpan={4} className="pt-0 pb-3.5">
                          <EventJson event={e} />
                        </TableCell>
                      </TableRow>
                    )}
                  </TableBody>
                );
              })}
            </Table>
          </div>
          <div className="flex items-center gap-3 text-xs text-muted-foreground">
            <span>
              Showing {rows.length} of {auditTotal} events
            </span>
            <span className="flex-1" />
            <Button variant="outline" size="sm" className="text-xs font-normal">
              Load more
            </Button>
          </div>
        </>
      )}
    </div>
  );
}

/** The event as JSON, one key per line; a { from, to } value is a change, shown red to green. */
function EventJson({ event }: { event: AuditEvent }) {
  const entries = Object.entries<string | AuditChange>({ event: event.event, id: event.id, ...event.details });
  return (
    <pre className="overflow-x-auto rounded-md border bg-code px-3 py-2.5 font-mono text-xs leading-[1.65]">
      {"{\n"}
      {entries.map(([key, value], i) => (
        <Fragment key={key}>
          {`  "${key}": `}
          {typeof value === "string" ? (
            JSON.stringify(value)
          ) : (
            <>
              {"{ "}
              <span className="text-destructive">{`"from": ${JSON.stringify(value.from)}`}</span>
              {", "}
              <span className="text-success">{`"to": ${JSON.stringify(value.to)}`}</span>
              {" }"}
            </>
          )}
          {i < entries.length - 1 ? ",\n" : "\n"}
        </Fragment>
      ))}
      {"}"}
    </pre>
  );
}
