import { create } from "@bufbuild/protobuf";
import { sizeDelimitedDecodeStream, sizeDelimitedEncode } from "@bufbuild/protobuf/wire";
import { describe, expect, it } from "vitest";
import { HostMessageSchema } from "./gen/irisrun/device/v1alpha1/device_pb";
import { TouchPhase } from "./gen/irisrun/device/v1alpha1/input_pb";

describe("device protocol", () => {
  it("round-trips size-delimited envelopes", async () => {
    const sent = [
      create(HostMessageSchema, {
        payload: {
          case: "input",
          value: {
            event: {
              case: "touch",
              value: { touches: [{ id: 1, phase: TouchPhase.BEGAN, x: 10.5, y: 20 }] },
            },
          },
        },
      }),
      create(HostMessageSchema, {
        payload: {
          case: "input",
          value: { event: { case: "text", value: { edit: { case: "commitText", value: "Tiếng Việt" } } } },
        },
      }),
    ];

    // One chunk holding every envelope, as a byte stream would deliver it.
    async function* stream() {
      yield new Uint8Array(sent.flatMap((m) => [...sizeDelimitedEncode(HostMessageSchema, m)]));
    }
    const received = [];
    for await (const message of sizeDelimitedDecodeStream(HostMessageSchema, stream())) {
      received.push(message);
    }

    expect(received).toEqual(sent);
  });
});
