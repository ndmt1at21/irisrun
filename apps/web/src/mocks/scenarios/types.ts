import type { ReactNode } from "react";

/** One state of the Device UI, picked on `/` with `?mock=<id>`. */
export interface Scenario {
  id: string;
  /** The artboard title, or its caption for the PanelStates artboard. */
  title: string;
  /** The design file the scenario reproduces, without `.dc.html`. */
  artboard: string;
  /** Rendered as a component, so it may call hooks. */
  render: () => ReactNode;
}
