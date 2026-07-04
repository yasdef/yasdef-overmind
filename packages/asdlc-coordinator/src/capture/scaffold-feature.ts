import {
  existsSync,
  mkdirSync,
  readFileSync,
  realpathSync,
  statSync,
  writeFileSync
} from "node:fs";
import path from "node:path";

import type { InteractionPort } from "../interaction/index.js";
import type { Diagnostic } from "../types/index.js";

/** Injected clock; returns the Unix timestamp (seconds) appended to feature folder names. */
export interface ScaffoldClock {
  now(): number;
}

export interface ScaffoldFeatureDeps {
  interaction: InteractionPort;
  clock: ScaffoldClock;
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
