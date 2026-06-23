import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";
import assert from "node:assert/strict";

import { buildBrClarificationContext } from "../src/context/br-clarification.js";
import { createFeatureFixture } from "./fixtures.js";

function withWorkspace(fn: (root: string) => void): void {
  const root = mkdtempSync(path.join(tmpdir(), "overmind-br-clarification-context-"));
  try {
    fn(root);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
}

test("br-clarification context assembles runtime paths, allowed writes, gate command, and skill assets", () => {
  withWorkspace((root) => {
    const featureDir = createFeatureFixture(root);
    const featurePath = path.relative(root, featureDir);
    const result = buildBrClarificationContext(featurePath, root);
    assert.equal(result.exitCode, 0);
    assert.match(result.text ?? "", /# br-clarification context/);
    assert.match(result.text ?? "", /target_br_artifact: projects\/project-a\/feature-alpha\/feature_br_summary\.md/);
    assert.match(result.text ?? "", /missing_data_artifact: projects\/project-a\/feature-alpha\/missing_br_data\.md/);
    assert.match(result.text ?? "", /gate_command: node \.overmind\/overmind\.js gate br-clarification projects\/project-a\/feature-alpha/);
    assert.match(result.text ?? "", /feature_br_template_asset: assets\/feature_br_summary_TEMPLATE\.md/);
    assert.match(result.text ?? "", /feature_br_golden_example_asset: assets\/feature_br_summary_GOLDEN_EXAMPLE\.md/);
    assert.match(result.text ?? "", /## Allowed Write Surface/);
    assert.doesNotMatch(result.text ?? "", /\.codex\/skills|\.claude\/skills|overmind\/templates/);
  });
});

test("br-clarification context exits 2 when missing_br_data.md is absent", () => {
  withWorkspace((root) => {
    const featureDir = createFeatureFixture(root, { missingData: null });
    const result = buildBrClarificationContext(path.relative(root, featureDir), root);
    assert.equal(result.exitCode, 2);
    assert.match(result.errorMessage ?? "", /Run the overmind-task-to-br skill/);
  });
});
