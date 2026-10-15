// @vitest-environment jsdom
import { createMemoryHistory, RouterProvider } from "@tanstack/react-router";
import { cleanup, render, screen, within } from "@testing-library/react";
import { afterEach, describe, expect, it } from "vitest";
import { consoleEntries, deviceEntries, foundationEntries } from "./gallery/entries";
import { createAppRouter } from "./router";

afterEach(cleanup);

// jsdom has no scrolling; the router scrolls to the top on navigation.
window.scrollTo = () => {};

async function renderAt(href: string) {
  const router = createAppRouter(createMemoryHistory({ initialEntries: [href] }));
  await router.load();
  render(<RouterProvider router={router} />);
  return router;
}

// `/live` is left out: it opens a WebSocket to the CLI.
const hrefs = ["/screens", ...[...deviceEntries, ...consoleEntries, ...foundationEntries].map((entry) => entry.href)].filter(
  (href) => href !== "/live",
);

describe("every screen in the gallery", () => {
  it.each(hrefs)("renders %s", async (href) => {
    await renderAt(href);
    expect(screen.queryByText("Something went wrong")).toBeNull();
    expect(screen.queryByText("Page not found")).toBeNull();
    expect(screen.queryByText(/^No scenario called/)).toBeNull();
  });
});

describe("routing", () => {
  it("sends /console to the projects page", async () => {
    const router = await renderAt("/console");
    expect(router.state.location.pathname).toBe("/console/projects");
  });

  it("shows the not-found page for unknown paths", async () => {
    await renderAt("/nowhere");
    expect(screen.getByText("Page not found")).toBeTruthy();
  });

  it("marks the current Console page in the sidebar", async () => {
    await renderAt("/console/hosts/new");
    const sidebar = screen.getByRole("navigation", { name: "Console" });
    expect(within(sidebar).getByRole("link", { name: "Mac hosts" }).getAttribute("aria-current")).toBe("page");
  });
});
