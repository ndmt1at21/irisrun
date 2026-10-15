import { useLayoutEffect, useRef, useState } from "react";
import { Button } from "../../components/ui/button";
import { Segmented, SegmentedItem } from "../../components/ui/segmented";
import { Skeleton } from "../../components/ui/skeleton";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "../../components/ui/table";
import { useMock } from "../../lib/mock";
import { cn } from "../../lib/utils";
import { cycle, projectUsage, type UsageDay, usageDays } from "../../mocks/console/usage";

const SERIES = [
  { key: "virtual", label: "Cloud virtual", tile: "Cloud virtual devices", color: "bg-series-1" },
  { key: "real", label: "Real devices", tile: "Real devices", color: "bg-series-2" },
] as const;

const RANGES = ["7", "30", "90"];
// The artboard shows this day's tooltip until a bar is hovered or focused.
const PINNED_DAY = "2026-10-13";
// The plot is 210 px tall and tops out at 15 h, so an hour is 14 px.
const PX_PER_HOUR = 210 / 15;
// ConsoleStates' skeleton bars, in percent of the chart height.
const LOADING_BARS = [40, 55, 48, 62, 20, 12, 66, 70, 58, 74, 52, 18, 10, 76, 82, 70, 86, 60, 22, 14];

const COLUMNS = [
  ["Project", ""],
  ["Cloud virtual", "w-[132px] text-right"],
  ["Real devices", "w-[132px] text-right"],
  ["Sessions", "w-[112px] text-right"],
];

export function UsagePage() {
  const loading = useMock() === "loading";
  const [range, setRange] = useState("30");

  return (
    <div className="flex w-full max-w-[1200px] flex-col gap-[18px] p-7">
      <div className="flex flex-wrap items-end gap-3">
        <div className="flex-[1_1_300px]">
          <h1 className="text-[22px] font-semibold tracking-[-0.02em]">Usage &amp; billing</h1>
          <p className="mt-1 text-muted-foreground">
            {cycle.plan} plan · cycle {cycle.period} · {cycle.daysLeft} days left
          </p>
        </div>
        <Button variant="outline" className="text-[12.5px]">
          Invoices
        </Button>
        <Button variant="outline" className="text-[12.5px]">
          Change plan
        </Button>
      </div>

      {loading ? (
        <div aria-busy="true" className="flex h-[280px] flex-col gap-3.5 rounded-[10px] border p-4">
          <div className="flex gap-2.5">
            {[0, 1, 2].map((i) => (
              <Skeleton key={i} className="h-[54px] flex-1 rounded-lg" />
            ))}
          </div>
          <div className="flex flex-1 items-end gap-1.5">
            {LOADING_BARS.map((height, i) => (
              <Skeleton key={i} className="flex-1 rounded-none rounded-t-[3px]" style={{ height: `${height}%` }} />
            ))}
          </div>
        </div>
      ) : (
        <>
          <div className="grid grid-cols-[repeat(auto-fit,minmax(220px,1fr))] gap-3">
            {SERIES.map((s) => {
              const { used, included } = cycle[s.key];
              return (
                <div key={s.key} className="rounded-[10px] border px-4 py-3.5">
                  <div className="flex items-center gap-1.5 text-xs text-muted-foreground">
                    <span className={cn("size-2 rounded-[2px]", s.color)} />
                    {s.tile}
                  </div>
                  <div className="mt-0.5 text-[22px] font-semibold">
                    {used} h <span className="text-[13px] font-normal text-muted-foreground">of {included} h</span>
                  </div>
                  <div className="mt-2 h-1.5 overflow-hidden rounded-[3px] bg-muted">
                    <div className={cn("h-full", s.color)} style={{ width: `${(used / included) * 100}%` }} />
                  </div>
                </div>
              );
            })}
            <div className="rounded-[10px] border px-4 py-3.5">
              <div className="text-xs text-muted-foreground">Estimated invoice</div>
              <div className="mt-0.5 text-[22px] font-semibold">{cycle.estimate}</div>
              <div className="mt-1.5 text-xs text-muted-foreground">No overage so far this cycle</div>
            </div>
          </div>

          <section aria-labelledby="chart-title" className="rounded-[10px] border px-[18px] py-4">
            <div className="mb-1.5 flex flex-wrap items-center gap-3">
              <h2 id="chart-title" className="text-sm font-semibold">
                Session hours per day
              </h2>
              <span className="inline-flex items-center gap-3.5 text-xs text-muted-foreground">
                {SERIES.map((s) => (
                  <span key={s.key} className="inline-flex items-center gap-1.5">
                    <span className={cn("size-2.5 rounded-[2px]", s.color)} />
                    {s.label}
                  </span>
                ))}
              </span>
              <span className="flex-1" />
              <Segmented aria-label="Range" value={range} onValueChange={setRange}>
                {RANGES.map((days) => (
                  <SegmentedItem
                    key={days}
                    value={days}
                    className="h-6 rounded-[5px] px-[9px] font-normal data-[state=on]:font-medium"
                  >
                    {days} days
                  </SegmentedItem>
                ))}
              </Segmented>
            </div>
            <UsageChart key={range} days={usageDays.slice(-Number(range))} />
          </section>

          <div className="flex flex-wrap items-start gap-4">
            <section aria-labelledby="by-project" className="min-w-0 flex-[999_1_482px] overflow-hidden rounded-[10px] border">
              <h2 id="by-project" className="border-b px-4 py-3 text-sm font-semibold">
                This cycle by project
              </h2>
              <Table aria-label="Usage by project" className="min-w-[560px] table-fixed text-[12.5px]">
                <TableHeader>
                  <TableRow>
                    {COLUMNS.map(([label, width]) => (
                      <TableHead key={label} className={cn("h-[34px] text-xs font-normal first:pl-4 last:pr-4", width)}>
                        {label}
                      </TableHead>
                    ))}
                  </TableRow>
                </TableHeader>
                <TableBody className="[&_td]:py-2.5 [&_td]:first:pl-4 [&_td]:last:pr-4">
                  {projectUsage.map((p) => (
                    <TableRow key={p.project}>
                      <TableCell className="truncate font-mono">{p.project}</TableCell>
                      <TableCell className="text-right font-mono">{p.virtualHours} h</TableCell>
                      <TableCell className="text-right font-mono">{p.realHours} h</TableCell>
                      <TableCell className="text-right">{p.sessions}</TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </section>
            <aside className="min-w-0 flex-[1_1_314px] rounded-[10px] border px-4 py-3.5 text-[12.5px] text-muted-foreground">
              <div className="mb-1 font-semibold text-foreground">Not included here</div>
              EC2 Mac hosts you connect through AWS are billed by AWS to your account. Local runs on your own computer are
              always free.
            </aside>
          </div>
        </>
      )}
    </div>
  );
}

const total = (day: UsageDay) => day.virtual + day.real;
const tenths = (hours: number) => Math.round(hours * 10) / 10;
const shortDate = (iso: string) => new Date(iso).toLocaleDateString("en-US", { timeZone: "UTC", month: "short", day: "numeric" });
const isWeekend = (iso: string) => new Date(iso).getUTCDay() % 6 === 0;

/** The chart's text for screen readers, e.g. "… Weekdays run 6 to 13.5 hours, weekends under 2. …" */
function describe(days: UsageDay[]) {
  const dates = days.map((d) => shortDate(d.date));
  const weekdays = days.filter((d) => !isWeekend(d.date)).map(total);
  const weekends = days.filter((d) => isWeekend(d.date)).map(total);
  const peak = days.reduce((a, b) => (total(b) > total(a) ? b : a));
  return (
    `Stacked bar chart of daily session hours from ${dates[0]} to ${dates.at(-1)}. ` +
    `Weekdays run ${Math.round(Math.min(...weekdays))} to ${tenths(Math.max(...weekdays))} hours, ` +
    `weekends under ${Math.ceil(Math.max(...weekends))}. Peak ${shortDate(peak.date)} at ${tenths(total(peak))} hours.`
  );
}

/** Stacked daily bars drawn with divs; hovering a bar, or arrowing through them, moves the tooltip. */
function UsageChart({ days }: { days: UsageDay[] }) {
  const [picked, setPicked] = useState<number | null>(null);
  const scroller = useRef<HTMLDivElement>(null);
  // On narrow screens the chart scrolls sideways; start at the newest days.
  useLayoutEffect(() => {
    if (scroller.current) scroller.current.scrollLeft = scroller.current.scrollWidth;
  }, []);
  const n = days.length;
  const active = picked ?? days.findIndex((d) => d.date === PINNED_DAY);
  const day = days[active];
  const start = days.findIndex((d) => d.date === cycle.start);
  const labelEvery = n > 30 ? 14 : n > 7 ? 7 : 1;
  const at = (i: number) => `${(i / n) * 100}%`;
  const hours = (h: number) => Math.round(h * PX_PER_HOUR);

  return (
    // The top padding keeps the "15 h" label and the tooltip clear of the scroll box's edge.
    <div ref={scroller} className="overflow-x-auto pt-2">
      <div
        role="img"
        aria-label={describe(days)}
        tabIndex={0}
        onKeyDown={(event) => {
          const step = event.key === "ArrowLeft" ? -1 : event.key === "ArrowRight" ? 1 : 0;
          if (!step) return;
          event.preventDefault();
          setPicked(Math.min(Math.max(active + step, 0), n - 1));
        }}
        onBlur={() => setPicked(null)}
        className="grid min-w-[520px] grid-cols-[36px_minmax(0,1fr)] gap-x-2"
      >
        <div aria-hidden="true" className="relative h-[210px] font-mono text-[10.5px] text-muted-foreground">
          <span className="absolute -top-[7px] right-0">15 h</span>
          <span className="absolute top-[63px] right-0">10 h</span>
          <span className="absolute top-[133px] right-0">5 h</span>
          <span className="absolute right-0 -bottom-[7px]">0</span>
        </div>
        <div className="relative h-[211px] border-b bg-[linear-gradient(var(--grid)_1px,transparent_1px)] bg-size-[100%_70px]">
          {start >= 0 && (
            <>
              <div
                aria-hidden="true"
                className="absolute inset-y-0 border-l border-dashed border-muted-foreground opacity-60"
                style={{ left: at(start) }}
              />
              <span
                aria-hidden="true"
                className="absolute top-0.5 text-[11px] whitespace-nowrap text-muted-foreground"
                style={{ left: `calc(${at(start)} + 6px)` }}
              >
                Cycle start
              </span>
            </>
          )}
          <div
            className={cn("absolute inset-0 flex items-end", n > 30 ? "gap-0.5" : "gap-1")}
            onMouseLeave={() => setPicked(null)}
          >
            {days.map((d, i) => (
              <div
                key={d.date}
                onMouseEnter={() => setPicked(i)}
                className={cn("flex h-full flex-[1_1_0] flex-col justify-end", i !== active && "opacity-78")}
              >
                <span className="block rounded-t-[3px] bg-series-2" style={{ height: hours(d.real) }} />
                <span className="mt-px block bg-series-1" style={{ height: hours(d.virtual) }} />
              </div>
            ))}
          </div>
          {day && (
            <div
              role="tooltip"
              className="pointer-events-none absolute -top-1.5 w-[216px] rounded-lg border bg-card px-3 py-2.5 text-xs shadow-[0_12px_28px_-12px_rgba(0,0,0,.5)]"
              style={{ left: `clamp(2%, ${at(active + 0.5)} - 108px, 98% - 216px)` }}
            >
              <div className="mb-1.5 font-semibold">
                {new Date(day.date).toLocaleDateString("en-US", {
                  timeZone: "UTC",
                  weekday: "short",
                  month: "short",
                  day: "numeric",
                })}
              </div>
              {SERIES.map((s) => (
                <div key={s.key} className="flex justify-between gap-2">
                  <span className="inline-flex items-center gap-1.5 text-muted-foreground">
                    <span className={cn("size-2 rounded-[2px]", s.color)} />
                    {s.label}
                  </span>
                  <span className="font-mono">{day[s.key].toFixed(1)} h</span>
                </div>
              ))}
              <div className="mt-1 flex justify-between gap-2 border-t pt-1 font-medium">
                <span>Total</span>
                <span className="font-mono">{total(day).toFixed(1)} h</span>
              </div>
            </div>
          )}
        </div>
        <span />
        <div aria-hidden="true" className="relative h-[22px] text-[11px] text-muted-foreground">
          {days.map((d, i) => {
            // Every week (day, fortnight), skipping one too close to the last day, which sits flush right.
            const last = i === n - 1;
            if (!last && (i % labelEvery !== 0 || i >= n - 1 - labelEvery / 2)) return null;
            return (
              <span
                key={d.date}
                className={cn("absolute top-1.5 whitespace-nowrap", last && "right-0")}
                style={last ? undefined : { left: at(i) }}
              >
                {shortDate(d.date)}
              </span>
            );
          })}
        </div>
      </div>
    </div>
  );
}
