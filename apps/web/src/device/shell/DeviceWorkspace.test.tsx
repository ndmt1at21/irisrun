// @vitest-environment jsdom
import { createMemoryHistory, RouterProvider } from "@tanstack/react-router";
import { cleanup, fireEvent, render, screen } from "@testing-library/react";
import { afterEach, expect, it } from "vitest";
import { createAppRouter } from "../../router";

afterEach(cleanup);

// jsdom has no scrolling; the router scrolls to the top on navigation.
window.scrollTo = () => {};

it.each([
  ["/?mock=ios-inspector", "7 APIs not in the local runtime"],
  ["/?mock=ios-paused", "See all 7 in Compatibility"],
])("%s: “%s” opens the Compatibility tab", async (href, link) => {
  const router = createAppRouter(createMemoryHistory({ initialEntries: [href] }));
  await router.load();
  render(<RouterProvider router={router} />);
  const compat = await screen.findByRole("tab", { name: /^Compatibility/ });
  expect(compat.getAttribute("aria-selected")).toBe("false");

  fireEvent.click(screen.getByRole("button", { name: link }));
  expect(compat.getAttribute("aria-selected")).toBe("true");
});
