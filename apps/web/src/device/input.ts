import { create, type MessageInitShape } from "@bufbuild/protobuf";
import {
  type InputSchema,
  KeyAction,
  TouchPhase,
  type TouchPoint,
  TouchPointSchema,
} from "../gen/irisrun/device/v1alpha1/input_pb";
import type { HostPayload } from "./connection";

type InputEvent = MessageInitShape<typeof InputSchema>["event"];

export function input(event: InputEvent): HostPayload {
  return { case: "input", value: { event } };
}

/**
 * The touches on screen, keyed by browser pointer ID. Android allows pointer
 * IDs 0–31, so each pointer gets the lowest free small ID.
 */
export class Touches {
  readonly #active = new Map<number, TouchPoint>();

  /** Updates one pointer and returns every touch, ready to send. */
  update(pointerId: number, phase: TouchPhase, x: number, y: number): HostPayload {
    let touch = this.#active.get(pointerId);
    if (!touch) {
      const used = new Set([...this.#active.values()].map((t) => t.id));
      let id = 0;
      while (used.has(id)) id++;
      touch = create(TouchPointSchema, { id });
      this.#active.set(pointerId, touch);
    }
    for (const other of this.#active.values()) other.phase = TouchPhase.STATIONARY;
    Object.assign(touch, { phase, x, y });

    const touches = [...this.#active.values()].map((t) => ({ ...t }));
    if (phase === TouchPhase.ENDED || phase === TouchPhase.CANCELLED) this.#active.delete(pointerId);
    return input({ case: "touch", value: { touches } });
  }

  has(pointerId: number): boolean {
    return this.#active.has(pointerId);
  }
}

/** Keys the device gets as key presses; everything else arrives as text. */
const DEVICE_KEYS = new Set([
  "Enter",
  "NumpadEnter",
  "Backspace",
  "Delete",
  "Tab",
  "Escape",
  "ArrowLeft",
  "ArrowRight",
  "ArrowUp",
  "ArrowDown",
  "Home",
  "End",
]);

/**
 * The key press to send for a keyboard event, or undefined when the event
 * belongs to text input. Keys pressed while an input method composes belong
 * to the input method, such as Enter confirming a Japanese conversion.
 */
export function keyInput(
  event: Pick<KeyboardEvent, "code" | "isComposing" | "keyCode" | "shiftKey" | "ctrlKey" | "altKey" | "metaKey">,
  action: KeyAction,
): HostPayload | undefined {
  if (event.isComposing || event.keyCode === 229) return undefined;
  if (!DEVICE_KEYS.has(event.code) && !event.ctrlKey && !event.metaKey) return undefined;
  return input({
    case: "key",
    value: {
      action,
      code: event.code,
      shift: event.shiftKey,
      control: event.ctrlKey,
      alt: event.altKey,
      meta: event.metaKey,
    },
  });
}

export { KeyAction, TouchPhase };
