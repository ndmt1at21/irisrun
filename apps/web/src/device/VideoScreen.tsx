import { useEffect, useRef, useState } from "react";
import type { HostPayload } from "./connection";
import { input, KeyAction, keyInput, Touches, TouchPhase } from "./input";

interface Props {
  /** The cloud device's screen, from the gateway's video track. */
  stream?: MediaStream;
  send(payload: HostPayload): void;
}

/**
 * A cloud device's screen: plays the video track and turns the mouse into
 * touches in video pixels. As in Screen, a hidden textarea takes keyboard
 * focus so the input method composes text first; the cloud tier takes only
 * committed text so far.
 */
export function VideoScreen({ stream, send }: Props) {
  const video = useRef<HTMLVideoElement>(null);
  const textarea = useRef<HTMLTextAreaElement>(null);
  const touches = useRef(new Touches());
  const fps = useVideoFps(video);

  useEffect(() => {
    if (video.current) video.current.srcObject = stream ?? null;
  }, [stream]);

  const touch = (event: React.PointerEvent<HTMLVideoElement>, phase: TouchPhase) => {
    const target = event.currentTarget;
    const { videoWidth: width, videoHeight: height } = target;
    if (!width || (phase !== TouchPhase.BEGAN && !touches.current.has(event.pointerId))) return;
    // object-contain letterboxes the video inside the element.
    const rect = target.getBoundingClientRect();
    const scale = Math.min(rect.width / width, rect.height / height);
    const x = (event.clientX - rect.left - (rect.width - width * scale) / 2) / scale;
    const y = (event.clientY - rect.top - (rect.height - height * scale) / 2) / scale;
    send(touches.current.update(event.pointerId, phase, x, y));
  };

  const commit = (value: string) => send(input({ case: "text", value: { edit: { case: "commitText", value } } }));

  return (
    <div className="relative size-full overflow-hidden rounded-[26px] bg-black">
      <video
        ref={video}
        autoPlay
        muted
        playsInline
        className="block size-full cursor-pointer touch-none object-contain"
        onPointerDown={(event) => {
          event.currentTarget.setPointerCapture(event.pointerId);
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
        className="absolute bottom-0 left-0 size-px resize-none opacity-0"
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
        onCompositionEnd={(event) => {
          commit(event.data);
          event.currentTarget.value = "";
        }}
        onInput={(event) => {
          if ((event.nativeEvent as InputEvent).isComposing) return;
          const value = event.currentTarget.value;
          if (value) commit(value);
          event.currentTarget.value = "";
        }}
      />
      <span className="absolute top-2 right-2.5 rounded-md bg-black/50 px-1.5 py-0.5 font-mono text-[11px] text-white">
        {fps} fps
      </span>
    </div>
  );
}

/** Video frames presented per second. */
function useVideoFps(video: React.RefObject<HTMLVideoElement | null>): number {
  const [fps, setFps] = useState(0);
  useEffect(() => {
    const element = video.current;
    if (!element) return;
    let count = 0;
    let callback = 0;
    const onFrame = () => {
      count++;
      callback = element.requestVideoFrameCallback(onFrame);
    };
    callback = element.requestVideoFrameCallback(onFrame);
    const timer = setInterval(() => {
      setFps(count);
      count = 0;
    }, 1000);
    return () => {
      clearInterval(timer);
      element.cancelVideoFrameCallback(callback);
    };
  }, [video]);
  return fps;
}
