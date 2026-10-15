import { createContext, type ReactNode, useContext } from "react";
import { createPortal } from "react-dom";

/** The spot after the tabs in the tools panel's tab bar; null until it mounts. */
export const TabBarContext = createContext<HTMLElement | null>(null);

/** Puts its children in the tools panel's tab bar, after the tabs: a compact toolbar or a loading note. */
export function TabBarSlot({ children }: { children: ReactNode }) {
  const target = useContext(TabBarContext);
  return target && createPortal(children, target);
}
