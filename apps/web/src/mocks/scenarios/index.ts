import { androidScenarios } from "./android";
import { cloudScenarios } from "./cloud";
import { iosScenarios } from "./ios";
import { setupScenarios } from "./setup";
import { toolScenarios } from "./tools";
import type { Scenario } from "./types";

export const scenarios: Scenario[] = [
  ...androidScenarios,
  ...setupScenarios,
  ...iosScenarios,
  ...toolScenarios,
  ...cloudScenarios,
];
