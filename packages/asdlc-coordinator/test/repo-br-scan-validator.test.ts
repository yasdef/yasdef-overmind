import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";
import test from "node:test";
import assert from "node:assert/strict";

import { validateRepoBrScan } from "../src/validate/repo-br-scan.js";

const bundlePath = fileURLToPath(new URL("../overmind.js", import.meta.url));

function withWorkspace(fn: (root: string) => void): void {
  const root = mkdtempSync(path.join(tmpdir(), "overmind-repo-br-scan-validator-"));
  try {
    fn(root);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
}

function makeFeatureDir(root: string, summary: string): string {
  const featureDir = path.join(root, "projects", "p1", "feature-a");
  mkdirSync(featureDir, { recursive: true });
  writeFileSync(path.join(featureDir, "feature_br_summary.md"), summary);
  return featureDir;
}

function validSummary(): string {
  return `# Feature Business Requirements Summary

## 1. Document Meta
- source_type: Repository scan
- last_updated: 2026-04-06

## 13. Existing-System Context

### 13.1 Repository: backend
- repository_id_or_class: backend
- repository_path: /repos/backend
- repository_business_domain: Payment processing
- repository_primary_capability: Invoice creation
- repository_supported_business_flows: Invoice creation, approval
- repository_supported_user_roles: admin, operator
- already_implemented_behavior: Invoice CRUD
- partially_implemented_behavior: Approval workflow
- known_gaps: none identified
- known_workarounds: none
- legacy_constraints: none
- refactor_signals: none
- prerequisite_missing_parts: none
`;
}

test("repo-br-scan validator passes when ## 1 and ## 13 are filled", () => {
  withWorkspace((root) => {
    const featureDir = makeFeatureDir(root, validSummary());
    const result = validateRepoBrScan(featureDir, root);
    assert.equal(result.exitCode, 0);
    assert.equal(result.passMessage, "business-context gate passed");
  });
});

test("repo-br-scan validator passes via golden-example-based summary with repo scan content", () => {
  withWorkspace((root) => {
    const summary = `# Feature Business Requirements Summary

## 1. Document Meta
- source_type: Repository scan
- last_updated: 2026-04-10

## 13. Existing-System Context

### 13.1 Repository: backend
- repository_id_or_class: backend
- repository_path: /path/to/backend
- repository_business_domain: Order management
- repository_primary_capability: Order fulfilment
- repository_supported_business_flows: Order placement and fulfilment
- repository_supported_user_roles: customer, admin
- already_implemented_behavior: Order CRUD and status tracking
- partially_implemented_behavior: Returns processing
- known_gaps: Refund initiation not implemented
- known_workarounds: Manual refund via admin panel
- legacy_constraints: Uses deprecated payment gateway v1
- refactor_signals: Payment gateway migration pending
- prerequisite_missing_parts: New payment gateway integration
`;
    const featureDir = makeFeatureDir(root, summary);
    const result = validateRepoBrScan(featureDir, root);
    assert.equal(result.exitCode, 0);
  });
});

test("repo-br-scan validator fails when ## 1. Document Meta is missing", () => {
  withWorkspace((root) => {
    const featureDir = makeFeatureDir(
      root,
      `# Feature Business Requirements Summary\n\n## 13. Existing-System Context\n- some_field: value\n`
    );
    const result = validateRepoBrScan(featureDir, root);
    assert.equal(result.exitCode, 1);
    assert.ok(result.problems.some((p) => p.includes("section ## 1. Document Meta is missing")));
  });
});

test("repo-br-scan validator fails when source_type is absent", () => {
  withWorkspace((root) => {
    const featureDir = makeFeatureDir(
      root,
      `# Feature Business Requirements Summary\n\n## 1. Document Meta\n- last_updated: 2026-04-06\n\n## 13. Existing-System Context\n- repo_field: value\n`
    );
    const result = validateRepoBrScan(featureDir, root);
    assert.equal(result.exitCode, 1);
    assert.ok(result.problems.some((p) => p.includes("source_type is missing")));
  });
});

test("repo-br-scan validator fails when source_type is unfilled", () => {
  withWorkspace((root) => {
    const featureDir = makeFeatureDir(
      root,
      `# Feature Business Requirements Summary\n\n## 1. Document Meta\n- source_type: [UNFILLED]\n- last_updated: 2026-04-06\n\n## 13. Existing-System Context\n- repo_field: value\n`
    );
    const result = validateRepoBrScan(featureDir, root);
    assert.equal(result.exitCode, 1);
    assert.ok(result.problems.some((p) => p.includes("source_type is unfilled")));
  });
});

test("repo-br-scan validator fails when last_updated is absent", () => {
  withWorkspace((root) => {
    const featureDir = makeFeatureDir(
      root,
      `# Feature Business Requirements Summary\n\n## 1. Document Meta\n- source_type: Repository scan\n\n## 13. Existing-System Context\n- repo_field: value\n`
    );
    const result = validateRepoBrScan(featureDir, root);
    assert.equal(result.exitCode, 1);
    assert.ok(result.problems.some((p) => p.includes("last_updated is missing")));
  });
});

test("repo-br-scan validator fails when last_updated is unfilled", () => {
  withWorkspace((root) => {
    const featureDir = makeFeatureDir(
      root,
      `# Feature Business Requirements Summary\n\n## 1. Document Meta\n- source_type: Repository scan\n- last_updated: [UNFILLED]\n\n## 13. Existing-System Context\n- repo_field: value\n`
    );
    const result = validateRepoBrScan(featureDir, root);
    assert.equal(result.exitCode, 1);
    assert.ok(result.problems.some((p) => p.includes("last_updated is unfilled")));
  });
});

test("repo-br-scan validator fails when last_updated is not YYYY-MM-DD", () => {
  withWorkspace((root) => {
    const featureDir = makeFeatureDir(
      root,
      `# Feature Business Requirements Summary\n\n## 1. Document Meta\n- source_type: Repository scan\n- last_updated: 06-04-2026\n\n## 13. Existing-System Context\n- repo_field: value\n`
    );
    const result = validateRepoBrScan(featureDir, root);
    assert.equal(result.exitCode, 1);
    assert.ok(result.problems.some((p) => p.includes("last_updated must be YYYY-MM-DD")));
  });
});

test("repo-br-scan validator fails when ## 13. Existing-System Context is missing", () => {
  withWorkspace((root) => {
    const featureDir = makeFeatureDir(
      root,
      `# Feature Business Requirements Summary\n\n## 1. Document Meta\n- source_type: Repository scan\n- last_updated: 2026-04-06\n`
    );
    const result = validateRepoBrScan(featureDir, root);
    assert.equal(result.exitCode, 1);
    assert.ok(result.problems.some((p) => p.includes("section ## 13. Existing-System Context is missing")));
  });
});

test("repo-br-scan validator fails when ## 13 has no fields", () => {
  withWorkspace((root) => {
    const featureDir = makeFeatureDir(
      root,
      `# Feature Business Requirements Summary\n\n## 1. Document Meta\n- source_type: Repository scan\n- last_updated: 2026-04-06\n\n## 13. Existing-System Context\n`
    );
    const result = validateRepoBrScan(featureDir, root);
    assert.equal(result.exitCode, 1);
    assert.ok(result.problems.some((p) => p.includes("## 13. Existing-System Context has no fields")));
  });
});

test("repo-br-scan validator fails for each unfilled field in ## 13", () => {
  withWorkspace((root) => {
    const featureDir = makeFeatureDir(
      root,
      `# Feature Business Requirements Summary\n\n## 1. Document Meta\n- source_type: Repository scan\n- last_updated: 2026-04-06\n\n## 13. Existing-System Context\n- repository_id_or_class: [UNFILLED]\n- repository_path: /repos/be\n`
    );
    const result = validateRepoBrScan(featureDir, root);
    assert.equal(result.exitCode, 1);
    assert.ok(result.problems.some((p) => p.includes("repository_id_or_class is unfilled")));
    assert.ok(!result.problems.some((p) => p.includes("repository_path is unfilled")));
  });
});

test("repo-br-scan validator exits 2 when target file not found", () => {
  withWorkspace((root) => {
    const missing = path.join(root, "projects", "p1", "missing-feature");
    const result = validateRepoBrScan(missing, root);
    assert.equal(result.exitCode, 2);
    assert.ok(result.errorMessage?.includes("Target BR summary not found:"));
  });
});

test("overmind gate repo-br-scan exits 0 for valid artifacts", () => {
  withWorkspace((root) => {
    const featureDir = makeFeatureDir(root, validSummary());
    const featurePath = path.relative(root, featureDir);
    const result = spawnSync(process.execPath, [bundlePath, "gate", "repo-br-scan", featurePath], {
      cwd: root,
      encoding: "utf8"
    });
    assert.equal(result.status, 0);
    assert.match(result.stdout, /business-context gate passed/);
  });
});

test("overmind gate repo-br-scan exits 1 with missing lines for invalid content", () => {
  withWorkspace((root) => {
    const featureDir = makeFeatureDir(
      root,
      `# Feature Business Requirements Summary\n\n## 1. Document Meta\n- source_type: [UNFILLED]\n- last_updated: bad-date\n\n## 13. Existing-System Context\n- field1: value\n`
    );
    const featurePath = path.relative(root, featureDir);
    const result = spawnSync(process.execPath, [bundlePath, "gate", "repo-br-scan", featurePath], {
      cwd: root,
      encoding: "utf8"
    });
    assert.equal(result.status, 1);
    assert.match(result.stdout, /^business-context gate failed/m);
    assert.match(result.stdout, /^missing: ## 1\. Document Meta -> source_type is unfilled/m);
    assert.match(result.stdout, /^missing: ## 1\. Document Meta -> last_updated must be YYYY-MM-DD/m);
  });
});

test("overmind gate repo-br-scan exits 2 for missing target", () => {
  withWorkspace((root) => {
    const missing = path.join(root, "projects", "p1", "nonexistent");
    const result = spawnSync(process.execPath, [bundlePath, "gate", "repo-br-scan", missing], {
      cwd: root,
      encoding: "utf8"
    });
    assert.equal(result.status, 2);
    assert.match(result.stderr, /ERROR: Target BR summary not found:/);
  });
});

test("overmind capture repo-br-scan exits 2 (capture unregistered for this step)", () => {
  withWorkspace((root) => {
    const featureDir = makeFeatureDir(root, validSummary());
    const featurePath = path.relative(root, featureDir);
    const result = spawnSync(
      process.execPath,
      [bundlePath, "capture", "repo-br-scan", featurePath, "--source-file", "story.md"],
      { cwd: root, encoding: "utf8" }
    );
    assert.equal(result.status, 2);
    assert.match(result.stderr, /ERROR: Unknown capture step: repo-br-scan/);
  });
});
