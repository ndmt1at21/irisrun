import { Download, Folder, Terminal } from "lucide-react";
import { Button } from "../../components/ui/button";
import { Progress } from "../../components/ui/progress";
import { cn } from "../../lib/utils";
import { type ToolchainPart, toolchainDownload } from "../../mocks/device/setup";
import { linkClass, SetupLayout, StepIcon } from "./SetupLayout";

const STEPS = ["Toolchain", "SDK license", "Build", "Launch"];

function partStatus({ state, percent, downloaded }: ToolchainPart) {
  if (state === "active") return `${percent}% · ${downloaded}`;
  return state === "done" ? "Done" : "Queued";
}

/** Step 1 of the first run: downloading the Android toolchain. */
export function ToolchainScreen() {
  const download = toolchainDownload;
  return (
    <SetupLayout
      status="setting-up"
      footer={<span>Setting up · step 1 of 4</span>}
      className="flex-col items-center justify-center gap-4 px-4 py-8"
    >
      <ol aria-label="Setup steps" className="flex flex-wrap items-center gap-2 text-xs text-muted-foreground">
        {STEPS.map((step, i) => [
          i > 0 && <li key={`${step}-rule`} aria-hidden="true" className="h-px w-4 bg-border" />,
          <li
            key={step}
            aria-current={i === 0 ? "step" : undefined}
            className={cn(
              "inline-flex items-center gap-1.5",
              i === 0 &&
                "box-content h-[26px] rounded-full border border-[color-mix(in_srgb,var(--primary)_40%,var(--border))] bg-background px-2.5 font-medium text-foreground",
            )}
          >
            <span
              className={cn(
                "inline-flex size-4 items-center justify-center rounded-full text-[10px]",
                i === 0 ? "bg-primary text-primary-foreground" : "border border-input",
              )}
            >
              {i + 1}
            </span>
            {step}
          </li>,
        ])}
      </ol>

      <section
        aria-labelledby="dl-title"
        className="w-full max-w-[600px] rounded-xl border bg-card shadow-[0_12px_32px_-16px_rgba(9,9,11,.18)]"
      >
        <div className="px-6 pt-[22px] pb-[18px]">
          <h1 id="dl-title" className="text-lg font-semibold tracking-[-0.01em]">
            Downloading the Android toolchain
          </h1>
          <p className="mt-1 text-muted-foreground">
            First run only. Iris keeps the SDK, build tools and runtime in its own folder — nothing is installed
            system-wide, and Android Studio isn’t needed.
          </p>
          <div className="mt-[18px] flex items-baseline justify-between">
            <span className="text-[15px] font-semibold">
              {download.downloaded} <span className="font-normal text-muted-foreground">of {download.total}</span>
            </span>
            <span className="font-mono font-medium">{download.percent}%</span>
          </div>
          <Progress aria-label="Toolchain download" value={download.percent} className="mt-2 *:rounded-full" />
          <div className="mt-2.5 flex flex-wrap items-center gap-4 text-xs text-muted-foreground">
            <span className="inline-flex items-center gap-1.5">
              <Download aria-hidden="true" className="size-[13px]" />
              <span className="font-mono text-foreground">{download.speed}</span>
            </span>
            <span>About {download.timeLeft} left</span>
            <span>
              Mirror: {download.mirror} ·{" "}
              <button type="button" className={linkClass}>
                Change
              </button>
            </span>
            <Button variant="outline" size="xs" className="ml-auto">
              Pause
            </Button>
          </div>
        </div>

        <ul aria-label="Components" className="border-t py-1.5">
          {download.parts.map((part) => (
            <li
              key={part.name}
              className="grid grid-cols-[18px_minmax(0,1fr)_72px_96px] items-center gap-3 px-6 py-2 text-[12.5px]"
            >
              <StepIcon state={part.state} />
              <span className="min-w-0">
                <span className={cn("block truncate", part.state === "queued" && "text-muted-foreground")}>
                  {part.name}
                </span>
                {part.percent !== undefined && (
                  <Progress aria-label={part.name} value={part.percent} className="mt-1.5 h-1 rounded-[2px]" />
                )}
              </span>
              <span className="text-right font-mono text-xs text-muted-foreground">{part.size}</span>
              <span className={cn("text-right text-xs", part.state !== "active" && "text-muted-foreground")}>
                {partStatus(part)}
              </span>
            </li>
          ))}
        </ul>

        <div className="flex flex-wrap items-center gap-3 border-t px-6 py-3 text-xs text-muted-foreground">
          <span className="inline-flex items-center gap-1.5">
            <Folder aria-hidden="true" className="size-[13px]" />
            <span className="font-mono">{download.folder}</span>
          </span>
          <span>Shared by all your projects</span>
          <Button variant="ghost" size="xs" className="ml-auto text-muted-foreground">
            Cancel setup
          </Button>
        </div>
      </section>

      <p className="inline-flex items-center gap-2 text-xs text-muted-foreground">
        <Terminal aria-hidden="true" className="size-[13px]" />
        Started by <span className="font-mono text-foreground">irisrun start</span> · safe to leave this tab, it will
        continue
      </p>
    </SetupLayout>
  );
}
