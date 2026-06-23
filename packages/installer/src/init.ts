import { chmodSync, cpSync, existsSync, mkdirSync, rmSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

import { getBundledOvermindPath } from "asdlc-coordinator";

const PACKAGED_SKILLS = [
  "overmind-task-to-br",
  "overmind-repo-br-scan",
  "overmind-br-clarification",
  "overmind-requirements-ears",
  "overmind-ears-review",
  "overmind-contract-delta",
  "overmind-surface-map",
  "overmind-surface-map-enrich",
  "overmind-technical-requirements",
  "overmind-implementation-slices",
  "overmind-prerequisite-gaps",
  "overmind-implementation-plan",
  "overmind-plan-semantic-review"
] as const;

// Skills whose source directory intentionally has no assets/ subdirectory.
const ASSETLESS_SKILLS = new Set<string>(["overmind-surface-map-enrich"]);

// Supported local runner skill directories for this change. The packaged skill

// is installed under "<runner>/skills/<skill-name>" for each entry. The shared
// runtime CLI (`.overmind/overmind.js`) is intentionally NOT part of this set.
const SUPPORTED_RUNNER_SKILL_DIRS = [".codex", ".claude"] as const;

export interface InstallResult {
  projectRoot: string;
  cliPath: string;
  // Compatibility field: the Claude runner skill path for overmind-task-to-br (retained from CRP-129).
  skillPath: string;
  // All installed runner skill paths for this install (Codex + Claude × all skills).
  skillPaths: string[];
}

export function installProject(projectRoot = process.cwd()): InstallResult {
  const resolvedProjectRoot = path.resolve(projectRoot);
  const bundledCliPath = getBundledOvermindPath();
  if (!existsSync(bundledCliPath)) {
    throw new Error(`Bundled overmind CLI not found: ${bundledCliPath}`);
  }

  const cliDir = path.join(resolvedProjectRoot, ".overmind");
  const cliPath = path.join(cliDir, "overmind.js");
  mkdirSync(cliDir, { recursive: true });
  cpSync(bundledCliPath, cliPath);
  chmodSync(cliPath, 0o755);

  // Validate all packaged skills before writing any runner target.
  const pkgRoot = packageRoot();
  for (const skillName of PACKAGED_SKILLS) {
    const skillSourcePath = path.join(pkgRoot, "_data", "skills", skillName);
    if (!existsSync(skillSourcePath)) {
      throw new Error(`Skill source not found: ${skillSourcePath}`);
    }
    const requiredPayload = ASSETLESS_SKILLS.has(skillName)
      ? ["SKILL.md"]
      : ["SKILL.md", "assets"];
    for (const payloadEntry of requiredPayload) {
      const payloadPath = path.join(skillSourcePath, payloadEntry);
      if (!existsSync(payloadPath)) {
        throw new Error(`Skill payload missing: ${payloadPath}`);
      }
    }
  }

  // Install all validated skills into all supported runners.
  const allSkillPaths: string[] = [];
  for (const skillName of PACKAGED_SKILLS) {
    const skillSourcePath = path.join(pkgRoot, "_data", "skills", skillName);
    for (const runnerDir of SUPPORTED_RUNNER_SKILL_DIRS) {
      const target = path.join(resolvedProjectRoot, runnerDir, "skills", skillName);
      mkdirSync(path.dirname(target), { recursive: true });
      // Treat the installed skill as package-owned payload: refresh from canonical
      // source so stale files do not survive a reinstall.
      rmSync(target, { recursive: true, force: true });
      cpSync(skillSourcePath, target, { recursive: true, force: true });
      allSkillPaths.push(target);
    }
  }

  const claudeTaskToBrSkillPath = path.join(
    resolvedProjectRoot,
    ".claude",
    "skills",
    "overmind-task-to-br"
  );

  return {
    projectRoot: resolvedProjectRoot,
    cliPath,
    skillPath: claudeTaskToBrSkillPath,
    skillPaths: allSkillPaths
  };
}

function packageRoot(): string {
  const moduleDir = path.dirname(fileURLToPath(import.meta.url));
  return path.resolve(moduleDir, "..", "..");
}
