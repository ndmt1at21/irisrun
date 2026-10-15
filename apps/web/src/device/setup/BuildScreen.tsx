import { Check, Smartphone } from "lucide-react";
import { Button } from "../../components/ui/button";
import { Progress } from "../../components/ui/progress";
import { cn } from "../../lib/utils";
import { buildRun, setupSession } from "../../mocks/device/setup";
import { GradleLines, linkClass, SetupLayout, StepIcon } from "./SetupLayout";

/** Step 3 of the first run: the build, with the device booting beside it. */
export function BuildScreen() {
  const { elapsed, steps, device, workers } = buildRun;
  return (
    <SetupLayout
      status="building"
      footer={
        <>
          <span>Building · step 3 of 4</span>
          <span>Gradle daemon · {workers} workers</span>
        </>
      }
      className="flex-wrap items-center justify-center gap-10 px-6 py-8"
    >
      <section
        aria-labelledby="build-title"
        className="min-w-0 flex-[0_1_642px] rounded-xl border bg-card shadow-[0_12px_32px_-16px_rgba(9,9,11,.18)]"
      >
        <div className="flex flex-wrap items-start gap-3 border-b px-[22px] pt-5 pb-4">
          <div className="flex-[1_1_280px]">
            <div className="mb-2.5 flex gap-1.5 text-[11.5px] text-muted-foreground">
              <span className="text-success">✓ Toolchain</span>
              <span>·</span>
              <span className="text-success">✓ License</span>
              <span>·</span>
              <span className="font-medium text-foreground">3 Build</span>
              <span>·</span>
              <span>4 Launch</span>
            </div>
            <h1 id="build-title" className="text-lg font-semibold tracking-[-0.01em]">
              Building {setupSession.project}
            </h1>
            <p className="mt-0.5 text-muted-foreground">
              First build compiles everything. After this, edits hot reload in about a second.
            </p>
          </div>
          <span className="font-mono text-xl font-medium">{elapsed}</span>
        </div>

        <ol aria-label="Build steps" className="py-2">
          {steps.map((step) => (
            <li key={step.name} className={cn("px-[22px] py-2", step.state === "active" && "bg-primary/5")}>
              <div className="grid grid-cols-[18px_minmax(0,1fr)_auto] items-center gap-3">
                <StepIcon state={step.state} />
                <span className="min-w-0">
                  <span className={cn("font-medium", step.state === "queued" && "text-muted-foreground")}>
                    {step.name}
                  </span>
                  <span className="ml-2 text-xs text-muted-foreground">{step.detail}</span>
                </span>
                <span className="font-mono text-xs text-muted-foreground">{step.time}</span>
              </div>
              {step.progress && (
                <div className="mt-2.5 mb-1 ml-[30px]">
                  <Progress aria-label={step.progress.label} value={step.progress.percent} className="h-1 rounded-[2px]" />
                  <pre className="mt-2.5 overflow-x-auto rounded-md border bg-code px-3 py-2.5 font-mono text-[11.5px] leading-[1.6] text-muted-foreground">
                    <GradleLines lines={step.progress.output} />
                  </pre>
                </div>
              )}
            </li>
          ))}
        </ol>

        <div className="flex flex-wrap items-center gap-2.5 border-t px-[22px] py-3">
          <button type="button" className={cn(linkClass, "text-xs")}>
            Show full build log
          </button>
          <Button variant="outline" size="sm" className="ml-auto text-xs">
            Cancel build
          </Button>
        </div>
      </section>

      <div
        role="group"
        aria-label="Device booting"
        className="flex h-[632px] w-[300px] flex-none flex-col items-center justify-center gap-2.5 rounded-[38px] border-[1.5px] border-dashed border-foreground/22 p-6 text-center text-muted-foreground"
      >
        <Smartphone aria-hidden="true" className="size-7" strokeWidth={1.6} />
        <span className="font-medium text-foreground">{device.name}</span>
        <span className="inline-flex items-center gap-1.5 text-xs text-success">
          <Check aria-hidden="true" className="size-[13px]" strokeWidth={2.4} />
          Booted in {device.bootedIn}
        </span>
        <span className="text-xs">Waiting for the build to install</span>
      </div>
    </SetupLayout>
  );
}
