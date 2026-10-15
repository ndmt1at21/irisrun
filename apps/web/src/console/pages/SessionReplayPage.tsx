import { Link, useParams } from "@tanstack/react-router";
import { Download, Pause, Play, RotateCcw, RotateCw } from "lucide-react";
import { Fragment, type PointerEvent, useEffect, useLayoutEffect, useRef, useState } from "react";
import { IrisLogo } from "../../components/IrisLogo";
import { LevelChip } from "../../components/LevelChip";
import { TopBar } from "../../components/TopBar";
import { Badge } from "../../components/ui/badge";
import { Button } from "../../components/ui/button";
import { Checkbox } from "../../components/ui/checkbox";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "../../components/ui/select";
import { Switch } from "../../components/ui/switch";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "../../components/ui/tabs";
import { IPhoneFrame } from "../../device/shell/frames";
import { cn } from "../../lib/utils";
import { type MarkTone, type ReplayMark, type ReplayRow, sessionReplay as replay } from "../../mocks/console/replay";
import { IosLookAround } from "../../mocks/screens/IosLookAround";

const TABS = [
  ["logs", "Logs"],
  ["network", "Network"],
  ["events", "Events"],
] as const;
const SPEEDS = ["0.5", "1", "2", "4"];
/** The playback timer's step, in seconds. */
const TICK = 0.1;
const SEEK_KEYS: Record<string, number> = { ArrowLeft: -5, ArrowDown: -5, ArrowRight: 5, ArrowUp: 5, Home: -Infinity, End: Infinity };
const TONES: Record<MarkTone, string> = {
  foreground: "bg-foreground",
  primary: "bg-primary",
  muted: "bg-muted-foreground/45",
  info: "bg-info",
  success: "bg-success",
  warning: "bg-warning",
  destructive: "bg-destructive",
};

/** 54.6 → "00:54.6"; without tenths, 1385 → "23:05". */
function clock(seconds: number, tenths = true) {
  const t = Math.round(seconds * 10);
  const mm = String(Math.floor(t / 600)).padStart(2, "0");
  const ss = String(Math.floor(t / 10) % 60).padStart(2, "0");
  return tenths ? `${mm}:${ss}.${t % 10}` : `${mm}:${ss}`;
}

/** Clamps to the recording and rounds to 1/100 s, so times compare exactly with the mock's. */
const snap = (seconds: number) => Math.round(Math.min(replay.duration, Math.max(0, seconds)) * 100) / 100;
const percent = (seconds: number) => `${(seconds / replay.duration) * 100}%`;
/** Rows and taps from the last second before the playhead are highlighted. */
const isNow = (at: number, time: number) => at <= time && at > time - 1;

/** A cloud session's recording: the video with taps, logs synced to it and a timeline to seek. */
export function SessionReplayPage() {
  const { sessionId } = useParams({ from: "/console/sessions/$sessionId" });
  const [time, setTime] = useState(replay.start);
  const [playing, setPlaying] = useState(false);
  const [speed, setSpeed] = useState("1");
  const [showTaps, setShowTaps] = useState(true);
  const [follow, setFollow] = useState(true);
  const running = playing && time < replay.duration;
  const seek = (to: number) => setTime(snap(to));
  const tap = showTaps && replay.taps.findLast(({ at }) => isNow(at, time));

  // ponytail: an interval steps the clock; the real <video> element drives it once recordings exist.
  useEffect(() => {
    if (!running) return;
    const timer = setInterval(() => setTime((t) => snap(t + TICK * Number(speed))), TICK * 1000);
    return () => clearInterval(timer);
  }, [running, speed]);

  return (
    <div className="flex min-h-dvh flex-col">
      <TopBar className="min-h-[73px] gap-3 px-4 py-2">
        <IrisLogo />
        <nav aria-label="Breadcrumb" className="flex items-center gap-2 text-muted-foreground">
          <Link to="/console/sessions" className="text-muted-foreground hover:text-foreground">
            Sessions
          </Link>
          <span aria-hidden="true">/</span>
          <span className="font-mono font-medium text-foreground">{sessionId}</span>
        </nav>
        <Badge className="font-normal">Ended · replay</Badge>
        <span className="text-xs text-muted-foreground">{replay.meta}</span>
        <span className="flex-1" />
        <Button variant="outline" className="text-[12.5px]">
          <Download className="size-3.5" />
          Download video
        </Button>
        <Button variant="outline" className="text-[12.5px]">
          Export logs
        </Button>
      </TopBar>
      <main className="flex min-h-0 flex-auto flex-wrap">
        <section aria-label="Video" className="flex min-w-0 flex-[999_1_520px] flex-col bg-stage">
          <div className="flex flex-auto items-center justify-center p-5">
            <div style={{ zoom: 600 / 720 }}>
              <IPhoneFrame>
                <IosLookAround />
                {tap && (
                  <span
                    aria-hidden="true"
                    style={{ left: tap.x, top: tap.y }}
                    className="absolute size-[41px] -translate-1/2 rounded-full bg-[rgba(91,91,214,.28)] shadow-[0_0_0_2.4px_#5b5bd6]"
                  />
                )}
              </IPhoneFrame>
            </div>
          </div>
          <div className="flex flex-wrap items-center gap-2 border-t bg-background px-4 py-2.5">
            <Button variant="ghost" size="icon" aria-label="Back 5 seconds" className="text-foreground" onClick={() => seek(time - 5)}>
              <RotateCcw />
            </Button>
            <Button
              size="icon"
              aria-label={running ? "Pause" : "Play"}
              className="size-9 rounded-full bg-foreground text-background hover:bg-foreground/85"
              onClick={() => {
                if (!running && time >= replay.duration) setTime(0);
                setPlaying(!running);
              }}
            >
              {running ? (
                <Pause className="size-3.5" fill="currentColor" strokeWidth={0} />
              ) : (
                <Play className="size-3.5" fill="currentColor" strokeWidth={0} />
              )}
            </Button>
            <Button variant="ghost" size="icon" aria-label="Forward 5 seconds" className="text-foreground" onClick={() => seek(time + 5)}>
              <RotateCw />
            </Button>
            <span className="font-mono text-[12.5px]">
              {clock(time)} <span className="text-muted-foreground">/ {clock(replay.duration, false)}</span>
            </span>
            <span className="flex-1" />
            <label className="inline-flex items-center gap-1.5 text-xs text-muted-foreground">
              <Checkbox checked={showTaps} onChange={(event) => setShowTaps(event.target.checked)} className="size-[13px]" />
              Show taps
            </label>
            <Select value={speed} onValueChange={setSpeed}>
              <SelectTrigger aria-label="Playback speed" className="h-7 px-2.5 text-xs [&>svg]:hidden">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {SPEEDS.map((value) => (
                  <SelectItem key={value} value={value}>
                    {value}×
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
        </section>
        <aside aria-label="Synced logs" className="box-content flex max-w-[640px] min-w-0 flex-[1_1_520px] flex-col border-l">
          <Tabs defaultValue="logs" className="flex min-h-0 flex-auto flex-col">
            <div className="flex flex-wrap items-center gap-2 border-b px-3 py-2">
              <TabsList aria-label="Replay panels">
                {TABS.map(([id, label]) => (
                  <TabsTrigger key={id} value={id}>
                    {label}
                  </TabsTrigger>
                ))}
              </TabsList>
              <span className="flex-1" />
              <label className="inline-flex items-center gap-2 text-xs text-muted-foreground">
                <Switch aria-label="Follow playback" checked={follow} onCheckedChange={setFollow} />
                Follow playback
              </label>
            </div>
            {TABS.map(([id, label]) => (
              <TabsContent key={id} value={id} className="flex min-h-0 flex-auto flex-col">
                <SyncedList label={`${label} at playback time`} rows={replay[id]} time={time} follow={follow} />
              </TabsContent>
            ))}
          </Tabs>
        </aside>
      </main>
      <Timeline time={time} onSeek={seek} />
    </div>
  );
}

/** Rows up to the playhead are bright, the last second's are highlighted; with `follow` the list keeps the latest in view. */
function SyncedList({ label, rows, time, follow }: { label: string; rows: ReplayRow[]; time: number; follow: boolean }) {
  const list = useRef<HTMLDivElement>(null);
  const latest = rows.findLastIndex(({ at }) => at <= time);

  useLayoutEffect(() => {
    const row = list.current?.children[Math.max(latest, 0)];
    if (follow && list.current && row instanceof HTMLElement) {
      list.current.scrollTop = row.offsetTop - list.current.clientHeight / 2;
    }
  }, [follow, latest]);

  return (
    <div ref={list} role="log" aria-label={label} className="relative min-h-0 flex-auto overflow-auto py-1.5 font-mono text-[11.5px] leading-5">
      {rows.map(({ at, level, tag, message }, index) => {
        const now = isNow(at, time);
        return (
          <div
            key={index}
            aria-current={now ? "time" : undefined}
            className={cn("grid grid-cols-[62px_16px_112px_minmax(0,1fr)] items-center gap-2 px-3 py-px", now && "bg-selection")}
          >
            <span className={now ? "text-link" : "text-muted-foreground"}>{clock(at)}</span>
            <LevelChip level={level} />
            <span className="truncate text-muted-foreground">{tag}</span>
            <span className={cn("truncate", at > time && "text-muted-foreground")}>{message}</span>
          </div>
        );
      })}
    </div>
  );
}

/** Time ticks, a track per kind of event and the playhead; click, drag or use the arrow keys to seek. */
function Timeline({ time, onSeek }: { time: number; onSeek: (seconds: number) => void }) {
  const taps: ReplayMark[] = replay.taps.map(({ at }) => ({ at, tone: isNow(at, time) ? "primary" : "foreground" }));
  const seekTo = (event: PointerEvent<HTMLElement>) => {
    const { left, width } = event.currentTarget.getBoundingClientRect();
    onSeek(((event.clientX - left) / width) * replay.duration);
  };
  return (
    <section aria-label="Timeline" className="border-t px-4 pt-2.5 pb-3.5">
      <div className="relative grid grid-cols-[96px_minmax(0,1fr)] items-center gap-x-3 gap-y-2 text-[11.5px]">
        <span />
        <div className="relative h-4 font-mono text-[10.5px] text-muted-foreground">
          {[0, 0.25, 0.5, 0.75, 1].map((part) => (
            // The quarter ticks would run into the end tick on a phone.
            <span
              key={part}
              className={cn("absolute", part % 0.5 && "max-sm:hidden")}
              style={part === 1 ? { right: 0 } : { left: `${part * 100}%` }}
            >
              {clock(replay.duration * part, false)}
            </span>
          ))}
        </div>
        {[{ label: "Taps", marks: taps }, ...replay.tracks].map(({ label, marks }) => (
          <Fragment key={label}>
            <span className="text-muted-foreground">{label}</span>
            <div className="relative h-[18px] rounded-sm bg-muted">
              {marks.map(({ at, length, tone }, index) => (
                <span
                  key={index}
                  style={{ left: percent(at), width: length ? percent(length) : 3 }}
                  className={cn("absolute top-[3px] h-3 rounded-[2px]", TONES[tone])}
                />
              ))}
            </div>
          </Fragment>
        ))}
        <div
          role="slider"
          tabIndex={0}
          aria-label="Playback position"
          aria-valuemin={0}
          aria-valuemax={replay.duration}
          aria-valuenow={time}
          aria-valuetext={`${clock(time)} of ${clock(replay.duration, false)}`}
          className="absolute -top-2 right-0 bottom-0 left-[108px] cursor-pointer touch-none select-none"
          onPointerDown={(event) => {
            event.currentTarget.setPointerCapture(event.pointerId);
            seekTo(event);
          }}
          onPointerMove={(event) => event.currentTarget.hasPointerCapture(event.pointerId) && seekTo(event)}
          onKeyDown={(event) => {
            const step = SEEK_KEYS[event.key];
            if (step === undefined) return;
            event.preventDefault();
            onSeek(time + step);
          }}
        >
          <span className="absolute inset-y-0 w-0.5 rounded-[1px] bg-primary" style={{ left: percent(time) }} />
        </div>
      </div>
    </section>
  );
}
