import { Globe, TriangleAlert } from "lucide-react";
import { useState } from "react";
import { Alert, AlertTitle } from "../../components/ui/alert";
import { Badge } from "../../components/ui/badge";
import { Button } from "../../components/ui/button";
import { Input } from "../../components/ui/input";
import { RadioGroup, RadioGroupItem } from "../../components/ui/radio-group";
import { Segmented, SegmentedItem } from "../../components/ui/segmented";
import { cn } from "../../lib/utils";
import { orgSlug, regions, retentionDays, stored } from "../../mocks/console/region";

export function DataRegionPage() {
  // As in the artboard: Tokyo picked and the name half typed.
  const [picked, setPicked] = useState("ap-northeast-1");
  const [confirm, setConfirm] = useState("acme-mob");
  const [retention, setRetention] = useState(String(retentionDays));
  const target = regions.find((r) => r.code === picked && r.code !== stored.code);

  return (
    <div className="flex w-full max-w-[920px] flex-col gap-[18px] p-7">
      <div>
        <h1 className="text-[22px] font-semibold tracking-[-0.02em]">Data region</h1>
        <p className="mt-1 text-muted-foreground">
          Where session recordings, logs and screenshots are stored. Live device video is streamed, not stored, outside
          this region.
        </p>
      </div>

      <section aria-labelledby="dr-current" className="flex flex-wrap items-center gap-4 rounded-[10px] border px-[18px] py-4">
        <span className="inline-flex size-10 items-center justify-center rounded-[10px] bg-selection text-link">
          <Globe className="size-[18px]" />
        </span>
        <div className="flex-[1_1_240px]">
          <h2 id="dr-current" className="text-[15px] font-semibold">
            {stored.name} <span className="font-mono text-xs font-normal text-muted-foreground">{stored.code}</span>
          </h2>
          <div className="text-[12.5px] text-muted-foreground">
            Since {stored.since} · {stored.recordings} recordings · {stored.size}
          </div>
        </div>
        <Badge tone="success">Current</Badge>
      </section>

      <section aria-labelledby="dr-change" className="rounded-[10px] border">
        <div className="border-b px-[18px] py-4">
          <h2 id="dr-change" className="text-[15px] font-semibold">
            Move to another region
          </h2>
          <p className="mt-0.5 text-[12.5px] text-muted-foreground">
            Only Owners can change this. Members are emailed when the move starts and finishes.
          </p>
        </div>
        <RadioGroup
          aria-label="Region"
          value={picked}
          onValueChange={setPicked}
          className="grid-cols-[repeat(auto-fill,minmax(200px,1fr))] px-[18px] py-4"
        >
          {regions.map((r) => {
            const current = r.code === stored.code;
            return (
              <RadioGroupItem
                key={r.code}
                value={r.code}
                disabled={current}
                className={cn("bg-transparent", current && "border-dashed border-input disabled:cursor-default disabled:opacity-70")}
              >
                <span className="block font-semibold">{r.name}</span>
                <span className="block font-mono text-[11.5px] text-muted-foreground">{r.code}</span>
                <span className="mt-1.5 block text-xs text-muted-foreground">
                  {current ? "Current region" : r === target ? "Selected" : "Available"}
                </span>
              </RadioGroupItem>
            );
          })}
        </RadioGroup>
        {target && (
          <>
            <Alert variant="warning" className="mx-[18px] px-3.5">
              <TriangleAlert />
              <div className="text-[12.5px]">
                <AlertTitle>Moving to {target.name}</AlertTitle>
                New recordings go to {target.name} right away. Existing data ({stored.size}) is copied in the background,
                then deleted from {stored.name}. Replays stay available during the move.
              </div>
            </Alert>
            <div className="flex flex-wrap items-end gap-3 px-[18px] py-4">
              <label className="flex flex-[1_1_260px] flex-col gap-1.5 text-[12.5px] font-medium">
                <span>
                  Type <span className="font-mono">{orgSlug}</span> to confirm
                </span>
                <Input
                  value={confirm}
                  onChange={(event) => setConfirm(event.target.value)}
                  className="h-[34px] font-mono text-[12.5px] font-normal"
                />
              </label>
              <Button
                variant="outline"
                size="lg"
                onClick={() => {
                  setPicked("");
                  setConfirm("");
                }}
              >
                Cancel
              </Button>
              <Button size="lg" disabled={confirm !== orgSlug}>
                Start move
              </Button>
            </div>
          </>
        )}
      </section>

      <section aria-labelledby="dr-ret" className="flex flex-wrap items-center gap-4 rounded-[10px] border px-[18px] py-4">
        <div className="flex-[1_1_280px]">
          <h2 id="dr-ret" className="text-[15px] font-semibold">
            Keep recordings for
          </h2>
          <p className="mt-0.5 text-[12.5px] text-muted-foreground">Older recordings and their logs are deleted automatically.</p>
        </div>
        <Segmented aria-label="Retention" value={retention} onValueChange={setRetention}>
          {["7", "30", "90"].map((days) => (
            <SegmentedItem key={days} value={days} className="h-7 px-3 text-[12.5px] font-normal data-[state=on]:font-medium">
              {days} days
            </SegmentedItem>
          ))}
        </Segmented>
      </section>
    </div>
  );
}
