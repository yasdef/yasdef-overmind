import assert from "node:assert/strict";
import test from "node:test";

import { CodexAgentRunner, StubAgentRunner } from "../src/runner/index.js";

test("CodexAgentRunner spawns codex with shell-parity argv, cwd, and inherited stdio", async () => {
  const calls: Array<{ command: string; args: string[]; cwd: string; stdio: string }> = [];
  const runner = new CodexAgentRunner((command, args, options) => {
    calls.push({ command, args, cwd: options.cwd, stdio: options.stdio });
    return {
      once(event, listener: ((code: number | null) => void) | ((error: Error) => void)) {
        if (event === "exit") {
          (listener as (code: number | null) => void)(0);
        }
      }
    };
  });

  const result = await runner.run({
    command: "codex",
    model: "gpt-5.4",
    args: ["--config", "model_reasoning_effort='high'"],
    prompt: "hello prompt",
    cwd: "/runtime"
  });

  assert.equal(result.exitCode, 0);
  assert.deepEqual(calls, [
    {
      command: "codex",
      args: ["-m", "gpt-5.4", "--config", "model_reasoning_effort='high'", "hello prompt"],
      cwd: "/runtime",
      stdio: "inherit"
    }
  ]);
});

test("CodexAgentRunner returns non-zero child exit codes without throwing", async () => {
  const runner = new CodexAgentRunner(() => ({
    once(event, listener: ((code: number | null) => void) | ((error: Error) => void)) {
      if (event === "exit") {
        (listener as (code: number | null) => void)(17);
      }
    }
  }));

  const result = await runner.run({
    command: "codex",
    model: "gpt-5.4",
    args: [],
    prompt: "prompt",
    cwd: "/runtime"
  });

  assert.equal(result.exitCode, 17);
});

test("CodexAgentRunner surfaces a spawn error as a non-zero result without rejecting", async () => {
  const runner = new CodexAgentRunner(() => ({
    once(event, listener: ((code: number | null) => void) | ((error: Error) => void)) {
      if (event === "error") {
        (listener as (error: Error) => void)(new Error("spawn codex ENOENT"));
      }
    }
  }));

  const result = await runner.run({
    command: "codex",
    model: "gpt-5.4",
    args: [],
    prompt: "prompt",
    cwd: "/runtime"
  });

  assert.notEqual(result.exitCode, 0);
  assert.match(result.errorMessage ?? "", /Failed to launch 'codex'.*ENOENT/);
});

test("StubAgentRunner records specs and returns a configured exit code", async () => {
  const runner = new StubAgentRunner(9);
  const spec = {
    command: "codex",
    model: "gpt-5.4",
    args: [],
    prompt: "prompt",
    cwd: "/runtime"
  };

  const result = await runner.run(spec);

  assert.equal(result.exitCode, 9);
  assert.deepEqual(runner.specs, [spec]);
});
