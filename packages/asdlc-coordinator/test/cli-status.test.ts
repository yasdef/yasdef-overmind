import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";
import test from "node:test";
import assert from "node:assert/strict";

const bundlePath = fileURLToPath(new URL("../overmind.js", import.meta.url));
const templatePath = fileURLToPath(
  new URL("../../../../overmind/templates/init_progress_definition_TEMPLATE.yaml", import.meta.url)
);

function withWorkspace(run: (root: string, project: string, feature: string) => void): void {
  const root = mkdtempSync(path.join(tmpdir(), "cli-status-"));
  const project = path.join(root, "projects", "project-a");
  const feature = path.join(project, "feature-a");
  mkdirSync(feature, { recursive: true });
  writeFileSync(path.join(root, "asdlc_metadata.yaml"), "projects:\n");
  const definition = readFileSync(templatePath, "utf8")
    .replace("  project_classes: []", '  project_classes: ["backend"]')
    .replace('  project_type_code: ""', '  project_type_code: "B"')
    .replace(
      "  class_repo_paths: {}",
      '  class_repo_paths:\n    backend:\n      state: "deferred"'
    );
  writeFileSync(path.join(project, "init_progress_definition.yaml"), definition);
  try {
    run(root, project, feature);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
}

test("overmind status accepts feature and project positional paths without writing state", () => {
  withWorkspace((root, project, feature) => {
    writeFileSync(path.join(project, "common_contract_definition.md"), "complete\n");
    writeFileSync(
      path.join(feature, "feature_br_summary.md"),
      "## 1. Document Meta\n- feature_title: Status feature\n"
    );
    const featureResult = spawnSync(process.execPath, [bundlePath, "status", feature], {
      cwd: root,
      encoding: "utf8"
    });
    assert.equal(featureResult.status, 0);
    assert.match(featureResult.stdout, /--- FEATURE LEVEL TASKS Status feature ---/);
    assert.match(featureResult.stdout, /next step: 4\.1 \(Scan repo and apply task-to-BR update\)/);
    assert.equal(existsSync(path.join(project, "step_state_feature-a.md")), false);

    const projectResult = spawnSync(process.execPath, [bundlePath, "status", project], {
      cwd: root,
      encoding: "utf8"
    });
    assert.equal(projectResult.status, 0);
    assert.match(projectResult.stdout, /<feature not initialized>/);
    assert.doesNotMatch(projectResult.stdout, /- \[[ x]\] 3 /);
  });
});

test("overmind status renders invalid-path diagnostics and exits non-zero", () => {
  withWorkspace((root) => {
    const result = spawnSync(process.execPath, [bundlePath, "status", path.join(root, "missing")], {
      cwd: root,
      encoding: "utf8"
    });
    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /No ASDLC runtime root|not an existing directory/);
  });
});
