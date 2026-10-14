import { useEffect, useRef, useState } from "react";
import { ImageFormat, type Frame } from "../gen/irisrun/device/v1alpha1/frame_pb";
import type { HostPayload } from "./connection";
import { input, KeyAction, keyInput, Touches, TouchPhase } from "./input";

const MIME_TYPES: Partial<Record<ImageFormat, string>> = {
  [ImageFormat.PNG]: "image/png",
  [ImageFormat.JPEG]: "image/jpeg",
  [ImageFormat.WEBP]: "image/webp",
};

interface Props {
  send(payload: HostPayload): void;
  /** Registers the sink for frames, which bypass React state. */
  subscribeFrames(sink: (frame: Frame) => void): () => void;
}

/**
 * The device's screen: draws frames on a canvas and turns the mouse into
 * touches. A hidden textarea takes keyboard focus, so the browser's input
 * method composes text (Vietnamese Telex, pinyin, kana…) before it is sent.
 */
export function Screen({ send, subscribeFrames }: Props) {
  const canvas = useRef<HTMLCanvasElement>(null);
  const textarea = useRef<HTMLTextAreaElement>(null);
  const touches = useRef(new Touches());
  const fps = useFrames(canvas, subscribeFrames);

  const touch = (event: React.PointerEvent<HTMLCanvasElement>, phase: TouchPhase) => {
    const target = event.currentTarget;
    if (phase !== TouchPhase.BEGAN && !touches.current.has(event.pointerId)) return;
    const rect = target.getBoundingClientRect();
    const x = ((event.clientX - rect.left) * target.width) / rect.width;
    const y = ((event.clientY - rect.top) * target.height) / rect.height;
    send(touches.current.update(event.pointerId, phase, x, y));
  };

  const text = (edit: "commitText" | "setComposingText", value: string) =>
    send(input({ case: "text", value: { edit: { case: edit, value } } }));

  return (
    <div className="screen">
      <canvas
        ref={canvas}
        onPointerDown={(event) => {
          event.currentTarget.setPointerCapture(event.pointerId);
          // Keep focus on the textarea so typing reaches the device.
          event.preventDefault();
          textarea.current?.focus();
          touch(event, TouchPhase.BEGAN);
        }}
        onPointerMove={(event) => touch(event, TouchPhase.MOVED)}
        onPointerUp={(event) => touch(event, TouchPhase.ENDED)}
        onPointerCancel={(event) => touch(event, TouchPhase.CANCELLED)}
      />
      <textarea
        ref={textarea}
        className="ime"
        aria-label="Type on the device"
        autoCapitalize="off"
        autoComplete="off"
        spellCheck={false}
        onKeyDown={(event) => {
          const key = keyInput(event.nativeEvent, KeyAction.DOWN);
          if (!key) return;
          event.preventDefault();
          send(key);
        }}
        onKeyUp={(event) => {
          const key = keyInput(event.nativeEvent, KeyAction.UP);
          if (key) send(key);
        }}
        onCompositionUpdate={(event) => text("setComposingText", event.data)}
        onCompositionEnd={(event) => {
          text("commitText", event.data);
          event.currentTarget.value = "";
        }}
        onInput={(event) => {
          const native = event.nativeEvent as InputEvent;
          if (native.isComposing) return;
          // Typed or pasted text; input methods that type by sending
          // backspaces and new letters (Unikey) arrive here and as keys.
          const value = event.currentTarget.value;
          if (value) text("commitText", value);
          event.currentTarget.value = "";
        }}
      />
      <span className="fps">{fps} fps</span>
    </div>
  );
}

/** Draws incoming frames, newest first, and counts them per second. */
function useFrames(
  canvas: React.RefObject<HTMLCanvasElement | null>,
  subscribeFrames: Props["subscribeFrames"],
): number {
  const [fps, setFps] = useState(0);
  useEffect(() => {
    // Counts frames as they arrive, not by frame.sequence, which starts over
    // when the device restarts.
    let received = 0;
    let drawn = 0;
    let count = 0;
    const timer = setInterval(() => {
      setFps(count);
      count = 0;
    }, 1000);
    const unsubscribe = subscribeFrames(async (frame) => {
      const index = ++received;
      const bitmap = await createImageBitmap(new Blob([frame.data as BlobPart], { type: MIME_TYPES[frame.format] }));
      // Decoding finishes out of order; never draw over a newer frame.
      const target = canvas.current;
      if (index > drawn && target) {
        drawn = index;
        count++;
        if (target.width !== bitmap.width || target.height !== bitmap.height) {
          target.width = bitmap.width;
          target.height = bitmap.height;
        }
        target.getContext("2d")?.drawImage(bitmap, 0, 0);
      }
      bitmap.close();
    });
    return () => {
      clearInterval(timer);
      unsubscribe();
    };
  }, [canvas, subscribeFrames]);
  return fps;
}
