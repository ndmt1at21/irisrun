// @vitest-environment jsdom
import { cleanup, fireEvent, render, screen, within } from "@testing-library/react";
import { afterEach, expect, it } from "vitest";
import { InspectorPanel } from "./InspectorPanel";

afterEach(cleanup);

const rows = () => screen.getAllByRole("treeitem").length;
const row = (name: RegExp) => screen.getByRole("treeitem", { name });

it("collapses, finds and walks the view tree", () => {
  render(<InspectorPanel />);
  expect(rows()).toBe(19);

  fireEvent.click(within(row(/^LazyVGrid/)).getByText("▾"));
  expect(rows()).toBe(12); // its 4 cards and the 3 children of the open one

  const find = screen.getByRole("searchbox", { name: "Find view" });
  fireEvent.change(find, { target: { value: "text" } });
  expect(rows()).toBe(24); // 10 Text and TextField views and their 14 ancestors
  fireEvent.change(find, { target: { value: "" } });
  expect(rows()).toBe(12);

  fireEvent.click(row(/^SearchField/));
  fireEvent.keyDown(row(/^SearchField/), { key: "ArrowDown" });
  expect(row(/^CategoryChips/).getAttribute("aria-selected")).toBe("true");
  fireEvent.keyDown(row(/^CategoryChips/), { key: "ArrowRight" });
  expect(rows()).toBe(17);
  fireEvent.keyDown(row(/^CategoryChips/), { key: "ArrowLeft" });
  expect(rows()).toBe(12);
  fireEvent.keyDown(row(/^CategoryChips/), { key: "ArrowLeft" });
  expect(row(/^VStack/).getAttribute("aria-selected")).toBe("true");
});
