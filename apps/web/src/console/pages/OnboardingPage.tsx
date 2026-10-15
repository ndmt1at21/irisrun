import { Link } from "@tanstack/react-router";
import { ChevronRight, Server, Smartphone } from "lucide-react";
import { useState } from "react";
import { IrisLogo } from "../../components/IrisLogo";
import { Tag } from "../../components/ui/badge";
import { Button } from "../../components/ui/button";
import { Checkbox } from "../../components/ui/checkbox";
import { cn } from "../../lib/utils";
import { deviceChoices, setupSteps } from "../../mocks/console/onboarding";

const STEP_STATUS = {
  done: { label: "✓ Done", className: "text-success" },
  now: { label: "Now", className: "text-link" },
  next: { label: "Next", className: "text-muted-foreground" },
};

const MAC_HOST_OPTIONS = [
  {
    title: "Connect AWS",
    detail: "Iris provisions EC2 Mac in your account · 24 h minimum billing",
    search: {},
  },
  { title: "Use any Mac", detail: "Install the agent on a Mac you manage", search: { mock: "any-mac" } },
];

export function OnboardingPage() {
  const [choices, setChoices] = useState(deviceChoices);
  const picked = choices.filter((choice) => choice.selected).length;
  return (
    <div className="flex min-h-screen flex-col bg-background leading-normal">
      <header className="flex min-h-14 flex-wrap items-center gap-3 border-b px-6">
        <IrisLogo size={22} />
        <span className="font-semibold">Set up Acme Mobile</span>
        <span className="flex-1" />
        <span className="text-xs text-muted-foreground">Step 2 of 3</span>
        <Link to="/console/projects" className="text-[12.5px] text-muted-foreground no-underline">
          Skip for now
        </Link>
      </header>

      <main className="mx-auto flex w-full max-w-[980px] flex-1 flex-col gap-6 px-6 py-8">
        <ol aria-label="Setup steps" className="grid grid-cols-3 gap-3">
          {setupSteps.map((step) => (
            <li
              key={step.title}
              aria-current={step.status === "now" ? "step" : undefined}
              className={cn("border-t-[3px] pt-2.5", step.status === "next" ? "border-border" : "border-primary")}
            >
              <div className={cn("text-xs font-medium", STEP_STATUS[step.status].className)}>
                {STEP_STATUS[step.status].label}
              </div>
              <div className={cn("font-semibold", step.status === "next" && "text-muted-foreground")}>{step.title}</div>
              <div className="text-xs text-muted-foreground">{step.detail}</div>
            </li>
          ))}
        </ol>

        <div>
          <h1 className="text-2xl font-semibold tracking-[-0.02em]">Where should your team’s apps run?</h1>
          <p className="mt-1 text-muted-foreground">
            Pick one or both. Local runs on your own computer always work — this is for cloud sessions.
          </p>
        </div>

        <div className="grid grid-cols-[repeat(auto-fit,minmax(min(380px,100%),1fr))] gap-4">
          <section aria-labelledby="ob-ios" className="flex flex-col gap-3 rounded-xl border bg-card p-5">
            <div className="flex items-center gap-2.5">
              <span className="inline-flex size-9 shrink-0 items-center justify-center rounded-[9px] bg-muted">
                <Server aria-hidden="true" className="size-[18px]" />
              </span>
              <div>
                <h2 id="ob-ios" className="text-[15px] font-semibold">
                  iOS · Add a Mac host
                </h2>
                <div className="text-xs text-muted-foreground">Cloud simulators need a Mac. Each host runs up to 4.</div>
              </div>
            </div>
            {MAC_HOST_OPTIONS.map((option) => (
              <Link
                key={option.title}
                to="/console/hosts/new"
                search={option.search}
                className="flex items-center gap-3 rounded-lg border px-3.5 py-3 text-foreground no-underline hover:bg-accent"
              >
                <span className="flex-1">
                  <span className="block font-medium">{option.title}</span>
                  <span className="block text-xs text-muted-foreground">{option.detail}</span>
                </span>
                <ChevronRight aria-hidden="true" className="size-4 shrink-0 text-muted-foreground" />
              </Link>
            ))}
          </section>

          <section aria-labelledby="ob-android" className="flex flex-col gap-3 rounded-xl border-[1.5px] border-primary bg-card p-5">
            <div className="flex items-center gap-2.5">
              <span className="inline-flex size-9 shrink-0 items-center justify-center rounded-[9px] bg-selection text-link">
                <Smartphone aria-hidden="true" className="size-[18px]" />
              </span>
              <div>
                <h2 id="ob-android" className="text-[15px] font-semibold">
                  Android · Pick cloud devices
                </h2>
                <div className="text-xs text-muted-foreground">Favorites appear first when your team opens a session.</div>
              </div>
            </div>
            <fieldset className="flex flex-col gap-1.5">
              <legend className="sr-only">Devices</legend>
              {choices.map((choice) => (
                <label
                  key={choice.name}
                  className="flex cursor-pointer items-center gap-3 rounded-lg border px-3 py-[9px] has-checked:bg-selection"
                >
                  <Checkbox
                    checked={choice.selected}
                    onChange={() =>
                      setChoices(choices.map((c) => (c === choice ? { ...c, selected: !c.selected } : c)))
                    }
                  />
                  <span className="min-w-0 flex-1">
                    <span className="block font-medium">{choice.name}</span>
                    <span className="block text-xs text-muted-foreground">{choice.detail}</span>
                  </span>
                  <Tag>{choice.type}</Tag>
                </label>
              ))}
            </fieldset>
            <Link to="/console/devices" className="self-start text-[12.5px] no-underline">
              Browse all 64 devices
            </Link>
          </section>
        </div>

        <div className="flex flex-wrap items-center gap-2.5 border-t pt-2">
          <Button variant="outline" className="h-9 px-3.5">
            Back
          </Button>
          <span className="flex-1" />
          <span aria-live="polite" className="text-xs text-muted-foreground">
            {picked} {picked === 1 ? "device" : "devices"} selected
          </span>
          <Button className="h-9 px-4">Continue</Button>
        </div>
      </main>
    </div>
  );
}
