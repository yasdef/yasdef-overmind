import {
  cpSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  realpathSync,
  rmSync,
  writeFileSync
} from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

import {
  InteractionClosedError,
  type InteractionPort,
  type SelectRequest
} from "../src/interaction/index.js";
import { defaultStepExecutorDeps, type StepExecutorDeps } from "../src/runner/index.js";
import { StubAgentRunner } from "../src/runner/agent-runner.js";
import { STEP_CATALOG } from "../src/sequencing/index.js";
import type { CheckpointPort, CheckpointResult } from "../src/git/index.js";

const templatesDir = fileURLToPath(new URL("../../../../overmind/templates", import.meta.url));

const PROJECT_TYPE_LABELS: Record<string, string> = {
  A: "New project",
  B: "Existing project with partial context",
  C: "Existing project with code-first context"
};

export interface ClassRepoOption {
  /** Omit to emit a class_repo_paths entry with no `state:` line. */
  state?: "ready" | "deferred";
  reconciled?: boolean;
  /** Absolute repo path; filled in by withWorkspace for ready classes. */
  repoPath?: string;
}

export interface DefinitionOptions {
  typeCode?: string;
  classes?: string[];
  classRepoPaths?: Record<string, ClassRepoOption>;
}

export function buildDefinition(options: DefinitionOptions = {}): string {
  const typeCode = options.typeCode ?? "B";
  const classes = options.classes ?? ["backend"];
  const repos = options.classRepoPaths ?? { backend: { state: "ready", reconciled: true } };

  const raw = readFileSync(
    path.join(templatesDir, "init_progress_definition_TEMPLATE.yaml"),
    "utf8"
  );
  const classList = `[${classes.map((klass) => `"${klass}"`).join(", ")}]`;
  const repoBlock = Object.entries(repos)
    .map(([className, entry]) => {
      const lines = [`    ${className}:`];
      if (entry.state) lines.push(`      state: "${entry.state}"`);
      lines.push(`      path: "${entry.repoPath ?? `/tmp/${className}`}"`, `      policy: "C"`);
      if (entry.reconciled !== undefined)
        lines.push(`      contract_reconciled: ${entry.reconciled}`);
      return lines.join("\n");
    })
    .join("\n");

  return raw
    .replace("  project_classes: []", `  project_classes: ${classList}`)
    .replace('  project_type_code: ""', `  project_type_code: "${typeCode}"`)
    .replace(
      '  project_type_label: ""',
      `  project_type_label: "${PROJECT_TYPE_LABELS[typeCode] ?? ""}"`
    )
    .replace("  class_repo_paths: {}", `  class_repo_paths:\n${repoBlock}`);
}

export interface Workspace {
  root: string;
  projectDir: string;
  projectPathRel: string;
}

export interface WorkspaceOptions {
  definition?: DefinitionOptions;
  /** Create common_contract_definition.md so init reads as complete (default true). */
  initComplete?: boolean;
}

/**
 * Build a staged workspace: runtime root with asdlc_metadata.yaml, valid
 * `.setup/models.md`, the real BR-summary template, and one project whose
 * definition derives from the shipped template. Ready class repos are created on
 * disk so `runIf: hasReadyClassRepo` resolves against real directories.
 */
export async function withWorkspace(
  options: WorkspaceOptions,
  run: (workspace: Workspace) => Promise<void> | void
): Promise<void> {
  const root = realpathSync(mkdtempSync(path.join(tmpdir(), "overmind-orch-")));
  const projectDir = path.join(root, "projects", "p");
  mkdirSync(projectDir, { recursive: true });
  mkdirSync(path.join(root, ".setup"), { recursive: true });
  mkdirSync(path.join(root, ".templates"), { recursive: true });

  writeFileSync(path.join(root, "asdlc_metadata.yaml"), "project: overmind\n");
  writeFileSync(path.join(root, ".setup", "models.md"), validModelsMd());
  cpSync(
    path.join(templatesDir, "feature_br_summary_TEMPLATE.md"),
    path.join(root, ".templates", "feature_br_summary_TEMPLATE.md")
  );

  const definition = options.definition ?? {};
  const repos = definition.classRepoPaths ?? { backend: { state: "ready", reconciled: true } };
  for (const [className, entry] of Object.entries(repos)) {
    if (entry.state === "ready" && !entry.repoPath) {
      const repoDir = path.join(root, "repos", className);
      mkdirSync(repoDir, { recursive: true });
      entry.repoPath = realpathSync(repoDir);
    }
  }
  writeFileSync(
    path.join(projectDir, "init_progress_definition.yaml"),
    buildDefinition({ ...definition, classRepoPaths: repos })
  );
  if (options.initComplete !== false) {
    writeFileSync(path.join(projectDir, "common_contract_definition.md"), "complete\n");
  }

  try {
    await run({ root, projectDir, projectPathRel: path.relative(root, projectDir) });
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
}

/** Create a feature directory pre-populated with every catalog output artifact. */
export function seedCompleteFeature(projectDir: string, name: string): string {
  const featureDir = path.join(projectDir, name);
  mkdirSync(featureDir, { recursive: true });
  const artifacts = [
    "feature_br_summary.md",
    "user_br_input.md",
    "requirements_ears.md",
    "requirements_ears_review.md",
    "feature_contract_delta.md",
    "project_surface_struct_resp_map_backend.md",
    "technical_requirements.md",
    "implementation_slices.md",
    "prerequisite_gaps.md",
    "implementation_plan.md",
    "implementation_plan_semantic_review.md"
  ];
  writeFileSync(
    path.join(featureDir, "feature_br_summary.md"),
    "## 1. Document Meta\n- feature_title: Alpha\n- ready_to_ears: true\n"
  );
  for (const artifact of artifacts.slice(1)) {
    writeFileSync(path.join(featureDir, artifact), `# ${artifact}\n`);
  }
  return featureDir;
}

export function validModelsMd(): string {
  const phases = new Set<string>();
  for (const step of STEP_CATALOG) {
    for (const action of step.actions) {
      if (action.kind === "session") phases.add(action.modelPhase);
    }
  }
  return [...phases].map((phase) => `${phase} | codex | gpt-5.4`).join("\n");
}

/**
 * Ordered scripted interaction port. Each confirm/select/input consumes the next
 * scripted response; running out simulates a closed input stream (EOF), matching
 * the shell's rc-2 behavior.
 */
export class StubInteraction implements InteractionPort {
  public readonly log: string[] = [];
  /** Option values presented on each `select` call, for asserting hidden/offered choices. */
  public readonly selectRequests: string[][] = [];

  constructor(private readonly script: Array<boolean | string>) {}

  private next(kind: string): boolean | string {
    if (this.script.length === 0) throw new InteractionClosedError();
    const value = this.script.shift()!;
    this.log.push(`${kind}:${String(value)}`);
    return value;
  }

  async confirm(): Promise<boolean> {
    const value = this.next("confirm");
    return typeof value === "boolean" ? value : /^(y|yes)$/i.test(String(value));
  }

  async select<T extends string>(request: SelectRequest<T>): Promise<T> {
    this.selectRequests.push(request.options.map((option) => option.value));
    return String(this.next("select")) as T;
  }

  async input(): Promise<string> {
    return String(this.next("input"));
  }
}

/** A checkpoint port that records requested labels and returns a fixed result. */
export class RecordingCheckpoint implements CheckpointPort {
  public readonly labels: string[] = [];

  constructor(private readonly result: CheckpointResult = { kind: "clean" }) {}

  checkpoint(_root: string, label: string): CheckpointResult {
    this.labels.push(label);
    return this.result;
  }
}

/**
 * Executor deps whose context/sync/readiness succeed for any skill without
 * touching the filesystem, and whose agent runner is a stub. Isolates
 * orchestration flow from Slice 2 session internals.
 */
export function stubExecutorDeps(agentExitCode = 0): StepExecutorDeps {
  const context: StepExecutorDeps["context"] = {};
  const sync: StepExecutorDeps["sync"] = {};
  for (const step of STEP_CATALOG) {
    for (const action of step.actions) {
      if (action.kind === "session") {
        context[action.skillName] = () => ({ exitCode: 0 });
        sync[action.skillName] = () => ({ exitCode: 0 });
      }
    }
  }
  return {
    ...defaultStepExecutorDeps,
    agentRunner: new StubAgentRunner(agentExitCode),
    context,
    sync,
    readiness: { "br-clarification-readiness": () => ({ exitCode: 0 }) },
    write: {}
  };
}
