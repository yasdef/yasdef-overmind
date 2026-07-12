import { execFileSync } from "node:child_process";
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";
import assert from "node:assert/strict";

import { attachClassRepo, validateClassRecordCoherence } from "../src/repo/attach.js";
import { readProjectDefinitionMetadata } from "../src/parse/project-definition.js";

function initGitRepo(dir: string): string {
  mkdirSync(dir, { recursive: true });
  execFileSync("git", ["init", "-q"], { cwd: dir });
  return dir;
}

function withProject(
  definition: string,
  fn: (ctx: { projectDir: string; root: string }) => void
): void {
  const root = mkdtempSync(path.join(tmpdir(), "overmind-attach-"));
  try {
    const projectDir = path.join(root, "projects", "p1");
    mkdirSync(projectDir, { recursive: true });
    writeFileSync(path.join(projectDir, "init_progress_definition.yaml"), definition);
    fn({ projectDir, root });
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
}

function definition(classes: string): string {
  return `meta_info:
  project_type_code: A
  project_classes: [backend, frontend]
  class_repo_paths:
${classes}
steps:
  - id: "1"
    status: "done"
`;
}

const deferredBoth = definition(`    backend:
      state: "deferred"
      path: ""
      policy: "A"
    frontend:
      state: "deferred"
      path: ""
      policy: "A"`);

test("valid attach writes selected policy, ready state, and canonical path", () => {
  withProject(deferredBoth, ({ projectDir, root }) => {
    const repo = initGitRepo(path.join(root, "repos", "api"));
    const result = attachClassRepo(projectDir, "backend", repo, "B");
    assert.equal(result.ok, true, result.diagnostics.map((d) => d.reason).join("; "));
    const meta = readProjectDefinitionMetadata(
      path.join(projectDir, "init_progress_definition.yaml")
    );
    const entry = meta.classRepoPaths.backend!;
    assert.equal(entry.state, "ready");
    assert.equal(entry.policy, "B");
    assert.equal(entry.path, result.resolvedRepoPath);
    assert.equal(entry.contractReconciled, undefined);
    // Unrelated class and content preserved.
    assert.equal(meta.classRepoPaths.frontend!.state, "deferred");
  });
});

test("attach succeeds without a class blueprint file", () => {
  withProject(deferredBoth, ({ projectDir, root }) => {
    const repo = initGitRepo(path.join(root, "repos", "api"));
    // No project_stack_blueprint_backend.md exists.
    assert.equal(attachClassRepo(projectDir, "backend", repo, "C").ok, true);
  });
});

test("attach reattachment clears prior contract_reconciled", () => {
  const readyReconciled = definition(`    backend:
      state: "ready"
      path: "/old/path"
      policy: "C"
      contract_reconciled: true
    frontend:
      state: "deferred"
      path: ""
      policy: "A"`);
  withProject(readyReconciled, ({ projectDir, root }) => {
    const repo = initGitRepo(path.join(root, "repos", "api-2"));
    const result = attachClassRepo(projectDir, "backend", repo, "C");
    assert.equal(result.ok, true, result.diagnostics.map((d) => d.reason).join("; "));
    const meta = readProjectDefinitionMetadata(
      path.join(projectDir, "init_progress_definition.yaml")
    );
    const entry = meta.classRepoPaths.backend!;
    assert.equal(entry.state, "ready");
    assert.notEqual(entry.contractReconciled, true);
    assert.equal(entry.path, result.resolvedRepoPath);
  });
});

test("attach preserves unrelated definition content byte-for-byte outside the class block", () => {
  withProject(deferredBoth, ({ projectDir, root }) => {
    const repo = initGitRepo(path.join(root, "repos", "api"));
    attachClassRepo(projectDir, "backend", repo, "C");
    const content = readFileSync(path.join(projectDir, "init_progress_definition.yaml"), "utf8");
    assert.match(content, /project_type_code: A/);
    assert.match(content, /steps:\n {2}- id: "1"\n {4}status: "done"/);
    assert.match(content, /frontend:\n {6}state: "deferred"/);
  });
});

test("attach rejects unknown class without changing the file", () => {
  withProject(deferredBoth, ({ projectDir, root }) => {
    const repo = initGitRepo(path.join(root, "repos", "api"));
    const before = readFileSync(path.join(projectDir, "init_progress_definition.yaml"), "utf8");
    const result = attachClassRepo(projectDir, "mobile", repo, "C");
    assert.equal(result.ok, false);
    assert.match(result.diagnostics[0]!.reason, /not found in class_repo_paths/);
    const after = readFileSync(path.join(projectDir, "init_progress_definition.yaml"), "utf8");
    assert.equal(before, after);
  });
});

test("attach reports invalid repo paths with specific diagnostics", () => {
  withProject(deferredBoth, ({ projectDir, root }) => {
    assert.match(
      attachClassRepo(projectDir, "backend", "   ", "C").diagnostics[0]!.reason,
      /empty/
    );
    assert.match(
      attachClassRepo(projectDir, "backend", "/no/such/dir", "C").diagnostics[0]!.reason,
      /not a directory/
    );
    const nonGit = path.join(root, "plain");
    mkdirSync(nonGit, { recursive: true });
    assert.match(
      attachClassRepo(projectDir, "backend", nonGit, "C").diagnostics[0]!.reason,
      /git worktree/
    );
  });
});

test("coherence requires policy and rejects policy A on ready rows", () => {
  withProject(
    definition(`    backend:
      state: "ready"
      path: "/tmp/backend"`),
    ({ projectDir }) => {
      assert.match(
        validateClassRecordCoherence(projectDir, "backend")!.reason,
        /policy must be present/
      );
    }
  );

  withProject(
    definition(`    backend:
      state: "ready"
      path: "/tmp/backend"
      policy: "A"`),
    ({ projectDir }) => {
      assert.match(validateClassRecordCoherence(projectDir, "backend")!.reason, /policy A/);
    }
  );
});

test("coherence accepts deferred policy A only with an empty path", () => {
  withProject(
    definition(`    backend:
      state: "deferred"
      path: ""
      policy: "A"`),
    ({ projectDir }) => {
      assert.equal(validateClassRecordCoherence(projectDir, "backend"), undefined);
    }
  );

  withProject(
    definition(`    backend:
      state: "deferred"
      path: "/repo/backend"
      policy: "A"`),
    ({ projectDir }) => {
      assert.match(validateClassRecordCoherence(projectDir, "backend")!.reason, /policy A/);
    }
  );
});
