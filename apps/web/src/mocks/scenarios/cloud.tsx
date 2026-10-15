import { TriangleAlert } from "lucide-react";
import { LogsPanel } from "../../device/panels/LogsPanel";
import { DeviceWorkspace, type PanelTab } from "../../device/shell/DeviceWorkspace";
import { cloudLogs, cloudSession, reconnectingLogs } from "../device/cloud";
import { AndroidHomeReconnecting } from "../screens/AndroidHomeReconnecting";
import { IosLookAround } from "../screens/IosLookAround";
import type { Scenario } from "./types";

const TABS: PanelTab[] = [{ id: "logs" }, { id: "network" }, { id: "inspector" }, { id: "adapters" }];

export const cloudScenarios: Scenario[] = [
  {
    id: "cloud-session",
    title: "Cloud · Session running",
    artboard: "CloudSession",
    render: () => (
      <DeviceWorkspace
        platform="ios"
        project={{ name: "kedai-ios", detail: "Kedai · Debug" }}
        status="running"
        target="cloud"
        remote={cloudSession}
        toolbar={{
          device: "iPhone 15 Pro",
          os: "iOS 18.0 · cloud simulator",
          language: "en-US",
          textSize: "Large",
          note: "Continued from local · state reset",
        }}
        screen={<IosLookAround />}
        hardwareButtons={false}
        tabs={TABS}
        panels={{ logs: <LogsPanel variant="compact" logs={cloudLogs} tagWidth={120} /> }}
        footer={{
          status: "Cloud · sg-m2-01 · ap-southeast-1",
          items: ["Session ses_7f2c91"],
          end: "Acme Mobile · 88 of 200 cloud hours this cycle",
        }}
      />
    ),
  },
  {
    id: "cloud-reconnecting",
    title: "Cloud · Reconnecting",
    artboard: "CloudReconnecting",
    render: () => (
      <DeviceWorkspace
        platform="android"
        project={{ name: "kedai-android", detail: "app · debug" }}
        status="reconnecting"
        target="device"
        remote={{ region: "Jakarta", endsIn: "12:40" }}
        banner={
          <div
            role="status"
            className="flex flex-wrap items-center gap-2.5 border-b border-[color-mix(in_srgb,var(--warning)_35%,var(--border))] bg-[color-mix(in_srgb,var(--warning)_8%,var(--background))] px-3.5 py-2 text-[12.5px]"
          >
            <TriangleAlert aria-hidden="true" className="size-[15px] text-warning" />
            <span className="font-medium">Connection to the device dropped.</span>
            <span className="text-muted-foreground">
              Taps and keys are paused. Logs are buffered on the device and will catch up.
            </span>
            <span className="flex-1" />
            <span className="text-muted-foreground">Attempt 3 · next try in 4 s</span>
          </div>
        }
        screen={<AndroidHomeReconnecting />}
        hardwareButtons={false}
        tabs={TABS}
        panels={{ logs: <LogsPanel variant="compact" logs={reconnectingLogs} tagWidth={112} /> }}
        footer={{
          status: "Real device · Samsung Galaxy A55 · Android 14 · Jakarta",
          tone: "warning",
          items: ["Session ses_91ab3e"],
          end: "Offline for 0:17",
        }}
      />
    ),
  },
];
