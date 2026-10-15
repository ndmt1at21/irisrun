// @vitest-environment jsdom
import { cleanup, fireEvent, render, screen } from "@testing-library/react";
import { afterEach, expect, it } from "vitest";
import { NetworkPanel } from "./NetworkPanel";

afterEach(cleanup);

const rows = () => screen.queryAllByRole("row").length - 1;

it("filters by URL, method, status and type, and colors the response JSON", () => {
  render(<NetworkPanel />);
  expect(rows()).toBe(10);
  expect(screen.getByText('"cartId"').className).toBe("text-link");
  expect(screen.getByText('"c_8f21a9"').className).toBe("text-success");
  expect(screen.getByText("648000").className).toBe("text-warning");
  expect(screen.getByText("null").className).toBe("text-muted-foreground");

  const filter = screen.getByRole("searchbox", { name: "Filter requests" });
  fireEvent.change(filter, { target: { value: "post" } });
  expect(rows()).toBe(3);
  fireEvent.change(filter, { target: { value: "failed" } });
  expect(rows()).toBe(1);
  expect(screen.queryByRole("button", { name: "Copy as cURL" })).toBeNull(); // the selected row is filtered out
  fireEvent.change(filter, { target: { value: "/checkout" } });
  expect(screen.getByText("No requests match “/checkout”")).toBeTruthy();

  fireEvent.click(screen.getByRole("button", { name: "Clear filter" }));
  fireEvent.click(screen.getByRole("radio", { name: "Images" }));
  expect(rows()).toBe(2);
});
