import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";
import test from "node:test";
import assert from "node:assert/strict";

import { buildEarsReviewContext } from "../src/context/ears-review.js";
import { createFeatureFixture } from "./fixtures.js";

const bundlePath = fileURLToPath(new URL("../overmind.js", import.meta.url));

function escapeRegExp(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function withWorkspace(fn: (root: string) => void): void {
  const root = mkdtempSync(path.join(tmpdir(), "overmind-ears-review-context-"));
  try {
    fn(root);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
}

function writeRequirements(featureDir: string): void {
  writeFileSync(path.join(featureDir, "requirements_ears.md"), "# Requirements\n", "utf8");
}

test("ears-review context assembles runtime paths, allowed writes, gate command, and skill assets", () => {
  withWorkspace((root) => {
    const featureDir = createFeatureFixture(root);
    writeRequirements(featureDir);
    const featurePath = path.relative(root, featureDir);
    const result = buildEarsReviewContext(featurePath, root);
    assert.equal(result.exitCode, 0);
    assert.match(result.text ?? "", /# ears-review context/);
    assert.match(result.text ?? "", new RegExp(`feature_path: ${escapeRegExp(featureDir)}`));
    assert.match(result.text ?? "", /feature_path_for_command: projects\/project-a\/feature-alpha/);
    assert.match(
      result.text ?? "",
      new RegExp(
        `read_only_br_source: ${escapeRegExp(path.join(featureDir, "feature_br_summary.md"))}`
      )
    );
    assert.match(
      result.text ?? "",
      new RegExp(
        `requirements_ears_artifact: ${escapeRegExp(path.join(featureDir, "requirements_ears.md"))}`
      )
    );
    assert.match(
      result.text ?? "",
      new RegExp(
        `review_ledger_artifact: ${escapeRegExp(path.join(featureDir, "requirements_ears_review.md"))}`
      )
    );
    assert.match(
      result.text ?? "",
      /gate_command: node \.overmind\/overmind\.js gate ears-review projects\/project-a\/feature-alpha/
    );
    assert.match(
      result.text ?? "",
      /review_template_asset: assets\/requirements_ears_review_TEMPLATE\.md/
    );
    assert.match(
      result.text ?? "",
      /review_golden_example_asset: assets\/requirements_ears_review_GOLDEN_EXAMPLE\.md/
    );
    assert.match(
      result.text ?? "",
      /## Allowed Write Surface\n- requirements_ears\.md\n- requirements_ears_review\.md/
    );
    assert.doesNotMatch(
      result.text ?? "",
      /\.codex\/skills|\.claude\/skills|overmind\/templates|\.rules\/requirements_ears_review/
    );
  });
});

test("ears-review context accepts absolute feature path", () => {
  withWorkspace((root) => {
    const featureDir = createFeatureFixture(root);
    writeRequirements(featureDir);
    const result = buildEarsReviewContext(featureDir, root);
    assert.equal(result.exitCode, 0);
    assert.match(result.text ?? "", new RegExp(`feature_path: ${escapeRegExp(featureDir)}`));
  });
});

test("ears-review context exits 2 when upstream BR summary is missing", () => {
  withWorkspace((root) => {
    const featureDir = createFeatureFixture(root);
    writeRequirements(featureDir);
    rmSync(path.join(featureDir, "feature_br_summary.md"));
    const result = buildEarsReviewContext(path.relative(root, featureDir), root);
    assert.equal(result.exitCode, 2);
    assert.match(result.errorMessage ?? "", /Upstream BR summary is required/);
  });
});

test("ears-review context exits 2 when upstream EARS requirements are missing", () => {
  withWorkspace((root) => {
    const featureDir = createFeatureFixture(root);
    const result = buildEarsReviewContext(path.relative(root, featureDir), root);
    assert.equal(result.exitCode, 2);
    assert.match(result.errorMessage ?? "", /Upstream EARS requirements are required/);
  });
});

test("overmind context ears-review uses common usage and unknown-step errors", () => {
  withWorkspace((root) => {
    const missingArg = spawnSync(process.execPath, [bundlePath, "context", "ears-review"], {
      cwd: root,
      encoding: "utf8"
    });
    assert.equal(missingArg.status, 2);
    assert.match(missingArg.stderr, /ERROR: Usage: overmind context <step> <path>/);

    const unknown = spawnSync(
      process.execPath,
      [bundlePath, "context", "unknown-ears-review", "."],
      {
        cwd: root,
        encoding: "utf8"
      }
    );
    assert.equal(unknown.status, 2);
    assert.match(unknown.stderr, /ERROR: Unknown context step: unknown-ears-review/);
  });
});
