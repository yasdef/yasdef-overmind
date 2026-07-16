import {
  existsSync,
  mkdirSync,
  readFileSync,
  realpathSync,
  statSync,
  writeFileSync
} from "node:fs";
import path from "node:path";

import type { PathInspectionResult, ProjectGitPort } from "../git/index.js";
import type { InteractionPort } from "../interaction/index.js";
import { readProjectDefinitionMetadata } from "../parse/project-definition.js";
import {
  resolveProjectInitOwnership,
  type ProjectInitOwnership
} from "../orchestrator/project-init-ownership.js";
import type { Diagnostic } from "../types/index.js";

/** Injected clock; returns the Unix timestamp (seconds) appended to feature folder names. */
export interface ScaffoldClock {
  now(): number;
}

export interface ScaffoldFeatureDeps {
  interaction: InteractionPort;
  clock: ScaffoldClock;
  projectGit: ProjectGitPort;
  /** Optional overrides used when the caller already has id/title (CLI/tests). */
  featureId?: string;
  featureTitle?: string;
  /** Absolute template path; defaults to `<runtimeRoot>/.templates/feature_br_summary_TEMPLATE.md`. */
  templatePath?: string;
  /** Human-readable progress sink (CLI wires stderr); collected notices are also returned. */
  emit?: (line: string) => void;
}

export interface ScaffoldFeatureResult {
  /** Workspace-relative created feature directory (consumed directly, never scraped). */
  featurePath?: string;
  /** Workspace-relative `feature_br_summary.md` path. */
  outputPath?: string;
  notices: string[];
  diagnostics: Diagnostic[];
}

const TEMPLATE_RELATIVE = path.join(".templates", "feature_br_summary_TEMPLATE.md");

const PROJECT_TYPE_LABELS: Record<string, string> = {
  A: "New project",
  B: "Existing project with partial context",
  C: "Existing project with code-first context"
};

/**
 * Deterministic feature capture primitive (port of `feature_br_scaffold.sh`).
 * Resolves a project inside the workspace, loads its type metadata, collects a
 * feature id/title through the interaction port, normalizes the folder name with
 * an injected timestamp, and renders the BR summary template — returning the
 * created paths as typed fields rather than stdout to scrape.
 */
export async function scaffoldFeature(
  runtimeRoot: string,
  projectPathInput: string,
  deps: ScaffoldFeatureDeps
): Promise<ScaffoldFeatureResult> {
  const notices: string[] = [];
  const emit = (line: string): void => {
    notices.push(line);
    deps.emit?.(line);
  };
  const fail = (reason: string): ScaffoldFeatureResult => ({
    notices,
    diagnostics: [{ severity: "error", source: "scaffold-feature", reason }]
  });

  const normalizedInput = projectPathInput.replace(/^\.\//, "").replace(/\/+$/, "");
  if (normalizedInput.trim() === "") return fail("path must not be empty.");

  const candidate = path.isAbsolute(normalizedInput)
    ? normalizedInput
    : path.join(runtimeRoot, normalizedInput);
  if (!existsSync(candidate) || !statSync(candidate).isDirectory()) {
    return fail(`Project path directory not found: ${projectPathInput}`);
  }

  let runtimeRootResolved: string;
  let projectResolved: string;
  try {
    runtimeRootResolved = realpathSync(runtimeRoot);
    projectResolved = realpathSync(candidate);
  } catch (error) {
    return fail(`Failed to resolve project path: ${message(error)}`);
  }
  if (!projectResolved.startsWith(runtimeRootResolved + path.sep)) {
    return fail(`Path must resolve inside ASDLC workspace: ${projectResolved}`);
  }

  const projectRoot = resolveDefinitionAncestor(runtimeRootResolved, projectResolved);
  if (!projectRoot) {
    return fail(
      `Project path must resolve to a project-level folder containing init_progress_definition.yaml: ${projectPathInput}`
    );
  }

  const definitionPath = path.join(projectRoot, "init_progress_definition.yaml");
  const templatePath = deps.templatePath ?? path.join(runtimeRootResolved, TEMPLATE_RELATIVE);
  if (!existsSync(templatePath)) return fail(`Required file not found: ${TEMPLATE_RELATIVE}`);
  if (!existsSync(definitionPath))
    return fail("Required file not found: init_progress_definition.yaml");

  const meta = readProjectTypeMeta(definitionPath);
  if (!meta) return fail("Unable to load project metadata for BR scaffold init.");

  const projectPathRel = path.relative(runtimeRootResolved, projectRoot);
  // Applicable step 1.1 stack/agent-guidelines paths (type A only) are part of the
  // initial baseline the checkpoint gate must inspect, not just the shared files.
  const ownership = resolveProjectInitOwnership(readProjectDefinitionMetadata(definitionPath));
  const checkpoint = classifyPendingProjectCheckpoint(
    projectRoot,
    projectPathRel,
    deps.projectGit,
    ownership
  );
  if (checkpoint.kind === "blocked") {
    return fail(checkpoint.reason);
  }
  if (checkpoint.kind === "pending") {
    return fail(
      `Pending ${checkpoint.boundary} checkpoint must be completed before feature scaffolding. Run ${checkpoint.command}.`
    );
  }

  // A new feature must not start on top of uncommitted work (CRP-169 D6). The
  // mid-run checkpoints stage the whole project root, so a previous feature's
  // artifacts — including work whose completion commit the operator declined —
  // would otherwise be swept into this feature's commits. Continuing an existing
  // feature is unaffected: uncommitted work there belongs to that feature.
  const worktree = deps.projectGit.worktreeStatus(projectRoot);
  if (worktree.kind === "dirty") {
    return fail(
      `Project worktree has uncommitted changes, so a new feature cannot be started: ${formatDirtyPaths(worktree.paths)}. Commit or discard them, then retry with overmind run --path ${projectPathRel}. Continuing an existing feature does not require a clean worktree.`
    );
  }
  if (worktree.kind !== "clean") {
    return fail(
      `Unable to inspect the project worktree before feature scaffolding for ${projectPathRel}: ${describePathInspectionFailure(worktree)}. Resolve project Git inspection, then retry starting the feature with overmind run --path ${projectPathRel}.`
    );
  }

  const featureId = await requireInput(deps, "Feature ID:", deps.featureId, emit);
  const featureTitle = await requireInput(deps, "Feature title:", deps.featureTitle, emit);

  const normalizedName = normalizeFeatureFolderName(featureTitle);
  if (normalizedName === "") {
    return fail("Feature title must contain at least one letter or digit.");
  }

  const timestamp = deps.clock.now();
  if (!Number.isInteger(timestamp) || timestamp < 0) {
    return fail("Failed to generate unix timestamp for feature folder name.");
  }

  const featureDir = path.join(projectRoot, `${normalizedName}-${timestamp}`);
  const outputFile = path.join(featureDir, "feature_br_summary.md");
  if (existsSync(featureDir)) {
    return fail(
      `Target feature folder already exists: ${path.relative(runtimeRootResolved, featureDir)}`
    );
  }

  let template: string;
  try {
    template = readFileSync(templatePath, "utf8");
  } catch (error) {
    return fail(`Template file not found: ${message(error)}`);
  }

  const rendered = renderSummary(template, {
    featureId,
    featureTitle,
    code: meta.code,
    label: meta.label
  });

  try {
    mkdirSync(featureDir, { recursive: true });
    writeFileSync(outputFile, rendered);
  } catch (error) {
    return fail(`Failed to write feature summary: ${message(error)}`);
  }

  const featurePath = path.relative(runtimeRootResolved, featureDir);
  const outputPath = path.relative(runtimeRootResolved, outputFile);
  emit(`Created feature folder: ${featurePath}`);
  emit(`Updated ${outputPath}`);

  return { featurePath, outputPath, notices, diagnostics: [] };
}

function classifyPendingProjectCheckpoint(
  projectRoot: string,
  projectPathRel: string,
  projectGit: ProjectGitPort,
  ownership: ProjectInitOwnership
):
  | { kind: "ready" }
  | { kind: "blocked"; reason: string }
  | { kind: "pending"; boundary: string; command: string } {
  if (!projectGit.inspectPaths) {
    return {
      kind: "blocked",
      reason: `Unable to inspect project checkpoint state before feature scaffolding for ${projectPathRel}: project Git adapter does not support path-scoped inspection. Resolve project Git inspection, then retry starting the feature with overmind run --path ${projectPathRel}.`
    };
  }

  // Inspect the whole initial baseline: the shared project-definition files and,
  // for type A, the applicable step 1.1 stack/agent-guidelines artifacts.
  const inspect = projectGit.inspectPaths(projectRoot, ownership.initialBaselinePaths);
  if (inspect.kind === "ok") {
    const byPath = new Map(inspect.paths.map((entry) => [entry.path, entry]));
    const common = byPath.get("common_contract_definition.md");
    const dirtyShared = ownership.sharedProjectDefinitionPaths.some((candidate) => {
      const entry = byPath.get(candidate);
      return entry ? entry.staged || entry.unstaged || entry.untracked : false;
    });

    // Post-baseline shared-file change is a reconciliation checkpoint, taking
    // precedence over pre-baseline init checkpoint state (crp-160 contract).
    if (dirtyShared && common?.hasHeadVersion) {
      return {
        kind: "pending",
        boundary: "project reconciliation",
        command: `overmind project reconcile --path ${projectPathRel}`
      };
    }
    // Pre-baseline init: the shared baseline is not committed, or an applicable
    // step 1.1 artifact that already exists has no finalized checkpoint.
    const step11CheckpointPending = ownership.step11Paths.some((candidate) => {
      if (!existsSync(path.join(projectRoot, candidate))) return false;
      const entry = byPath.get(candidate);
      return entry ? !entry.hasHeadVersion : false;
    });
    if (dirtyShared || !common?.hasHeadVersion || step11CheckpointPending) {
      return {
        kind: "pending",
        boundary: "project initialization",
        command: `overmind project init --path ${projectPathRel}`
      };
    }
    return { kind: "ready" };
  }
  return {
    kind: "blocked",
    reason: `Unable to inspect project checkpoint state before feature scaffolding for ${projectPathRel}: ${describePathInspectionFailure(inspect)}. Resolve project Git inspection, then retry starting the feature with overmind run --path ${projectPathRel}.`
  };
}

const MAX_LISTED_DIRTY_PATHS = 5;

/** Name the uncommitted paths that block a new feature, capped so the refusal stays readable. */
function formatDirtyPaths(paths: string[]): string {
  const remaining = paths.length - MAX_LISTED_DIRTY_PATHS;
  const listed = paths.slice(0, MAX_LISTED_DIRTY_PATHS).join(", ");
  return remaining > 0 ? `${listed} (and ${remaining} more)` : listed;
}

function describePathInspectionFailure(
  inspect: Exclude<PathInspectionResult, { kind: "ok" }>
): string {
  switch (inspect.kind) {
    case "unavailable":
      return "git is not available";
    case "notWorktree":
      return "project root is not a git worktree";
    case "inspectionFailed":
      return `git inspection failed with exit code ${inspect.exitCode}: ${inspect.stderr.trim()}`;
  }
}

async function requireInput(
  deps: ScaffoldFeatureDeps,
  message: string,
  preset: string | undefined,
  emit: (line: string) => void
): Promise<string> {
  if (preset !== undefined && preset.trim() !== "") return preset.trim();
  for (;;) {
    const value = (await deps.interaction.input({ message })).trim();
    if (value !== "") return value;
    emit("Input cannot be empty.");
  }
}

function resolveDefinitionAncestor(
  runtimeRoot: string,
  projectResolved: string
): string | undefined {
  let current = projectResolved;
  for (;;) {
    if (existsSync(path.join(current, "init_progress_definition.yaml"))) {
      // The definition must sit below the runtime root, never at it.
      return current !== runtimeRoot ? current : undefined;
    }
    if (current === runtimeRoot) return undefined;
    const parent = path.dirname(current);
    if (parent === current || !parent.startsWith(runtimeRoot)) return undefined;
    current = parent;
  }
}

/** Read `project_type_code`/`project_type_label` and validate their pairing. */
function readProjectTypeMeta(definitionPath: string): { code: string; label: string } | undefined {
  let content: string;
  try {
    content = readFileSync(definitionPath, "utf8");
  } catch {
    return undefined;
  }
  const lines = content.split(/\r?\n/);
  const metaStart = lines.findIndex((line) => /^meta_info:\s*$/.test(line));
  if (metaStart < 0) return undefined;
  let code: string | undefined;
  let label: string | undefined;
  for (const line of lines.slice(metaStart + 1)) {
    if (/^\S/.test(line)) break;
    const codeMatch = line.match(/^\s{2}project_type_code:\s*(.*)$/);
    if (codeMatch) code = scalar(codeMatch[1]!);
    const labelMatch = line.match(/^\s{2}project_type_label:\s*(.*)$/);
    if (labelMatch) label = scalar(labelMatch[1]!);
  }
  if (!code || !label) return undefined;
  if (PROJECT_TYPE_LABELS[code] !== label) return undefined;
  return { code, label };
}

/** Lowercase, collapse non-alphanumeric runs to underscores, trim/dedupe underscores. */
export function normalizeFeatureFolderName(raw: string): string {
  return raw
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "_")
    .replace(/^_+/, "")
    .replace(/_+$/, "")
    .replace(/_+/g, "_");
}

function renderSummary(
  template: string,
  values: { featureId: string; featureTitle: string; code: string; label: string }
): string {
  return template
    .replaceAll("- feature_id: [UNFILLED]", `- feature_id: ${values.featureId}`)
    .replaceAll("- feature_title: [UNFILLED]", `- feature_title: ${values.featureTitle}`)
    .replaceAll("{{PROJECT_TYPE_CODE}}", values.code)
    .replaceAll("{{PROJECT_TYPE_LABEL}}", values.label)
    .replaceAll("- ready_to_ears: [UNFILLED]", "- ready_to_ears: false");
}

function scalar(value: string): string {
  const trimmed = value.trim().replace(/\s+#.*$/, "");
  if (
    (trimmed.startsWith('"') && trimmed.endsWith('"')) ||
    (trimmed.startsWith("'") && trimmed.endsWith("'"))
  ) {
    return trimmed.slice(1, -1);
  }
  return trimmed;
}

function message(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}
