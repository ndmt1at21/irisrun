import type { LogRow } from "./logs";

/** What the local runtime does when the app calls an API it doesn't have. */
export type CompatBehavior = "pause" | "stub" | "ignore";

/** An API the app calls that the local iOS runtime doesn't have yet. */
export interface UnsupportedApi {
  api: string;
  framework: string;
  behavior: CompatBehavior;
  /** Why it behaves this way. */
  note: string;
  /** Every call in the app, the first one leading. */
  sites: { file: string; code: string }[];
}

export interface CompatReport {
  apis: UnsupportedApi[];
  /** Swift files the scan read. */
  files: number;
  scanned: string;
}

/** Kedai on iOS, from the IosCompat artboard. */
export const kedaiCompat: CompatReport = {
  files: 214,
  scanned: "12s ago",
  apis: [
    {
      api: "MKLookAroundSceneRequest(coordinate:)",
      framework: "MapKit",
      behavior: "pause",
      note: "Look Around needs Apple map services that only a full simulator has. Iris pauses the app here and offers a cloud simulator.",
      sites: [
        { file: "StoreLocatorView.swift:57", code: "let request = MKLookAroundSceneRequest(coordinate: store.coordinate)" },
        { file: "StoreLocatorView.swift:58", code: "scene = try await request.scene" },
        { file: "StoreDetailSheet.swift:33", code: "LookAroundPreview(initialScene: scene)" },
      ],
    },
    {
      api: "Activity.request(attributes:content:)",
      framework: "ActivityKit",
      behavior: "pause",
      note: "Live Activities need the system’s ActivityKit services, which only a full simulator has. Iris pauses the app here and offers a cloud simulator.",
      sites: [{ file: "OrderTracker.swift:52", code: "activity = try Activity.request(attributes: attributes, content: content)" }],
    },
    {
      api: "DCAppAttestService.attestKey(_:…)",
      framework: "DeviceCheck",
      behavior: "stub",
      note: "App Attest needs a Secure Enclave. The stub reports it as unsupported, as an older device would, so your fallback runs.",
      sites: [
        { file: "CheckoutGuard.swift:48", code: "try await DCAppAttestService.shared.attestKey(keyID, clientDataHash: hash)" },
        { file: "CheckoutGuard.swift:31", code: "guard DCAppAttestService.shared.isSupported else { return .skip }" },
      ],
    },
    {
      api: "SFSpeechRecognizer.requestAuthorization",
      framework: "Speech",
      behavior: "stub",
      note: "There’s no speech recognition locally. The stub answers .denied, so the app hides voice search.",
      sites: [{ file: "VoiceSearch.swift:30", code: "SFSpeechRecognizer.requestAuthorization { status in" }],
    },
    {
      api: "CNContactStore.requestAccess(for:)",
      framework: "Contacts",
      behavior: "stub",
      note: "There’s no address book locally. The stub denies access, so the app shows its empty state.",
      sites: [{ file: "InviteFriendsView.swift:22", code: "let granted = try await store.requestAccess(for: .contacts)" }],
    },
    {
      api: "WidgetCenter.shared.reloadAllTimelines()",
      framework: "WidgetKit",
      behavior: "ignore",
      note: "There are no widgets to refresh locally, so the call does nothing. Try your widgets on a cloud simulator.",
      sites: [
        { file: "CartStore.swift:91", code: "WidgetCenter.shared.reloadAllTimelines()" },
        { file: "CartStore.swift:118", code: "WidgetCenter.shared.reloadAllTimelines()" },
        { file: "OrderStore.swift:40", code: "WidgetCenter.shared.reloadAllTimelines()" },
        { file: "SettingsView.swift:77", code: "WidgetCenter.shared.reloadAllTimelines()" },
      ],
    },
    {
      api: "UIApplication.setAlternateIconName(_:)",
      framework: "UIKit",
      behavior: "ignore",
      note: "The local runtime has no home screen, so the icon stays the same. The call still finishes without an error.",
      sites: [{ file: "AppIconPicker.swift:18", code: "try await UIApplication.shared.setAlternateIconName(icon.assetName)" }],
    },
  ],
};

/** Where the app paused: the call it made that the local runtime can't run. */
export interface PausedCall {
  api: string;
  framework: string;
  site: string;
  /** The API's feature as people know it, e.g. "Look Around". */
  feature: string;
}

/** The IosUnsupported artboard: Kedai paused at Look Around. */
export const lookAroundPause: PausedCall = {
  api: "MKLookAroundSceneRequest",
  framework: "MapKit",
  site: "StoreLocatorView.swift:57",
  feature: "Look Around",
};

/** The log up to the pause, from the IosUnsupported artboard. */
export const pausedLogs: LogRow[] = [
  { time: "21:06:51.204", level: "D", tag: "com.kedai.app · Network", message: "GET /v2/products/p_1042 → 200 (182 ms)" },
  { time: "21:06:51.390", level: "I", tag: "com.kedai.app · Detail", message: "ProductDetailView appeared · product=p_1042" },
  { time: "21:06:55.872", level: "D", tag: "com.kedai.app · Analytics", message: "event=view_item item_id=p_1042" },
  { time: "21:07:02.114", level: "I", tag: "com.kedai.app · Stores", message: "Tapped “Look Around” · store=Nguyen Hue" },
  { time: "21:07:02.131", level: "D", tag: "com.kedai.app · Stores", message: "Requesting Look Around scene…" },
  {
    time: "21:07:02.140",
    level: "P",
    tag: "iris",
    message: "Paused · MKLookAroundSceneRequest isn’t in the local runtime yet (StoreLocatorView.swift:57) — run on cloud or stub it",
  },
  { time: "21:07:02.141", level: "I", tag: "iris", message: "App state kept · memory 148 MB · 2 tasks suspended" },
];
