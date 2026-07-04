import { execFileSync } from "node:child_process";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";
import assert from "node:assert/strict";

import { buildContractReconciliationContext } from "../src/context/contract-reconciliation.js";

interface ClassSpec {
  state: "ready" | "deferred";
  repoPath?: string;
  contractReconciled?: boolean;
}

function initGitRepo(dir: string): void {
  mkdirSync(dir, { recursive: true });
  execFileSync("git", ["init", "-q"], { cwd: dir });
}

function withWorkspace(
  classes: Record<string, ClassSpec>,
  fn: (ctx: { workspaceRoot: string; projectDir: string }) => void
): void {
  const root = mkdtempSync(path.join(tmpdir(), "overmind-reconciliation-context-"));
  try {
    writeFileSync(path.join(root, "asdlc_metadata.yaml"), "version: 1\n");
    const projectDir = path.join(root, "projects", "p1");
    mkdirSync(projectDir, { recursive: true });
    const classNames = Object.keys(classes);
    const repoLines: string[] = [];
    for (const [name, spec] of Object.entries(classes)) {
      repoLines.push(`    ${name}:`);
      repoLines.push(`      state: "${spec.state}"`);
      if (spec.repoPath !== undefined) repoLines.push(`      path: "${spec.repoPath}"`);
      if (spec.state === "ready") repoLines.push(`      policy: "C"`);
      if (spec.contractReconciled) repoLines.push(`      contract_reconciled: true`);
    }
    const definition = `meta_info:
  project_type_code: A
  project_classes: [${classNames.join(", ")}]
  class_repo_paths:
${repoLines.join("\n")}
steps:
  - id: "1"
`;
    writeFileSync(path.join(projectDir, "init_progress_definition.yaml"), definition);
    fn({ workspaceRoot: root, projectDir });
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
}

test("context maps multiple ready classes with distinct repos", () => {
  withWorkspace({}, () => {});
  const root = mkdtempSync(path.join(tmpdir(), "overmind-reconciliation-context-multi-"));
  try {
    writeFileSync(path.join(root, "asdlc_metadata.yaml"), "version: 1\n");
    const projectDir = path.join(root, "projects", "p1");
    mkdirSync(projectDir, { recursive: true });
    const apiRepo = path.join(root, "repos", "api");
    const webRepo = path.join(root, "repos", "web");
    initGitRepo(apiRepo);
    initGitRepo(webRepo);
    const definition = `meta_info:
  project_type_code: A
  project_classes: [backend, frontend, mobile]
  class_repo_paths:
    backend:
      state: "ready"
      path: "${apiRepo}"
      policy: "C"
    frontend:
      state: "ready"
      path: "${webRepo}"
      policy: "C"
    mobile:
      state: "deferred"
steps:
  - id: "1"
`;
    writeFileSync(path.join(projectDir, "init_progress_definition.yaml"), definition);
    const result = buildContractReconciliationContext(projectDir, ["backend", "frontend"]);
    assert.equal(result.exitCode, 0, result.errorMessage);
    const text = result.text ?? "";
    assert.match(text, /## In-Scope Classes/);
    assert.match(text, /- backend: /);
    assert.match(text, /- frontend: /);
    assert.match(text, /## Out-Of-Scope Classes\n- mobile: deferred/);
    assert.match(text, /gate contract-reconciliation projects\/p1/);
    assert.match(text, /## Allowed Write Surface\n- projects\/p1\/common_contract_definition\.md/);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("shared repo appears once in inspection list but once per class mapping", () => {
  const root = mkdtempSync(path.join(tmpdir(), "overmind-reconciliation-context-shared-"));
  try {
    writeFileSync(path.join(root, "asdlc_metadata.yaml"), "version: 1\n");
    const projectDir = path.join(root, "projects", "p1");
    mkdirSync(projectDir, { recursive: true });
    const shared = path.join(root, "repos", "mono");
    initGitRepo(shared);
    const definition = `meta_info:
  project_type_code: A
  project_classes: [backend, frontend]
  class_repo_paths:
    backend:
      state: "ready"
      path: "${shared}"
      policy: "C"
    frontend:
      state: "ready"
      path: "${shared}"
      policy: "C"
steps:
  - id: "1"
`;
    writeFileSync(path.join(projectDir, "init_progress_definition.yaml"), definition);
    const result = buildContractReconciliationContext(projectDir, ["backend", "frontend"]);
    assert.equal(result.exitCode, 0, result.errorMessage);
    const text = result.text ?? "";
    const inspectionBlock = text
      .split("## Unique Repository Inspection Paths")[1]!
      .split("## Out-Of-Scope")[0]!;
    const uniqueCount = (inspectionBlock.match(/mono/g) ?? []).length;
    assert.equal(uniqueCount, 1);
    const mappingBlock = text.split("## In-Scope Classes")[1]!.split("## Unique")[0]!;
    assert.equal((mappingBlock.match(/mono/g) ?? []).length, 2);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("invalid class bindings produce actionable diagnostics", () => {
  withWorkspace(
    {
      backend: { state: "ready", repoPath: "/nonexistent/repo" },
      frontend: { state: "deferred" }
    },
    ({ projectDir }) => {
      assert.equal(buildContractReconciliationContext(projectDir, []).exitCode, 2);
      assert.equal(
        buildContractReconciliationContext(projectDir, ["backend", "backend"]).exitCode,
        2
      );
      assert.equal(buildContractReconciliationContext(projectDir, ["unknown"]).exitCode, 2);
      assert.equal(buildContractReconciliationContext(projectDir, ["frontend"]).exitCode, 2);
      const missingRepo = buildContractReconciliationContext(projectDir, ["backend"]);
      assert.equal(missingRepo.exitCode, 2);
      assert.match(missingRepo.errorMessage ?? "", /not an existing directory/);
    }
  );
});
