import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";
import test from "node:test";
import assert from "node:assert/strict";

import { runBrClarificationReadiness } from "../src/readiness/br-clarification.js";

import { completeSummary, createFeatureFixture } from "./fixtures.js";

const bundlePath = fileURLToPath(new URL("../overmind.js", import.meta.url));

function withWorkspace(fn: (root: string) => void): void {
  const root = mkdtempSync(path.join(tmpdir(), "overmind-br-clarification-readiness-"));
  try {
    fn(root);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
}

function summaryWithReady(value = "false", repoContext = ""): string {
  return (
    completeSummary().replace(
      "- last_updated: 2026-03-20",
      `- last_updated: 2026-03-20\n- ready_to_ears: ${value}`
    ) + repoContext
  );
}

function missingData(entry: string): string {
  // A ledger with no pending item is terminal, so its loop decision must read `none`.
  const unresolvedAfterStop = entry.includes("rised=false")
    ? "Pending business clarification."
    : "none";
  return `# Missing Business Data

## 3. Unresolved Items Ledger (Rised)
${entry}

## 6. Latest User Answers
- answers: This was recorded in ## 7. Business Rules and Decision Logic - BR-1.

## 7. Loop Decision
- unresolved_after_stop: ${unresolvedAfterStop}
`;
}

function writeDefinition(
  featureDir: string,
  entries: Array<{ name: string; state: string; repoPath: string }>
): void {
  const projectDir = path.dirname(featureDir);
  const lines = ["meta_info:", "  class_repo_paths:"];
  for (const entry of entries) {
    lines.push(`    ${entry.name}:`);
    lines.push(`      state: "${entry.state}"`);
    lines.push(`      path: "${entry.repoPath}"`);
  }
  lines.push("steps: []");
  writeFileSync(path.join(projectDir, "init_progress_definition.yaml"), `${lines.join("\n")}\n`);
}

function validRepoContext(): string {
  return `
## 13. Existing-System Context
- repository_id_or_class: backend
- repository_path: /repos/backend
- repository_business_domain: Payment processing
- repository_primary_capability: Invoice creation
`;
}

test("readiness passes with no ready class, prints skip notice, and flips ready_to_ears", () => {
  withWorkspace((root) => {
    const featureDir = createFeatureFixture(root, {
      summary: summaryWithReady("false"),
      missingData: missingData(
        "- rised_item_1: source=## 15. Open Questions -> critical_questions; rised=true; unresolved_item=A?"
      )
    });
    writeDefinition(featureDir, [{ name: "backend", state: "deferred", repoPath: "" }]);

    const result = runBrClarificationReadiness(path.relative(root, featureDir), root);
    assert.equal(result.exitCode, 0);
    assert.match(result.message ?? "", /Skipping repository business-context readiness gate/);
    assert.match(result.message ?? "", /EARS readiness check passed/);
    assert.match(
      readFileSync(path.join(featureDir, "feature_br_summary.md"), "utf8"),
      /- ready_to_ears: true/
    );
  });
});

test("readiness evaluates repo validator when a class is ready", () => {
  withWorkspace((root) => {
    const repoPath = path.join(root, "repos", "backend");
    mkdirSync(repoPath, { recursive: true });
    const featureDir = createFeatureFixture(root, {
      summary: summaryWithReady("false", validRepoContext()),
      missingData: missingData(
        "- rised_item_1: source=## 15. Open Questions -> critical_questions; rised=true; unresolved_item=A?"
      )
    });
    writeDefinition(featureDir, [{ name: "backend", state: "ready", repoPath }]);

    const result = runBrClarificationReadiness(path.relative(root, featureDir), root);
    assert.equal(result.exitCode, 0, result.errorMessage);
    assert.match(
      readFileSync(path.join(featureDir, "feature_br_summary.md"), "utf8"),
      /- ready_to_ears: true/
    );
  });
});

test("readiness blocks unresolved or skipped clarification item and does not flip", () => {
  withWorkspace((root) => {
    const featureDir = createFeatureFixture(root, {
      summary: summaryWithReady("false"),
      missingData: missingData(
        "- rised_item_1: source=## 15. Open Questions -> critical_questions; rised=false; unresolved_item=Skipped for now?"
      )
    });
    writeDefinition(featureDir, [{ name: "backend", state: "deferred", repoPath: "" }]);

    const result = runBrClarificationReadiness(path.relative(root, featureDir), root);
    assert.equal(result.exitCode, 1);
    assert.match(
      (result.problems ?? []).join("\n"),
      /unresolved user BR clarification items remain/
    );
    assert.match(
      readFileSync(path.join(featureDir, "feature_br_summary.md"), "utf8"),
      /- ready_to_ears: false/
    );
  });
});

test("readiness requires init_progress_definition before business gates", () => {
  withWorkspace((root) => {
    const featureDir = createFeatureFixture(root, {
      summary: summaryWithReady("false"),
      missingData: missingData(
        "- rised_item_1: source=## 15. Open Questions -> critical_questions; rised=false; unresolved_item=Skipped for now?"
      )
    });

    const result = runBrClarificationReadiness(path.relative(root, featureDir), root);
    assert.equal(result.exitCode, 2);
    assert.match(
      result.errorMessage ?? "",
      /Required file not found: .*init_progress_definition\.yaml/
    );
  });
});

test("readiness rejects feature paths outside the workspace root", () => {
  withWorkspace((root) => {
    const outsideRoot = mkdtempSync(path.join(tmpdir(), "overmind-outside-feature-"));
    try {
      const featureDir = createFeatureFixture(outsideRoot, {
        summary: summaryWithReady("false"),
        missingData: missingData(
          "- rised_item_1: source=## 15. Open Questions -> critical_questions; rised=true; unresolved_item=A?"
        )
      });
      writeDefinition(featureDir, [{ name: "backend", state: "deferred", repoPath: "" }]);

      const result = runBrClarificationReadiness(featureDir, root);
      assert.equal(result.exitCode, 2);
      assert.match(result.errorMessage ?? "", /Feature path must resolve inside ASDLC workspace/);
    } finally {
      rmSync(outsideRoot, { recursive: true, force: true });
    }
  });
});

test("readiness blocks repo-br-scan validator failure and does not flip", () => {
  withWorkspace((root) => {
    const repoPath = path.join(root, "repos", "backend");
    mkdirSync(repoPath, { recursive: true });
    const featureDir = createFeatureFixture(root, {
      summary: summaryWithReady("false"),
      missingData: missingData(
        "- rised_item_1: source=## 15. Open Questions -> critical_questions; rised=true; unresolved_item=A?"
      )
    });
    writeDefinition(featureDir, [{ name: "backend", state: "ready", repoPath }]);

    const result = runBrClarificationReadiness(path.relative(root, featureDir), root);
    assert.equal(result.exitCode, 1);
    assert.match(
      (result.problems ?? []).join("\n"),
      /section ## 13\. Existing-System Context is missing/
    );
    assert.match(
      readFileSync(path.join(featureDir, "feature_br_summary.md"), "utf8"),
      /- ready_to_ears: false/
    );
  });
});

test("readiness validates ready_to_ears precondition", () => {
  withWorkspace((root) => {
    const featureDir = createFeatureFixture(root, {
      summary: summaryWithReady("true"),
      missingData: missingData(
        "- rised_item_1: source=## 15. Open Questions -> critical_questions; rised=true; unresolved_item=A?"
      )
    });
    writeDefinition(featureDir, [{ name: "backend", state: "deferred", repoPath: "" }]);

    const result = runBrClarificationReadiness(path.relative(root, featureDir), root);
    assert.equal(result.exitCode, 2);
    assert.match(result.errorMessage ?? "", /Expected ready_to_ears to be false/);
  });
});

test("readiness accepts an absolute feature path", () => {
  withWorkspace((root) => {
    const featureDir = createFeatureFixture(root, {
      summary: summaryWithReady("false"),
      missingData: missingData(
        "- rised_item_1: source=## 15. Open Questions -> critical_questions; rised=true; unresolved_item=A?"
      )
    });
    writeDefinition(featureDir, [{ name: "backend", state: "deferred", repoPath: "" }]);

    const result = runBrClarificationReadiness(featureDir, root);
    assert.equal(result.exitCode, 0);
  });
});

test("overmind readiness br-clarification exposes CLI success, usage, and unknown-step behavior", () => {
  withWorkspace((root) => {
    const featureDir = createFeatureFixture(root, {
      summary: summaryWithReady("false"),
      missingData: missingData(
        "- rised_item_1: source=## 15. Open Questions -> critical_questions; rised=true; unresolved_item=A?"
      )
    });
    writeDefinition(featureDir, [{ name: "backend", state: "deferred", repoPath: "" }]);
    const featurePath = path.relative(root, featureDir);

    const success = spawnSync(
      process.execPath,
      [bundlePath, "readiness", "br-clarification", featurePath],
      {
        cwd: root,
        encoding: "utf8"
      }
    );
    assert.equal(success.status, 0);
    assert.match(success.stdout, /EARS readiness check passed/);

    const usage = spawnSync(process.execPath, [bundlePath, "readiness", "br-clarification"], {
      cwd: root,
      encoding: "utf8"
    });
    assert.equal(usage.status, 2);
    assert.match(usage.stderr, /capture\|context\|gate\|sync\|readiness/);

    const unknown = spawnSync(process.execPath, [bundlePath, "readiness", "unknown", featurePath], {
      cwd: root,
      encoding: "utf8"
    });
    assert.equal(unknown.status, 2);
    assert.match(unknown.stderr, /Unknown readiness step: unknown/);
  });
});
