import { Link } from "@tanstack/react-router";
import { Cloud, Pause } from "lucide-react";
import { useId } from "react";
import { Button } from "../../components/ui/button";
import { Card } from "../../components/ui/card";
import { Checkbox } from "../../components/ui/checkbox";
import type { PausedCall } from "../../mocks/device/compat";

/**
 * Iris's dialog over the paused app, inside the phone screen. It's always light,
 * like the screen, and doesn't take focus or block the page: the app is paused,
 * the rest of the Device UI isn't.
 */
export function PausedDialog({ api, framework, site }: PausedCall) {
  const id = useId();
  return (
    <div
      role="dialog"
      aria-labelledby={`${id}-title`}
      aria-describedby={`${id}-text`}
      className="light absolute inset-0 z-[4] flex items-center justify-center bg-[rgba(250,250,252,.72)] p-4 font-sans text-foreground backdrop-blur-[8px]"
    >
      <div className="w-full rounded-[18px] border bg-background px-[18px] pt-5 pb-4 shadow-[0_18px_40px_-16px_rgba(9,9,11,.28)]">
        <span className="inline-flex size-10 items-center justify-center rounded-xl bg-selection text-link">
          <Pause className="size-[18px]" fill="currentColor" strokeWidth={0} />
        </span>
        <h2 id={`${id}-title`} className="mt-3 text-[17px] leading-[1.3] font-semibold tracking-[-0.01em]">
          This screen needs a full iOS simulator
        </h2>
        <p id={`${id}-text`} className="mt-1.5 leading-normal text-[#52525b]">
          Your app called an API the local runtime doesn’t support yet. Nothing crashed — the app is paused right where it was.
        </p>
        <div className="mt-3 rounded-[10px] bg-muted px-3 py-2.5 font-mono text-[11.5px] leading-[1.6]">
          <div className="truncate">{api}</div>
          <div className="flex justify-between gap-2 text-muted-foreground">
            <span>{framework}</span>
            <Button variant="link" className="h-auto px-0 text-[11.5px] font-normal">
              {site}
            </Button>
          </div>
        </div>
        <Button className="mt-3.5 h-10 w-full gap-2 rounded-[10px] text-[13.5px]">
          <Cloud />
          Run on cloud simulator
        </Button>
        <Button variant="outline" className="mt-2 h-10 w-full rounded-[10px] bg-background text-[13.5px]">
          Skip with a stub and continue
        </Button>
        <div className="mt-2.5 flex items-center justify-between text-xs">
          <Button variant="link" className="h-auto px-0 text-xs font-normal text-[#52525b]">
            Go back one screen
          </Button>
          <Link to="." search hash="why" className="no-underline">
            Why does this happen?
          </Link>
        </div>
      </div>
    </div>
  );
}

/** The cards beside the paused phone: what keeps working, and stubbing the API from now on. */
export function PausedCards({
  feature,
  unsupported,
  onOpenCompat,
}: {
  feature: string;
  unsupported: number;
  /** Opens the Compatibility tab. */
  onOpenCompat: () => void;
}) {
  return (
    <div className="flex w-[260px] shrink flex-col gap-2.5">
      <Card className="p-3.5 shadow-xs">
        <div className="mb-1 font-semibold">What still works</div>
        <p className="text-xs leading-normal text-muted-foreground">
          Logs, Inspector and every other screen keep running locally. Only {feature} needs the cloud.
        </p>
        <Button variant="link" className="mt-2 h-auto p-0 text-xs font-normal" onClick={onOpenCompat}>
          See all {unsupported} in Compatibility
        </Button>
      </Card>
      <label className="flex items-start gap-2.5 rounded-[10px] border bg-card px-3.5 py-3 text-xs leading-normal text-muted-foreground shadow-xs">
        <Checkbox className="mt-0.5 size-3.5" />
        <span>
          <span className="block font-medium text-foreground">Always stub {feature} locally</span>
          Don’t pause next time. You can change this in Compatibility.
        </span>
      </label>
    </div>
  );
}
