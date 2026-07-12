import { PassThrough } from "node:stream";
import assert from "node:assert/strict";
import test from "node:test";

import { createTtyInteractionPort } from "../src/interaction/index.js";

function readOutput(stream: PassThrough): string {
  const chunk = stream.read() as Buffer | string | null;
  if (chunk === null) {
    return "";
  }
  return typeof chunk === "string" ? chunk : chunk.toString();
}

test("TTY interaction port confirm preserves y/n semantics", async () => {
  const input = new PassThrough();
  const output = new PassThrough();
  const port = createTtyInteractionPort({ input, output });

  input.end("y\n");
  const confirmed = await port.confirm({ message: "Commit reconciliation results?" });

  assert.equal(confirmed, true);
  assert.match(readOutput(output), /\[y\/n\]/);
});

test("TTY confirm renders default yes and accepts blank as yes", async () => {
  const input = new PassThrough();
  const output = new PassThrough();
  const port = createTtyInteractionPort({ input, output });

  input.end("\n");
  const confirmed = await port.confirm({ message: "Continue?", defaultValue: true });

  assert.equal(confirmed, true);
  assert.match(readOutput(output), /Continue\? \[Y\/n\]/);
});

test("TTY confirm renders default no and accepts blank as no", async () => {
  const input = new PassThrough();
  const output = new PassThrough();
  const port = createTtyInteractionPort({ input, output });

  input.end("\n");
  const confirmed = await port.confirm({ message: "Commit?", defaultValue: false });

  assert.equal(confirmed, false);
  assert.match(readOutput(output), /Commit\? \[y\/N\]/);
});

test("TTY confirm re-prompts on invalid input instead of declining", async () => {
  const input = new PassThrough();
  const output = new PassThrough();
  let collected = "";
  output.on("data", (chunk: Buffer | string) => {
    collected += typeof chunk === "string" ? chunk : chunk.toString();
  });
  const port = createTtyInteractionPort({ input, output });

  const tick = (): Promise<void> => new Promise((resolve) => setImmediate(resolve));
  const confirmedPromise = port.confirm({ message: "Proceed?" });
  await tick();
  input.write("maybe\n"); // invalid -> re-prompt, not a decline
  await tick();
  input.write("y\n");
  const confirmed = await confirmedPromise;
  input.end();

  assert.equal(confirmed, true);
  assert.match(collected, /Please answer yes or no\./);
});

test("TTY interaction port exposes typed select and input requests without orchestrator wiring", async () => {
  const selectInput = new PassThrough();
  const selectOutput = new PassThrough();
  const port = createTtyInteractionPort({ input: selectInput, output: selectOutput });

  selectInput.end("2\n");
  const choice = await port.select({
    message: "Choose",
    options: [
      { value: "one", label: "One" },
      { value: "two", label: "Two" }
    ]
  });
  assert.equal(choice, "two");
  assert.match(readOutput(selectOutput), /1\. One/);

  const textInput = new PassThrough();
  const textOutput = new PassThrough();
  const inputPort = createTtyInteractionPort({ input: textInput, output: textOutput });
  textInput.end("typed answer\n");

  const typed = await inputPort.input({ message: "Enter value" });
  assert.equal(typed, "typed answer");
});

test("TTY select re-prompts on an invalid response instead of throwing", async () => {
  const input = new PassThrough();
  const output = new PassThrough();
  let collected = "";
  output.on("data", (chunk: Buffer | string) => {
    collected += typeof chunk === "string" ? chunk : chunk.toString();
  });
  const port = createTtyInteractionPort({ input, output });

  const tick = (): Promise<void> => new Promise((resolve) => setImmediate(resolve));
  // Feed one line at a time (as a real TTY does) so the pending prompt reads each.
  const choicePromise = port.select({
    message: "Choose",
    options: [
      { value: "one", label: "One" },
      { value: "two", label: "Two" }
    ]
  });
  await tick();
  input.write("x\n"); // invalid -> re-prompt
  await tick();
  input.write("2\n"); // valid on retry
  const choice = await choicePromise;
  input.end();

  assert.equal(choice, "two");
  assert.match(collected, /Invalid selection: x/);
});
