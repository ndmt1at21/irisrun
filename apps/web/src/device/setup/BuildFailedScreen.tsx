import { Check, CircleX, Copy, Info, RefreshCw, X } from "lucide-react";
import { Fragment } from "react";
import { Button } from "../../components/ui/button";
import { Kbd } from "../../components/ui/kbd";
import { Switch } from "../../components/ui/switch";
import { cn } from "../../lib/utils";
import { buildFailure, type CompilerError } from "../../mocks/device/setup";
import { GradleLines, linkClass, SetupLayout } from "./SetupLayout";

/** The first build failed: the compiler errors with their code, and the Gradle output. */
export function BuildFailedScreen() {
  const { done, failed, skipped, duration, errors, output } = buildFailure;
  const files = [...new Set(errors.map((error) => error.file.split("/").pop()))].join(", ");
  const copyErrors = () =>
    void navigator.clipboard.writeText(
      errors.map((error) => `${error.file}:${error.line}:${error.column} ${error.message}`).join("\n"),
    );
  return (
    <SetupLayout
      status="build-failed"
      footer={
        <span className="inline-flex items-center gap-1.5">
          <span aria-hidden="true" className="size-1.5 rounded-full bg-destructive" />
          Build failed · watching for changes
        </span>
      }
      className="items-start justify-center px-6 py-8"
    >
      <section
        aria-labelledby="fail-title"
        className="w-full max-w-[882px] rounded-xl border bg-card shadow-[0_12px_32px_-16px_rgba(0,0,0,.5)]"
      >
        <div className="flex flex-wrap items-center gap-3 border-b px-5 py-[18px]">
          <span className="inline-flex size-[34px] items-center justify-center rounded-lg bg-destructive/14 text-destructive">
            <CircleX aria-hidden="true" className="size-[18px]" />
          </span>
          <div className="min-w-0 flex-[1_1_260px]">
            <h1 id="fail-title" className="text-[17px] font-semibold tracking-[-0.01em]">
              Build failed at {failed.name}
            </h1>
            <p className="text-muted-foreground">
              {errors.length} {errors.length === 1 ? "error" : "errors"} in{" "}
              <span className="font-mono text-foreground">{files}</span> · after {duration}
            </p>
          </div>
          <Button variant="outline" className="text-[12.5px]" onClick={copyErrors}>
            <Copy aria-hidden="true" className="size-3.5" />
            Copy errors
          </Button>
          <Button className="gap-2 text-[12.5px]">
            <RefreshCw aria-hidden="true" className="size-3.5" />
            Retry build
            <Kbd>⌘R</Kbd>
          </Button>
        </div>

        <div className="flex flex-wrap gap-2 border-b px-5 py-3 text-xs">
          {done.map((step) => (
            <Fragment key={step.name}>
              <span className="inline-flex items-center gap-1.5 text-success">
                <Check aria-hidden="true" className="size-[13px]" strokeWidth={2.4} />
                {step.name} {step.time}
              </span>
              <span className="text-muted-foreground">→</span>
            </Fragment>
          ))}
          <span className="inline-flex items-center gap-1.5 font-medium text-destructive">
            <X aria-hidden="true" className="size-[13px]" strokeWidth={2.4} />
            {failed.name} {failed.time}
          </span>
          <span className="text-muted-foreground">→ {skipped} skipped</span>
        </div>

        <div className="flex flex-col gap-3.5 px-5 py-4">
          {errors.map((error) => (
            <ErrorCard key={`${error.file}:${error.line}:${error.column}`} error={error} />
          ))}

          <details open className="overflow-hidden rounded-lg border">
            <summary className="cursor-pointer bg-muted px-3 py-2.5 font-medium">
              Gradle output <span className="font-normal text-muted-foreground">· last {output.length} lines</span>
            </summary>
            <pre className="overflow-x-auto bg-code p-3 font-mono text-[11.5px] leading-[1.65] text-muted-foreground">
              <GradleLines lines={output} />
            </pre>
          </details>

          <div className="flex flex-wrap items-center gap-3 rounded-lg bg-muted px-3.5 py-3">
            <Info aria-hidden="true" className="size-4 text-muted-foreground" />
            <span className="flex-[1_1_280px]">
              Fix the code and save — Iris rebuilds automatically when a file changes.
            </span>
            <label className="inline-flex items-center gap-2 text-xs font-medium">
              <Switch aria-label="Retry on save" defaultChecked />
              Retry on save
            </label>
          </div>
        </div>
      </section>
    </SetupLayout>
  );
}

function ErrorCard({ error }: { error: CompilerError }) {
  const [start, end] = error.span;
  return (
    <div className="overflow-hidden rounded-lg border">
      <div className="flex flex-wrap items-center gap-2.5 border-b bg-destructive/7 px-3 py-2.5">
        <span className="font-medium">{error.message}</span>
        <button type="button" className={cn(linkClass, "ml-auto font-mono text-xs")}>
          {error.file}:{error.line}:{error.column}
        </button>
      </div>
      <pre className="overflow-x-auto bg-code py-2.5 font-mono text-xs leading-[1.7]">
        {error.excerpt.map((text, i) => {
          const number = error.excerptStart + i;
          const isError = number === error.line;
          return (
            <Fragment key={number}>
              {i > 0 && "\n"}
              <span className={cn("select-none", isError ? "text-destructive" : "text-muted-foreground")}>
                {`${String(number).padStart(4)} │ `}
              </span>
              {isError ? (
                <>
                  {text.slice(0, start)}
                  <span className="underline decoration-destructive decoration-wavy underline-offset-3">
                    {text.slice(start, end)}
                  </span>
                  {text.slice(end)}
                </>
              ) : (
                text
              )}
            </Fragment>
          );
        })}
      </pre>
      {error.suggestion && (
        <div className="border-t px-3 py-2 text-xs text-muted-foreground">
          Did you mean <span className="font-mono text-foreground">{error.suggestion.name}</span>?{" "}
          {error.suggestion.reason}
        </div>
      )}
    </div>
  );
}
