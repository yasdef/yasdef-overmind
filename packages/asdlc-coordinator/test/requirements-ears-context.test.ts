import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";
import test from "node:test";
import assert from "node:assert/strict";

import { buildRequirementsEarsContext } from "../src/context/requirements-ears.js";
import { completeSummary, createFeatureFixture } from "./fixtures.js";

const bundlePath = fileURLToPath(new URL("../overmind.js", import.meta.url));

function escapeRegExp(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function withWorkspace(fn: (root: string) => void): void {
  const root = mkdtempSync(path.join(tmpdir(), "overmind-requirements-ears-context-"));
  try {
    fn(root);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
}

function readySummary(): string {
  return completeSummary().replace(
    "- last_updated: 2026-03-20",
    "- last_updated: 2026-03-20\n- ready_to_ears: true"
  );
}

test("requirements-ears context assembles runtime paths, allowed write, gate command, and skill assets", () => {
  withWorkspace((root) => {
    const featureDir = createFeatureFixture(root, { summary: readySummary() });
    const featurePath = path.relative(root, featureDir);
    const result = buildRequirementsEarsContext(featurePath, root);
    assert.equal(result.exitCode, 0);
    assert.match(result.text ?? "", /# requirements-ears context/);
    assert.match(result.text ?? "", new RegExp(`feature_path: ${escapeRegExp(featureDir)}`));
    assert.match(result.text ?? "", /feature_path_for_command: projects\/project-a\/feature-alpha/);
    assert.match(
      result.text ?? "",
      new RegExp(
        `target_ears_artifact: ${escapeRegExp(path.join(featureDir, "requirements_ears.md"))}`
      )
    );
    assert.match(
      result.text ?? "",
      new RegExp(
        `read_only_br_source: ${escapeRegExp(path.join(featureDir, "feature_br_summary.md"))}`
      )
    );
    assert.match(
      result.text ?? "",
      /gate_command: node \.overmind\/overmind\.js gate requirements-ears projects\/project-a\/feature-alpha/
    );
    assert.match(result.text ?? "", /ears_template_asset: assets\/reqirements_ears_TEMPLATE\.md/);
    assert.match(
      result.text ?? "",
      /ears_golden_example_asset: assets\/reqirements_ears_GOLDEN_EXAMPLE\.md/
    );
    assert.match(result.text ?? "", /## Allowed Write Surface\n- requirements_ears\.md/);
    assert.doesNotMatch(
      result.text ?? "",
      /\.codex\/skills|\.claude\/skills|overmind\/templates|\.rules\/br_to_ears/
    );
  });
});

test("requirements-ears context accepts absolute feature path", () => {
  withWorkspace((root) => {
    const featureDir = createFeatureFixture(root, { summary: readySummary() });
    const result = buildRequirementsEarsContext(featureDir, root);
    assert.equal(result.exitCode, 0);
    assert.match(result.text ?? "", new RegExp(`feature_path: ${escapeRegExp(featureDir)}`));
  });
});

test("requirements-ears context exits 2 when feature_br_summary.md is missing", () => {
  withWorkspace((root) => {
    const featureDir = createFeatureFixture(root, { summary: readySummary() });
    rmSync(path.join(featureDir, "feature_br_summary.md"));
    const result = buildRequirementsEarsContext(path.relative(root, featureDir), root);
    assert.equal(result.exitCode, 2);
    assert.match(result.errorMessage ?? "", /Upstream BR summary is required/);
  });
});

test("requirements-ears context exits 2 when ready_to_ears is missing or not true", () => {
  for (const summary of [
    completeSummary(),
    readySummary().replace("- ready_to_ears: true", "- ready_to_ears: false")
  ]) {
    withWorkspace((root) => {
      const featureDir = createFeatureFixture(root, { summary });
      const result = buildRequirementsEarsContext(path.relative(root, featureDir), root);
      assert.equal(result.exitCode, 2);
      assert.match(result.errorMessage ?? "", /Expected ready_to_ears: true/);
      assert.match(result.errorMessage ?? "", /readiness br-clarification/);
    });
  }
});

test("overmind context requirements-ears uses common usage and unknown-step errors", () => {
  withWorkspace((root) => {
    const missingArg = spawnSync(process.execPath, [bundlePath, "context", "requirements-ears"], {
      cwd: root,
      encoding: "utf8"
    });
    assert.equal(missingArg.status, 2);
    assert.match(missingArg.stderr, /ERROR: Usage: overmind context <step> <path>/);

    const unknown = spawnSync(
      process.execPath,
      [bundlePath, "context", "unknown-requirements-ears", "."],
      {
        cwd: root,
        encoding: "utf8"
      }
    );
    assert.equal(unknown.status, 2);
    assert.match(unknown.stderr, /ERROR: Unknown context step: unknown-requirements-ears/);
  });
});
