import { chmodSync, cpSync, existsSync, mkdirSync, rmSync, writeFileSync } from "node:fs";
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

export function installProject(projectRoot = process.cwd()): InstallResult {
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
node .overmind/overmind.js project reconcile [--path projects/<project-id>]
node .overmind/overmind.js project init --path projects/<project-id>
\`\`\`

## Feature Commands

\`\`\`text
node .overmind/overmind.js run
node .overmind/overmind.js run --path projects/<project-id>
node .overmind/overmind.js run --path projects/<project-id> --resume <step>
node .overmind/overmind.js scaffold feature --path projects/<project-id>
node .overmind/overmind.js status projects/<project-id>
node .overmind/overmind.js status projects/<project-id>/<feature-folder>
\`\`\`

## Worker Commands

\`\`\`text
node .overmind/overmind.js worker register --path projects/<project-id>
node .overmind/overmind.js worker assign --feature-path projects/<project-id>/<feature-folder>
\`\`\`

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
`;
}

function packageRoot(): string {
  const moduleDir = path.dirname(fileURLToPath(import.meta.url));
  return path.resolve(moduleDir, "..", "..");
}
