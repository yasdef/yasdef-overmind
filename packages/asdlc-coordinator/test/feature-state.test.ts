import { mkdirSync, mkdtempSync, realpathSync, rmSync, writeFileSync } from "node:fs";
import { readFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";
import assert from "node:assert/strict";

import {
  FEATURE_STATE_FILE_NAME,
  LEGACY_FEATURE_STATE_FILE_NAME,
  readFeatureState,
  writeFeatureState
} from "../src/state/index.js";

function withProject(run: (root: string, project: string, feature: string) => void): void {
  const root = realpathSync(mkdtempSync(path.join(tmpdir(), "feature-state-")));
  const project = path.join(root, "projects", "p");
  const feature = path.join(project, "feature-a");
  mkdirSync(feature, { recursive: true });
  try {
    run(root, project, feature);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
}

test("valid cache loads a workspace-relative feature path under the project", () => {
  withProject((root, project, feature) => {
    writeFeatureState(project, path.relative(root, feature));
    const result = readFeatureState(root, project);
    assert.equal(result.state, "valid");
    assert.equal(result.featurePath, path.relative(root, feature));
  });
});

test("write persists an atomic JSON cache and read round-trips it", () => {
  withProject((root, project, feature) => {
    const rel = path.relative(root, feature);
    const write = writeFeatureState(project, rel);
    assert.equal(write.ok, true);
    const onDisk = JSON.parse(
      readFileSync(path.join(project, FEATURE_STATE_FILE_NAME), "utf8")
    ) as { featurePath: string };
    assert.equal(onDisk.featurePath, rel);
    assert.equal(readFeatureState(root, project).featurePath, rel);
  });
});

test("missing cache is reported as missing without diagnostics", () => {
  withProject((root, project) => {
    const result = readFeatureState(root, project);
    assert.equal(result.state, "missing");
    assert.equal(result.diagnostics.length, 0);
  });
});

test("malformed JSON does not crash the run", () => {
  withProject((root, project) => {
    writeFileSync(path.join(project, FEATURE_STATE_FILE_NAME), "{ not json");
    const result = readFeatureState(root, project);
    assert.equal(result.state, "stale");
    assert.ok(result.notices.some((notice) => /malformed/i.test(notice)));
  });
});

test("missing feature directory is stale with an actionable notice", () => {
  withProject((root, project) => {
    writeFileSync(
      path.join(project, FEATURE_STATE_FILE_NAME),
      JSON.stringify({ featurePath: "projects/p/gone" })
    );
    const result = readFeatureState(root, project);
    assert.equal(result.state, "stale");
    assert.ok(result.notices.some((notice) => /stale/i.test(notice)));
  });
});

test("a path escaping the project or workspace is rejected as stale", () => {
  withProject((root, project) => {
    // Points outside the selected project (sibling of projects/), still inside workspace.
    const outside = path.join(root, "outside");
    mkdirSync(outside, { recursive: true });
    writeFileSync(
      path.join(project, FEATURE_STATE_FILE_NAME),
      JSON.stringify({ featurePath: path.relative(root, outside) })
    );
    assert.equal(readFeatureState(root, project).state, "stale");
  });
});

test("a cross-project feature path is treated as stale", () => {
  withProject((root, project) => {
    const otherFeature = path.join(root, "projects", "q", "feature-x");
    mkdirSync(otherFeature, { recursive: true });
    writeFileSync(
      path.join(project, FEATURE_STATE_FILE_NAME),
      JSON.stringify({ featurePath: path.relative(root, otherFeature) })
    );
    assert.equal(readFeatureState(root, project).state, "stale");
  });
});

test("legacy env state is ignored, not migrated", () => {
  withProject((root, project) => {
    writeFileSync(
      path.join(project, LEGACY_FEATURE_STATE_FILE_NAME),
      "FEATURE_PATH=projects/p/feature-a\n"
    );
    const result = readFeatureState(root, project);
    assert.equal(result.state, "missing");
  });
});

test("a cached path pointing to a file (not a directory) is stale without throwing", () => {
  withProject((root, project) => {
    const file = path.join(project, "not-a-dir");
    writeFileSync(file, "x");
    writeFileSync(
      path.join(project, FEATURE_STATE_FILE_NAME),
      JSON.stringify({ featurePath: path.relative(root, file) })
    );
    assert.equal(readFeatureState(root, project).state, "stale");
  });
});

test("a cache without a string featurePath is stale", () => {
  withProject((root, project) => {
    writeFileSync(path.join(project, FEATURE_STATE_FILE_NAME), JSON.stringify({ featurePath: 42 }));
    assert.equal(readFeatureState(root, project).state, "stale");
  });
});
