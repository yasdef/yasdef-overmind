import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";
import assert from "node:assert/strict";

import { readProjectDefinitionMetadata } from "../src/parse/project-definition.js";

test("definition metadata is exposed in one typed read", () => {
  const root = mkdtempSync(path.join(tmpdir(), "definition-meta-"));
  const definition = path.join(root, "init_progress_definition.yaml");
  writeFileSync(
    definition,
    `meta_info:
  project_id: "p"
  project_classes: ["backend", "frontend"]
  project_type_code: "B"
  class_repo_paths:
    backend:
      state: "ready"
      path: "/repo/backend"
      policy: "C"
    frontend:
      state: "deferred"
steps:
  - step_number: 1
    phase_name: "init"
    step_name: "Init"
`
  );
  try {
    const result = readProjectDefinitionMetadata(definition);
    assert.equal(result.parsed, true);
    assert.equal(result.projectTypeCode, "B");
    assert.deepEqual(result.projectClasses, ["backend", "frontend"]);
    assert.deepEqual(result.classRepoPaths.backend, {
      state: "ready",
      path: "/repo/backend",
      policy: "C"
    });
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("malformed metadata returns diagnostics without throwing", () => {
  const root = mkdtempSync(path.join(tmpdir(), "definition-meta-"));
  const definition = path.join(root, "init_progress_definition.yaml");
  writeFileSync(definition, "meta_info:\nsteps:\n");
  try {
    const result = readProjectDefinitionMetadata(definition);
    assert.equal(result.parsed, false);
    assert.ok(result.diagnostics.length > 0);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});
