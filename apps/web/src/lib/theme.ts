import { useSyncExternalStore } from "react";

export type Theme = "light" | "dark";

const listeners = new Set<() => void>();

// The class on <html> is the source of truth; index.html sets it before the
// first paint and the `.dark` rules in styles.css set color-scheme with it.
function readTheme(): Theme {
  return document.documentElement.classList.contains("dark") ? "dark" : "light";
}

function subscribe(listener: () => void) {
  listeners.add(listener);
  return () => {
    listeners.delete(listener);
  };
}

function applyTheme(theme: Theme) {
  document.documentElement.classList.toggle("dark", theme === "dark");
  try {
    localStorage.setItem("iris-theme", theme);
  } catch {
    // Storage can be blocked; the theme still applies to this page.
  }
  for (const listener of listeners) listener();
}

/** The current theme and a setter; calling the setter without a theme toggles it. */
export function useTheme(): [Theme, (theme?: Theme) => void] {
  const theme = useSyncExternalStore(subscribe, readTheme, (): Theme => "light");
  return [theme, (next = theme === "dark" ? "light" : "dark") => applyTheme(next)];
}
