import { Link } from "@tanstack/react-router";
import { Cloud, ShoppingBag } from "lucide-react";
import { type CSSProperties, type ReactNode, useState } from "react";
import { Badge, type BadgeTone } from "../../components/ui/badge";
import { EmptyState } from "../../components/ui/empty-state";
import { SearchField } from "../../components/ui/search-field";
import { Segmented, SegmentedItem } from "../../components/ui/segmented";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "../../components/ui/select";
import { Skeleton } from "../../components/ui/skeleton";
import { cn } from "../../lib/utils";
import { type PreviewStatus, type PreviewThumb, previewGallery } from "../../mocks/device/previews";
import { PageLayout } from "./PageLayout";

const STATUSES: Record<PreviewStatus, { label: string; tone: BadgeTone }> = {
  "on-device": { label: "On device", tone: "primary" },
  ready: { label: "Ready", tone: "muted" },
  "cloud-only": { label: "Cloud only", tone: "warning" },
  rendering: { label: "Rendering…", tone: "muted" },
};

type Appearance = "light" | "dark";

// iOS system colors of the mock renders in each appearance; product photos keep theirs.
const IOS_COLORS: Record<Appearance, CSSProperties> = {
  light: {
    "--ios-bg": "#ffffff",
    "--ios-label": "#000000",
    "--ios-ink": "#1c1c1e",
    "--ios-secondary": "#3c3c43",
    "--ios-gray": "#8e8e93",
    "--ios-fill": "#eeeef0",
    "--ios-bar": "#f2f2f4",
    "--ios-stroke": "#d1d1d6",
    "--ios-red": "#ff3b30",
    "--ios-tint": "#0a7a6f",
    "--ios-tint-soft": "#e6f4f2",
  } as CSSProperties,
  dark: {
    "--ios-bg": "#000000",
    "--ios-label": "#ffffff",
    "--ios-ink": "#f2f2f7",
    "--ios-secondary": "#ebebf599",
    "--ios-gray": "#8e8e93",
    "--ios-fill": "#1c1c1e",
    "--ios-bar": "#1c1c1e",
    "--ios-stroke": "#48484a",
    "--ios-red": "#ff453a",
    "--ios-tint": "#14a394",
    "--ios-tint-soft": "#0f2f2b",
  } as CSSProperties,
};

/** Route `/previews`: every `#Preview` of the iOS project as a thumbnail that opens it on the device. */
export function PreviewsPage() {
  const { project, target, devices, previews } = previewGallery;
  const [query, setQuery] = useState("");
  const [appearance, setAppearance] = useState<Appearance>("light");
  const q = query.trim().toLowerCase();
  const shown = previews.filter((p) => p.name.toLowerCase().includes(q) || p.file.toLowerCase().includes(q));
  const files = new Set(previews.map((p) => p.file.split(":")[0])).size;

  return (
    <PageLayout project={project} target={target}>
      <div className="flex flex-col gap-4 p-6">
        <div className="flex flex-wrap items-end gap-3">
          <div className="flex-[1_1_280px]">
            <h1 className="text-[22px] font-semibold tracking-[-0.02em]">Previews</h1>
            <p className="mt-0.5 text-muted-foreground">
              Every <span className="font-mono text-foreground">#Preview</span> in the project, rendered live. Click one
              to open it on the device.
            </p>
          </div>
          <SearchField
            aria-label="Search previews"
            placeholder="Search previews or files"
            className="flex-[0_1_282px]"
            value={query}
            onChange={(event) => setQuery(event.target.value)}
          />
          <Segmented aria-label="Appearance" value={appearance} onValueChange={(v) => setAppearance(v as Appearance)}>
            <SegmentedItem value="light">Light</SegmentedItem>
            <SegmentedItem value="dark">Dark</SegmentedItem>
          </Segmented>
          <Select defaultValue={devices[0]}>
            <SelectTrigger aria-label="Device" className="text-xs">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              {devices.map((device) => (
                <SelectItem key={device} value={device}>
                  {device}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>
        <div className="flex gap-4 text-xs text-muted-foreground">
          <span>
            {previews.length} previews · {files} files
          </span>
          <span>Updated with hot reload</span>
        </div>

        {shown.length === 0 && <EmptyState title={`No previews match “${query}”`} />}
        <div className="grid grid-cols-[repeat(auto-fill,minmax(250px,1fr))] gap-3.5">
          {shown.map((preview) => (
            <Link
              key={preview.file}
              to="/"
              search={{ mock: "ios-inspector" }}
              className={cn(
                "flex flex-col overflow-hidden rounded-[10px] border bg-card text-foreground",
                preview.status === "on-device" && "ring-2 ring-primary",
              )}
            >
              <div
                className="flex h-[220px] items-center justify-center bg-muted bg-[radial-gradient(color-mix(in_srgb,var(--foreground)_9%,transparent)_1px,transparent_1px)] bg-size-[12px_12px] font-[-apple-system,'SF_Pro_Text',system-ui,sans-serif]"
                style={IOS_COLORS[appearance]}
              >
                <Thumb thumb={preview.thumb} />
              </div>
              <div className="flex items-center gap-2 border-t px-3 py-2.5">
                <span className="min-w-0 flex-1">
                  <span className="block truncate font-medium">{preview.name}</span>
                  <span className="block font-mono text-[11.5px] text-muted-foreground">{preview.file}</span>
                </span>
                <Badge tone={STATUSES[preview.status].tone} className="h-5 px-[7px] text-[11px]">
                  {STATUSES[preview.status].label}
                </Badge>
              </div>
            </Link>
          ))}
        </div>
      </div>
    </PageLayout>
  );
}

const TILES = ["#fde8da", "#dde8fb", "#ddf2e3", "#f1e3f6"];
const BAG_BUTTON = "flex h-[30px] items-center justify-center rounded-[9px]";
const BONE = "rounded bg-foreground/12";

/** The mock render of a preview, drawn in the colors of the chosen appearance. */
function Thumb({ thumb }: { thumb: PreviewThumb }) {
  switch (thumb.kind) {
    case "product-card":
      return (
        <div className="relative w-[148px] rounded-[14px] bg-(--ios-bg) p-2 shadow-[0_6px_18px_-8px_rgba(0,0,0,.35)]">
          <div className="h-24 rounded-[10px]" style={{ background: thumb.tint }} />
          <div className="mt-1.5 text-[11px] text-(--ios-secondary)">{thumb.title}</div>
          <div className="text-xs font-semibold text-(--ios-label)">{thumb.price}</div>
          {thumb.sale && (
            <span className="absolute top-3.5 left-3.5 rounded-sm bg-(--ios-red) px-1.5 py-px text-[9px] font-bold text-white">
              {thumb.sale}
            </span>
          )}
        </div>
      );
    case "home":
      return (
        <Phone>
          <div className="h-2 w-1/2 rounded-[3px] bg-(--ios-ink)" />
          <div className="h-2.5 rounded bg-(--ios-fill)" />
          <div className="grid grid-cols-2 gap-1">
            {TILES.map((tint) => (
              <div key={tint} className="h-10 rounded-[5px]" style={{ background: tint }} />
            ))}
          </div>
          <div className="mt-auto h-3 rounded-[3px] bg-(--ios-bar)" />
        </Phone>
      );
    case "detail":
      return (
        <Phone>
          <div className="h-[78px] rounded-md bg-[#fde8da]" />
          <div className="h-2 w-[70%] rounded-[3px] bg-(--ios-ink)" />
          <div className="h-[7px] w-2/5 rounded-[3px] bg-(--ios-gray)" />
          <div className="flex gap-[3px]">
            <span className="h-2.5 w-3.5 rounded-[3px] border border-(--ios-stroke)" />
            <span className="h-2.5 w-3.5 rounded-[3px] border-[1.5px] border-(--ios-tint)" />
            <span className="h-2.5 w-3.5 rounded-[3px] border border-(--ios-stroke)" />
          </div>
          <div className="mt-auto h-3.5 rounded bg-(--ios-tint)" />
        </Phone>
      );
    case "empty-bag":
      return (
        <div className="w-[174px] rounded-[14px] bg-(--ios-bg) px-3 py-[18px] text-center text-(--ios-gray)">
          <ShoppingBag className="inline size-[26px] align-baseline" strokeWidth={1.6} />
          <div className="mt-1.5 text-[11px] font-semibold text-(--ios-ink)">Your bag is empty</div>
          <div className="mx-auto mt-2.5 h-[18px] w-4/5 rounded-[9px] bg-(--ios-tint)" />
        </div>
      );
    case "add-to-bag":
      return (
        <div className="flex w-[150px] flex-col gap-2 text-[11px] font-semibold">
          <span className={cn(BAG_BUTTON, "bg-(--ios-tint) text-white")}>Add to Bag</span>
          <span className={cn(BAG_BUTTON, "bg-(--ios-tint)/55 text-white")}>Adding…</span>
          <span className={cn(BAG_BUTTON, "bg-(--ios-tint-soft) text-(--ios-tint)")}>✓ Added</span>
        </div>
      );
    // The last two are Iris's own placeholders, so they follow the Iris theme.
    case "needs-cloud":
      return (
        <div className="w-[180px] text-center font-sans">
          <span className="inline-flex size-8 items-center justify-center rounded-[9px] bg-selection text-link">
            <Cloud className="size-[15px]" />
          </span>
          <div className="mt-2 text-xs font-medium text-foreground">Needs a cloud simulator</div>
          <div className="mt-0.5 font-mono text-[11px] text-muted-foreground">{thumb.api}</div>
        </div>
      );
    case "rendering":
      return (
        <div aria-label="Rendering" className="flex w-[150px] flex-col gap-2">
          <div className="flex items-center gap-2">
            <Skeleton className={cn(BONE, "size-[26px] rounded-full")} />
            <Skeleton className={cn(BONE, "h-2 flex-1")} />
          </div>
          <Skeleton className={cn(BONE, "h-2")} />
          <Skeleton className={cn(BONE, "h-2 w-[70%]")} />
          <Skeleton className={cn(BONE, "h-2 w-[85%]")} />
        </div>
      );
  }
}

function Phone({ children }: { children: ReactNode }) {
  return (
    <div className="flex h-[196px] w-[98px] flex-col gap-[5px] rounded-[18px] bg-(--ios-bg) p-1.5 shadow-[0_0_0_3px_#2b2a2e,0_6px_18px_-8px_rgba(0,0,0,.4)]">
      {children}
    </div>
  );
}
