import { mkdirSync, mkdtempSync, realpathSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";
import assert from "node:assert/strict";

import {
  detectRuntimeRoot,
  discoverFeatures,
  discoverProjects,
  inferProjectFromFeature,
  resolveProjectPath
} from "../src/workspace/index.js";

function fixture(run: (root: string, project: string, feature: string) => void): void {
  const root = mkdtempSync(path.join(tmpdir(), "workspace-model-"));
  const project = path.join(root, "projects", "project-a");
  const feature = path.join(project, "feature-a");
  mkdirSync(feature, { recursive: true });
  writeFileSync(path.join(root, "asdlc_metadata.yaml"), "projects:\n");
  writeFileSync(path.join(project, "init_progress_definition.yaml"), "meta_info:\nsteps:\n");
  try {
    run(root, project, feature);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
}

test("workspace detection and project/feature discovery return typed paths", () => {
  fixture((root, project, feature) => {
    root = realpathSync(root);
    project = realpathSync(project);
    feature = realpathSync(feature);
    mkdirSync(path.join(root, "projects", "not-a-project"));
    assert.equal(detectRuntimeRoot(feature).path, root);
    assert.deepEqual(discoverProjects(path.join(root, "projects")).paths, [project]);
    assert.equal(resolveProjectPath(feature, path.join(root, "projects")).path, project);
    assert.deepEqual(discoverFeatures(project).paths, [feature]);
    assert.equal(inferProjectFromFeature(feature, path.join(root, "projects")).path, project);
  });
});

test("workspace data problems degrade to diagnostics", () => {
  fixture((root, project) => {
    root = realpathSync(root);
    project = realpathSync(project);
    assert.equal(detectRuntimeRoot(path.join(root, "missing")).path, root);
    const invalid = resolveProjectPath(path.join(root, "projects"), path.join(root, "projects"));
    assert.equal(invalid.path, undefined);
    assert.equal(invalid.diagnostics.length, 1);
    const equal = inferProjectFromFeature(project, path.join(root, "projects"));
    assert.equal(equal.path, undefined);
    assert.match(equal.diagnostics[0]!.reason, /feature-level folder/);
    const noRoot = detectRuntimeRoot(tmpdir());
    assert.equal(noRoot.path, undefined);
    assert.equal(noRoot.diagnostics.length, 1);
  });
});
