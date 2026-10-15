import { useState } from "react";
import { AdaptersPanel } from "../../device/panels/AdaptersPanel";
import { DeviceWorkspace } from "../../device/shell/DeviceWorkspace";
import type { PaymentResult } from "../device/adapters";
import { kedaiNetwork } from "../device/network";
import { AndroidProduct } from "../screens/AndroidProduct";
import { IosCheckout } from "../screens/IosCheckout";
import type { Scenario } from "./types";

/** AndroidNetwork: the product page after adding to cart, Network open; `panelState` is a PanelStates state. */
function AndroidNetwork({ panelState }: { panelState?: string }) {
  const empty = panelState === "empty";
  const { total, transferred, failed } = kedaiNetwork;
  return (
    <DeviceWorkspace
      platform="android"
      project={{ name: "kedai-android", detail: "app · debug" }}
      status="running"
      target="local"
      hotReload={{ state: "updated", detail: "1m ago" }}
      toolbar={{ device: "Pixel 8", os: "Android 14", language: "vi-VN", textSize: "Font 100%" }}
      screen={<AndroidProduct />}
      hardwareButtons={false}
      panelWidth={640}
      tabs={[
        { id: "logs" },
        { id: "network", count: empty ? undefined : String(total) },
        { id: "inspector" },
        { id: "adapters" },
        { id: "binaries" },
      ]}
      defaultTab="network"
      panelState={panelState}
      footer={{
        status: "Local · Android 14 runtime",
        items: [empty ? "0 requests" : `${total} requests · ${transferred} · ${failed} failed`],
        end: "irisrun · localhost:7420",
      }}
    />
  );
}

/** Adapters: Kedai's checkout waiting on a test payment; the sheet and the Payment adapter share the result. */
function IosAdapters({ panelState }: { panelState?: string }) {
  const [result, setResult] = useState<PaymentResult>("success");
  return (
    <DeviceWorkspace
      platform="ios"
      project={{ name: "kedai-ios", detail: "Kedai · Debug" }}
      status="running"
      target="local"
      hotReload={{ state: "updated", detail: "4m ago" }}
      screen={<IosCheckout result={result} onResult={setResult} />}
      hardwareButtons={false}
      panelWidth={780}
      tabs={[
        { id: "logs" },
        { id: "network" },
        { id: "inspector" },
        { id: "adapters", dot: true },
        { id: "previews" },
        { id: "compat", warnings: 7 },
      ]}
      defaultTab="adapters"
      panels={{ adapters: <AdaptersPanel state={panelState} result={result} onResult={setResult} /> }}
    />
  );
}

export const toolScenarios: Scenario[] = [
  {
    id: "android-network",
    title: "Android · Network detail",
    artboard: "AndroidNetwork",
    render: () => <AndroidNetwork />,
  },
  {
    id: "ios-adapters",
    title: "Adapters · Payment sheet",
    artboard: "Adapters",
    render: () => <IosAdapters />,
  },
  {
    id: "network-empty",
    title: "Network · Empty",
    artboard: "PanelStates",
    render: () => <AndroidNetwork panelState="empty" />,
  },
  {
    id: "network-no-results",
    title: "Network · No results for a filter",
    artboard: "PanelStates",
    render: () => <AndroidNetwork panelState="no-results" />,
  },
  {
    id: "adapters-camera-blocked",
    title: "Adapters · Camera blocked by browser",
    artboard: "PanelStates",
    render: () => <IosAdapters panelState="camera-blocked" />,
  },
];
