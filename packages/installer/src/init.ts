import {
  chmodSync,
  cpSync,
  existsSync,
  lstatSync,
  mkdirSync,
  readdirSync,
  rmSync,
  statSync,
  writeFileSync
} from "node:fs";
import { homedir } from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

import { getBundledOvermindPath } from "asdlc-coordinator";

const PACKAGED_SKILLS = [
  "overmind-task-to-br",
  "overmind-repo-br-scan",
  "overmind-br-clarification",
  "overmind-requirements-ears",
  "overmind-ears-review",
  "overmind-stack-blueprint",
  "overmind-agents-md",
  "overmind-common-contract",
  "overmind-contract-delta",
  "overmind-surface-map",
  "overmind-surface-map-enrich",
  "overmind-technical-requirements",
  "overmind-implementation-slices",
  "overmind-prerequisite-gaps",
  "overmind-implementation-plan",
  "overmind-plan-semantic-review",
  "overmind-contract-reconciliation"
] as const;

// Skills whose source directory intentionally has no assets/ subdirectory.
const ASSETLESS_SKILLS = new Set<string>(["overmind-surface-map-enrich"]);

// Supported local runner skill directories for this change. The packaged skill

// is installed under "<runner>/skills/<skill-name>" for each entry. The shared
// runtime CLI (`.overmind/overmind.js`) is intentionally NOT part of this set.
const SUPPORTED_RUNNER_SKILL_DIRS = [".codex", ".claude"] as const;

const RUNTIME_TEMPLATE_FILES = [
  "init_progress_definition_TEMPLATE.yaml",
  "feature_br_summary_TEMPLATE.md"
] as const;

const SETUP_DEFAULT_FILES = ["models.md", "external_sources.yaml"] as const;

export interface InstallResult {
  projectRoot: string;
  cliPath: string;
  // All installed runner skill paths for this install (Codex + Claude × all skills).
  skillPaths: string[];
  templatePaths: string[];
  setupPaths: string[];
  quickrunPath: string;
}

export type InstallTargetClassification =
  | { kind: "clean-install" }
  | { kind: "update" }
  | { kind: "refuse-not-empty" }
  | { kind: "refuse-not-directory" };

export function classifyInstallTarget(targetPath: string): InstallTargetClassification {
  let pathEntryStat: ReturnType<typeof lstatSync>;
  try {
    pathEntryStat = lstatSync(targetPath);
  } catch (error) {
    if (isNodeError(error) && error.code === "ENOENT") {
      return { kind: "clean-install" };
    }
    throw error;
  }

  let targetStat = pathEntryStat;
  if (pathEntryStat.isSymbolicLink()) {
    try {
      targetStat = statSync(targetPath);
    } catch (error) {
      if (isNodeError(error) && error.code === "ENOENT") {
        return { kind: "refuse-not-directory" };
      }
      throw error;
    }
  }

  if (!targetStat.isDirectory()) {
    return { kind: "refuse-not-directory" };
  }

  if (existsSync(path.join(targetPath, "asdlc_metadata.yaml"))) {
    return { kind: "update" };
  }

  return readdirSync(targetPath).length === 0
    ? { kind: "clean-install" }
    : { kind: "refuse-not-empty" };
}

export function resolveInstallTarget(inputPath: string, cwd = process.cwd()): string {
  const trimmed = inputPath.trim();
  if (trimmed === "~") {
    return homedir();
  }
  if (trimmed.startsWith("~/")) {
    return path.resolve(homedir(), trimmed.slice(2));
  }
  if (trimmed.startsWith("~")) {
    throw new Error(`Unsupported home path syntax: ${trimmed}. Use ~ or ~/.`);
  }
  return path.resolve(cwd, trimmed);
}

export function installProject(projectRoot: string): InstallResult {
  if (projectRoot === undefined) {
    throw new Error("installProject requires an explicit projectRoot");
  }

  const resolvedProjectRoot = path.resolve(projectRoot);
  const bundledCliPath = getBundledOvermindPath();
  const pkgRoot = packageRoot();
  validateRequiredSources(pkgRoot, bundledCliPath);

  const cliPath = installCli(resolvedProjectRoot, bundledCliPath);
  const allSkillPaths = installSkills(resolvedProjectRoot, pkgRoot);
  const templatePaths = installRuntimeTemplates(resolvedProjectRoot, pkgRoot);
  const setupPaths = installSetupDefaults(resolvedProjectRoot, pkgRoot);
  installWorkspaceScaffold(resolvedProjectRoot);
  const quickrunPath = writeQuickrunGuide(resolvedProjectRoot);

  return {
    projectRoot: resolvedProjectRoot,
    cliPath,
    skillPaths: allSkillPaths,
    templatePaths,
    setupPaths,
    quickrunPath
  };
}

function validateRequiredSources(pkgRoot: string, bundledCliPath: string): void {
  if (!existsSync(bundledCliPath)) {
    throw new Error(`Bundled overmind CLI not found: ${bundledCliPath}`);
  }

  for (const skillName of PACKAGED_SKILLS) {
    const skillSourcePath = path.join(pkgRoot, "_data", "skills", skillName);
    if (!existsSync(skillSourcePath)) {
      throw new Error(`Skill source not found: ${skillSourcePath}`);
    }
    const requiredPayload = ASSETLESS_SKILLS.has(skillName) ? ["SKILL.md"] : ["SKILL.md", "assets"];
    for (const payloadEntry of requiredPayload) {
      const payloadPath = path.join(skillSourcePath, payloadEntry);
      if (!existsSync(payloadPath)) {
        throw new Error(`Skill payload missing: ${payloadPath}`);
      }
    }
  }

  for (const templateName of RUNTIME_TEMPLATE_FILES) {
    const sourcePath = path.join(pkgRoot, "_data", "templates", templateName);
    if (!existsSync(sourcePath)) {
      throw new Error(`Runtime template source not found: ${sourcePath}`);
    }
  }

  for (const setupName of SETUP_DEFAULT_FILES) {
    const sourcePath = path.join(pkgRoot, "_data", "setup", setupName);
    if (!existsSync(sourcePath)) {
      throw new Error(`Setup default source not found: ${sourcePath}`);
    }
  }
}

function installCli(projectRoot: string, bundledCliPath: string): string {
  const cliDir = path.join(projectRoot, ".overmind");
  const cliPath = path.join(cliDir, "overmind.js");
  mkdirSync(cliDir, { recursive: true });
  cpSync(bundledCliPath, cliPath);
  chmodSync(cliPath, 0o755);
  return cliPath;
}

function installSkills(projectRoot: string, pkgRoot: string): string[] {
  const allSkillPaths: string[] = [];
  for (const skillName of PACKAGED_SKILLS) {
    const skillSourcePath = path.join(pkgRoot, "_data", "skills", skillName);
    for (const runnerDir of SUPPORTED_RUNNER_SKILL_DIRS) {
      const target = path.join(projectRoot, runnerDir, "skills", skillName);
      mkdirSync(path.dirname(target), { recursive: true });
      // Treat the installed skill as package-owned payload: refresh from canonical
      // source so stale files do not survive a reinstall.
      rmSync(target, { recursive: true, force: true });
      cpSync(skillSourcePath, target, { recursive: true, force: true });
      allSkillPaths.push(target);
    }
  }
  return allSkillPaths;
}

function installRuntimeTemplates(projectRoot: string, pkgRoot: string): string[] {
  const installed: string[] = [];
  const targetDir = path.join(projectRoot, ".templates");
  mkdirSync(targetDir, { recursive: true });
  for (const templateName of RUNTIME_TEMPLATE_FILES) {
    const sourcePath = path.join(pkgRoot, "_data", "templates", templateName);
    const targetPath = path.join(targetDir, templateName);
    cpSync(sourcePath, targetPath);
    installed.push(targetPath);
  }
  return installed;
}

function installSetupDefaults(projectRoot: string, pkgRoot: string): string[] {
  const installed: string[] = [];
  const targetDir = path.join(projectRoot, ".setup");
  mkdirSync(targetDir, { recursive: true });
  for (const setupName of SETUP_DEFAULT_FILES) {
    const sourcePath = path.join(pkgRoot, "_data", "setup", setupName);
    const targetPath = path.join(targetDir, setupName);
    if (!existsSync(targetPath)) {
      cpSync(sourcePath, targetPath);
    }
    installed.push(targetPath);
  }
  return installed;
}

function installWorkspaceScaffold(projectRoot: string): void {
  const metadataPath = path.join(projectRoot, "asdlc_metadata.yaml");
  if (!existsSync(metadataPath)) {
    writeFileSync(
      metadataPath,
      'meta:\n  description: "this repo is for asdlc projects management"\nprojects:\n'
    );
  }
  mkdirSync(path.join(projectRoot, "projects"), { recursive: true });
}

function writeQuickrunGuide(projectRoot: string): string {
  const quickrunPath = path.join(projectRoot, "quickrun.md");
  writeFileSync(quickrunPath, renderQuickrunGuide(projectRoot));
  return quickrunPath;
}

function renderQuickrunGuide(projectRoot: string): string {
  const skillList = PACKAGED_SKILLS.map((skillName) => `- ${skillName}`).join("\n");
  const runnerList = SUPPORTED_RUNNER_SKILL_DIRS.map((runnerDir) => `- ${runnerDir}/skills/`).join(
    "\n"
  );
  return `# ASDLC Quick Run

This ASDLC workspace was initialized at:
\`${projectRoot}\`

Run commands from this workspace root.

## First-Time Happy Path

Use this path when starting from an empty ASDLC workspace:

\`\`\`text
node .overmind/overmind.js project create
node .overmind/overmind.js project add-class
node .overmind/overmind.js project reconcile --path projects/<project-id>
node .overmind/overmind.js project init --path projects/<project-id>
node .overmind/overmind.js run --path projects/<project-id>
node .overmind/overmind.js status projects/<project-id>
\`\`\`

Replace \`<project-id>\` with the project folder created under \`projects/\`. \`project init\` owns the project initialization flow: type A projects define stack blueprints and agent guidelines first, commit the stack baseline, then render \`Continue with common contract definition? [Y/n]\`. Answer yes or press Enter to continue into common contract definition in the same command; answer no to pause cleanly and resume step 2 later with the same \`project init --path projects/<project-id>\` command. Type B/C projects start common contract definition directly. \`run\` is the single feature-creation entrypoint: select "Start a new feature" to create the feature and continue into the workflow, then fill in the generated feature inputs.

## Installed Runtime

- CLI: \`.overmind/overmind.js\`
- Project registry: \`asdlc_metadata.yaml\`
- Project directory: \`projects/\`
- Runtime templates: \`.templates/init_progress_definition_TEMPLATE.yaml\`, \`.templates/feature_br_summary_TEMPLATE.md\`
- Setup defaults: \`.setup/models.md\`, \`.setup/external_sources.yaml\`

Supported runner skill directories:
${runnerList}

Installed skills:
${skillList}

## Project Commands

\`\`\`text
node .overmind/overmind.js project create
node .overmind/overmind.js project add-class
node .overmind/overmind.js project reconcile [--path projects/<project-id>]
node .overmind/overmind.js project init --path projects/<project-id>
\`\`\`

- \`project create\`: create a new project entry and folder under \`projects/\`.
- \`project add-class\`: add a project class so the workflow knows which system surface or domain area the project covers.
- \`project reconcile [--path projects/<project-id>]\`: sync project metadata and folders after creating or editing project details.
- \`project init --path projects/<project-id>\`: run project initialization through the stack-baseline checkpoint and common-contract baseline before feature work.

## Feature Commands

\`\`\`text
node .overmind/overmind.js run
node .overmind/overmind.js run --path projects/<project-id>
node .overmind/overmind.js run --path projects/<project-id> --resume <step>
node .overmind/overmind.js status projects/<project-id>
node .overmind/overmind.js status projects/<project-id>/<feature-folder>
node .overmind/overmind.js gate all projects/<project-id>/<feature-folder>
\`\`\`

- \`run\`: continue the next available workflow step for the active/default project context.
- \`run --path projects/<project-id>\`: run the next workflow step for a specific project.
- \`run --path projects/<project-id> --resume <step>\`: resume from a named workflow step after fixing inputs or reviewing output.
- \`status projects/<project-id>\`: show project-level progress across features and workflow steps.
- \`status projects/<project-id>/<feature-folder>\`: show detailed progress for one feature.
- \`gate all projects/<project-id>/<feature-folder>\`: re-validate every applicable existing feature artifact and print per-gate rows plus passed/failed/skipped counts. Exit \`0\` all applicable gates pass, \`1\` a recoverable artifact defect, \`2\` a path/runtime failure. \`run\` applies the same check before reporting a finished plan; on failure it names the earliest owning step, which you resume with \`run --path projects/<project-id> --resume <step>\`.

## Worker Commands

\`\`\`text
node .overmind/overmind.js worker register --path projects/<project-id>
node .overmind/overmind.js worker assign --feature-path projects/<project-id>/<feature-folder>
\`\`\`

- \`worker register --path projects/<project-id>\`: register the current agent/session as available to work on a project.
- \`worker assign --feature-path projects/<project-id>/<feature-folder>\`: assign registered worker context to a specific feature.

## Skill Context And Gates

\`\`\`text
node .overmind/overmind.js capture task-to-br projects/<project-id>/<feature-folder> --source-file <story-file>
node .overmind/overmind.js context task-to-br projects/<project-id>/<feature-folder>
node .overmind/overmind.js gate task-to-br projects/<project-id>/<feature-folder>
node .overmind/overmind.js context br-clarification projects/<project-id>/<feature-folder>
node .overmind/overmind.js readiness br-clarification projects/<project-id>/<feature-folder>
node .overmind/overmind.js context requirements-ears projects/<project-id>/<feature-folder>
node .overmind/overmind.js context contract-delta projects/<project-id>/<feature-folder>
node .overmind/overmind.js gate contract-delta projects/<project-id>/<feature-folder>
node .overmind/overmind.js context surface-map projects/<project-id>/<feature-folder> --class <class>
node .overmind/overmind.js gate surface-map projects/<project-id>/<feature-folder> --class <class>
node .overmind/overmind.js context technical-requirements projects/<project-id>/<feature-folder>
node .overmind/overmind.js gate technical-requirements projects/<project-id>/<feature-folder>
node .overmind/overmind.js context implementation-slices projects/<project-id>/<feature-folder>
node .overmind/overmind.js context prerequisite-gaps projects/<project-id>/<feature-folder>
node .overmind/overmind.js context implementation-plan projects/<project-id>/<feature-folder>
node .overmind/overmind.js context plan-semantic-review projects/<project-id>/<feature-folder>
\`\`\`

- \`capture task-to-br ... --source-file <story-file>\`: import a story or task brief into the feature's business-requirements workflow.
- \`context task-to-br ...\`: build the model context for turning the task into a business-requirements brief.
- \`gate task-to-br ...\`: validate the task-to-business-requirements output before continuing.
- \`context br-clarification ...\`: build context for clarifying open business-requirements questions.
- \`readiness br-clarification ...\`: check whether clarification is complete enough to proceed.
- \`context requirements-ears ...\`: build context for converting business requirements into EARS requirements.
- \`context contract-delta ...\`: build context for the contract delta step.
- \`gate contract-delta ...\`: validate the contract delta output.
- \`context surface-map ... --class <class>\`: build context for mapping the touched system surface for one class.
- \`gate surface-map ... --class <class>\`: validate the surface map for one class.
- \`context technical-requirements ...\`: build context for technical requirements.
- \`gate technical-requirements ...\`: validate technical requirements before planning implementation.
- \`context implementation-slices ...\`: build context for breaking the work into implementation slices.
- \`context prerequisite-gaps ...\`: build context for identifying missing prerequisites.
- \`context implementation-plan ...\`: build context for the implementation plan.
- \`context plan-semantic-review ...\`: build context for reviewing plan consistency and completeness.
`;
}

function packageRoot(): string {
  const moduleDir = path.dirname(fileURLToPath(import.meta.url));
  return path.resolve(moduleDir, "..", "..");
}

function isNodeError(error: unknown): error is NodeJS.ErrnoException {
  return error instanceof Error && "code" in error;
}
