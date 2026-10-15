import { Link } from "@tanstack/react-router";
import { GripHorizontal, GripVertical } from "lucide-react";
import {
  type PointerEvent,
  type ReactNode,
  type RefObject,
  useId,
  useLayoutEffect,
  useRef,
  useState,
  useSyncExternalStore,
} from "react";
import { StatusFooter } from "../../components/StatusFooter";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "../../components/ui/tabs";
import { cn } from "../../lib/utils";
import { AdaptersPanel } from "../panels/AdaptersPanel";
import { CompatPanel } from "../panels/CompatPanel";
import { InspectorPanel } from "../panels/InspectorPanel";
import { LogsPanel } from "../panels/LogsPanel";
import { NetworkPanel } from "../panels/NetworkPanel";
import { DeviceHeader, type DeviceHeaderProps, type Dock } from "./DeviceHeader";
import { DeviceToolbar, type DeviceToolbarInfo } from "./DeviceToolbar";
import { AndroidFrame, FRAME_SIZE, HardwareButtons, IPhoneFrame, type Platform } from "./frames";
import { TabBarContext } from "./tabBar";

export type PanelId = "logs" | "network" | "inspector" | "adapters" | "compat";
/** Binaries and Previews are links to their full pages, not panels. */
export type TabId = PanelId | "binaries" | "previews";

export interface PanelTab {
  id: TabId;
  /** A muted count after the label, e.g. "12.4k". */
  count?: string;
  /** A warning pill, e.g. the 7 APIs Compatibility found. */
  warnings?: number;
  /** A primary dot: the panel has something new. */
  dot?: boolean;
}

export interface DeviceWorkspaceProps extends DeviceHeaderProps {
  platform: Platform;
  /** The strip under the header, e.g. a dropped-connection notice. */
  banner?: ReactNode;
  /** The bar above the device; none without it. */
  toolbar?: DeviceToolbarInfo;
  /** What the phone's screen shows. */
  screen: ReactNode;
  /** Cards beside the phone. */
  stageAside?: ReactNode;
  hardwareButtons?: boolean;
  /** Where the tools panel starts; the header toggles it. Under 768 px it's always at the bottom. */
  dock?: Dock;
  /** The panel's starting width when docked right, 500 px by default. */
  panelWidth?: number;
  tabs: PanelTab[];
  /** The tab that starts active; the first panel tab by default. */
  defaultTab?: PanelId;
  /** The active tab, when the scenario opens tabs itself (e.g. a "See all in Compatibility" link); pair it with `onTabChange`. */
  tab?: PanelId;
  onTabChange?: (tab: PanelId) => void;
  /** Replaces what a tab shows; by default it's the panel from `device/panels`. */
  panels?: Partial<Record<PanelId, ReactNode>>;
  /** A PanelStates state (`empty`, `loading`, `error`…) for the starting tab's default panel. */
  panelState?: string;
  /** The status bar; none without it, as in the Adapters artboard. */
  footer?: {
    status: string;
    /** The status dot. */
    tone?: "success" | "warning" | "link";
    items?: ReactNode[];
    /** Right-aligned, e.g. "irisrun · localhost:7420". */
    end?: ReactNode;
  };
}

const TAB_LABELS: Record<TabId, string> = {
  logs: "Logs",
  network: "Network",
  inspector: "Inspector",
  adapters: "Adapters",
  compat: "Compatibility",
  binaries: "Binaries",
  previews: "Previews",
};
const TAB_LINKS = { binaries: "/binaries", previews: "/previews" } as const;
const PANELS: Record<PanelId, (props: { state?: string }) => ReactNode> = {
  logs: LogsPanel,
  network: NetworkPanel,
  inspector: InspectorPanel,
  adapters: AdaptersPanel,
  compat: CompatPanel,
};
const isPanel = (id: string): id is PanelId => id in PANELS;
const DOTS = { success: "bg-success", warning: "bg-warning", link: "bg-link" };

/** The Device UI: header, device stage, resizable tools panel and status bar. Scenarios fill it with mock data. */
export function DeviceWorkspace({
  platform,
  banner,
  toolbar,
  screen,
  stageAside,
  hardwareButtons = true,
  panelWidth = 500,
  tabs,
  defaultTab = tabs.map(({ id }) => id).find(isPanel),
  tab,
  onTabChange,
  panels,
  panelState,
  footer,
  ...header
}: DeviceWorkspaceProps) {
  const [chosenDock, setDock] = useState<Dock>(header.dock ?? "right");
  const dock = useNarrow() ? "bottom" : chosenDock;
  const [sizes, setSizes] = useState<Record<Dock, number>>({ right: panelWidth, bottom: 260 });
  const [startTab] = useState(tab ?? defaultTab);
  const [ownTab, setOwnTab] = useState(startTab);
  const active = tab ?? ownTab;
  const [tabBar, setTabBar] = useState<HTMLElement | null>(null);
  const stage = useRef<HTMLDivElement>(null);
  const scale = useFitScale(stage, FRAME_SIZE[platform]);
  const panelId = useId();
  const right = dock === "right";
  const Frame = platform === "ios" ? IPhoneFrame : AndroidFrame;

  return (
    <div className="flex h-dvh flex-col bg-background text-foreground">
      <DeviceHeader {...header} dock={dock} onDock={setDock} />
      {banner}
      <main className={cn("flex min-h-0 flex-1", !right && "flex-col")}>
        <section aria-label="Device" className="flex min-h-0 min-w-0 flex-1 flex-col bg-stage-grid">
          {toolbar && <DeviceToolbar platform={platform} {...toolbar} />}
          <div ref={stage} className="flex min-h-0 flex-1 items-center justify-center gap-4 overflow-hidden p-6">
            <div style={{ zoom: scale }}>
              <Frame>{screen}</Frame>
            </div>
            {hardwareButtons && <HardwareButtons platform={platform} />}
            {stageAside}
          </div>
        </section>
        <Resizer
          dock={dock}
          size={sizes[dock]}
          onSize={(size) => setSizes({ ...sizes, [dock]: size })}
          controls={panelId}
        />
        <aside
          id={panelId}
          aria-label="Tools panel"
          style={right ? { width: sizes.right } : { height: sizes.bottom }}
          className={cn(
            "flex min-h-0 min-w-0 shrink-0 flex-col bg-background",
            right ? "max-w-[calc(100%-360px)]" : "max-h-[calc(100%-160px)]",
          )}
        >
          <Tabs
            value={active}
            onValueChange={(value) => {
              if (!isPanel(value)) return;
              setOwnTab(value);
              onTabChange?.(value);
            }}
            className="flex min-h-0 flex-1 flex-col"
          >
            <div className={cn("flex flex-wrap items-center gap-2 border-b px-3", right ? "py-2" : "py-1.5")}>
              {/* Its height follows the tabs, so the tabs can wrap on a narrow screen. */}
              <TabsList aria-label="Panels" className="h-auto max-w-full flex-wrap">
                {tabs.map(({ id, count, warnings, dot }) => {
                  const label = (
                    <>
                      {TAB_LABELS[id]}
                      {count && <span className="text-[11px] text-muted-foreground">{count}</span>}
                      {warnings !== undefined && (
                        <span className="inline-flex h-[18px] min-w-[18px] items-center justify-center rounded-[9px] bg-warning/16 px-[5px] text-[11px] text-warning">
                          {warnings}
                        </span>
                      )}
                      {dot && <span className="size-1.5 rounded-full bg-primary" />}
                    </>
                  );
                  // The design pads tabs 9 px when there are six, and in cloud and real-device sessions.
                  const tight = tabs.length > 5 || header.target !== "local";
                  const className = cn(!right && "h-6 rounded-[5px]", tight && "px-[9px]");
                  return isPanel(id) ? (
                    <TabsTrigger key={id} value={id} className={className}>
                      {label}
                    </TabsTrigger>
                  ) : (
                    <TabsTrigger key={id} value={id} asChild className={className}>
                      <Link to={TAB_LINKS[id]}>{label}</Link>
                    </TabsTrigger>
                  );
                })}
              </TabsList>
              {/* Wraps to a line of its own when the tabs leave too little room. */}
              <div ref={setTabBar} className="flex min-w-0 flex-auto items-center gap-2 empty:hidden" />
            </div>
            <TabBarContext value={tabBar}>
              {tabs.map(({ id }) => {
                if (!isPanel(id)) return null;
                const Panel = PANELS[id];
                return (
                  // A panel squeezed below its minimum is clipped, not drawn over the status bar.
                  <TabsContent key={id} value={id} className="flex min-h-0 flex-1 flex-col overflow-hidden">
                    {panels?.[id] ?? <Panel state={id === startTab ? panelState : undefined} />}
                  </TabsContent>
                );
              })}
            </TabBarContext>
          </Tabs>
        </aside>
      </main>
      {footer && (
        <StatusFooter>
          <span className="inline-flex items-center gap-1.5">
            <span className={cn("size-1.5 rounded-full", DOTS[footer.tone ?? "success"])} />
            {footer.status}
          </span>
          {footer.items?.map((item, index) => (
            <span key={index}>{item}</span>
          ))}
          <span className="flex-1" />
          {footer.end}
        </StatusFooter>
      )}
    </div>
  );
}

const subscribeResize = (onChange: () => void) => {
  window.addEventListener("resize", onChange);
  return () => window.removeEventListener("resize", onChange);
};

/** Under 768 px, Tailwind's `md`, where a panel docked right would squeeze the stage. */
function useNarrow() {
  return useSyncExternalStore(subscribeResize, () => window.innerWidth < 768, () => false);
}

/**
 * The largest scale, up to 1, at which the stage's first child (the frame) fits
 * its content box beside the other children, which sit 16 px apart.
 */
function useFitScale(ref: RefObject<HTMLElement | null>, { width, height }: { width: number; height: number }) {
  const [scale, setScale] = useState(1);
  useLayoutEffect(() => {
    const stage = ref.current;
    // jsdom, which the smoke test runs in, has no ResizeObserver.
    if (!stage || typeof ResizeObserver === "undefined") return;
    const observer = new ResizeObserver(([entry]) => {
      if (!entry) return;
      const beside = [...stage.children].slice(1).reduce((sum, child) => sum + child.getBoundingClientRect().width + 16, 0);
      setScale(Math.min(1, entry.contentRect.height / height, (entry.contentRect.width - beside) / width));
    });
    observer.observe(stage);
    return () => observer.disconnect();
  }, [ref, width, height]);
  return scale;
}

const LIMITS: Record<Dock, [min: number, max: number]> = { right: [320, 960], bottom: [160, 560] };
/** What the stage keeps beside the panel, as the panel's max-w and max-h classes leave it. */
const STAGE_MIN: Record<Dock, number> = { right: 360, bottom: 160 };
const STEPS: Record<Dock, Record<string, number>> = {
  right: { ArrowLeft: 16, ArrowRight: -16 },
  bottom: { ArrowUp: 16, ArrowDown: -16 },
};

/** The line between the stage and the panel: drag it or use the arrow keys to resize the panel. */
function Resizer({ dock, size, onSize, controls }: { dock: Dock; size: number; onSize: (size: number) => void; controls: string }) {
  const drag = useRef<{ from: number; size: number } | null>(null);
  const right = dock === "right";
  const [min, max] = LIMITS[dock];
  const at = (event: PointerEvent) => (right ? event.clientX : event.clientY);
  const extent = (box?: DOMRect) => box && (right ? box.width : box.height);
  // Resizing starts from the size the panel renders at and stops where the stage's minimum caps it,
  // so no part of a drag goes unseen on a small window.
  const rendered = () => extent(document.getElementById(controls)?.getBoundingClientRect()) ?? size;
  const resize = (separator: Element, next: number) => {
    const main = extent(separator.parentElement?.getBoundingClientRect());
    const room = main === undefined ? max : Math.min(max, main - STAGE_MIN[dock]);
    onSize(Math.round(Math.max(min, Math.min(room, next))));
  };
  return (
    <div
      role="separator"
      aria-orientation={right ? "vertical" : "horizontal"}
      aria-label="Resize panel"
      aria-controls={controls}
      aria-valuenow={size}
      aria-valuemin={min}
      aria-valuemax={max}
      tabIndex={0}
      onPointerDown={(event) => {
        event.preventDefault();
        event.currentTarget.setPointerCapture(event.pointerId);
        drag.current = { from: at(event), size: rendered() };
      }}
      onPointerMove={(event) => drag.current && resize(event.currentTarget, drag.current.size + drag.current.from - at(event))}
      onPointerUp={() => (drag.current = null)}
      onKeyDown={(event) => {
        const step = STEPS[dock][event.key];
        if (!step) return;
        event.preventDefault();
        resize(event.currentTarget, rendered() + step);
      }}
      className={cn(
        "relative z-10 flex shrink-0 touch-none items-center justify-center bg-border before:absolute",
        right ? "w-px cursor-col-resize before:-inset-x-1 before:inset-y-0" : "h-px cursor-row-resize before:inset-x-0 before:-inset-y-1",
      )}
    >
      <span
        className={cn(
          "relative flex items-center justify-center rounded-[3px] border bg-border text-muted-foreground",
          right ? "h-[18px] w-3" : "h-3 w-[18px]",
        )}
      >
        {right ? <GripVertical className="size-2.5" /> : <GripHorizontal className="size-2.5" />}
      </span>
    </div>
  );
}
