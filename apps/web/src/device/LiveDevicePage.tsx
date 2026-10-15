import { Button } from "../components/ui/button";
import { AppState, DeviceKind, Platform } from "../gen/irisrun/device/v1alpha1/device_pb";
import { Button as PhoneButton } from "../gen/irisrun/device/v1alpha1/input_pb";
import { LogLevel } from "../gen/irisrun/device/v1alpha1/log_pb";
import { deviceUrl } from "./connection";
import { input } from "./input";
import { Screen } from "./Screen";
import { useDevice } from "./useDevice";
import { VideoScreen } from "./VideoScreen";

const PLATFORMS: Record<Platform, string> = {
  [Platform.UNSPECIFIED]: "Unknown OS",
  [Platform.ANDROID]: "Android",
  [Platform.IOS]: "iOS",
};

const KINDS: Record<DeviceKind, string> = {
  [DeviceKind.UNSPECIFIED]: "unknown device",
  [DeviceKind.LOCAL_RUNTIME]: "local runtime",
  [DeviceKind.EMULATOR]: "emulator",
  [DeviceKind.SIMULATOR]: "simulator",
  [DeviceKind.PHYSICAL]: "phone",
};

const STATES: Record<AppState, string> = {
  [AppState.UNSPECIFIED]: "Connected",
  [AppState.LAUNCHING]: "Launching",
  [AppState.FOREGROUND]: "Running",
  [AppState.BACKGROUND]: "In background",
  [AppState.STOPPED]: "Stopped",
  [AppState.CRASHED]: "Crashed",
};

const LEVEL_COLORS: Partial<Record<LogLevel, string>> = {
  [LogLevel.WARNING]: "text-warning",
  [LogLevel.ERROR]: "text-destructive",
  [LogLevel.FATAL]: "text-destructive",
};

/**
 * Route `/live`: the P0-12 Device UI, connected to the device of a running
 * `irisrun start`, or with `?gateway=<url>` to a cloud device of irisrun-gateway.
 */
export function LiveDevicePage() {
  const gateway = new URLSearchParams(window.location.hash.split("?")[1]).get("gateway");
  const { state, send, subscribeFrames } = useDevice(
    gateway ?? deviceUrl(window.location),
    gateway ? "webrtc" : "websocket",
  );
  const { info, status } = state;
  const press = (button: PhoneButton) => send(input({ case: "button", value: { button } }));
  const restart = () => send({ case: "appControl", value: { action: { case: "restart", value: {} } } });
  const appState = status?.state ?? AppState.UNSPECIFIED;

  return (
    <main className="flex h-screen gap-6 bg-stage-grid p-6">
      <section className="flex flex-col items-center gap-3">
        <div className="relative aspect-[1080/2424] h-[calc(100vh-120px)] rounded-[36px] bg-[#1b1b1f] p-3 shadow-[0_0_0_1px_#3a3a42]">
          {gateway ? (
            <VideoScreen stream={state.stream} send={send} />
          ) : (
            <Screen send={send} subscribeFrames={subscribeFrames} />
          )}
          {appState === AppState.CRASHED || appState === AppState.STOPPED ? (
            <div className="absolute inset-3 grid place-content-center gap-3 rounded-[26px] bg-black/70 text-center text-white">
              <p>The app {appState === AppState.CRASHED ? "crashed" : "stopped"}.</p>
              <Button onClick={restart}>Restart</Button>
            </div>
          ) : null}
        </div>
        <nav className="flex gap-2" aria-label="Phone buttons">
          {info?.platform !== Platform.IOS && (
            <Button variant="outline" className="bg-background" onClick={() => press(PhoneButton.BACK)}>
              Back
            </Button>
          )}
          <Button variant="outline" className="bg-background" onClick={() => press(PhoneButton.HOME)}>
            Home
          </Button>
          <Button variant="outline" className="bg-background" onClick={() => press(PhoneButton.APP_SWITCH)}>
            Apps
          </Button>
          <Button variant="outline" className="bg-background" onClick={restart}>
            Restart
          </Button>
        </nav>
      </section>

      <aside className="flex min-w-0 flex-1 flex-col overflow-hidden rounded-xl border bg-card">
        <header className="border-b px-4 py-3">
          <h1 className="text-base font-semibold">{status?.appId || "Iris"}</h1>
          <p className="mt-1 text-muted-foreground">
            {state.connected ? STATES[appState] : "Disconnected"}
            {info && ` · ${info.model} · ${PLATFORMS[info.platform]} ${info.osVersion} · ${KINDS[info.kind]}`}
          </p>
        </header>
        {status?.crashReport ? (
          <pre className="max-h-[30%] overflow-auto border-b px-4 py-3 font-mono text-xs text-destructive">
            {status.crashReport}
          </pre>
        ) : null}
        {/* column-reverse keeps the scroll position at the bottom, so the newest
            line stays in view until the reader scrolls up; mb-auto keeps a short log at the top. */}
        <div className="flex flex-1 flex-col-reverse overflow-auto">
          <ol aria-label="Logs" className="m-0 mb-auto px-4 py-2 font-mono text-xs leading-normal">
            {state.logs.map((log, index) => (
              <li key={index} className={LEVEL_COLORS[log.level]}>
                <span className="text-muted-foreground">{log.tag}</span> {log.message}
              </li>
            ))}
          </ol>
        </div>
      </aside>
    </main>
  );
}
