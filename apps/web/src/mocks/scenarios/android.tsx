import { DeviceWorkspace } from "../../device/shell/DeviceWorkspace";
import { AndroidHome } from "../screens/AndroidHome";
import type { Scenario } from "./types";

/** Main: Kedai running locally on a Pixel 8, Logs open; `panelState` puts the Logs panel in a PanelStates state. */
function AndroidRunning({ panelState }: { panelState?: string }) {
  return (
    <DeviceWorkspace
      platform="android"
      project={{ name: "kedai-android", detail: "app · debug" }}
      status="running"
      target="local"
      hotReload={{ state: "updated", detail: "CartViewModel.kt · 412 ms · 2s ago" }}
      recording="00:42"
      toolbar={{
        device: "Pixel 8",
        os: "Android 14 · API 34",
        language: "Tiếng Việt · vi-VN",
        textSize: "Font 100%",
        resolution: "1080 × 2400 · 420 dpi · 72%",
      }}
      screen={<AndroidHome />}
      tabs={[
        { id: "logs", count: panelState === "empty" || panelState === "loading" ? undefined : "12.4k" },
        { id: "network" },
        { id: "inspector" },
        { id: "adapters" },
        { id: "binaries" },
      ]}
      panelState={panelState}
      footer={{
        status: "Local · Android 14 runtime",
        items: ["Last build 18.4 s", "Native libs · 5 ok · 2 slow · 1 needs cloud"],
        end: "irisrun · localhost:7420",
      }}
    />
  );
}

export const androidScenarios: Scenario[] = [
  {
    id: "android-running",
    title: "Android · Running · Logs (dark)",
    artboard: "Main",
    render: () => <AndroidRunning />,
  },
  {
    id: "logs-empty",
    title: "Logs · Empty",
    artboard: "PanelStates",
    render: () => <AndroidRunning panelState="empty" />,
  },
  {
    id: "logs-loading",
    title: "Logs · Loading",
    artboard: "PanelStates",
    render: () => <AndroidRunning panelState="loading" />,
  },
  {
    id: "logs-error",
    title: "Logs · Stream error",
    artboard: "PanelStates",
    render: () => <AndroidRunning panelState="error" />,
  },
];
