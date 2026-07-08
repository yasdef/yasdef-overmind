import { captureTaskToBrInput } from "../capture/index.js";
import {
  buildTaskToBrContext,
  buildRepoBrScanContext,
  buildBrClarificationContext,
  buildRequirementsEarsContext,
  buildEarsReviewContext,
  buildContractDeltaContext,
  buildContractReconciliationContext,
  buildCommonContractInitContext,
  buildStackBlueprintContext,
  buildSurfaceMapContext,
  buildSurfaceMapEnrichContext,
  buildTechnicalRequirementsContext,
  buildImplementationSlicesContext,
  buildPrerequisiteGapsContext,
  buildImplementationPlanContext,
  buildPlanSemanticReviewContext
} from "../context/index.js";
import { runBrClarificationReadiness } from "../readiness/index.js";
import { evaluate, formatChecklist, nextStep } from "../sequencing/index.js";
import {
  syncContractDeltaStep,
  syncRepoBrScanStep,
  syncSurfaceMapStep,
  syncPrerequisiteGapsStep
} from "../sync/index.js";
import {
  validateTaskToBr,
  validateRepoBrScan,
  validateBrClarification,
  validateRequirementsEars,
  validateEarsReview,
  validateContractDelta,
  validateContractReconciliation,
  validateInitialCommonContract,
  validateStackBlueprint,
  validateSurfaceMap,
  validateTechnicalRequirements,
  validateImplementationSlices,
  validatePrerequisiteGaps,
  validateImplementationPlan,
  validatePlanSemanticReview
} from "../validate/index.js";

import type {
  CaptureResult,
  ContextResult,
  GateResult,
  ReadinessResult,
  SyncStepResult
} from "../types/index.js";
import type { SurfaceMapClass } from "../validate/surface-map.js";
import { detectRuntimeRoot, discoverProjects, resolveProjectPath } from "../workspace/index.js";
import { readProjectDefinitionMetadata } from "../parse/project-definition.js";
import { loadRunnerConfig, resolveRunnerPhase } from "../config/index.js";
import {
  createTtyInteractionPort,
  InteractionClosedError,
  type InteractionPort
} from "../interaction/index.js";
import { CodexAgentRunner, type AgentRunner } from "../runner/agent-runner.js";
import { defaultStepExecutorDeps, executeStep } from "../runner/execute-step.js";
import {
  RepoGitAdapter,
  RepoGitProjectAdapter,
  type CheckpointPort,
  type CommitResult,
  type ProjectGitPort
} from "../git/index.js";
import { RepoGitProjectInitAdapter, type ProjectInitGitPort } from "../git/index.js";
import type { ScaffoldClock } from "../capture/scaffold-feature.js";
import {
  createProject,
  FileSystemTempFilePort,
  type ProjectCreationClock,
  type TempFilePort
} from "../capture/project.js";
import { resolveStep, STEP_CATALOG } from "../sequencing/step-catalog.js";
import { PROJECT_RECONCILIATION_STEP } from "../sequencing/project-reconciliation.js";
import { scaffoldFeature } from "../capture/scaffold-feature.js";
import { registerWorker, type UuidGenerator } from "../workers/registry.js";
import { assignWorkers } from "../workers/assignment.js";
import {
  runFeatureFlow,
  runProjectReconciliationFlow,
  type FeatureFlowOutcome,
  type ProjectReconciliationOutcome
} from "../orchestrator/index.js";
import type { Diagnostic } from "../types/index.js";
import { randomUUID } from "node:crypto";
import path from "node:path";
import { realpathSync } from "node:fs";

const SURFACE_CLASSES = ["backend", "frontend", "mobile"] as const;

type OutputStreams = {
  stdout: Pick<NodeJS.WriteStream, "write">;
  stderr: Pick<NodeJS.WriteStream, "write">;
};

const gateRegistry: Record<string, (targetPath: string) => GateResult> = {
  "plan-semantic-review": validatePlanSemanticReview,
  "implementation-plan": validateImplementationPlan,
  "common-contract": validateInitialCommonContract,
  "contract-delta": validateContractDelta,
  "contract-reconciliation": validateContractReconciliation,
  "stack-blueprint": validateStackBlueprint,
  "br-clarification": validateBrClarification,
  "ears-review": validateEarsReview,
  "requirements-ears": validateRequirementsEars,
  "task-to-br": validateTaskToBr,
  "repo-br-scan": validateRepoBrScan,
  "technical-requirements": validateTechnicalRequirements,
  "implementation-slices": validateImplementationSlices,
  "prerequisite-gaps": validatePrerequisiteGaps
};

const contextRegistry: Record<string, (featurePath: string) => ContextResult> = {
  "plan-semantic-review": buildPlanSemanticReviewContext,
  "implementation-plan": buildImplementationPlanContext,
  "contract-delta": buildContractDeltaContext,
  "br-clarification": buildBrClarificationContext,
  "ears-review": buildEarsReviewContext,
  "requirements-ears": buildRequirementsEarsContext,
  "task-to-br": buildTaskToBrContext,
  "repo-br-scan": buildRepoBrScanContext,
  "surface-map-enrich": buildSurfaceMapEnrichContext,
  "technical-requirements": buildTechnicalRequirementsContext,
  "implementation-slices": buildImplementationSlicesContext,
  "prerequisite-gaps": buildPrerequisiteGapsContext
};

const captureRegistry: Record<
  string,
  (featurePath: string, options: CaptureOptions) => CaptureResult
> = {
  "task-to-br": captureTaskToBrInput
};

const syncRegistry: Record<string, (featurePath: string) => SyncStepResult> = {
  "contract-delta": syncContractDeltaStep,
  "repo-br-scan": syncRepoBrScanStep,
  "prerequisite-gaps": syncPrerequisiteGapsStep
};

const readinessRegistry: Record<string, (featurePath: string) => ReadinessResult> = {
  "br-clarification": runBrClarificationReadiness
};

const classGateRegistry: Record<
  string,
  (targetPath: string, klass: SurfaceMapClass) => GateResult
> = {
  "surface-map": validateSurfaceMap
};

const classContextRegistry: Record<
  string,
  (featurePath: string, klass: SurfaceMapClass, cwd?: string) => ContextResult
> = {
  "surface-map": buildSurfaceMapContext,
  "stack-blueprint": buildStackBlueprintContext
};

const classSyncRegistry: Record<
  string,
  (featurePath: string, klass: SurfaceMapClass) => SyncStepResult
> = {
  "surface-map": syncSurfaceMapStep
};

function parseClassOption(
  args: string[],
  verb: string
): { klass?: SurfaceMapClass; error?: string } {
  let klass: string | undefined;
  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];
    if (arg === "--class") {
      const value = args[index + 1];
      if (!value || value.startsWith("--")) {
        return { error: "Missing value for --class." };
      }
      klass = value;
      index += 1;
      continue;
    }
    return { error: `Unknown ${verb} argument: ${arg}` };
  }
  if (!klass) {
    return { error: "Missing required option: --class <backend|frontend|mobile>." };
  }
  if (!(SURFACE_CLASSES as readonly string[]).includes(klass)) {
    return { error: `Invalid class '${klass}'. Supported classes: backend, frontend, mobile.` };
  }
  return { klass: klass as SurfaceMapClass };
}

/** Parse one or more repeated `--class <name>` flags for the project reconciliation context. */
function parseClassListOption(args: string[], verb: string): { classes: string[]; error?: string } {
  const classes: string[] = [];
  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];
    if (arg === "--class") {
      const value = args[index + 1];
      if (!value || value.startsWith("--")) {
        return { classes, error: "Missing value for --class." };
      }
      classes.push(value);
      index += 1;
      continue;
    }
    return { classes, error: `Unknown ${verb} argument: ${arg}` };
  }
  if (classes.length === 0) {
    return { classes, error: "Missing required option: --class <class> (repeatable)." };
  }
  return { classes };
}

function parseOptionalClassListOption(
  args: string[],
  verb: string
): { classes: string[]; error?: string } {
  const classes: string[] = [];
  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];
    if (arg === "--class") {
      const value = args[index + 1];
      if (!value || value.startsWith("--")) {
        return { classes, error: "Missing value for --class." };
      }
      classes.push(value);
      index += 1;
      continue;
    }
    return { classes, error: `Unknown ${verb} argument: ${arg}` };
  }
  return { classes };
}

interface CaptureOptions {
  sourceFile?: string;
  jira?: string;
  overwrite?: boolean;
}

/** Test-only seam: inject interaction/agent/git/clock adapters the CLI would otherwise create. */
export interface CliAdapterOverrides {
  interaction?: InteractionPort;
  agentRunner?: AgentRunner;
  checkpoint?: CheckpointPort;
  projectGit?: ProjectGitPort;
  projectInitGit?: ProjectInitGitPort;
  clock?: ScaffoldClock;
  projectClock?: ProjectCreationClock;
  uuid?: UuidGenerator;
  temp?: TempFilePort;
}

export async function runCli(
  argv: string[],
  streams: OutputStreams = { stdout: process.stdout, stderr: process.stderr },
  cwd: string = process.cwd(),
  overrides: CliAdapterOverrides = {}
): Promise<number> {
  const [command, step, targetPath, ...args] = argv.slice(2);

  if (command === "run") {
    return runRun(argv.slice(3), streams, cwd, overrides);
  }
  if (command === "project") {
    if (step === "create") return runProjectCreate(argv.slice(4), streams, cwd, overrides);
    if (step === "init") return runProjectInit(argv.slice(4), streams, cwd, overrides);
    if (step === "reconcile") return runProjectReconcile(argv.slice(4), streams, cwd, overrides);
    streams.stderr.write(
      "ERROR: Usage: overmind project create | overmind project init --path <project> | overmind project reconcile [--path <project>]\n"
    );
    return 2;
  }
  if (command === "worker") {
    return runWorker(step, argv.slice(4), streams, cwd, overrides);
  }
  if (command === "scaffold") {
    return runScaffold(step, argv.slice(4), streams, cwd, overrides);
  }

  if (command === "status") {
    return runStatus(step, targetPath ? [targetPath, ...args] : [], streams);
  }

  if (command === "gate") {
    return runGate(step, targetPath, args, streams);
  }
  if (command === "context") {
    return runContext(step, targetPath, args, streams, cwd);
  }
  if (command === "capture") {
    return runCapture(step, targetPath, args, streams);
  }
  if (command === "sync") {
    return runSync(step, targetPath, args, streams);
  }
  if (command === "readiness") {
    return runReadiness(step, targetPath, streams);
  }

  streams.stderr.write(
    "ERROR: Usage: overmind <run|project create|project init|project reconcile|worker register|worker assign|scaffold|capture|context|gate|sync|readiness> ... | overmind status <path>\n"
  );
  return 2;
}

async function runProjectCreate(
  args: string[],
  streams: OutputStreams,
  cwd: string,
  overrides: CliAdapterOverrides
): Promise<number> {
  if (args.length === 1 && (args[0] === "--help" || args[0] === "-h")) {
    streams.stdout.write("Usage: overmind project create\n");
    return 0;
  }
  if (args.length > 0) {
    streams.stderr.write(`ERROR: Unknown project create argument: ${args[0]}\n`);
    streams.stderr.write("Usage: overmind project create\n");
    return 2;
  }

  const workspace = detectRuntimeRoot(path.resolve(cwd));
  if (!workspace.path) {
    renderDiagnostics(workspace.diagnostics, streams);
    return 2;
  }

  try {
    const result = await createProject(workspace.path, {
      interaction: overrides.interaction ?? createTtyInteractionPort(),
      clock: overrides.projectClock ?? {
        now: () => new Date().toISOString().replace(/\.\d{3}Z$/, "Z")
      },
      uuid: overrides.uuid ?? { next: () => randomUUID() },
      temp: overrides.temp ?? new FileSystemTempFilePort(),
      git: overrides.projectInitGit ?? new RepoGitProjectInitAdapter(),
      emitError: (line) => streams.stderr.write(`${line}\n`)
    });
    if (result.diagnostics.length > 0) {
      renderDiagnostics(result.diagnostics, streams);
      return 1;
    }
    if (result.projectFolder) {
      streams.stdout.write(`Created ASDLC project folder: ${result.projectFolder}\n`);
    }
    if (result.metadataPath) {
      streams.stdout.write(`Updated ASDLC metadata: ${result.metadataPath}\n`);
    }
    return 0;
  } catch (error) {
    if (error instanceof InteractionClosedError) {
      streams.stdout.write(
        "Execution stopped: user input stream closed during project creation.\n"
      );
      return 0;
    }
    throw error;
  }
}

async function runProjectInit(
  args: string[],
  streams: OutputStreams,
  cwd: string,
  overrides: CliAdapterOverrides
): Promise<number> {
  const parsed = parseSinglePathOption(args, "--path", "--path <project>", "project init");
  if (parsed.help) {
    streams.stdout.write("Usage: overmind project init --path <project>\n");
    return 0;
  }
  if (parsed.error || !parsed.pathInput) {
    streams.stderr.write(
      `ERROR: ${parsed.error ?? "Missing required option: --path <project>."}\n`
    );
    streams.stderr.write("Usage: overmind project init --path <project>\n");
    return 2;
  }

  const startPath = path.resolve(cwd, parsed.pathInput);
  const workspace = detectRuntimeRoot(startPath);
  if (!workspace.path) {
    renderDiagnostics(workspace.diagnostics, streams);
    return 2;
  }
  const workspaceRoot = workspace.path;
  const project = resolveProjectPath(startPath, path.join(workspaceRoot, "projects"));
  if (!project.path) {
    renderDiagnostics(project.diagnostics, streams);
    return 2;
  }
  const projectRoot = project.path;
  const projectPathRel = path.relative(workspaceRoot, projectRoot);
  const definitionPath = path.join(projectRoot, "init_progress_definition.yaml");
  const metadata = readProjectDefinitionMetadata(definitionPath);
  if (!metadata.parsed) {
    renderDiagnostics(metadata.diagnostics, streams);
    return 1;
  }

  const report = evaluate(workspaceRoot, projectRoot);
  const next = nextStep(report);
  if (!next || next.scope !== "project" || !isProjectInitStep(next.stepId)) {
    streams.stdout.write("No pending project init step remains.\n");
    return 0;
  }
  if (next.stepId === "1") {
    streams.stderr.write(
      "ERROR: Project metadata initialization is incomplete; create init_progress_definition.yaml before running project init.\n"
    );
    return 1;
  }

  const stepDef = STEP_CATALOG.find((candidate) => candidate.id === next.stepId);
  if (!stepDef) {
    streams.stderr.write(`ERROR: Unknown project init step selected: ${next.stepId}\n`);
    return 2;
  }

  const overmindCliPath = path.join(workspaceRoot, ".overmind", "overmind.js");
  const modelsPath = path.join(workspaceRoot, ".setup", "models.md");
  const executorDeps = {
    ...defaultStepExecutorDeps,
    agentRunner: overrides.agentRunner ?? new CodexAgentRunner()
  };
  const activeStackClasses = metadata.projectClasses.filter((klass) =>
    (SURFACE_CLASSES as readonly string[]).includes(klass)
  ) as SurfaceMapClass[];
  const dispatchClasses =
    stepDef.perClass && next.stepId === "1.1" ? activeStackClasses : ([undefined] as const);

  for (const klass of dispatchClasses) {
    const result = await executeStep(
      stepDef,
      {
        step: stepDef,
        runtimeRoot: workspaceRoot,
        featurePath: projectPathRel,
        overmindCliPath,
        modelsPath,
        ...(klass ? { targetClass: klass } : {}),
        classes: activeStackClasses
      },
      executorDeps
    );
    if (!result.ok) {
      renderDiagnostics(result.diagnostics, streams);
      return result.exitCode === 0 ? 1 : result.exitCode;
    }
  }

  if (next.stepId === "2") {
    const baselineGate = validateInitialCommonContract(projectRoot);
    if (baselineGate.exitCode !== 0) {
      renderBaselineGateFailure(baselineGate, streams);
      return baselineGate.exitCode === 2 ? 2 : 1;
    }
    const commit = commitInitializationBaseline(
      projectRoot,
      metadata.projectTypeCode,
      activeStackClasses,
      overrides.projectGit ?? new RepoGitProjectAdapter()
    );
    if (commit.error) {
      streams.stderr.write(`ERROR: ${commit.error}\n`);
      return 1;
    }
    if (commit.message) streams.stdout.write(`${commit.message}\n`);
  }

  streams.stdout.write(`Completed project init step ${next.stepId}: ${next.name}\n`);
  return 0;
}

function renderBaselineGateFailure(result: GateResult, streams: OutputStreams): void {
  if (result.exitCode === 1) {
    streams.stderr.write(
      "ERROR: common-contract baseline validation failed before initialization commit.\n"
    );
    for (const problem of result.problems) {
      streams.stderr.write(`common-contract: ${problem}\n`);
    }
    return;
  }
  streams.stderr.write(
    `ERROR: common-contract baseline validation could not run before initialization commit: ${result.errorMessage ?? "Validation cannot run."}\n`
  );
}

function isProjectInitStep(stepId: string): boolean {
  return stepId === "1" || stepId === "1.1" || stepId === "2";
}

function commitInitializationBaseline(
  projectRoot: string,
  projectTypeCode: string | undefined,
  activeStackClasses: SurfaceMapClass[],
  git: ProjectGitPort
): { message?: string; error?: string } {
  const ownedPaths = [
    "init_progress_definition.yaml",
    "common_contract_definition.md",
    ...(projectTypeCode === "A"
      ? activeStackClasses.map((klass) => `project_stack_blueprint_${klass}.md`)
      : [])
  ];

  const changed = git.changedPaths(projectRoot);
  if (changed.kind !== "ok") {
    return {
      error: describeChangedPathsFailure(changed, projectRoot)
    };
  }
  const unexpected = changed.paths.filter((candidate) => !ownedPaths.includes(candidate));
  if (unexpected.length > 0) {
    return {
      error: `Project initialization created unexpected changes; baseline was not committed: ${unexpected.join(", ")}`
    };
  }
  if (!changed.paths.some((candidate) => ownedPaths.includes(candidate))) {
    return { message: "Project initialization baseline has no changes to commit." };
  }

  const commit = git.commitOwnedPaths(
    projectRoot,
    ownedPaths,
    "Finalize project initialization baseline"
  );
  if (commit.kind === "committed") {
    return { message: "Committed project initialization baseline." };
  }
  return { error: describeCommitFailure(commit, projectRoot) };
}

function describeChangedPathsFailure(
  result: Exclude<ReturnType<ProjectGitPort["changedPaths"]>, { kind: "ok" }>,
  projectRoot: string
): string {
  switch (result.kind) {
    case "unavailable":
      return "Project path must be a git repository to finalize initialization baseline: git not found in PATH.";
    case "notWorktree":
      return `Project path must be a git repository to finalize initialization baseline: ${projectRoot}`;
    case "inspectionFailed":
      return `Failed to validate project initialization baseline paths for ${projectRoot} (git exited ${result.exitCode}): ${result.stderr.trim()}`;
  }
}

function describeCommitFailure(commit: CommitResult, projectRoot: string): string {
  switch (commit.kind) {
    case "committed":
      return "committed";
    case "unavailable":
      return "Project path must be a git repository to finalize initialization baseline: git not found in PATH.";
    case "notWorktree":
      return `Project path must be a git repository to finalize initialization baseline: ${projectRoot}`;
    case "stageFailed":
      return `Failed to stage project initialization baseline for ${projectRoot}: git add exited ${commit.exitCode}: ${commit.stderr.trim()}`;
    case "commitFailed":
      return `Failed to commit project initialization baseline for ${projectRoot}: git commit exited ${commit.exitCode}: ${commit.stderr.trim()}`;
    case "dirtyAfterCommit":
      return `Project initialization baseline left unexpected uncommitted changes: ${commit.paths.join(", ")}`;
    case "inspectionFailed":
      return `Failed to verify project initialization baseline for ${projectRoot} (git exited ${commit.exitCode}): ${commit.stderr.trim()}`;
  }
}

async function runWorker(
  subcommand: string | undefined,
  args: string[],
  streams: OutputStreams,
  cwd: string,
  overrides: CliAdapterOverrides
): Promise<number> {
  if (subcommand === "register") return runWorkerRegister(args, streams, cwd, overrides);
  if (subcommand === "assign") return runWorkerAssign(args, streams, cwd, overrides);
  streams.stderr.write(
    "ERROR: Usage: overmind worker register --path <project> | overmind worker assign --feature-path <feature>\n"
  );
  return 2;
}

function parseSinglePathOption(
  args: string[],
  optionName: "--path" | "--feature-path",
  usage: string,
  verb: string
): { pathInput?: string; help?: boolean; error?: string } {
  let pathInput: string | undefined;
  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];
    if (arg === "--help" || arg === "-h") return { help: true };
    if (arg === optionName) {
      const value = args[index + 1];
      if (!value || value.startsWith("--")) return { error: `Missing value for ${optionName}.` };
      pathInput = value;
      index += 1;
      continue;
    }
    return { error: `Unknown ${verb} argument: ${arg}` };
  }
  if (!pathInput) return { error: `Missing required option: ${usage}.` };
  return { pathInput };
}

async function runWorkerRegister(
  args: string[],
  streams: OutputStreams,
  cwd: string,
  overrides: CliAdapterOverrides
): Promise<number> {
  const parsed = parseSinglePathOption(args, "--path", "--path <project>", "worker register");
  if (parsed.help) {
    streams.stdout.write("Usage: overmind worker register --path <project>\n");
    return 0;
  }
  if (parsed.error || !parsed.pathInput) {
    streams.stderr.write(
      `ERROR: ${parsed.error ?? "Missing required option: --path <project>."}\n`
    );
    return 2;
  }

  let result: Awaited<ReturnType<typeof registerWorker>>;
  try {
    result = await registerWorker(path.resolve(cwd, parsed.pathInput), {
      interaction: overrides.interaction ?? createTtyInteractionPort(),
      clock: overrides.clock ?? { now: () => new Date().toISOString() },
      uuid: overrides.uuid ?? { next: () => randomUUID() }
    });
  } catch (error) {
    if (error instanceof InteractionClosedError) {
      streams.stdout.write(
        "Execution stopped: user input stream closed during worker registration.\n"
      );
      return 0;
    }
    throw error;
  }
  if (!result.ok) {
    renderDiagnostics(result.diagnostics, streams);
    return 1;
  }
  streams.stdout.write(
    `new worker registered with uuid: ${result.uuid} - copy and pass this unique id to developer so he'll register worker on he's side\n`
  );
  return 0;
}

async function runWorkerAssign(
  args: string[],
  streams: OutputStreams,
  cwd: string,
  overrides: CliAdapterOverrides
): Promise<number> {
  const parsed = parseSinglePathOption(
    args,
    "--feature-path",
    "--feature-path <feature>",
    "worker assign"
  );
  if (parsed.help) {
    streams.stdout.write("Usage: overmind worker assign --feature-path <feature>\n");
    return 0;
  }
  if (parsed.error || !parsed.pathInput) {
    streams.stderr.write(
      `ERROR: ${parsed.error ?? "Missing required option: --feature-path <feature>."}\n`
    );
    return 2;
  }

  let result: Awaited<ReturnType<typeof assignWorkers>>;
  try {
    result = await assignWorkers(path.resolve(cwd, parsed.pathInput), {
      interaction: overrides.interaction ?? createTtyInteractionPort(),
      cwd
    });
  } catch (error) {
    if (error instanceof InteractionClosedError) {
      streams.stdout.write(
        "Execution stopped: user input stream closed during worker assignment.\n"
      );
      return 0;
    }
    throw error;
  }
  for (const assignment of result.stepAssignments) {
    streams.stdout.write(`Step ${assignment.stepId}: ${assignment.value}\n`);
  }
  if (!result.ok) {
    renderDiagnostics(result.diagnostics, streams);
    return 1;
  }
  streams.stdout.write("Assigned workers to implementation_plan.md\n");
  return 0;
}

interface ProjectReconcileOptions {
  path?: string;
}

function parseProjectReconcileOptions(args: string[]): {
  options: ProjectReconcileOptions;
  help?: boolean;
  error?: string;
} {
  const options: ProjectReconcileOptions = {};
  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];
    if (arg === "--help" || arg === "-h") return { options, help: true };
    if (arg === "--path") {
      const value = args[index + 1];
      if (value === undefined || value.startsWith("--")) {
        return { options, error: `Missing value for ${arg}.` };
      }
      options.path = value;
      index += 1;
      continue;
    }
    return { options, error: `Unknown project reconcile argument: ${arg}` };
  }
  return { options };
}

async function runProjectReconcile(
  args: string[],
  streams: OutputStreams,
  cwd: string,
  overrides: CliAdapterOverrides
): Promise<number> {
  const parsed = parseProjectReconcileOptions(args);
  if (parsed.help) {
    streams.stdout.write("Usage: overmind project reconcile [--path <project>]\n");
    return 0;
  }
  if (parsed.error) {
    streams.stderr.write(`ERROR: ${parsed.error}\n`);
    return 2;
  }

  const startPath = parsed.options.path
    ? path.resolve(cwd, parsed.options.path)
    : path.resolve(cwd);
  const workspace = detectRuntimeRoot(startPath);
  if (!workspace.path) {
    renderDiagnostics(workspace.diagnostics, streams);
    return 2;
  }
  const workspaceRoot = workspace.path;
  const projectsRoot = path.join(workspaceRoot, "projects");
  const interaction = overrides.interaction ?? createTtyInteractionPort();

  // Project selection mirrors `overmind run` (D2): explicit --path, single-project
  // auto-selection, or interactive selection with a command-specific finish choice.
  let projectRoot: string;
  let selectedInteractively = false;
  if (parsed.options.path) {
    const project = resolveProjectPath(path.resolve(cwd, parsed.options.path), projectsRoot);
    if (!project.path) {
      renderDiagnostics(project.diagnostics, streams);
      return 2;
    }
    projectRoot = project.path;
  } else {
    const discovered = discoverProjects(projectsRoot);
    if (discovered.paths.length === 0) {
      streams.stderr.write(`ERROR: No projects found under ${projectsRoot}\n`);
      return 2;
    }
    if (discovered.paths.length === 1) {
      projectRoot = discovered.paths[0]!;
      streams.stdout.write(`Selected project: ${path.relative(workspaceRoot, projectRoot)}\n`);
    } else {
      try {
        const selected = await interaction.select({
          message: "Choose project or finish:",
          options: [
            ...discovered.paths.map((candidate) => ({
              value: candidate,
              label: path.relative(workspaceRoot, candidate)
            })),
            { value: "__finish__", label: "Finish without running project reconcile" }
          ]
        });
        if (selected === "__finish__") {
          streams.stdout.write("Finished without selecting a project.\n");
          return 0;
        }
        projectRoot = selected;
        selectedInteractively = true;
      } catch (error) {
        if (error instanceof InteractionClosedError) {
          streams.stdout.write(
            "Execution stopped: user input stream closed during project selection.\n"
          );
          return 0;
        }
        throw error;
      }
    }
  }

  const projectPathRel = path.relative(workspaceRoot, projectRoot);
  if (selectedInteractively) {
    streams.stdout.write(
      "Updating class repositories runs the full project reconciliation flow, not just a repo attach.\n"
    );
    streams.stdout.write("'overmind project reconcile' will:\n");
    streams.stdout.write("  - prompt for each deferred class repository to attach,\n");
    streams.stdout.write(
      "  - run a one-time contract reconciliation session over newly ready classes, and\n"
    );
    streams.stdout.write("  - offer to commit the reconciliation results.\n");
    try {
      const confirmed = await interaction.confirm({
        message: `Proceed with attach + full reconciliation for project '${path.basename(projectRoot)}'?`
      });
      if (!confirmed) {
        streams.stdout.write(
          `Aborted: no changes made to project '${path.basename(projectRoot)}'.\n`
        );
        return 0;
      }
    } catch (error) {
      if (error instanceof InteractionClosedError) {
        streams.stdout.write(
          `Aborted: no changes made to project '${path.basename(projectRoot)}'.\n`
        );
        return 0;
      }
      throw error;
    }
  }

  const modelsPath = path.join(workspaceRoot, ".setup", "models.md");
  const overmindCliPath = path.join(workspaceRoot, ".overmind", "overmind.js");
  const executorDeps = {
    ...defaultStepExecutorDeps,
    agentRunner: overrides.agentRunner ?? new CodexAgentRunner()
  };

  try {
    const outcome = await runProjectReconciliationFlow({
      projectRoot,
      projectPathRel,
      interaction,
      git: new RepoGitProjectAdapter(),
      runReconciliationSession: async (classes) => {
        const result = await executeStep(
          PROJECT_RECONCILIATION_STEP,
          {
            step: PROJECT_RECONCILIATION_STEP,
            runtimeRoot: workspaceRoot,
            featurePath: projectPathRel,
            overmindCliPath,
            modelsPath,
            classes
          },
          executorDeps
        );
        return { ok: result.ok, diagnostics: result.diagnostics };
      },
      emit: (line) => streams.stdout.write(`${line}\n`),
      emitError: (line) => streams.stderr.write(`${line}\n`)
    });
    return mapReconcileOutcomeToExit(outcome, streams);
  } catch (error) {
    if (error instanceof InteractionClosedError) {
      streams.stdout.write("Execution stopped: user input stream closed during reconciliation.\n");
      return 0;
    }
    throw error;
  }
}

function mapReconcileOutcomeToExit(
  outcome: ProjectReconciliationOutcome,
  streams: OutputStreams
): number {
  switch (outcome.kind) {
    case "completed":
    case "noPendingWork":
    case "stoppedByOperator":
      return 0;
    case "startupError":
    case "failed":
      renderDiagnostics(outcome.diagnostics, streams);
      return 1;
  }
}

interface RunOptions {
  path?: string;
  resume?: string;
}

function parseRunOptions(args: string[]): { options: RunOptions; help?: boolean; error?: string } {
  const options: RunOptions = {};
  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];
    if (arg === "--help" || arg === "-h") {
      return { options, help: true };
    }
    if (arg === "--path" || arg === "--resume") {
      const value = args[index + 1];
      if (value === undefined || value.startsWith("--")) {
        return { options, error: `Missing value for ${arg}.` };
      }
      if (arg === "--path") options.path = value;
      else options.resume = value;
      index += 1;
      continue;
    }
    return { options, error: `Unknown run argument: ${arg}` };
  }
  return { options };
}

async function runRun(
  args: string[],
  streams: OutputStreams,
  cwd: string,
  overrides: CliAdapterOverrides
): Promise<number> {
  const parsed = parseRunOptions(args);
  if (parsed.help) {
    streams.stdout.write("Usage: overmind run [--path <project>] [--resume <step>]\n");
    return 0;
  }
  if (parsed.error) {
    streams.stderr.write(`ERROR: ${parsed.error}\n`);
    return 2;
  }

  const startPath = parsed.options.path
    ? path.resolve(cwd, parsed.options.path)
    : path.resolve(cwd);
  const workspace = detectRuntimeRoot(startPath);
  if (!workspace.path) {
    renderDiagnostics(workspace.diagnostics, streams);
    return 2;
  }
  const workspaceRoot = workspace.path;
  const projectsRoot = path.join(workspaceRoot, "projects");

  const interaction = overrides.interaction ?? createTtyInteractionPort();

  // Resolve the target project (explicit path, auto-select one, or interactive).
  let projectRoot: string;
  if (parsed.options.path) {
    const project = resolveProjectPath(path.resolve(cwd, parsed.options.path), projectsRoot);
    if (!project.path) {
      renderDiagnostics(project.diagnostics, streams);
      return 2;
    }
    projectRoot = project.path;
  } else {
    const discovered = discoverProjects(projectsRoot);
    if (discovered.paths.length === 0) {
      streams.stderr.write(`ERROR: No projects found under ${projectsRoot}\n`);
      return 2;
    }
    if (discovered.paths.length === 1) {
      projectRoot = discovered.paths[0]!;
      streams.stdout.write(`Selected project: ${path.relative(workspaceRoot, projectRoot)}\n`);
    } else {
      try {
        const selected = await interaction.select({
          message: "Choose project or finish:",
          options: [
            ...discovered.paths.map((candidate) => ({
              value: candidate,
              label: path.relative(workspaceRoot, candidate)
            })),
            { value: "__finish__", label: "Finish without running overmind run" }
          ]
        });
        if (selected === "__finish__") {
          streams.stdout.write("Finished without selecting a project.\n");
          return 0;
        }
        projectRoot = selected;
      } catch (error) {
        if (error instanceof InteractionClosedError) {
          streams.stdout.write(
            "Execution stopped: user input stream closed during project selection.\n"
          );
          return 0;
        }
        throw error;
      }
    }
  }

  const projectPathRel = path.relative(workspaceRoot, projectRoot);
  const modelsPath = path.join(workspaceRoot, ".setup", "models.md");

  // D8: validate runner config for the model phases the planned execution can
  // reach — from the resume step, or the whole catalog for a default run whose
  // start step is only known after feature selection. An unresolvable --resume
  // is left for runFeatureFlow to report as an unsupported-resume error.
  const plannedStartIndex = resolvePlannedStartIndex(parsed.options.resume);
  if (plannedStartIndex !== undefined) {
    const configDiagnostics = validateRunnerConfigForCatalog(modelsPath, plannedStartIndex);
    if (configDiagnostics.length > 0) {
      renderDiagnostics(configDiagnostics, streams);
      return 1;
    }
  }

  const outcome = await runFeatureFlow({
    workspaceRoot,
    projectRoot,
    projectPathRel,
    ...(parsed.options.resume ? { resumeInput: parsed.options.resume } : {}),
    interaction,
    executorDeps: {
      ...defaultStepExecutorDeps,
      agentRunner: overrides.agentRunner ?? new CodexAgentRunner()
    },
    checkpoint: overrides.checkpoint ?? new RepoGitAdapter(),
    clock: overrides.clock ?? { now: () => Math.floor(Date.now() / 1000) },
    overmindCliPath: path.join(workspaceRoot, ".overmind", "overmind.js"),
    modelsPath,
    emit: (line) => streams.stdout.write(`${line}\n`),
    emitError: (line) => streams.stderr.write(`${line}\n`)
  });

  return mapOutcomeToExit(outcome, projectPathRel, streams);
}

/**
 * Catalog index the planned execution starts from: the resolved `--resume` step,
 * `0` (whole catalog) for a default run, or `undefined` when `--resume` is
 * unsupported so config validation is skipped and the unsupported-resume error
 * surfaces from the flow instead.
 */
function resolvePlannedStartIndex(resume: string | undefined): number | undefined {
  if (!resume) return 0;
  const resolved = resolveStep(resume);
  if (!resolved.stepId) return undefined;
  return STEP_CATALOG.findIndex((step) => step.id === resolved.stepId);
}

function validateRunnerConfigForCatalog(modelsPath: string, startIndex: number): Diagnostic[] {
  const config = loadRunnerConfig(modelsPath);
  const phases = new Set<string>();
  for (const step of STEP_CATALOG.slice(startIndex)) {
    for (const action of step.actions) {
      if (action.kind === "session") phases.add(action.modelPhase);
    }
  }
  const diagnostics: Diagnostic[] = [];
  for (const phase of phases) {
    const resolved = resolveRunnerPhase(config, phase);
    if (!resolved.config) diagnostics.push(...resolved.diagnostics);
  }
  return diagnostics;
}

function mapOutcomeToExit(
  outcome: FeatureFlowOutcome,
  projectPathRel: string,
  streams: OutputStreams
): number {
  switch (outcome.kind) {
    case "completed":
    case "finished":
    case "stoppedByOperator":
      return 0;
    case "refusedPendingWork":
      for (const line of outcome.guidance) streams.stderr.write(`${line}\n`);
      return 1;
    case "startupError":
      renderDiagnostics(outcome.diagnostics, streams);
      return 1;
    case "failed":
      renderDiagnostics(outcome.diagnostics, streams);
      streams.stderr.write(
        `Fix the error above and restart. It will continue from the correct step:\n` +
          `  overmind run --path ${projectPathRel} --resume ${outcome.resumeStep}\n`
      );
      return 1;
  }
}

async function runScaffold(
  subcommand: string | undefined,
  args: string[],
  streams: OutputStreams,
  cwd: string,
  overrides: CliAdapterOverrides
): Promise<number> {
  if (subcommand !== "feature") {
    streams.stderr.write("ERROR: Usage: overmind scaffold feature --path <project>\n");
    return 2;
  }
  let pathInput: string | undefined;
  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];
    if (arg === "--path") {
      const value = args[index + 1];
      if (value === undefined || value.startsWith("--")) {
        streams.stderr.write("ERROR: Missing value for --path.\n");
        return 2;
      }
      pathInput = value;
      index += 1;
      continue;
    }
    streams.stderr.write(`ERROR: Unknown scaffold argument: ${arg}\n`);
    return 2;
  }
  if (!pathInput) {
    streams.stderr.write("ERROR: Missing required option: --path <project>.\n");
    return 2;
  }

  const startPath = path.resolve(cwd, pathInput);
  const workspace = detectRuntimeRoot(startPath);
  if (!workspace.path) {
    renderDiagnostics(workspace.diagnostics, streams);
    return 2;
  }

  try {
    const result = await scaffoldFeature(workspace.path, startPath, {
      interaction: overrides.interaction ?? createTtyInteractionPort(),
      clock: overrides.clock ?? { now: () => Math.floor(Date.now() / 1000) },
      emit: (line) => streams.stdout.write(`${line}\n`)
    });
    if (result.diagnostics.length > 0) {
      renderDiagnostics(result.diagnostics, streams);
      return 2;
    }
    return 0;
  } catch (error) {
    if (error instanceof InteractionClosedError) {
      streams.stdout.write("Execution stopped: user input stream closed during scaffold input.\n");
      return 0;
    }
    throw error;
  }
}

function renderDiagnostics(diagnostics: Diagnostic[], streams: OutputStreams): void {
  for (const diagnostic of diagnostics) {
    streams.stderr.write(`${diagnostic.source}: ${diagnostic.reason}\n`);
  }
}

function runStatus(
  inputPath: string | undefined,
  extraArgs: string[],
  streams: OutputStreams
): number {
  if (!inputPath || extraArgs.length > 0) {
    streams.stderr.write("ERROR: Usage: overmind status <path>\n");
    return 2;
  }
  const absoluteInput = path.resolve(inputPath);
  const workspace = detectRuntimeRoot(absoluteInput);
  if (!workspace.path) {
    for (const diagnostic of workspace.diagnostics) {
      streams.stderr.write(`${diagnostic.source}: ${diagnostic.reason}\n`);
    }
    return 2;
  }
  const project = resolveProjectPath(absoluteInput, path.join(workspace.path, "projects"));
  if (!project.path) {
    for (const diagnostic of project.diagnostics) {
      streams.stderr.write(`${diagnostic.source}: ${diagnostic.reason}\n`);
    }
    return 2;
  }
  const resolvedInput = realpathSync(absoluteInput);
  const featureRoot = resolvedInput === project.path ? undefined : resolvedInput;
  const report = evaluate(workspace.path, project.path, featureRoot);
  const renderedReport = featureRoot
    ? report
    : { ...report, steps: report.steps.filter((candidate) => candidate.scope === "project") };
  streams.stdout.write(`${formatChecklist(renderedReport)}\n`);
  for (const diagnostic of report.diagnostics) {
    streams.stderr.write(`${diagnostic.source}: ${diagnostic.reason}\n`);
  }
  return report.diagnostics.some((diagnostic) => diagnostic.severity === "error") ? 2 : 0;
}

function runGate(
  step: string | undefined,
  targetPath: string | undefined,
  args: string[],
  streams: OutputStreams
): number {
  if (!step || !targetPath) {
    streams.stderr.write("ERROR: Usage: overmind gate <step> <path>\n");
    return 2;
  }

  const classValidator = classGateRegistry[step];
  let result: GateResult;
  if (classValidator) {
    const parsed = parseClassOption(args, "gate");
    if (parsed.error || !parsed.klass) {
      streams.stderr.write(`ERROR: ${parsed.error ?? "Missing required option: --class."}\n`);
      return 2;
    }
    result = classValidator(targetPath, parsed.klass);
  } else {
    const validator = gateRegistry[step];
    if (!validator) {
      streams.stderr.write(`ERROR: Unknown gate step: ${step}\n`);
      return 2;
    }
    result =
      step === "br-clarification"
        ? validateBrClarification(targetPath, process.cwd(), {
            onProgress: (line) => streams.stdout.write(`${line}\n`)
          })
        : validator(targetPath);
  }
  if (result.exitCode === 0) {
    streams.stdout.write(`${result.passMessage}\n`);
    return 0;
  }
  if (result.exitCode === 1) {
    streams.stdout.write("business-context gate failed\n");
    for (const problem of result.problems) {
      streams.stdout.write(`missing: ${problem}\n`);
    }
    return 1;
  }

  streams.stderr.write(`ERROR: ${result.errorMessage ?? "Validation cannot run."}\n`);
  return 2;
}

function runContext(
  step: string | undefined,
  featurePath: string | undefined,
  args: string[],
  streams: OutputStreams,
  cwd = process.cwd()
): number {
  if (!step || !featurePath) {
    streams.stderr.write("ERROR: Usage: overmind context <step> <path>\n");
    return 2;
  }

  if (step === "contract-reconciliation") {
    const parsed = parseClassListOption(args, "context");
    if (parsed.error) {
      streams.stderr.write(`ERROR: ${parsed.error}\n`);
      return 2;
    }
    const result = buildContractReconciliationContext(featurePath, parsed.classes, cwd);
    if (result.exitCode === 0) {
      streams.stdout.write(result.text ?? "");
      return 0;
    }
    const errMsg = result.errorMessage ?? "Context cannot be assembled.";
    streams.stderr.write(result.verbatim ? `${errMsg}\n` : `ERROR: ${errMsg}\n`);
    return 2;
  }

  if (step === "common-contract") {
    const parsed = parseOptionalClassListOption(args, "context");
    if (parsed.error) {
      streams.stderr.write(`ERROR: ${parsed.error}\n`);
      return 2;
    }
    const result = buildCommonContractInitContext(featurePath, parsed.classes, cwd);
    if (result.exitCode === 0) {
      streams.stdout.write(result.text ?? "");
      return 0;
    }
    const errMsg = result.errorMessage ?? "Context cannot be assembled.";
    streams.stderr.write(result.verbatim ? `${errMsg}\n` : `ERROR: ${errMsg}\n`);
    return 2;
  }

  const classBuilder = classContextRegistry[step];
  let result: ContextResult;
  if (classBuilder) {
    const parsed = parseClassOption(args, "context");
    if (parsed.error || !parsed.klass) {
      streams.stderr.write(`ERROR: ${parsed.error ?? "Missing required option: --class."}\n`);
      return 2;
    }
    result = classBuilder(featurePath, parsed.klass, cwd);
  } else {
    const builder = contextRegistry[step];
    if (!builder) {
      streams.stderr.write(`ERROR: Unknown context step: ${step}\n`);
      return 2;
    }
    result = builder(featurePath);
  }
  if (result.exitCode === 0) {
    streams.stdout.write(result.text ?? "");
    return 0;
  }

  const errMsg = result.errorMessage ?? "Context cannot be assembled.";
  streams.stderr.write(result.verbatim ? `${errMsg}\n` : `ERROR: ${errMsg}\n`);
  return 2;
}

function runCapture(
  step: string | undefined,
  featurePath: string | undefined,
  args: string[],
  streams: OutputStreams
): number {
  if (!step || !featurePath) {
    streams.stderr.write(
      "ERROR: Usage: overmind capture <step> <feature_path> (--source-file <path> | --jira <ticket>) [--overwrite]\n"
    );
    return 2;
  }

  const capture = captureRegistry[step];
  if (!capture) {
    streams.stderr.write(`ERROR: Unknown capture step: ${step}\n`);
    return 2;
  }

  const parsed = parseCaptureOptions(args);
  if (parsed.error) {
    streams.stderr.write(`ERROR: ${parsed.error}\n`);
    return 2;
  }

  const result = capture(featurePath, parsed.options);
  if (result.exitCode === 0) {
    streams.stdout.write(`${result.message ?? "capture complete"}\n`);
    return 0;
  }

  streams.stderr.write(`ERROR: ${result.errorMessage ?? "Capture cannot run."}\n`);
  return 2;
}

function runSync(
  step: string | undefined,
  featurePath: string | undefined,
  args: string[],
  streams: OutputStreams
): number {
  if (!step || !featurePath) {
    streams.stderr.write("ERROR: Usage: overmind sync <step> <feature_path>\n");
    return 2;
  }

  const classSyncer = classSyncRegistry[step];
  let result: SyncStepResult;
  if (classSyncer) {
    const parsed = parseClassOption(args, "sync");
    if (parsed.error || !parsed.klass) {
      streams.stderr.write(`ERROR: ${parsed.error ?? "Missing required option: --class."}\n`);
      return 2;
    }
    result = classSyncer(featurePath, parsed.klass);
  } else {
    const syncer = syncRegistry[step];
    if (!syncer) {
      streams.stderr.write(`ERROR: Unknown sync step: ${step}\n`);
      return 2;
    }
    result = syncer(featurePath);
  }
  if (result.exitCode === 0) {
    const count = result.syncedCount ?? 0;
    streams.stdout.write(
      count === 0 ? "No ready repos to sync.\n" : `Synced ${count} repo(s) to default branch.\n`
    );
    return 0;
  }

  if (result.blockedMessages && result.blockedMessages.length > 0) {
    for (const msg of result.blockedMessages) {
      streams.stderr.write(`${msg}\n`);
    }
    return 2;
  }

  streams.stderr.write(`ERROR: ${result.errorMessage ?? "Sync cannot run."}\n`);
  return 2;
}

function runReadiness(
  step: string | undefined,
  featurePath: string | undefined,
  streams: OutputStreams
): number {
  if (!step || !featurePath) {
    streams.stderr.write("ERROR: Usage: overmind readiness <step> <feature_path>\n");
    streams.stderr.write(
      "ERROR: Usage: overmind <capture|context|gate|sync|readiness> <step> <path>\n"
    );
    return 2;
  }

  const checker = readinessRegistry[step];
  if (!checker) {
    streams.stderr.write(`ERROR: Unknown readiness step: ${step}\n`);
    return 2;
  }

  const result = checker(featurePath);
  if (result.exitCode === 0) {
    streams.stdout.write(`${result.message ?? "readiness check passed"}\n`);
    return 0;
  }
  if (result.exitCode === 1) {
    streams.stdout.write("business-context gate failed\n");
    for (const problem of result.problems ?? []) {
      streams.stdout.write(`missing: ${problem}\n`);
    }
    return 1;
  }

  streams.stderr.write(`ERROR: ${result.errorMessage ?? "Readiness cannot run."}\n`);
  return 2;
}

function parseCaptureOptions(args: string[]): { options: CaptureOptions; error?: string } {
  const options: CaptureOptions = {};

  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];
    if (arg === "--source-file") {
      const value = args[index + 1];
      if (!value || value.startsWith("--")) {
        return { options, error: "Missing value for --source-file." };
      }
      options.sourceFile = value;
      index += 1;
      continue;
    }
    if (arg === "--jira") {
      const value = args[index + 1];
      if (!value || value.startsWith("--")) {
        return { options, error: "Missing value for --jira." };
      }
      options.jira = value;
      index += 1;
      continue;
    }
    if (arg === "--overwrite") {
      options.overwrite = true;
      continue;
    }
    return { options, error: `Unknown capture argument: ${arg}` };
  }

  return { options };
}
