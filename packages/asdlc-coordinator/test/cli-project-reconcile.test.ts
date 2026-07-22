import { execFileSync } from "node:child_process";
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";
import assert from "node:assert/strict";

import { runCli, type CliAdapterOverrides } from "../src/cli/run.js";
import { StubAgentRunner } from "../src/runner/agent-runner.js";
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

function initGitRepo(dir: string): string {
  mkdirSync(dir, { recursive: true });
  execFileSync("git", ["init", "-q"], { cwd: dir });
  execFileSync("git", ["-C", dir, "config", "user.email", "t@t.t"]);
  execFileSync("git", ["-C", dir, "config", "user.name", "t"]);
  return dir;
}

interface ClassSpec {
  state: "ready" | "deferred";
  repoPath?: string;
  reconciled?: boolean;
}

interface WsOptions {
  projects: Record<string, Record<string, ClassSpec>>;
  gitProjects?: string[];
}

function withWorkspace(options: WsOptions, fn: (root: string) => Promise<void>): Promise<void> {
  const root = mkdtempSync(path.join(tmpdir(), "overmind-cli-reconcile-"));
  writeFileSync(path.join(root, "asdlc_metadata.yaml"), "project: overmind\n");
  mkdirSync(path.join(root, ".setup"), { recursive: true });
  writeFileSync(
    path.join(root, ".setup", "models.md"),
    "project_contract_reconciliation | codex | gpt-5.4\n"
  );
  mkdirSync(path.join(root, ".overmind"), { recursive: true });
  writeFileSync(path.join(root, ".overmind", "overmind.js"), "// cli\n");

  for (const [projectId, classes] of Object.entries(options.projects)) {
    const projectDir = path.join(root, "projects", projectId);
    mkdirSync(projectDir, { recursive: true });
    const repoLines: string[] = [];
    for (const [name, spec] of Object.entries(classes)) {
      repoLines.push(`    ${name}:`);
      repoLines.push(`      state: "${spec.state}"`);
      if (spec.state === "ready") {
        repoLines.push(`      path: "${spec.repoPath}"`);
        repoLines.push(`      policy: "C"`);
      } else {
        repoLines.push('      path: ""');
        repoLines.push('      policy: "A"');
      }
      if (spec.reconciled) repoLines.push(`      contract_reconciled: true`);
    }
    writeFileSync(
      path.join(projectDir, "init_progress_definition.yaml"),
      `meta_info:
  project_type_code: A
  project_classes: [${Object.keys(classes).join(", ")}]
  class_repo_paths:
${repoLines.join("\n")}
steps:
  - id: "1"
`
    );
    writeFileSync(path.join(projectDir, "common_contract_definition.md"), "# Common contract\n");
    if (options.gitProjects?.includes(projectId)) {
      initGitRepo(projectDir);
      execFileSync("git", ["-C", projectDir, "add", "-A"]);
      execFileSync("git", ["-C", projectDir, "commit", "-q", "-m", "init"]);
    }
  }
  return fn(root).finally(() => rmSync(root, { recursive: true, force: true }));
}

test("project reconcile --help exits zero with usage", async () => {
  await withWorkspace({ projects: { p1: {} } }, async (root) => {
    const { code, out } = await run(["project", "reconcile", "--help"], root);
    assert.equal(code, 0);
    assert.match(out.stdout, /overmind project reconcile \[--path <project>\]/);
  });
});

test("project reconcile rejects unknown option, bad subcommand, and missing --path value", async () => {
  await withWorkspace({ projects: { p1: {} } }, async (root) => {
    assert.equal((await run(["project", "reconcile", "--bogus"], root)).code, 2);
    assert.equal((await run(["project", "boom"], root)).code, 2);
    assert.equal((await run(["project", "reconcile", "--path"], root)).code, 2);
  });
});

test("no projects exits non-zero", async () => {
  const root = mkdtempSync(path.join(tmpdir(), "overmind-cli-reconcile-empty-"));
  try {
    writeFileSync(path.join(root, "asdlc_metadata.yaml"), "project: overmind\n");
    mkdirSync(path.join(root, "projects"), { recursive: true });
    const { code } = await run(["project", "reconcile"], root);
    assert.equal(code, 2);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("single project auto-selects and reports a reconciled no-op", async () => {
  await withWorkspace(
    { projects: { only: { backend: { state: "ready", repoPath: "/x", reconciled: true } } } },
    async (root) => {
      const { code, out } = await run(["project", "reconcile"], root, {
        interaction: new StubInteraction([])
      });
      assert.equal(code, 0);
      assert.match(out.stdout, /Selected project: projects\/only/);
      assert.match(out.stdout, /No pending project reconciliation work/);
    }
  );
});

test("multiple projects offer selection with a finish choice that exits zero", async () => {
  await withWorkspace(
    {
      projects: {
        a: { backend: { state: "ready", repoPath: "/x", reconciled: true } },
        b: { backend: { state: "ready", repoPath: "/y", reconciled: true } }
      }
    },
    async (root) => {
      const interaction = new StubInteraction(["__finish__"]);
      const { code, out } = await run(["project", "reconcile"], root, { interaction });
      assert.equal(code, 0);
      assert.match(out.stdout, /Finished without selecting a project/);
      assert.ok(interaction.selectRequests[0]!.includes("__finish__"));
    }
  );
});

test("interactive project selection shows reconciliation guidance and decline aborts cleanly", async () => {
  await withWorkspace(
    {
      projects: {
        a: { backend: { state: "ready", repoPath: "/x", reconciled: true } },
        b: { backend: { state: "ready", repoPath: "/y", reconciled: true } }
      }
    },
    async (root) => {
      const agent = new StubAgentRunner(0);
      const { code, out } = await run(["project", "reconcile"], root, {
        interaction: new StubInteraction(["b", false]),
        agentRunner: agent
      });
      assert.equal(code, 0);
      assert.match(out.stdout, /full project reconciliation flow, not just a repo attach/);
      assert.match(out.stdout, /overmind project add-class/);
      assert.match(out.stdout, /Aborted: no changes made to project 'b'/);
      assert.equal(agent.specs.length, 0);
    }
  );
});

test("EOF at interactive reconciliation confirmation aborts cleanly", async () => {
  await withWorkspace(
    {
      projects: {
        a: { backend: { state: "ready", repoPath: "/x", reconciled: true } },
        b: { backend: { state: "ready", repoPath: "/y", reconciled: true } }
      }
    },
    async (root) => {
      const { code, out } = await run(["project", "reconcile"], root, {
        interaction: new StubInteraction(["a"]),
        agentRunner: new StubAgentRunner(0)
      });
      assert.equal(code, 0);
      assert.match(out.stdout, /Aborted: no changes made to project 'a'/);
    }
  );
});

test("closed input during selection exits zero", async () => {
  await withWorkspace(
    {
      projects: {
        a: { backend: { state: "ready", repoPath: "/x", reconciled: true } },
        b: { backend: { state: "ready", repoPath: "/y", reconciled: true } }
      }
    },
    async (root) => {
      const { code, out } = await run(["project", "reconcile"], root, {
        interaction: new StubInteraction([])
      });
      assert.equal(code, 0);
      assert.match(out.stdout, /input stream closed during project selection/);
    }
  );
});

test("explicit invalid --path exits non-zero", async () => {
  await withWorkspace({ projects: { p1: {} } }, async (root) => {
    const { code } = await run(["project", "reconcile", "--path", "projects"], root);
    assert.equal(code, 2);
  });
});

test("project reconcile can bind a class created as policy A", async () => {
  await withWorkspace({ projects: { p1: { backend: { state: "deferred" } } } }, async (root) => {
    const repo = initGitRepo(path.join(root, "repos", "api"));
    const projectDir = path.join(root, "projects", "p1");
    const agent = new StubAgentRunner(0);
    const { code, out } = await run(["project", "reconcile", "--path", projectDir], root, {
      interaction: new StubInteraction(["C", repo]),
      agentRunner: agent
    });
    assert.equal(code, 0);
    assert.match(out.stdout, /Attached 'backend'/);
    assert.equal(agent.specs.length, 1);
    const definition = readFileSync(path.join(projectDir, "init_progress_definition.yaml"), "utf8");
    assert.match(definition, /state: "ready"/);
    assert.match(definition, /path: ".*repos\/api"/);
    assert.match(definition, /policy: "C"/);
    assert.match(definition, /contract_reconciled: true/);
  });
});

test("git-backed success with confirmed commit exits zero and launches one agent", async () => {
  const root = mkdtempSync(path.join(tmpdir(), "overmind-cli-reconcile-ok-"));
  try {
    writeFileSync(path.join(root, "asdlc_metadata.yaml"), "project: overmind\n");
    mkdirSync(path.join(root, ".setup"), { recursive: true });
    writeFileSync(
      path.join(root, ".setup", "models.md"),
      "project_contract_reconciliation | codex | gpt-5.4\n"
    );
    mkdirSync(path.join(root, ".overmind"), { recursive: true });
    writeFileSync(path.join(root, ".overmind", "overmind.js"), "// cli\n");
    const repo = initGitRepo(path.join(root, "repos", "api"));
    const projectDir = path.join(root, "projects", "p1");
    mkdirSync(projectDir, { recursive: true });
    writeFileSync(
      path.join(projectDir, "init_progress_definition.yaml"),
      `meta_info:
  project_type_code: A
  project_classes: [backend]
  class_repo_paths:
    backend:
      state: "ready"
      path: "${repo}"
      policy: "C"
steps:
  - id: "1"
`
    );
    writeFileSync(path.join(projectDir, "common_contract_definition.md"), "# Common contract\n");
    initGitRepo(projectDir);
    execFileSync("git", ["-C", projectDir, "add", "-A"]);
    execFileSync("git", ["-C", projectDir, "commit", "-q", "-m", "init"]);

    const agent = new StubAgentRunner(0);
    const { code } = await run(["project", "reconcile", "--path", projectDir], root, {
      interaction: new StubInteraction([true]),
      agentRunner: agent
    });
    assert.equal(code, 0);
    assert.equal(agent.specs.length, 1);
    // Definition committed with the reconciliation flag.
    const log = execFileSync("git", ["-C", projectDir, "log", "--oneline"], { encoding: "utf8" });
    assert.match(log, /Update project reconciliation state/);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("stopped commit (declined) exits zero without committing", async () => {
  const root = mkdtempSync(path.join(tmpdir(), "overmind-cli-reconcile-decline-"));
  try {
    writeFileSync(path.join(root, "asdlc_metadata.yaml"), "project: overmind\n");
    mkdirSync(path.join(root, ".setup"), { recursive: true });
    writeFileSync(
      path.join(root, ".setup", "models.md"),
      "project_contract_reconciliation | codex | gpt-5.4\n"
    );
    const repo = initGitRepo(path.join(root, "repos", "api"));
    const projectDir = path.join(root, "projects", "p1");
    mkdirSync(projectDir, { recursive: true });
    writeFileSync(
      path.join(projectDir, "init_progress_definition.yaml"),
      `meta_info:
  project_type_code: A
  project_classes: [backend]
  class_repo_paths:
    backend:
      state: "ready"
      path: "${repo}"
      policy: "C"
steps:
  - id: "1"
`
    );
    writeFileSync(path.join(projectDir, "common_contract_definition.md"), "# Common contract\n");
    initGitRepo(projectDir);
    execFileSync("git", ["-C", projectDir, "add", "-A"]);
    execFileSync("git", ["-C", projectDir, "commit", "-q", "-m", "init"]);

    const { code } = await run(["project", "reconcile", "--path", projectDir], root, {
      interaction: new StubInteraction([false]),
      agentRunner: new StubAgentRunner(0)
    });
    assert.equal(code, 0);
    const log = execFileSync("git", ["-C", projectDir, "log", "--oneline"], { encoding: "utf8" });
    assert.doesNotMatch(log, /Reconcile contract/);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("session failure exits non-zero", async () => {
  await withWorkspace(
    { projects: { p1: { backend: { state: "ready", repoPath: undefined } } }, gitProjects: ["p1"] },
    async (root) => {
      // backend has no valid repo path (undefined) -> context binding fails -> session fails.
      const { code } = await run(
        ["project", "reconcile", "--path", path.join(root, "projects", "p1")],
        root,
        {
          interaction: new StubInteraction([]),
          agentRunner: new StubAgentRunner(0)
        }
      );
      assert.equal(code, 1);
    }
  );
});
