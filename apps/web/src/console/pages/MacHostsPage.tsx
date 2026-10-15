import { Link } from "@tanstack/react-router";
import { Ellipsis, Plus, Server } from "lucide-react";
import { useState } from "react";
import { Badge, type BadgeTone } from "../../components/ui/badge";
import { Button } from "../../components/ui/button";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "../../components/ui/dropdown-menu";
import { EmptyState } from "../../components/ui/empty-state";
import { SearchField } from "../../components/ui/search-field";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "../../components/ui/table";
import { useMock } from "../../lib/mock";
import { cn } from "../../lib/utils";
import { type HostStatus, type MacHost, macHosts } from "../../mocks/console/hosts";
import { FacetFilter } from "../FacetFilter";

const STATUS: Record<HostStatus, { label: string; tone: BadgeTone }> = {
  online: { label: "Online", tone: "success" },
  offline: { label: "Offline", tone: "muted" },
  provisioning: { label: "Provisioning", tone: "info" },
};

const FACETS = [
  { label: "Region", of: (host: MacHost) => host.region },
  { label: "Status", of: (host: MacHost) => STATUS[host.status].label },
  { label: "Chip", of: (host: MacHost) => host.chip },
];

const sum = (hosts: MacHost[], of: (host: MacHost) => number) => hosts.reduce((total, host) => total + of(host), 0);

export function MacHostsPage() {
  const hosts = useMock() === "empty" ? [] : macHosts;
  const [query, setQuery] = useState("");
  const [filters, setFilters] = useState<Record<string, string[]>>({});

  const q = query.trim().toLowerCase();
  const rows = hosts.filter(
    (host) =>
      FACETS.every(({ label, of }) => {
        const picked = filters[label] ?? [];
        return picked.length === 0 || picked.includes(of(host));
      }) && [host.name, host.source, host.region, host.regionCode].some((text) => text.toLowerCase().includes(q)),
  );
  const stats = [
    { label: "Hosts online", value: hosts.filter((host) => host.status === "online").length, of: `of ${hosts.length}` },
    {
      label: "Simulators running",
      value: sum(hosts, (host) => host.simulatorsRunning),
      of: `of ${sum(hosts, (host) => host.simulatorSlots)} slots`,
    },
    { label: "Regions", value: new Set(hosts.map((host) => host.region)).size },
  ];

  return (
    <div className="flex w-full max-w-[1200px] flex-col gap-[18px] p-7">
      <div className="flex flex-wrap items-end gap-3">
        <div className="flex-[1_1_320px]">
          <h1 className="text-[22px] font-semibold tracking-[-0.02em]">Mac hosts</h1>
          <p className="mt-1 text-muted-foreground">Macs that run cloud iOS simulators for Acme Mobile.</p>
        </div>
        <Button asChild size="lg">
          <Link to="/console/hosts/new">
            <Plus className="size-[15px]" strokeWidth={2.2} />
            Add host
          </Link>
        </Button>
      </div>

      {hosts.length === 0 ? (
        <EmptyState
          className="h-[280px] rounded-[10px] border border-dashed border-input"
          icon={<Server />}
          title="No Mac hosts yet"
          description="Add one to open iOS cloud simulators. Android cloud devices work without a host."
          actions={
            <>
              <Button asChild size="sm">
                <Link to="/console/hosts/new">Connect AWS</Link>
              </Button>
              <Button asChild size="sm" variant="outline">
                <Link to="/console/hosts/new" search={{ mock: "any-mac" }}>
                  Use any Mac
                </Link>
              </Button>
            </>
          }
        />
      ) : (
        <>
          <div className="grid grid-cols-[repeat(auto-fit,minmax(200px,1fr))] gap-3">
            {stats.map(({ label, value, of }) => (
              <div key={label} className="rounded-[10px] border px-3.5 py-3">
                <div className="text-xs text-muted-foreground">{label}</div>
                <div className="text-xl font-semibold">
                  {value} {of && <span className="text-[13px] font-normal text-muted-foreground">{of}</span>}
                </div>
              </div>
            ))}
          </div>

          <div className="flex flex-wrap gap-2">
            <SearchField
              aria-label="Search hosts"
              placeholder="Search hosts"
              className="box-content flex-[0_1_280px]"
              value={query}
              onChange={(event) => setQuery(event.target.value)}
            />
            {FACETS.map(({ label, of }) => (
              <FacetFilter
                key={label}
                label={label}
                options={[...new Set(hosts.map(of))]}
                value={filters[label] ?? []}
                onChange={(picked) => setFilters({ ...filters, [label]: picked })}
              />
            ))}
          </div>

          <div className="overflow-hidden rounded-[10px] border">
            <Table aria-label="Mac hosts" className="min-w-[860px] table-fixed">
              <TableHeader>
                <TableRow className="h-[38px] [&>th]:text-xs">
                  {/* The design's 1.5fr 1fr 96px 120px 120px 1fr 36px: the percentages overshoot and the
                      fixed layout scales them down to the space the px columns leave. */}
                  <TableHead className="w-[30%]">Host</TableHead>
                  <TableHead className="w-[20%]">Region</TableHead>
                  <TableHead className="w-[108px]">Chip</TableHead>
                  <TableHead className="w-[132px]">Status</TableHead>
                  <TableHead className="w-[132px]">Simulators</TableHead>
                  <TableHead className="w-[20%]">macOS · Xcode</TableHead>
                  <TableHead className="w-[56px]">
                    <span className="sr-only">Actions</span>
                  </TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {rows.map((host) => (
                  <TableRow key={host.name} className="h-[69px]">
                    <TableCell>
                      <span className="block font-mono font-medium">{host.name}</span>
                      <span className="block text-xs text-muted-foreground">{host.source}</span>
                    </TableCell>
                    <TableCell>
                      <span className="block">{host.region}</span>
                      <span className="block font-mono text-[11.5px] text-muted-foreground">{host.regionCode}</span>
                    </TableCell>
                    <TableCell>{host.chip}</TableCell>
                    <TableCell>
                      <Badge tone={STATUS[host.status].tone} dot>
                        {STATUS[host.status].label}
                      </Badge>
                    </TableCell>
                    <TableCell>
                      <span className="flex items-center gap-2">
                        <span aria-hidden="true" className="inline-flex gap-[3px]">
                          {Array.from({ length: host.simulatorSlots }, (_, slot) => (
                            <span
                              key={slot}
                              className={cn(
                                "h-3.5 w-2 rounded-[2px]",
                                slot < host.simulatorsRunning
                                  ? "bg-primary"
                                  : "bg-muted shadow-[inset_0_0_0_1px_var(--border)]",
                              )}
                            />
                          ))}
                        </span>
                        <span className="font-mono text-xs text-muted-foreground">
                          {host.simulatorsRunning} / {host.simulatorSlots}
                        </span>
                      </span>
                    </TableCell>
                    <TableCell className="text-[12.5px] text-muted-foreground">{host.software}</TableCell>
                    <TableCell>
                      <HostMenu host={host} />
                    </TableCell>
                  </TableRow>
                ))}
                {rows.length === 0 && (
                  <TableRow>
                    <TableCell colSpan={7} className="h-24 text-center text-muted-foreground">
                      No hosts match these filters.{" "}
                      <Button
                        variant="link"
                        className="h-auto px-0"
                        onClick={() => {
                          setQuery("");
                          setFilters({});
                        }}
                      >
                        Clear filters
                      </Button>
                    </TableCell>
                  </TableRow>
                )}
              </TableBody>
            </Table>
          </div>
        </>
      )}
    </div>
  );
}

function HostMenu({ host }: { host: MacHost }) {
  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <Button variant="ghost" size="icon-xs" aria-label="Host actions">
          <Ellipsis className="size-[15px]" />
        </Button>
      </DropdownMenuTrigger>
      {/* Named for the host, as in the design, instead of after the trigger. */}
      <DropdownMenuContent
        align="end"
        aria-label={`Actions for ${host.name}`}
        aria-labelledby={undefined}
        className="w-[248px]"
      >
        <DropdownMenuItem disabled={host.status !== "online"}>Open a session on this host</DropdownMenuItem>
        <DropdownMenuItem>Drain — stop new sessions</DropdownMenuItem>
        <DropdownMenuItem>Restart agent</DropdownMenuItem>
        <DropdownMenuSeparator />
        <DropdownMenuItem variant="destructive" className="flex-col items-start gap-0">
          Release host…
          {host.billedUntil && (
            <span className="text-[11.5px] text-muted-foreground">
              Billed until 24 h after allocation ({host.billedUntil})
            </span>
          )}
        </DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenu>
  );
}
