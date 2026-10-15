// @vitest-environment jsdom
import { cleanup, fireEvent, render, screen } from "@testing-library/react";
import { afterEach, expect, it } from "vitest";
import { LogsPanel } from "./LogsPanel";

afterEach(cleanup);

const rows = () => [...screen.getByRole("log").children].filter((row) => row.getAttribute("role") !== "separator").length;

it("filters by text, /regex/ and level, keeping stack frames with their line", () => {
  render(<LogsPanel />);
  expect(rows()).toBe(26);

  const filter = screen.getByRole("searchbox", { name: "Filter logs" });
  fireEvent.change(filter, { target: { value: "okhttp" } });
  expect(rows()).toBe(10); // 7 OkHttp lines and the 3 frames of the failed one
  fireEvent.change(filter, { target: { value: "/cart size \\d/" } });
  expect(rows()).toBe(1);
  fireEvent.change(filter, { target: { value: "/[/" } });
  expect(rows()).toBe(0); // not a regex yet, so matched as text

  fireEvent.change(filter, { target: { value: "" } });
  fireEvent.click(screen.getByRole("button", { name: /^Error/ }));
  expect(rows()).toBe(22);
});
