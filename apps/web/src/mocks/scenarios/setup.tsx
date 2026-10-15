import { BuildFailedScreen } from "../../device/setup/BuildFailedScreen";
import { BuildScreen } from "../../device/setup/BuildScreen";
import { LicenseScreen } from "../../device/setup/LicenseScreen";
import { ToolchainScreen } from "../../device/setup/ToolchainScreen";
import type { Scenario } from "./types";

export const setupScenarios: Scenario[] = [
  { id: "setup-toolchain", title: "Preparing · Toolchain download", artboard: "PrepToolchain", render: ToolchainScreen },
  { id: "setup-license", title: "Preparing · Android SDK license", artboard: "PrepLicense", render: LicenseScreen },
  { id: "setup-build", title: "Preparing · Build steps", artboard: "PrepBuild", render: BuildScreen },
  { id: "setup-build-failed", title: "Preparing · Build failed", artboard: "PrepBuildFailed", render: BuildFailedScreen },
];
