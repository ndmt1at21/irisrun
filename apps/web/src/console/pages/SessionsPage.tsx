import { Link } from "@tanstack/react-router";
import { useState } from "react";
import { LatencyChip } from "../../components/LatencyChip";
import { Button } from "../../components/ui/button";
import { Card } from "../../components/ui/card";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "../../components/ui/select";
import { Skeleton } from "../../components/ui/skeleton";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "../../components/ui/table";
import { useMock } from "../../lib/mock";
import { members } from "../../mocks/console/members";
import { projects } from "../../mocks/console/projects";
import { type EndReason, endedSessions, endedTotal, type LiveSession, liveSessions } from "../../mocks/console/sessions";

const ENDINGS: Record<EndReason, { label: string; color: string }> = {
  user: { label: "Ended by user", color: "text-muted-foreground" },
  "time-limit": { label: "Time limit reached", color: "text-warning" },
  "connection-lost": { label: "Connection lost · didn’t reconnect", color: "text-destructive" },
};

const PERIODS = ["Last 24 hours", "Last 7 days", "Last 30 days", "Last 90 days"];

// Bar widths of the loading rows, as in ConsoleStates.
const SKELETON_ROWS = [
  [120, 80],
  [90, 110],
  [140, 70],
  [100, 96],
  [76, 120],
  [130, 88],
];

export function SessionsPage() {
  const loading = useMock() === "loading";
  const [project, setProject] = useState("all");
  const [person, setPerson] = useState("anyone");
  const filtered = project !== "all" || person !== "anyone";
  const matches = (s: { project: string; user: string }) =>
    (project === "all" || s.project === project) && (person === "anyone" || s.user === person);
  const live = liveSessions.filter(matches);
  const ended = endedSessions.filter(matches);

  return (
    <div className="flex w-full max-w-[1200px] flex-col gap-4 p-7">
      <div className="flex flex-wrap items-end gap-3">
        <div className="flex-[1_1_300px]">
          <h1 className="text-[22px] font-semibold tracking-[-0.02em]">Sessions</h1>
          <p className="mt-1 text-muted-foreground">Cloud and real-device sessions. Recordings are kept for 30 days.</p>
        </div>
        <Select value={project} onValueChange={setProject}>
          <SelectTrigger aria-label="Project">
            <SelectValue />
          </SelectTrigger>
          <SelectContent align="end">
            <SelectItem value="all">All projects</SelectItem>
            {projects.map(({ name }) => (
              <SelectItem key={name} value={name}>
                {name}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
        <Select value={person} onValueChange={setPerson}>
          <SelectTrigger aria-label="Started by">
            <SelectValue />
          </SelectTrigger>
          <SelectContent align="end">
            <SelectItem value="anyone">Anyone</SelectItem>
            {members.map(({ name }) => (
              <SelectItem key={name} value={name}>
                {name}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
        {/* The mock rows only carry display dates, so the period is left to the API. */}
        <Select defaultValue="Last 30 days">
          <SelectTrigger aria-label="Period">
            <SelectValue />
          </SelectTrigger>
          <SelectContent align="end">
            {PERIODS.map((period) => (
              <SelectItem key={period} value={period}>
                {period}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
      </div>

      {loading ? (
        <div aria-busy="true" className="overflow-hidden rounded-[10px] border">
          <span className="sr-only">Loading sessions</span>
          <div className="h-9 bg-muted" />
          {SKELETON_ROWS.map(([first, second], i) => (
            <div key={i} className="flex h-10 items-center gap-3.5 border-t px-3.5">
              <Skeleton className="h-[9px] w-16" />
              <Skeleton className="h-[9px]" style={{ width: first }} />
              <Skeleton className="h-[9px]" style={{ width: second }} />
              <Skeleton className="ml-auto h-[22px] w-14 rounded-md" />
            </div>
          ))}
        </div>
      ) : (
        <>
          <section aria-labelledby="s-live">
            <h2 id="s-live" className="mb-2.5 flex items-center gap-2 text-sm font-semibold">
              <span aria-hidden="true" className="size-2 rounded-full bg-success" />
              Running now
              <span className="font-normal text-muted-foreground">{live.length}</span>
            </h2>
            {live.length > 0 ? (
              <div className="grid grid-cols-[repeat(auto-fill,minmax(min(300px,100%),1fr))] gap-3">
                {live.map((session) => (
                  <LiveCard key={session.id} session={session} />
                ))}
              </div>
            ) : (
              <p className="text-[12.5px] text-muted-foreground">Nothing running for these filters.</p>
            )}
          </section>

          <section aria-labelledby="s-ended">
            <h2 id="s-ended" className="mt-2 mb-2.5 flex items-center gap-2 text-sm font-semibold">
              Ended
              {/* ponytail: the mock counts the loaded rows once filtered; the API will return the total. */}
              <span className="font-normal text-muted-foreground">{filtered ? ended.length : endedTotal}</span>
            </h2>
            <div className="overflow-hidden rounded-[10px] border">
              {/* The design's 112px 1fr 1.3fr 1fr 72px 1.2fr 104px, each cell plus its padding: the percentages
                  overshoot and the fixed layout scales them down to the space the px columns leave. */}
              <Table aria-label="Ended sessions" className="min-w-[860px] table-fixed">
                <TableHeader>
                  <TableRow className="[&>th]:text-xs">
                    <TableHead className="w-[132px]">Started</TableHead>
                    <TableHead className="w-[20%]">Project</TableHead>
                    <TableHead className="w-[25.6%]">Device</TableHead>
                    <TableHead className="w-[20%]">By</TableHead>
                    <TableHead className="w-[84px]">Length</TableHead>
                    <TableHead className="w-[23.7%]">How it ended</TableHead>
                    <TableHead className="w-[124px]">
                      <span className="sr-only">Replay</span>
                    </TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody className="text-[12.5px] [&_td]:py-1">
                  {ended.map((s) => (
                    <TableRow key={s.id} className="h-[47px]">
                      <TableCell className="text-muted-foreground">{s.started}</TableCell>
                      <TableCell className="font-mono text-xs">{s.project}</TableCell>
                      <TableCell>
                        <span className="block">{s.device}</span>
                        <span className="block text-[11.5px] text-muted-foreground">{s.where}</span>
                      </TableCell>
                      <TableCell>{s.user}</TableCell>
                      <TableCell className="font-mono text-xs">{s.length}</TableCell>
                      <TableCell className={ENDINGS[s.endReason].color}>{ENDINGS[s.endReason].label}</TableCell>
                      <TableCell className="text-right">
                        {s.hasRecording ? (
                          <Button asChild variant="outline" size="xs">
                            {/* Every id opens the same replay mock (UI-07) until recordings are real. */}
                            <Link to="/console/sessions/$sessionId" params={{ sessionId: s.id }}>
                              ▶ Replay
                            </Link>
                          </Button>
                        ) : (
                          <Button variant="outline" size="xs" disabled>
                            Expired
                          </Button>
                        )}
                      </TableCell>
                    </TableRow>
                  ))}
                  {ended.length === 0 && (
                    <TableRow>
                      <TableCell colSpan={7} className="h-24 text-center text-muted-foreground">
                        No sessions match these filters.{" "}
                        <Button
                          variant="link"
                          className="h-auto px-0"
                          onClick={() => {
                            setProject("all");
                            setPerson("anyone");
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
          </section>
        </>
      )}
    </div>
  );
}

function LiveCard({ session: s }: { session: LiveSession }) {
  return (
    <Card role="article" className="flex gap-3 p-3.5">
      <div aria-hidden="true" className="h-[108px] w-[54px] shrink-0 rounded-[10px] bg-[#2b2a2e] p-[3px]">
        <div className="size-full rounded-[7px]" style={{ background: s.screen }} />
      </div>
      <div className="flex min-w-0 flex-1 flex-col gap-0.5">
        <span className="font-semibold">{s.device}</span>
        <span className="text-xs text-muted-foreground">{s.where}</span>
        <span className="text-xs text-muted-foreground">
          {s.project} · {s.user}
        </span>
        <span className="mt-1 flex flex-wrap items-center gap-2.5 font-mono text-[11.5px]">
          <span>{s.elapsed}</span>
          <span className="text-muted-foreground">ends in {s.endsIn}</span>
          <LatencyChip ms={s.latencyMs} className="h-auto border-0 px-0 text-[11.5px]" />
        </span>
        <span className="mt-auto flex gap-1.5 pt-2">
          <Button size="xs">Open</Button>
          <Button size="xs" variant="destructive">
            End
          </Button>
        </span>
      </div>
    </Card>
  );
}
