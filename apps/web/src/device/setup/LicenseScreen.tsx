import { ExternalLink, FileText } from "lucide-react";
import { useState } from "react";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from "../../components/ui/alert-dialog";
import { Tag } from "../../components/ui/badge";
import { Checkbox } from "../../components/ui/checkbox";
import { Skeleton } from "../../components/ui/skeleton";
import { cn } from "../../lib/utils";
import { linkClass, SetupLayout } from "./SetupLayout";

const LICENSES = ["android-sdk-license", "android-sdk-arm-dbt-license"];
// Widths of the placeholder lines, two paragraphs of five.
const LINES = [42, 96, 91, 94, 63, 36, 97, 89, 93, 71];

/** Step 2 of the first run: the Android SDK license, over the dimmed stage. */
export function LicenseScreen() {
  const [accepted, setAccepted] = useState(true);
  return (
    <SetupLayout status="waiting" themeToggle={false} className="flex-col items-center justify-center gap-4 px-4 py-8">
      <div className="flex gap-2 text-xs text-muted-foreground">
        <span className="box-content inline-flex h-[26px] items-center rounded-full border px-2.5">✓ Toolchain</span>
        <span className="box-content inline-flex h-[26px] items-center rounded-full border border-primary px-2.5 text-foreground">
          2 SDK license
        </span>
        <span className="inline-flex h-[26px] items-center px-2.5">3 Build</span>
        <span className="inline-flex h-[26px] items-center px-2.5">4 Launch</span>
      </div>
      <div className="h-[362px] w-[600px] max-w-full rounded-xl border bg-card" />

      {/* Accept and Decline are the CLI's to handle, so the dialog stays open. */}
      <AlertDialog open>
        <AlertDialogContent
          onOpenAutoFocus={(event) => {
            // Focus the dialog, not Decline: the license is read first, and Enter must not decline it.
            event.preventDefault();
            (event.currentTarget as HTMLElement).focus();
          }}
        >
          <AlertDialogHeader>
            <div className="flex items-center gap-2.5">
              <span className="inline-flex size-8 items-center justify-center rounded-lg bg-muted">
                <FileText aria-hidden="true" className="size-4" />
              </span>
              <AlertDialogTitle>Accept the Android SDK license</AlertDialogTitle>
            </div>
            <AlertDialogDescription>
              Iris builds your app with the Android SDK from Google. Please review and accept its license to continue.
              You’ll only be asked once on this computer.
            </AlertDialogDescription>
          </AlertDialogHeader>

          <div className="mx-6 mt-4 overflow-hidden rounded-lg border">
            <div className="flex items-center justify-between border-b bg-muted px-3 py-2 text-xs">
              <span className="font-medium">Android Software Development Kit License Agreement</span>
              <button type="button" className={cn(linkClass, "inline-flex items-center gap-1")}>
                Open full text
                <ExternalLink aria-hidden="true" className="size-3" />
              </button>
            </div>
            <div
              role="region"
              tabIndex={0}
              aria-label="License text"
              className="flex h-56 flex-col gap-[9px] overflow-auto px-3 py-3.5"
            >
              <span className="text-xs text-muted-foreground">[License text is loaded from the SDK package at run time]</span>
              {LINES.map((width, i) => (
                <Skeleton key={i} className={cn("h-2 shrink-0", i === 5 && "mt-2")} style={{ width: `${width}%` }} />
              ))}
            </div>
          </div>

          <div className="mx-6 mt-2.5 flex flex-wrap gap-1.5 text-[11.5px] text-muted-foreground">
            <span>Covers</span>
            {LICENSES.map((id) => (
              <Tag key={id} className="font-mono text-[11.5px]">
                {id}
              </Tag>
            ))}
          </div>

          <label className="mx-6 mt-4 flex items-start gap-2.5 font-medium">
            <Checkbox className="mt-0.5" checked={accepted} onChange={(event) => setAccepted(event.target.checked)} />
            I have read and accept the Android SDK License Agreement
          </label>

          <AlertDialogFooter>
            <span className="flex-[1_1_200px] text-xs text-muted-foreground">
              Declining stops Android setup. iOS projects still work.
            </span>
            <AlertDialogCancel>Decline</AlertDialogCancel>
            <AlertDialogAction disabled={!accepted}>Accept and continue</AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </SetupLayout>
  );
}
