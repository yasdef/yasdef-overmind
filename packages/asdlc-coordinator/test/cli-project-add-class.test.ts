import { mkdirSync, mkdtempSync, readFileSync, realpathSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";
import assert from "node:assert/strict";

import { runCli, type CliAdapterOverrides } from "../src/cli/run.js";
import type { ProjectGitPort } from "../src/git/index.js";
import { StubInteraction } from "./orchestrator-fixtures.js";

interface Captured {
  stdout: string;
  stderr: string;
}

function capture(): {
  streams: { stdout: { write: (s: string) => boolean }; stderr: { write: (s: string) => boolean } };
  out: Captured;
} {
  const out: Captured = { stdout: "", stderr: "" };
  return {
    streams: {
      stdout: { write: (s: string) => ((out.stdout += s), true) },
      stderr: { write: (s: string) => ((out.stderr += s), true) }
    },
    out
  };
}

async function run(
  argv: string[],
  cwd: string,
  overrides: CliAdapterOverrides = {}
): Promise<{ code: number; out: Captured }> {
  const { streams, out } = capture();
  const code = await runCli(["node", "overmind", ...argv], streams, cwd, overrides);
  return { code, out };
}

function writeProject(root: string, id: string, className = "backend"): string {
  const projectDir = path.join(root, "projects", id);
  mkdirSync(projectDir, { recursive: true });
  writeFileSync(
    path.join(projectDir, "init_progress_definition.yaml"),
    `meta_info:
  project_id: "${id}"
  project_classes: [${className}]
  project_type_code: "B"
  class_repo_paths:
    ${className}:
      state: "deferred"
      path: ""
      policy: "A"
steps:
  - id: "1"
`
  );
  return projectDir;
}

function withWorkspace(runFn: (root: string) => Promise<void>): Promise<void> {
  const root = mkdtempSync(path.join(tmpdir(), "overmind-cli-add-class-"));
  writeFileSync(path.join(root, "asdlc_metadata.yaml"), "project: overmind\n");
  mkdirSync(path.join(root, "projects"), { recursive: true });
  return runFn(root).finally(() => rmSync(root, { recursive: true, force: true }));
}

function fakeGit(): { port: ProjectGitPort; commits: string[] } {
  const commits: string[] = [];
  return {
    commits,
    port: {
      worktreeStatus: () => ({ kind: "clean" }),
      changedPaths: () => ({ kind: "ok", paths: [] }),
      commitOwnedPaths: (_root, paths, message) => {
        commits.push(`${paths.join(",")}:${message}`);
        return { kind: "committed" };
      }
    }
  };
}

test("project add-class rejects arguments with usage error", async () => {
  await withWorkspace(async (root) => {
    writeProject(root, "p1");
    const { code, out } = await run(["project", "add-class", "--path", "projects/p1"], root);
    assert.equal(code, 2);
    assert.match(out.stderr, /Unknown project add-class argument/);
    assert.match(out.stderr, /Usage: overmind project add-class/);
  });
});

test("project add-class selects among projects before prompting for class", async () => {
  await withWorkspace(async (root) => {
    writeProject(root, "a", "backend");
    const projectB = writeProject(root, "b", "frontend");
    const selectedProjectB = realpathSync(projectB);
    const interaction = new StubInteraction([selectedProjectB, "add", "mobile"]);
    const { code, out } = await run(["project", "add-class"], root, {
      interaction,
      projectGit: fakeGit().port
    });
    assert.equal(code, 0);
    assert.match(out.stdout, /Selected project: projects\/b/);
    assert.deepEqual(interaction.selectRequests[0], [
      realpathSync(path.join(root, "projects", "a")),
      selectedProjectB
    ]);
    assert.deepEqual(interaction.selectRequests[1], ["add", "change", "done"]);
    assert.deepEqual(interaction.selectRequests[2], ["backend", "mobile", "infrastructure"]);
    assert.match(
      readFileSync(path.join(projectB, "init_progress_definition.yaml"), "utf8"),
      /mobile:\n      state: "deferred"\n      path: ""\n      policy: "A"/
    );
  });
});

test("project add-class uses current project and can commit", async () => {
  await withWorkspace(async (root) => {
    const project = writeProject(root, "p1", "backend");
    const git = fakeGit();
    const { code, out } = await run(["project", "add-class"], project, {
      interaction: new StubInteraction(["add", "frontend", true]),
      projectGit: git.port
    });
    assert.equal(code, 0);
    assert.match(out.stdout, /Committed class membership change/);
    assert.deepEqual(git.commits, [
      "init_progress_definition.yaml:Update project class membership"
    ]);
  });
});
