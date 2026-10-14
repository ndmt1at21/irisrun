import { AppState, DeviceKind, Platform } from "./gen/irisrun/device/v1alpha1/device_pb";
import { Button } from "./gen/irisrun/device/v1alpha1/input_pb";
import { LogLevel } from "./gen/irisrun/device/v1alpha1/log_pb";
import { deviceUrl } from "./device/connection";
import { input } from "./device/input";
import { Screen } from "./device/Screen";
import { useDevice } from "./device/useDevice";

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
  [AppState.UNSPECIFIED]: "Connecting",
  [AppState.LAUNCHING]: "Launching",
  [AppState.FOREGROUND]: "Running",
  [AppState.BACKGROUND]: "In background",
  [AppState.STOPPED]: "Stopped",
  [AppState.CRASHED]: "Crashed",
};

export function App() {
  const { state, send, subscribeFrames } = useDevice(deviceUrl(window.location));
  const { info, status } = state;
  const press = (button: Button) => send(input({ case: "button", value: { button } }));
  const appState = status?.state ?? AppState.UNSPECIFIED;

  return (
    <main className="app">
      <section className="device">
        <div className="bezel">
          <Screen send={send} subscribeFrames={subscribeFrames} />
          {appState === AppState.CRASHED || appState === AppState.STOPPED ? (
            <div className="overlay">
              <p>The app {appState === AppState.CRASHED ? "crashed" : "stopped"}.</p>
              <button type="button" onClick={() => send({ case: "appControl", value: { action: { case: "restart", value: {} } } })}>
                Restart
              </button>
            </div>
          ) : null}
        </div>
        <nav className="buttons" aria-label="Phone buttons">
          {info?.platform !== Platform.IOS && (
            <button type="button" onClick={() => press(Button.BACK)}>
              Back
            </button>
          )}
          <button type="button" onClick={() => press(Button.HOME)}>
            Home
          </button>
          <button type="button" onClick={() => press(Button.APP_SWITCH)}>
            Apps
          </button>
          <button type="button" onClick={() => send({ case: "appControl", value: { action: { case: "restart", value: {} } } })}>
            Restart
          </button>
        </nav>
      </section>

      <aside className="panel">
        <header>
          <h1>{status?.appId || "Iris"}</h1>
          <p>
            {state.connected ? STATES[appState] : "Disconnected"}
            {info && ` · ${info.model} · ${PLATFORMS[info.platform]} ${info.osVersion} · ${KINDS[info.kind]}`}
          </p>
        </header>
        {status?.crashReport ? <pre className="crash">{status.crashReport}</pre> : null}
        <div className="logs">
          <ol aria-label="Logs">
            {state.logs.map((log, index) => (
              <li key={index} className={`log level-${LogLevel[log.level].toLowerCase()}`}>
                <span className="tag">{log.tag}</span> {log.message}
              </li>
            ))}
          </ol>
        </div>
      </aside>
    </main>
  );
}
