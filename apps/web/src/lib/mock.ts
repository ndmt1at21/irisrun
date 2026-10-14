import { rootRouteId, useSearch } from "@tanstack/react-router";

/** The `?mock=` state a screen should show, e.g. `empty`, `loading` or a scenario ID. */
export function useMock(): string | undefined {
  return useSearch({ from: rootRouteId, select: (search) => search.mock });
}
