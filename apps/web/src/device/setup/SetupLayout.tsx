import { CircleCheck, LoaderCircle } from "lucide-react";
import { Fragment, type ReactNode } from "react";
import { IrisLogo } from "../../components/IrisLogo";
import { type RunStatus, RunStatusBadge } from "../../components/RunStatusBadge";
import { StatusFooter } from "../../components/StatusFooter";
import { ThemeToggle } from "../../components/ThemeToggle";
import { TopBar } from "../../components/TopBar";
import { Separator } from "../../components/ui/separator";
import { cn } from "../../lib/utils";
import { setupSession, type StepState } from "../../mocks/device/setup";

/** Classes for a button drawn like the design's inline links; the CLI will handle its action. */
export const linkClass = "cursor-pointer text-link hover:text-foreground";

/** The first-run pages: a plain header, the dotted stage and the status bar. */
export function SetupLayout({
  status,
  footer,
  themeToggle = true,
  className,
  children,
}: {
  status: RunStatus;
  /** The left side of the status bar; without it there is none, as behind the license dialog. */
  footer?: ReactNode;
  themeToggle?: boolean;
  /** Classes for the stage. */
  className?: string;
  children: ReactNode;
}) {
  return (
    <div className="flex min-h-screen flex-col bg-background leading-normal text-foreground">
      <TopBar>
        <div className="flex items-center gap-2">
          <IrisLogo />
          <span className="text-sm font-semibold tracking-[-0.01em]">Iris</span>
        </div>
        <Separator orientation="vertical" />
        <span className="font-medium">
          {setupSession.project}
          <span className="font-normal text-muted-foreground"> / {setupSession.target}</span>
        </span>
        <RunStatusBadge status={status} />
        {themeToggle && <ThemeToggle className="ml-auto" />}
      </TopBar>
      <main className={cn("flex flex-1 bg-stage-grid", className)}>{children}</main>
      {footer && (
        <StatusFooter>
          {footer}
          <span className="ml-auto">irisrun · {setupSession.server}</span>
        </StatusFooter>
      )}
    </div>
  );
}

export function StepIcon({ state }: { state: StepState }) {
  if (state === "done") return <CircleCheck aria-hidden="true" className="size-4 text-success" strokeWidth={2.4} />;
  if (state === "active") {
    return <LoaderCircle aria-hidden="true" className="size-4 animate-spin text-primary" strokeWidth={2.4} />;
  }
  return (
    <svg aria-hidden="true" viewBox="0 0 24 24" className="size-4 text-muted-foreground">
      <circle cx="12" cy="12" r="9" fill="none" stroke="currentColor" strokeWidth="2" strokeDasharray="3 3" />
    </svg>
  );
}

/** Gradle output for a <pre>: errors in red, the last line (the latest news) in the foreground. */
export function GradleLines({ lines }: { lines: string[] }) {
  return lines.map((line, i) => (
    <Fragment key={i}>
      {i > 0 && "\n"}
      {gradleLine(line, i === lines.length - 1)}
    </Fragment>
  ));
}

function gradleLine(line: string, last: boolean) {
  if (line.startsWith("e: ")) return <span className="text-destructive">{line}</span>;
  if (line.endsWith(" FAILED")) {
    return (
      <>
        {line.slice(0, -"FAILED".length)}
        <span className="text-destructive">FAILED</span>
      </>
    );
  }
  return last ? <span className="text-foreground">{line}</span> : line;
}
