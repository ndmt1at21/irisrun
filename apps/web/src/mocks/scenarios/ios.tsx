import { Info } from "lucide-react";
import { useState } from "react";
import { Button } from "../../components/ui/button";
import { PausedCards, PausedDialog } from "../../device/ios/paused";
import { InspectorPanel, useViewSelection } from "../../device/panels/InspectorPanel";
import { LogsPanel } from "../../device/panels/LogsPanel";
import { DeviceWorkspace, type DeviceWorkspaceProps, type PanelId } from "../../device/shell/DeviceWorkspace";
import { kedaiCompat, lookAroundPause, pausedLogs } from "../device/compat";
import { kedaiViews } from "../device/inspector";
import { IosDiscover } from "../screens/IosDiscover";
import { IosProduct } from "../screens/IosProduct";
import { IosStorePaused } from "../screens/IosStorePaused";
import type { Scenario } from "./types";

const unsupported = kedaiCompat.apis.length;
const kedai = {
  platform: "ios",
  project: { name: "kedai-ios", detail: "Kedai · Debug" },
  target: "local",
  toolbar: { device: "iPhone 15 Pro", os: "iOS 18.0", language: "English · en-US", textSize: "Text size · Large" },
  tabs: [{ id: "logs" }, { id: "network" }, { id: "inspector" }, { id: "adapters" }, { id: "previews" }, { id: "compat", warnings: unsupported }],
} satisfies Partial<DeviceWorkspaceProps>;
const end = "irisrun · localhost:7420";

/** IosRunning: the Inspector on Kedai's Discover screen; `state` is an Inspector PanelStates state. */
function IosInspector({ state }: { state?: string }) {
  const selection = useViewSelection({ hovered: "search" });
  const [tab, setTab] = useState<PanelId>("inspector");
  // The selection is drawn on the screen while the Inspector is open.
  const live = !state && tab === "inspector";
  return (
    <DeviceWorkspace
      {...kedai}
      status="running"
      hotReload={{ state: "rebuilding", detail: "HomeView.swift", progress: 62 }}
      toolbar={{ ...kedai.toolbar, resolution: "393 × 852 pt · @3x · 82%" }}
      screen={
        <IosDiscover
          selected={live ? kedaiViews.find(({ id }) => id === selection.selected) : undefined}
          hovered={live ? selection.hovered : undefined}
        />
      }
      panelWidth={520}
      tab={tab}
      onTabChange={setTab}
      panels={{ inspector: <InspectorPanel state={state} selection={selection} /> }}
      footer={{
        status: "Local · iOS 18 runtime",
        items: [
          <Button variant="link" className="h-auto gap-1.5 p-0 text-[11px] font-normal text-warning" onClick={() => setTab("compat")}>
            <Info className="size-3" />
            {unsupported} APIs not in the local runtime
          </Button>,
          "Swift 6.0 · Debug",
        ],
        end,
      }}
    />
  );
}

/** IosCompat: the Compatibility report beside the product screen; `state` `all-clear` is its PanelStates state. */
function IosCompat({ state }: { state?: string }) {
  return (
    <DeviceWorkspace
      {...kedai}
      status="running"
      hotReload={{ state: "updated", detail: "ProductDetailView.swift · 18s ago" }}
      screen={<IosProduct />}
      hardwareButtons={false}
      panelWidth={760}
      tabs={state === "all-clear" ? kedai.tabs.map(({ id }) => ({ id })) : kedai.tabs}
      defaultTab="compat"
      panelState={state}
      footer={{ status: "Local · iOS 18 runtime", items: ["Swift 6.0 · Debug"], end }}
    />
  );
}

/** IosUnsupported: the app paused at Look Around, the Logs docked below. */
function IosPaused() {
  const [tab, setTab] = useState<PanelId>("logs");
  return (
    <DeviceWorkspace
      {...kedai}
      status="paused"
      hotReload={{ state: "updated", detail: "1m ago" }}
      screen={
        <>
          <IosStorePaused />
          <PausedDialog {...lookAroundPause} />
        </>
      }
      stageAside={
        <PausedCards feature={lookAroundPause.feature} unsupported={unsupported} onOpenCompat={() => setTab("compat")} />
      }
      hardwareButtons={false}
      dock="bottom"
      tab={tab}
      onTabChange={setTab}
      panels={{ logs: <LogsPanel variant="compact" logs={pausedLogs} /> }}
      footer={{ status: `Local · paused at ${lookAroundPause.site}`, tone: "link", items: ["Swift 6.0 · Debug"], end }}
    />
  );
}

export const iosScenarios: Scenario[] = [
  {
    id: "ios-inspector",
    title: "iOS · Running · Inspector (light)",
    artboard: "IosRunning",
    render: () => <IosInspector />,
  },
  {
    id: "ios-compat",
    title: "iOS · Compatibility report",
    artboard: "IosCompat",
    render: () => <IosCompat />,
  },
  {
    id: "ios-paused",
    title: "iOS · Paused at unsupported API",
    artboard: "IosUnsupported",
    render: () => <IosPaused />,
  },
  {
    id: "inspector-loading",
    title: "Inspector · Loading",
    artboard: "PanelStates",
    render: () => <IosInspector state="loading" />,
  },
  {
    id: "inspector-unavailable",
    title: "Inspector · Unavailable",
    artboard: "PanelStates",
    render: () => <IosInspector state="unavailable" />,
  },
  {
    id: "compat-all-clear",
    title: "Compatibility · All clear",
    artboard: "PanelStates",
    render: () => <IosCompat state="all-clear" />,
  },
];
