import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import assert from "node:assert/strict";
import test from "node:test";

import { runCli } from "../src/cli/run.js";
import { defaultStepExecutorDeps } from "../src/runner/index.js";
import { NON_CLASS_GATE_REGISTRY } from "../src/validate/gate-registry.js";

import { createFeatureFixture } from "./fixtures.js";

function withWorkspace(fn: (root: string) => void | Promise<void>): void | Promise<void> {
  const root = mkdtempSync(path.join(tmpdir(), "overmind-gate-registry-"));
  try {
    return fn(root);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
}

function captureStreams() {
  let stdout = "";
  let stderr = "";
  return {
    streams: {
      stdout: { write: (chunk: string) => ((stdout += chunk), true) },
      stderr: { write: (chunk: string) => ((stderr += chunk), true) }
    },
    get stdout() {
      return stdout;
    },
    get stderr() {
      return stderr;
    }
  };
}

const validRequirements = `# Requirements (EARS)

## Requirements

### Requirement 1 - Create task
**User Story:** As a user, I want to create a task, so that work can be tracked.

**Acceptance Criteria (EARS):**
- WHEN a create-task request is submitted, THE System SHALL create a task record.

**Verification:** API test for create-task success.
`;

const invalidRequirements = `# Requirements (EARS)

## Requirements

### Requirement 1 - Duplicate accounts
**User Story:** As a user, I want no duplicate accounts, so that billing stays correct.

**Acceptance Criteria (EARS):**
- WHEN a duplicate account is submitted, THEN THE System SHALL reject the request.

**Verification:** API test.
`;

test("the executor injects the same non-class gate registry the standalone CLI resolves through", () => {
  assert.equal(defaultStepExecutorDeps.gateRegistry, NON_CLASS_GATE_REGISTRY);
});

test("CLI gate dispatch and direct registry dispatch produce the same exit classification", async () => {
  for (const [content, expected] of [
    [validRequirements, 0],
    [invalidRequirements, 1]
  ] as const) {
    await withWorkspace(async (root) => {
      const featureDir = createFeatureFixture(root);
      writeFileSync(path.join(featureDir, "requirements_ears.md"), content, "utf8");

      // Absolute path resolves identically regardless of runtime root.
      const direct = NON_CLASS_GATE_REGISTRY["requirements-ears"]!({
        featurePath: featureDir,
        runtimeRoot: process.cwd()
      });
      assert.equal(direct.exitCode, expected);

      const cap = captureStreams();
      const cliExit = await runCli(
        ["node", "overmind", "gate", "requirements-ears", featureDir],
        cap.streams,
        process.cwd()
      );
      assert.equal(cliExit, expected);
      assert.equal(cliExit, direct.exitCode);
    });
  }
});

test("CLI br-clarification dispatch still streams clarification-loop progress through the shared registry", async () => {
  await withWorkspace(async (root) => {
    const featureDir = createFeatureFixture(root);
    const cap = captureStreams();
    await runCli(
      ["node", "overmind", "gate", "br-clarification", featureDir],
      cap.streams,
      process.cwd()
    );
    assert.match(cap.stdout, /rule 1: task-to-br base business-context validation/);
  });
});

test("CLI gate reports an unknown gate step through the shared registry", async () => {
  await withWorkspace(async (root) => {
    mkdirSync(path.join(root, "projects"), { recursive: true });
    const cap = captureStreams();
    const exit = await runCli(
      ["node", "overmind", "gate", "not-a-real-gate", root],
      cap.streams,
      process.cwd()
    );
    assert.equal(exit, 2);
    assert.match(cap.stderr, /Unknown gate step: not-a-real-gate/);
  });
});
