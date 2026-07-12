import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";
import assert from "node:assert/strict";

import {
  applyProjectClassMembership,
  readProjectDefinitionMetadata
} from "../src/parse/project-definition.js";

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
      path: ""
      policy: "A"
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

test("project class membership add/reset preserves steps and canonical order", () => {
  const content = `meta_info:
  project_id: "p"
  project_classes:
    - frontend
  project_type_code: "B"
  custom: "keep"
  class_repo_paths:
    frontend:
      policy: "C"
      path: '/repo/frontend'
      owner: "team-ui"
      state: "ready"
      contract_reconciled: true
steps:
  - step_number: 1
    phase_name: "init"
`;

  const added = applyProjectClassMembership(content, "backend");
  assert.equal("error" in added, false);
  if ("error" in added) return;
  assert.equal(added.action, "added");
  assert.match(
    added.content,
    /project_classes:\n    - backend\n    - frontend\n  project_type_code/
  );
  assert.match(
    added.content,
    /class_repo_paths:\n    backend:\n      state: "deferred"\n      path: ""\n      policy: "A"\n    frontend:\n      policy: "C"\n      path: '\/repo\/frontend'\n      owner: "team-ui"\n      state: "ready"\n      contract_reconciled: true/
  );
  assert.match(added.content, /\n  custom: "keep"\n/);
  assert.match(added.content, /\nsteps:\n  - step_number: 1\n    phase_name: "init"\n/);

  const reset = applyProjectClassMembership(added.content, "frontend");
  assert.equal("error" in reset, false);
  if ("error" in reset) return;
  assert.equal(reset.action, "reset");
  assert.match(
    reset.content,
    /frontend:\n      state: "deferred"\n      path: ""\n      policy: "A"/
  );
  assert.doesNotMatch(reset.content, /frontend:[\s\S]*?(contract_reconciled|owner)/);
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
