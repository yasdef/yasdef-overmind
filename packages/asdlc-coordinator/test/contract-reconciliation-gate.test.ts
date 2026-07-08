import { chmodSync, mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";
import test from "node:test";
import assert from "node:assert/strict";

import {
  validateContractReconciliation,
  validateInitialCommonContract
} from "../src/validate/contract-reconciliation.js";

const bundlePath = fileURLToPath(new URL("../overmind.js", import.meta.url));

function withProject(fn: (projectDir: string) => void): void {
  const root = mkdtempSync(path.join(tmpdir(), "overmind-contract-reconciliation-"));
  const projectDir = path.join(root, "projects", "p1");
  mkdirSync(projectDir, { recursive: true });
  try {
    fn(projectDir);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
}

function validContract(): string {
  return `# Common Contract Definition

## 1. Document Meta
- project_id: PROJ-1
- source_repo_count: 1
- last_updated: 2026-06-27
- confidence_level: high

## 2. Source Repository Evidence
### Repository: api
- class: backend
- repo_path: /repos/api
- contract_evidence_summary: reviewed routes
- key_surfaces_reviewed: /users
- notes: none

## 3. Common Contract Baseline
### Contract: users-api
- contract_kind: http_api
- interaction_mode: sync
- producer_repositories: api
- consumer_repositories: web
- contract_surface: GET /users
- contract_status: aligned
- source_of_truth: api
- canonical_shape: request: {} -> response: {id, name}
- shared_types: User
- trust_boundary: internal
- compatibility_rule: additive-only
- planning_implication: none
- notes: none

## 4. Reconciliation Decisions
- decision_1: adopt api as source of truth

## 5. Known Risks / Uncertainties
- uncertainty_1: none

## 6. Common Planning Signals
- prep_1: wire consumer tests
`;
}

function writeContract(projectDir: string, content: string): void {
  writeFileSync(path.join(projectDir, "common_contract_definition.md"), content);
}

test("contract-reconciliation gate accepts a complete common contract", () => {
  withProject((projectDir) => {
    writeContract(projectDir, validContract());
    const result = validateContractReconciliation(projectDir);
    assert.equal(result.exitCode, 0, result.problems.join("\n"));
  });
});

test("contract-reconciliation gate reports recoverable content issues (exit 1)", () => {
  withProject((projectDir) => {
    const cases: Array<[string, string]> = [
      [
        validContract().replace("## 6. Common Planning Signals", "## 6. Missing Planning"),
        "missing section ## 6. Common Planning Signals"
      ],
      [validContract().replace("- project_id: PROJ-1", "- project_id: [UNFILLED]"), "[UNFILLED]"],
      [
        validContract().replace("- contract_status: aligned", "- contract_status: bogus"),
        "invalid contract_status"
      ],
      [
        validContract().replace(
          "- canonical_shape: request: {} -> response: {id, name}",
          "- canonical_shape: it returns the user record as prose."
        ),
        "canonical_shape must be compact"
      ],
      [
        validContract().replace("- source_repo_count: 1", "- source_repo_count: 2"),
        "source_repo_count must match"
      ]
    ];
    for (const [content, expected] of cases) {
      writeContract(projectDir, content);
      const result = validateContractReconciliation(projectDir);
      assert.equal(result.exitCode, 1, `expected exit 1 for: ${expected}`);
      assert.ok(result.problems.join("\n").includes(expected), result.problems.join("\n"));
    }
  });
});

test("contract-reconciliation gate distinguishes runtime failures (exit 2)", (t) => {
  withProject((projectDir) => {
    assert.equal(validateContractReconciliation("").exitCode, 2);
    assert.equal(validateContractReconciliation(projectDir).exitCode, 2);
    writeContract(projectDir, " \n\t");
    assert.equal(validateContractReconciliation(projectDir).exitCode, 1);
    if (process.platform === "win32") {
      t.skip("POSIX permissions required for unreadable-file case");
      return;
    }
    const target = path.join(projectDir, "common_contract_definition.md");
    writeContract(projectDir, validContract());
    chmodSync(target, 0o000);
    try {
      assert.equal(validateContractReconciliation(projectDir).exitCode, 2);
    } finally {
      chmodSync(target, 0o644);
    }
  });
});

test("initial common-contract adapter matches reconciliation gate classifications", () => {
  withProject((projectDir) => {
    const fixtures: string[] = [
      validContract(),
      validContract().replace("- confidence_level: high", "- confidence_level: [UNFILLED]"),
      validContract().replace("- interaction_mode: sync", "- interaction_mode: telepathy"),
      validContract().replace("### Contract: users-api", "### Contract: users-api\n"),
      validContract().replace("- decision_1: adopt api as source of truth", "")
    ];
    for (const content of fixtures) {
      writeContract(projectDir, content);
      const ts = validateContractReconciliation(projectDir).exitCode;
      const init = validateInitialCommonContract(projectDir).exitCode;
      assert.equal(
        ts,
        init,
        `classification drift: reconciliation=${ts} initial=${init} for fixture starting: ${content.slice(0, 40)}`
      );
    }
  });
});

test("contract-reconciliation gate CLI passes and reports missing lines", () => {
  withProject((projectDir) => {
    writeContract(projectDir, validContract());
    const ok = spawnSync(
      process.execPath,
      [bundlePath, "gate", "contract-reconciliation", projectDir],
      { encoding: "utf8" }
    );
    assert.equal(ok.status, 0, ok.stdout + ok.stderr);
    assert.match(ok.stdout, /quality gate passed/);

    writeContract(projectDir, validContract().replace("- project_id: PROJ-1", "- project_id: "));
    const bad = spawnSync(process.execPath, [bundlePath, "gate", "common-contract", projectDir], {
      encoding: "utf8"
    });
    assert.equal(bad.status, 1);
    assert.match(bad.stdout, /missing: quality gate failed: /);
  });
});
