import { chmodSync, mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";
import test from "node:test";
import assert from "node:assert/strict";

import { validateContractDelta } from "../src/validate/contract-delta.js";

const bundlePath = fileURLToPath(new URL("../overmind.js", import.meta.url));

function withWorkspace(fn: (root: string, featureDir: string) => void): void {
  const root = mkdtempSync(path.join(tmpdir(), "overmind-contract-delta-validator-"));
  const featureDir = path.join(root, "projects", "p1", "feature-a");
  mkdirSync(featureDir, { recursive: true });
  try {
    fn(root, featureDir);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
}

function validDelta(deltaNeeded = true): string {
  return `# Feature Contract Delta

## 1. Document Meta
- feature_id: FEAT-1
- feature_title: Delta feature
- project_type_code: A
- source_requirements_ears: projects/p1/feature-a/requirements_ears.md
- source_common_contract_definition: projects/p1/common_contract_definition.md
- delta_needed: ${deltaNeeded}
- last_updated: 2026-06-27

## 2. Delta Summary
- baseline_reference: baseline
- feature_intent: feature intent
- impacted_tracks: backend
- no_delta_reason: ${deltaNeeded ? "none" : "baseline covers it"}

## 3. Contract Delta Items
${
  deltaNeeded
    ? `### Delta 1: add-field
- delta_kind: add
- related_baseline_contract: contract-a
- change_scope: add a field
- compatibility_impact: additive
- verification_expectation: contract test`
    : "- no_contract_delta_required: true"
}

## 4. Track Handoff Signals
- backend_handoff: implement the delta
- frontend_mobile_handoff: consume the delta
`;
}

function writeDelta(featureDir: string, content: string): void {
  writeFileSync(path.join(featureDir, "feature_contract_delta.md"), content);
}

test("contract-delta validator accepts true and false branches and ignores section 5", () => {
  withWorkspace((root, featureDir) => {
    for (const content of [
      validDelta(true),
      validDelta(false),
      `${validDelta(true)}\n## 5. Cross-Class Transport/Contract Approach Mirror\nmalformed but exempt\n`
    ]) {
      writeDelta(featureDir, content);
      const result = validateContractDelta(featureDir, root);
      assert.equal(result.exitCode, 0, result.problems.join("\n"));
    }
  });
});

test("contract-delta validator reports every required section and meta key", () => {
  withWorkspace((root, featureDir) => {
    const sections = [
      "## 1. Document Meta",
      "## 2. Delta Summary",
      "## 3. Contract Delta Items",
      "## 4. Track Handoff Signals"
    ];
    for (const section of sections) {
      writeDelta(featureDir, validDelta().replace(section, `## missing ${section}`));
      assert.match(
        validateContractDelta(featureDir, root).problems.join("\n"),
        new RegExp(`missing section: ${section.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}`)
      );
    }
    for (const key of [
      "feature_id",
      "feature_title",
      "project_type_code",
      "source_requirements_ears",
      "source_common_contract_definition",
      "delta_needed",
      "last_updated"
    ]) {
      writeDelta(featureDir, validDelta().replace(new RegExp(`^- ${key}:.*$`, "m"), ""));
      assert.match(
        validateContractDelta(featureDir, root).problems.join("\n"),
        new RegExp(`missing or unfilled meta key: ${key}`)
      );
    }
  });
});

test("contract-delta validator enforces delta branches, fields, handoffs, and placeholders", () => {
  withWorkspace((root, featureDir) => {
    const cases: Array<[string, string]> = [
      [validDelta().replace(/### Delta 1:[\s\S]*?(?=\n## 4)/, ""), "no Delta blocks"],
      [
        validDelta().replace("## 4. Track", "- no_contract_delta_required: true\n\n## 4. Track"),
        "must not be true"
      ],
      [validDelta(false).replace("- no_contract_delta_required: true", ""), "does not declare"],
      [
        validDelta(false).replace("- no_contract_delta_required: true", "### Delta 1: stale"),
        "Delta blocks are still present"
      ],
      [validDelta().replace("- backend_handoff: implement the delta", ""), "backend_handoff"],
      [
        validDelta().replace("- frontend_mobile_handoff: consume the delta", ""),
        "frontend_mobile_handoff"
      ],
      [
        validDelta().replace(
          "- verification_expectation: contract test",
          "- verification_expectation: [UNFILLED]"
        ),
        "still contains [UNFILLED]"
      ]
    ];
    for (const [content, expected] of cases) {
      writeDelta(featureDir, content);
      const result = validateContractDelta(featureDir, root);
      assert.equal(result.exitCode, 1);
      assert.ok(result.problems.join("\n").includes(expected), result.problems.join("\n"));
    }
    for (const key of [
      "delta_kind",
      "related_baseline_contract",
      "change_scope",
      "compatibility_impact",
      "verification_expectation"
    ]) {
      writeDelta(featureDir, validDelta().replace(new RegExp(`^- ${key}:.*$`, "m"), ""));
      assert.match(
        validateContractDelta(featureDir, root).problems.join("\n"),
        new RegExp(`delta block 1 missing or unfilled key: ${key}`)
      );
    }
  });
});

test("contract-delta validator distinguishes recoverable empty content from runtime failures", (t) => {
  if (process.platform === "win32") {
    t.skip("POSIX permissions required");
    return;
  }
  withWorkspace((root, featureDir) => {
    assert.equal(validateContractDelta("", root).exitCode, 2);
    assert.equal(validateContractDelta(featureDir, root).exitCode, 2);
    writeDelta(featureDir, " \n\t");
    assert.equal(validateContractDelta(featureDir, root).exitCode, 1);
    const target = path.join(featureDir, "feature_contract_delta.md");
    chmodSync(target, 0o000);
    try {
      assert.equal(validateContractDelta(featureDir, root).exitCode, 2);
    } finally {
      chmodSync(target, 0o644);
    }
  });
});

test("contract-delta CLI preserves common usage and unknown-step errors", () => {
  const missing = spawnSync(process.execPath, [bundlePath, "gate", "contract-delta"], {
    encoding: "utf8"
  });
  assert.equal(missing.status, 2);
  assert.match(missing.stderr, /Usage: overmind gate/);
  const unknown = spawnSync(process.execPath, [bundlePath, "gate", "unknown-contract", "."], {
    encoding: "utf8"
  });
  assert.equal(unknown.status, 2);
  assert.match(unknown.stderr, /Unknown gate step/);
});
