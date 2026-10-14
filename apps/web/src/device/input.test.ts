import { describe, expect, it } from "vitest";
import { KeyAction, keyInput, Touches, TouchPhase } from "./input";

function touchesOf(payload: ReturnType<Touches["update"]>) {
  if (payload?.case !== "input" || payload.value.event?.case !== "touch") throw new Error("not a touch");
  return payload.value.event.value.touches ?? [];
}

describe("Touches", () => {
  it("gives pointers small IDs and marks unchanged ones stationary", () => {
    const touches = new Touches();
    touchesOf(touches.update(901, TouchPhase.BEGAN, 1, 2));
    const second = touchesOf(touches.update(17, TouchPhase.BEGAN, 3, 4));
    expect(second).toEqual([
      expect.objectContaining({ id: 0, phase: TouchPhase.STATIONARY, x: 1, y: 2 }),
      expect.objectContaining({ id: 1, phase: TouchPhase.BEGAN, x: 3, y: 4 }),
    ]);

    touchesOf(touches.update(901, TouchPhase.ENDED, 1, 2));
    expect(touches.has(901)).toBe(false);
    const third = touchesOf(touches.update(5, TouchPhase.BEGAN, 0, 0));
    expect(third.map((t) => t.id)).toEqual([1, 0]);
  });
});

describe("keyInput", () => {
  const key = (init: Partial<Parameters<typeof keyInput>[0]>) =>
    keyInput(
      { isComposing: false, keyCode: 0, shiftKey: false, ctrlKey: false, altKey: false, metaKey: false, code: "", ...init },
      KeyAction.DOWN,
    );

  it("sends editing keys and leaves text to the input method", () => {
    expect(key({ code: "Backspace" })?.case).toBe("input");
    expect(key({ code: "KeyA" })).toBeUndefined();
    expect(key({ code: "Enter", isComposing: true })).toBeUndefined();
    expect(key({ code: "KeyC", ctrlKey: true })?.case).toBe("input");
  });
});
