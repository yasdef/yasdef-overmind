import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";
import assert from "node:assert/strict";

import { runCli, type CliAdapterOverrides } from "../src/cli/run.js";
import type { ProjectInitGitPort, ProjectInitResult } from "../src/git/index.js";
import { StubInteraction } from "./orchestrator-fixtures.js";

interface Captured {
  stdout: string;
  stderr: string;
}

class StubProjectInitGit implements ProjectInitGitPort {
  public readonly calls: string[] = [];

  constructor(
    private readonly result: ProjectInitResult = {
      kind: "ok",
      appliedFallbackName: true,
      appliedFallbackEmail: true
    }
  ) {}

  initAndCommitDefinition(root: string): ProjectInitResult {
    this.calls.push(root);
    return this.result;
  }
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

async function withRuntime(fn: (root: string) => Promise<void>): Promise<void> {
  const root = mkdtempSync(path.join(tmpdir(), "overmind-cli-create-"));
  mkdirSync(path.join(root, "projects"), { recursive: true });
  mkdirSync(path.join(root, ".templates"), { recursive: true });
  writeFileSync(path.join(root, "asdlc_metadata.yaml"), "meta:\nprojects:\n");
  writeFileSync(
    path.join(root, ".templates", "init_progress_definition_TEMPLATE.yaml"),
    'meta_info:\n  project_id: ""\nsteps:\n  - id: "1"\n'
  );
  try {
    await fn(root);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
}

test("project create renders typed success output", async () => {
  await withRuntime(async (root) => {
    const emptyRepo = path.join(root, "repos", "empty");
    const readyRepo = path.join(root, "repos", "ready");
    mkdirSync(emptyRepo, { recursive: true });
    mkdirSync(readyRepo, { recursive: true });
    writeFileSync(path.join(readyRepo, "README.md"), "repo\n");
    const git = new StubProjectInitGit();
    const { code, out } = await run(["project", "create"], root, {
      interaction: new StubInteraction([
        "CLI Project",
        "backend",
        "__done__",
        "ready",
        emptyRepo,
        readyRepo,
        "A"
      ]),
      projectClock: { now: () => "2026-07-09T12:00:00Z" },
      uuid: { next: () => "id-1" },
      projectInitGit: git
    });
    assert.equal(code, 0);
    assert.match(out.stdout, /Created ASDLC project folder: .*cli_project-id-1/);
    assert.match(out.stdout, /Updated ASDLC metadata:/);
    assert.match(out.stderr, /Repo path must point to a non-empty directory:/);
    assert.equal(git.calls.length, 1);
    assert.match(
      readFileSync(path.join(root, "asdlc_metadata.yaml"), "utf8"),
      /- project: cli_project-id-1/
    );
  });
});

test("project create rejects arguments with usage error", async () => {
  await withRuntime(async (root) => {
    const { code, out } = await run(["project", "create", "--path", "x"], root);
    assert.equal(code, 2);
    assert.match(out.stderr, /Unknown project create argument/);
    assert.match(out.stderr, /Usage: overmind project create/);
  });
});

test("project create treats EOF as a clean stop", async () => {
  await withRuntime(async (root) => {
    const { code, out } = await run(["project", "create"], root, {
      interaction: new StubInteraction([])
    });
    assert.equal(code, 0);
    assert.match(out.stdout, /input stream closed during project creation/);
  });
});
