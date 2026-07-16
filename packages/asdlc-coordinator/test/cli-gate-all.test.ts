import path from "node:path";
import test from "node:test";
import assert from "node:assert/strict";

import { runCli } from "../src/cli/run.js";
import type { TerminalGateChainResult } from "../src/validate/terminal-gate-chain.js";

import { seedCompleteFeature, withWorkspace } from "./orchestrator-fixtures.js";

function capture() {
  const out = { stdout: "", stderr: "" };
  return {
    out,
    streams: {
      stdout: { write: (chunk: string) => ((out.stdout += chunk), true) },
      stderr: { write: (chunk: string) => ((out.stderr += chunk), true) }
    }
  };
}

function chainResult(overrides: Partial<TerminalGateChainResult> = {}): TerminalGateChainResult {
  return {
    exitCode: 0,
    entries: [],
    diagnostics: [],
    passed: 0,
    failed: 0,
    skipped: 0,
    ...overrides
  };
}

const sampleEntries: TerminalGateChainResult["entries"] = [
  {
    order: 4,
    gate: "requirements-ears",
    artifact: "requirements_ears.md",
    repairStep: "5",
    status: "passed",
    result: { exitCode: 0, passMessage: "ok", problems: [] }
  },
  {
    order: 5,
    gate: "ears-review",
    artifact: "requirements_ears_review.md",
    repairStep: "5.1",
    status: "skipped",
    skipReason: "requirements_ears_review.md not found"
  },
  {
    order: 7,
    gate: "surface-map",
    artifact: "project_surface_struct_resp_map_backend.md",
    klass: "backend",
    repairStep: "7",
    status: "passed",
    result: { exitCode: 0, passMessage: "ok", problems: [] }
  },
  {
    order: 11,
    gate: "implementation-plan",
    artifact: "implementation_plan.md",
    repairStep: "8.3",
    status: "failed",
    result: {
      exitCode: 1,
      passMessage: "",
      problems: ["implementation_plan.md must start with exact header: # Implementation Plan"]
    }
  }
];

test("gate all requires exactly one feature path and takes no flags", async () => {
  await withWorkspace({}, async ({ root }) => {
    const missingPath = capture();
    assert.equal(
      await runCli(["node", "overmind", "gate", "all"], missingPath.streams, root, {}),
      2
    );
    assert.match(missingPath.out.stderr, /Usage: overmind gate <step> <path>/);

    const extraArgs = capture();
    assert.equal(
      await runCli(
        ["node", "overmind", "gate", "all", "projects/p/done-1", "--class", "backend"],
        extraArgs.streams,
        root,
        {}
      ),
      2
    );
    assert.match(extraArgs.out.stderr, /Usage: overmind gate all <feature-path>/);
  });
});

test("gate all resolves a relative feature path against the injected CLI working directory", async () => {
  await withWorkspace({}, async ({ root, projectDir, projectPathRel }) => {
    const featureDir = seedCompleteFeature(projectDir, "done-1");
    const seen: Array<{ featurePath: string; cwd: string }> = [];
    const cap = capture();

    const exit = await runCli(
      ["node", "overmind", "gate", "all", path.join(projectPathRel, "done-1")],
      cap.streams,
      root,
      {
        terminalGateChain: (featurePath, cwd) => {
          seen.push({ featurePath, cwd });
          return chainResult({ passed: 1 });
        }
      }
    );

    assert.equal(exit, 0);
    assert.deepEqual(seen, [{ featurePath: path.join(projectPathRel, "done-1"), cwd: root }]);
    // The real runner resolves that same relative input to the seeded feature.
    assert.equal(path.resolve(root, path.join(projectPathRel, "done-1")), featureDir);
  });
});

test("gate all prints one auditable row per entry plus the aggregate counts", async () => {
  await withWorkspace({}, async ({ root, projectPathRel }) => {
    const cap = capture();
    const exit = await runCli(
      ["node", "overmind", "gate", "all", path.join(projectPathRel, "done-1")],
      cap.streams,
      root,
      {
        terminalGateChain: () =>
          chainResult({
            exitCode: 1,
            entries: sampleEntries,
            passed: 2,
            failed: 1,
            skipped: 1,
            repairStep: "8.3",
            diagnostics: [
              { severity: "error", source: "terminal-gate-chain", reason: "plan header missing" }
            ]
          })
      }
    );

    assert.equal(exit, 1);
    assert.match(cap.out.stdout, /passed {2}requirements-ears {2}requirements_ears\.md/);
    assert.match(cap.out.stdout, /skipped ears-review {2}requirements_ears_review\.md/);
    assert.match(cap.out.stdout, /skipped: requirements_ears_review\.md not found/);
    assert.match(
      cap.out.stdout,
      /passed {2}surface-map --class backend {2}project_surface_struct_resp_map_backend\.md/
    );
    assert.match(
      cap.out.stdout,
      /missing: implementation_plan\.md must start with exact header: # Implementation Plan/
    );
    assert.match(cap.out.stdout, /gate all summary: 2 passed, 1 failed, 1 skipped/);
    // Recoverable failures name the earliest owning step for an explicit repair resume.
    assert.match(cap.out.stderr, /--resume 8\.3/);
  });
});

test("gate all returns the aggregate runtime classification and its diagnostic", async () => {
  await withWorkspace({}, async ({ root, projectPathRel }) => {
    const cap = capture();
    const exit = await runCli(
      ["node", "overmind", "gate", "all", path.join(projectPathRel, "nope")],
      cap.streams,
      root,
      {
        terminalGateChain: () =>
          chainResult({
            exitCode: 2,
            diagnostics: [
              {
                severity: "error",
                source: "terminal-gate-chain",
                reason: "Feature path directory not found: projects/p/nope"
              }
            ]
          })
      }
    );

    assert.equal(exit, 2);
    assert.match(cap.out.stderr, /Feature path directory not found/);
  });
});

test("gate all runs the real chain end to end against a seeded feature", async () => {
  await withWorkspace({}, async ({ root, projectDir, projectPathRel }) => {
    seedCompleteFeature(projectDir, "done-1");
    const cap = capture();
    const exit = await runCli(
      ["node", "overmind", "gate", "all", path.join(projectPathRel, "done-1")],
      cap.streams,
      root,
      {}
    );

    // Placeholder artifacts fail their real gates; the point is that every
    // applicable gate ran and the aggregate classified them.
    assert.ok(exit === 1 || exit === 2);
    assert.match(cap.out.stdout, /gate all summary: \d+ passed, \d+ failed, \d+ skipped/);
    assert.match(cap.out.stdout, /implementation_plan\.md/);
  });
});

test("individual gate commands keep their syntax, output, and dispatch", async () => {
  await withWorkspace({}, async ({ root, projectDir, projectPathRel }) => {
    seedCompleteFeature(projectDir, "done-1");
    const featureArg = path.join(projectPathRel, "done-1");

    // A class gate still requires --class and reports its own usage error.
    const noClass = capture();
    assert.equal(
      await runCli(["node", "overmind", "gate", "surface-map", featureArg], noClass.streams, root),
      2
    );
    assert.match(noClass.out.stderr, /Missing required option: --class/);

    const badClass = capture();
    assert.equal(
      await runCli(
        ["node", "overmind", "gate", "surface-map", featureArg, "--class", "server"],
        badClass.streams,
        root
      ),
      2
    );
    assert.match(badClass.out.stderr, /Invalid class 'server'/);

    // An unknown gate step is still rejected, and `all` is not treated as one.
    const unknown = capture();
    assert.equal(
      await runCli(["node", "overmind", "gate", "nope", featureArg], unknown.streams, root),
      2
    );
    assert.match(unknown.out.stderr, /Unknown gate step: nope/);

    // br-clarification still streams its per-rule progress.
    const clarification = capture();
    await runCli(
      ["node", "overmind", "gate", "br-clarification", featureArg],
      clarification.streams,
      root
    );
    assert.match(clarification.out.stdout, /rule 1: task-to-br base business-context validation/);
  });
});
