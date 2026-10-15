/** A step of the organization setup. */
export interface SetupStep {
  status: "done" | "now" | "next";
  title: string;
  detail: string;
}

export const setupSteps: SetupStep[] = [
  { status: "done", title: "Create organization", detail: "Acme Mobile · Singapore data region" },
  { status: "now", title: "Choose where apps run", detail: "Mac host for iOS, devices for Android" },
  { status: "next", title: "Open your first session", detail: "From the browser or irisrun" },
];

/** An Android cloud device the team can pick; `selected` is the suggested choice. */
export interface DeviceChoice {
  name: string;
  detail: string;
  type: "Real" | "Virtual";
  selected: boolean;
}

export const deviceChoices: DeviceChoice[] = [
  { name: "Pixel 8", detail: "Android 14 · emulator · Singapore", type: "Virtual", selected: true },
  { name: "Samsung Galaxy A55", detail: "Android 14 · Jakarta", type: "Real", selected: true },
  { name: "Xiaomi Redmi Note 13", detail: "Android 14 · Ho Chi Minh City", type: "Real", selected: true },
  { name: "OPPO Reno11", detail: "Android 14 · Bangkok", type: "Real", selected: false },
  { name: "vivo V30", detail: "Android 14 · Mumbai", type: "Real", selected: false },
];
