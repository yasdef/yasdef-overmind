import { writeFileSync } from "node:fs";
import path from "node:path";
import test from "node:test";
import assert from "node:assert/strict";

import { detectProjectPendingWork } from "../src/orchestrator/index.js";
import { withWorkspace } from "./orchestrator-fixtures.js";

test("pending project initialization refuses with step-specific guidance", async () => {
  await withWorkspace(
    {
      initComplete: false,
      definition: {
        typeCode: "B",
        classRepoPaths: { backend: { state: "ready", reconciled: true } }
      }
    },
    ({ root, projectDir, projectPathRel }) => {
      const result = detectProjectPendingWork(root, projectDir, projectPathRel);
      assert.equal(result.pending?.kind, "init");
      if (result.pending?.kind === "init") {
        assert.equal(result.pending.stepId, "2");
        assert.ok(
          result.pending.guidance.some((line) => /init_common_contract_definition\.sh/.test(line))
        );
      }
    }
  );
});

test("pending step 1.1 emits stack-blueprint guidance", async () => {
  await withWorkspace(
    {
      initComplete: false,
      definition: {
        typeCode: "A",
        classes: ["backend"],
        classRepoPaths: { backend: { state: "ready", reconciled: true } }
      }
    },
    ({ root, projectDir, projectPathRel }) => {
      const result = detectProjectPendingWork(root, projectDir, projectPathRel);
      assert.equal(result.pending?.kind, "init");
      if (result.pending?.kind === "init") {
        assert.equal(result.pending.stepId, "1.1");
        assert.ok(
          result.pending.guidance.some((line) => /init_project_stack_blueprints\.sh/.test(line))
        );
      }
    }
  );
});

test("a deferred class repo refuses before feature selection naming overmind project reconcile", async () => {
  await withWorkspace(
    { definition: { classes: ["backend"], classRepoPaths: { backend: { state: "deferred" } } } },
    ({ root, projectDir, projectPathRel }) => {
      const result = detectProjectPendingWork(root, projectDir, projectPathRel);
      assert.equal(result.pending?.kind, "attach");
      if (result.pending?.kind === "attach") {
        assert.deepEqual(result.pending.classes, ["backend"]);
        assert.ok(
          result.pending.guidance.some((line) =>
            line.includes(`overmind project reconcile --path ${projectPathRel}`)
          )
        );
        assert.ok(
          !result.pending.guidance.some((line) => /persist_class_repo_attach\.sh/.test(line))
        );
      }
    }
  );
});

test("a configured class repo with no state is treated as not-ready and refuses attach", async () => {
  await withWorkspace(
    { definition: { classes: ["backend"], classRepoPaths: { backend: {} } } },
    ({ root, projectDir, projectPathRel }) => {
      const result = detectProjectPendingWork(root, projectDir, projectPathRel);
      assert.equal(result.pending?.kind, "attach");
      if (result.pending?.kind === "attach") {
        assert.deepEqual(result.pending.classes, ["backend"]);
        assert.ok(result.pending.guidance.some((line) => /not ready/.test(line)));
      }
    }
  );
});

test("a ready but unreconciled class refuses with overmind project reconcile guidance", async () => {
  await withWorkspace(
    { definition: { classRepoPaths: { backend: { state: "ready" } } } },
    ({ root, projectDir, projectPathRel }) => {
      const result = detectProjectPendingWork(root, projectDir, projectPathRel);
      assert.equal(result.pending?.kind, "reconcile");
      if (result.pending?.kind === "reconcile") {
        assert.deepEqual(result.pending.classes, ["backend"]);
        assert.ok(
          result.pending.guidance.some((line) =>
            line.includes(`overmind project reconcile --path ${projectPathRel}`)
          )
        );
        assert.ok(
          !result.pending.guidance.some((line) => /project_contract_reconciliation\.sh/.test(line))
        );
      }
    }
  );
});

test("reconciliation via the definition field clears the block", async () => {
  await withWorkspace(
    { definition: { classRepoPaths: { backend: { state: "ready", reconciled: true } } } },
    ({ root, projectDir, projectPathRel }) => {
      assert.equal(detectProjectPendingWork(root, projectDir, projectPathRel).pending, undefined);
    }
  );
});

test("a legacy marker no longer unblocks a ready class (clean break, D8)", async () => {
  await withWorkspace(
    { definition: { classRepoPaths: { backend: { state: "ready" } } } },
    ({ root, projectDir, projectPathRel }) => {
      writeFileSync(path.join(projectDir, ".contract_reconciled_backend"), "");
      const result = detectProjectPendingWork(root, projectDir, projectPathRel);
      assert.equal(result.pending?.kind, "reconcile");
    }
  );
});

test("multiple affected classes are all reported", async () => {
  await withWorkspace(
    {
      definition: {
        classes: ["backend", "frontend"],
        classRepoPaths: { backend: { state: "ready" }, frontend: { state: "ready" } }
      }
    },
    ({ root, projectDir, projectPathRel }) => {
      const result = detectProjectPendingWork(root, projectDir, projectPathRel);
      assert.equal(result.pending?.kind, "reconcile");
      if (result.pending?.kind === "reconcile") {
        assert.deepEqual(result.pending.classes.sort(), ["backend", "frontend"]);
      }
    }
  );
});

test("malformed project data surfaces diagnostics without pending work", async () => {
  await withWorkspace({}, ({ root, projectDir, projectPathRel }) => {
    writeFileSync(path.join(projectDir, "init_progress_definition.yaml"), "not a definition\n");
    const result = detectProjectPendingWork(root, projectDir, projectPathRel);
    assert.equal(result.pending, undefined);
    assert.ok(result.diagnostics.some((d) => d.severity === "error"));
  });
});
