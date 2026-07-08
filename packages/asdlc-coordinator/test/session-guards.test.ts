import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import assert from "node:assert/strict";
import test from "node:test";

import {
  assertRequiredOutputs,
  snapshotReadOnlyGuards,
  validateReadOnlyGuardsBeforeSession,
  verifyReadOnlyGuards
} from "../src/runner/index.js";

function withTempDir(fn: (root: string) => void): void {
  const root = mkdtempSync(path.join(tmpdir(), "overmind-guards-"));
  try {
    fn(root);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
}

test("fromContext guard reports modified read-only input", () => {
  withTempDir((root) => {
    const protectedFile = path.join(root, "protected.md");
    writeFileSync(protectedFile, "before\n");

    const snapshot = snapshotReadOnlyGuards([{ mode: "fromContext" }], [protectedFile], () => []);
    writeFileSync(protectedFile, "after\n");

    const diagnostics = verifyReadOnlyGuards(snapshot);
    assert.match(diagnostics[0]!.reason, /fromContext guard violation/);
  });
});

test("fromContext guard allows an empty emitted read-only input set", () => {
  const diagnostics = validateReadOnlyGuardsBeforeSession([{ mode: "fromContext" }], []);

  assert.deepEqual(diagnostics, []);
});

test("fromContext guard fails before session when a protected input is missing", () => {
  withTempDir((root) => {
    const missingFile = path.join(root, "missing.md");
    const diagnostics = validateReadOnlyGuardsBeforeSession(
      [{ mode: "fromContext" }],
      [missingFile]
    );

    assert.equal(diagnostics.length, 1);
    assert.match(diagnostics[0]!.reason, /must exist before the session starts/);
  });
});

test("mustExistUnchanged guard reports altered files", () => {
  withTempDir((root) => {
    const guarded = path.join(root, "feature_br_summary.md");
    writeFileSync(guarded, "# before\n");

    const snapshot = snapshotReadOnlyGuards(
      [{ mode: "mustExistUnchanged", files: ["feature_br_summary.md"] }],
      [],
      (files) => files.map((file) => path.join(root, file))
    );
    writeFileSync(guarded, "# after\n");

    const diagnostics = verifyReadOnlyGuards(snapshot);
    assert.match(diagnostics[0]!.reason, /mustExistUnchanged guard violation/);
  });
});

test("preserveExistence passes when present file is unchanged and absent file stays absent", () => {
  withTempDir((root) => {
    const present = path.join(root, "present.yaml");
    writeFileSync(present, "value: 1\n");

    const snapshot = snapshotReadOnlyGuards(
      [{ mode: "preserveExistence", files: ["present.yaml", "absent.yaml"] }],
      [],
      (files) => files.map((file) => path.join(root, file))
    );

    assert.deepEqual(verifyReadOnlyGuards(snapshot), []);
    assert.equal(readFileSync(present, "utf8"), "value: 1\n");
  });
});

test("preserveExistence fails on modification or creation", () => {
  withTempDir((root) => {
    const present = path.join(root, "present.yaml");
    const absent = path.join(root, "absent.yaml");
    writeFileSync(present, "value: 1\n");

    const snapshot = snapshotReadOnlyGuards(
      [{ mode: "preserveExistence", files: ["present.yaml", "absent.yaml"] }],
      [],
      (files) => files.map((file) => path.join(root, file))
    );
    writeFileSync(present, "value: 2\n");
    writeFileSync(absent, "created: true\n");

    const diagnostics = verifyReadOnlyGuards(snapshot);
    assert.equal(diagnostics.length, 2);
    assert.match(diagnostics[0]!.reason, /preserveExistence guard violation/);
    assert.match(diagnostics[1]!.reason, /preserveExistence guard violation/);
  });
});

test("requiredOutputs reports missing files and accepts an empty list", () => {
  withTempDir((root) => {
    const existing = path.join(root, "exists.md");
    writeFileSync(existing, "ok\n");

    assert.deepEqual(assertRequiredOutputs([]), []);
    const diagnostics = assertRequiredOutputs([existing, path.join(root, "missing.md")]);
    assert.equal(diagnostics.length, 1);
    assert.match(diagnostics[0]!.reason, /Required output not found/);
  });
});
