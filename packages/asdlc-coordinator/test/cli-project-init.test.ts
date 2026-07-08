import { writeFileSync } from "node:fs";
import path from "node:path";
import assert from "node:assert/strict";
import test from "node:test";

import { runCli, type CliAdapterOverrides } from "../src/cli/run.js";
import type { AgentRunSpec, AgentRunner } from "../src/runner/agent-runner.js";
import type {
  ChangedPathsResult,
  CommitResult,
  ProjectGitPort,
  WorktreeStatus
} from "../src/git/index.js";

import { withWorkspace } from "./orchestrator-fixtures.js";

interface Captured {
  stdout: string;
  stderr: string;
}

class WritingAgent implements AgentRunner {
  public readonly specs: AgentRunSpec[] = [];

  constructor(private readonly contractContent = validCommonContract()) {}

  async run(spec: AgentRunSpec): Promise<{ exitCode: number }> {
    this.specs.push(spec);
    const projectMatch = spec.prompt.match(/- Project path: (projects\/[^\n]+)/);
    assert.ok(projectMatch, spec.prompt);
    const projectPath = projectMatch[1]!;
    if (spec.prompt.includes("overmind-stack-blueprint")) {
      const classMatch = spec.prompt.match(/- Target class: ([^\n]+)/);
      assert.ok(classMatch, spec.prompt);
      writeFileSync(
        path.join(spec.cwd, projectPath, `project_stack_blueprint_${classMatch[1]}.md`),
        "# blueprint\n"
      );
    } else if (spec.prompt.includes("overmind-common-contract")) {
      writeFileSync(
        path.join(spec.cwd, projectPath, "common_contract_definition.md"),
        this.contractContent
      );
    }
    return { exitCode: 0 };
  }
}

class RecordingProjectGit implements ProjectGitPort {
  public committedPaths: string[] = [];
  public commitMessage = "";

  constructor(private readonly changed: ChangedPathsResult = { kind: "ok", paths: [] }) {}

  worktreeStatus(): WorktreeStatus {
    return { kind: "clean" };
  }

  changedPaths(): ChangedPathsResult {
    return this.changed;
  }

  commitOwnedPaths(_root: string, paths: string[], message: string): CommitResult {
    this.committedPaths = paths;
    this.commitMessage = message;
    return { kind: "committed" };
  }
}

function capture(): {
  streams: { stdout: { write: (s: string) => boolean }; stderr: { write: (s: string) => boolean } };
  out: Captured;
} {
  const out: Captured = { stdout: "", stderr: "" };
  return {
    streams: {
      stdout: { write: (s) => ((out.stdout += s), true) },
      stderr: { write: (s) => ((out.stderr += s), true) }
    },
    out
  };
}

function validCommonContract(): string {
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

async function run(
  argv: string[],
  cwd: string,
  overrides: CliAdapterOverrides = {}
): Promise<{ code: number; out: Captured }> {
  const { streams, out } = capture();
  const code = await runCli(["node", "overmind", ...argv], streams, cwd, overrides);
  return { code, out };
}

test("project init requires --path", async () => {
  await withWorkspace({}, async ({ root }) => {
    const { code, out } = await run(["project", "init"], root);
    assert.equal(code, 2);
    assert.match(out.stderr, /Usage: overmind project init --path <project>/);
  });
});

test("stack-blueprint context is skill-asset only and does not bind the retired rule file", async () => {
  await withWorkspace(
    {
      definition: {
        typeCode: "A",
        classes: ["backend"],
        classRepoPaths: { backend: { state: "ready", reconciled: true } }
      }
    },
    async ({ root, projectPathRel }) => {
      const { code, out } = await run(
        ["context", "stack-blueprint", projectPathRel, "--class", "backend"],
        root
      );
      assert.equal(code, 0, out.stderr);
      assert.match(out.stdout, /stack_blueprint_template_asset: assets\//);
      assert.match(out.stdout, /stack_blueprint_golden_example_asset: assets\//);
      assert.doesNotMatch(out.stdout, /cross_class_peer_trigger_command/);
      assert.doesNotMatch(out.stdout, /\.rules\/project_stack_blueprint_rule\.md/);
    }
  );
});

test("cross-class-peer is not a public context subverb", async () => {
  await withWorkspace({}, async ({ root, projectPathRel }) => {
    const { code, out } = await run(["context", "cross-class-peer", projectPathRel], root);
    assert.equal(code, 2);
    assert.match(out.stderr, /Unknown context step: cross-class-peer/);
  });
});

test("common-contract context emits deterministic metadata and no retired rule file", async () => {
  await withWorkspace(
    {
      definition: {
        typeCode: "B",
        classRepoPaths: { backend: { state: "ready", reconciled: true } }
      }
    },
    async ({ root, projectPathRel }) => {
      const { code, out } = await run(["context", "common-contract", projectPathRel], root);
      assert.equal(code, 0, out.stderr);
      assert.match(out.stdout, /project_id: p/);
      assert.match(out.stdout, /project_type_code: B/);
      assert.match(out.stdout, /source_repo_count: 1/);
      assert.match(out.stdout, /source_repositories: backend/);
      assert.doesNotMatch(out.stdout, /cross_class_peer_trigger_command/);
      assert.doesNotMatch(out.stdout, /\.rules\/common_contract_definition_rule\.md/);
    }
  );
});

test("common-contract context leaves B/C read-only guard set empty", async () => {
  await withWorkspace(
    {
      definition: {
        typeCode: "C",
        classRepoPaths: { backend: { state: "ready", reconciled: true } }
      }
    },
    async ({ root, projectPathRel }) => {
      const { code, out } = await run(["context", "common-contract", projectPathRel], root);
      assert.equal(code, 0, out.stderr);
      assert.match(out.stdout, /progress_definition: projects\/p\/init_progress_definition.yaml/);
      assert.doesNotMatch(out.stdout, /read_only_input:/);
    }
  );
});

test("common-contract context guards only type-A stack blueprints", async () => {
  await withWorkspace(
    {
      definition: {
        typeCode: "A",
        classes: ["backend"],
        classRepoPaths: { backend: { state: "ready", reconciled: true } }
      }
    },
    async ({ root, projectDir, projectPathRel }) => {
      writeFileSync(path.join(projectDir, "project_stack_blueprint_backend.md"), "# blueprint\n");
      const { code, out } = await run(["context", "common-contract", projectPathRel], root);
      assert.equal(code, 0, out.stderr);
      const guardedInputs = out.stdout
        .split("\n")
        .filter((line) => line.startsWith("- read_only_input: "))
        .map((line) => line.replace("- read_only_input: ", ""));
      assert.deepEqual(guardedInputs, ["projects/p/project_stack_blueprint_backend.md"]);
    }
  );
});

test("project init dispatches step 1.1 once per active stack class", async () => {
  await withWorkspace(
    {
      initComplete: false,
      definition: {
        typeCode: "A",
        classes: ["backend", "frontend"],
        classRepoPaths: { backend: { state: "ready", reconciled: true } }
      }
    },
    async ({ root, projectPathRel }) => {
      const agent = new WritingAgent();
      const { code, out } = await run(["project", "init", "--path", projectPathRel], root, {
        agentRunner: agent
      });
      assert.equal(code, 0, out.stderr);
      assert.equal(agent.specs.length, 2);
      assert.match(agent.specs[0]!.prompt, /Target class: backend/);
      assert.match(agent.specs[1]!.prompt, /Target class: frontend/);
      assert.match(agent.specs[0]!.prompt, /gate stack-blueprint/);
    }
  );
});

test("project init advances non-type-A projects to step 2 and commits baseline paths", async () => {
  await withWorkspace(
    {
      initComplete: false,
      definition: {
        typeCode: "B",
        classRepoPaths: { backend: { state: "ready", reconciled: true } }
      }
    },
    async ({ root, projectPathRel }) => {
      const agent = new WritingAgent();
      const git = new RecordingProjectGit({
        kind: "ok",
        paths: ["common_contract_definition.md"]
      });
      const { code, out } = await run(["project", "init", "--path", projectPathRel], root, {
        agentRunner: agent,
        projectGit: git
      });
      assert.equal(code, 0, out.stderr);
      assert.equal(agent.specs.length, 1);
      assert.match(agent.specs[0]!.prompt, /overmind-common-contract/);
      assert.deepEqual(git.committedPaths, [
        "init_progress_definition.yaml",
        "common_contract_definition.md"
      ]);
      assert.equal(git.commitMessage, "Finalize project initialization baseline");
    }
  );
});

test("project init skips step 1.1 for type A projects without stack classes", async () => {
  await withWorkspace(
    {
      initComplete: false,
      definition: {
        typeCode: "A",
        classes: ["infrastructure"],
        classRepoPaths: { infrastructure: { state: "ready", reconciled: true } }
      }
    },
    async ({ root, projectPathRel }) => {
      const agent = new WritingAgent();
      const git = new RecordingProjectGit({ kind: "ok", paths: ["common_contract_definition.md"] });
      const { code, out } = await run(["project", "init", "--path", projectPathRel], root, {
        agentRunner: agent,
        projectGit: git
      });
      assert.equal(code, 0, out.stderr);
      assert.equal(agent.specs.length, 1);
      assert.match(agent.specs[0]!.prompt, /overmind-common-contract/);
    }
  );
});

test("project init is a clean no-op when project init is complete", async () => {
  await withWorkspace({}, async ({ root, projectPathRel }) => {
    const agent = new WritingAgent();
    const { code, out } = await run(["project", "init", "--path", projectPathRel], root, {
      agentRunner: agent
    });
    assert.equal(code, 0);
    assert.equal(agent.specs.length, 0);
    assert.match(out.stdout, /No pending project init step remains/);
  });
});

test("project init baseline commit aborts on unexpected changed paths", async () => {
  await withWorkspace(
    {
      initComplete: false,
      definition: {
        typeCode: "B",
        classRepoPaths: { backend: { state: "ready", reconciled: true } }
      }
    },
    async ({ root, projectPathRel }) => {
      const agent = new WritingAgent();
      const git = new RecordingProjectGit({
        kind: "ok",
        paths: ["common_contract_definition.md", "stray.txt"]
      });
      const { code, out } = await run(["project", "init", "--path", projectPathRel], root, {
        agentRunner: agent,
        projectGit: git
      });
      assert.equal(code, 1);
      assert.match(out.stderr, /unexpected changes/);
      assert.deepEqual(git.committedPaths, []);
    }
  );
});

test("project init validates common contract before baseline commit", async () => {
  await withWorkspace(
    {
      initComplete: false,
      definition: {
        typeCode: "B",
        classRepoPaths: { backend: { state: "ready", reconciled: true } }
      }
    },
    async ({ root, projectPathRel }) => {
      const agent = new WritingAgent("# contract\n");
      const git = new RecordingProjectGit({ kind: "ok", paths: ["common_contract_definition.md"] });
      const { code, out } = await run(["project", "init", "--path", projectPathRel], root, {
        agentRunner: agent,
        projectGit: git
      });
      assert.equal(code, 1);
      assert.match(out.stderr, /baseline validation failed before initialization commit/);
      assert.match(out.stderr, /quality gate failed/);
      assert.deepEqual(git.committedPaths, []);
    }
  );
});
