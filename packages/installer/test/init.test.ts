import {
  chmodSync,
  existsSync,
  mkdirSync,
  mkdtempSync,
  readdirSync,
  readFileSync,
  renameSync,
  rmSync,
  statSync,
  symlinkSync,
  writeFileSync
} from "node:fs";
import { homedir, tmpdir } from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";
import test from "node:test";
import assert from "node:assert/strict";

import { classifyInstallTarget, installProject, resolveInstallTarget } from "../src/index.js";

// Mirror init.ts packageRoot(): from dist/test/init.test.js up to packages/installer.
function packageRoot(): string {
  const moduleDir = path.dirname(fileURLToPath(import.meta.url));
  return path.resolve(moduleDir, "..", "..");
}

function packagedSkillSourceDir(skillName: string): string {
  return path.join(packageRoot(), "_data", "skills", skillName);
}

function packagedTemplateSourcePath(templateName: string): string {
  return path.join(packageRoot(), "_data", "templates", templateName);
}

/** Canonical source template under overmind/templates that the packaged copy mirrors. */
function canonicalTemplateSourcePath(templateName: string): string {
  return path.resolve(packageRoot(), "..", "..", "overmind", "templates", templateName);
}

function packagedSetupSourcePath(setupName: string): string {
  return path.join(packageRoot(), "_data", "setup", setupName);
}

function installerBinPath(): string {
  const moduleDir = path.dirname(fileURLToPath(import.meta.url));
  return path.resolve(moduleDir, "..", "src", "bin", "overmind.js");
}

function bundledCliPath(): string {
  return path.resolve(packageRoot(), "..", "asdlc-coordinator", "dist", "overmind.js");
}

function withProject(fn: (root: string) => void): void {
  const root = mkdtempSync(path.join(tmpdir(), "overmind-init-"));
  try {
    fn(root);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
}

function withTempRoot(fn: (root: string) => void): void {
  const root = mkdtempSync(path.join(tmpdir(), "overmind-target-"));
  try {
    fn(root);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
}

const ALL_SKILLS = [
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
const RUNNER_DIRS = [".codex", ".claude"] as const;
const RUNTIME_TEMPLATES = [
  "init_progress_definition_TEMPLATE.yaml",
  "feature_br_summary_TEMPLATE.md"
] as const;
const SETUP_DEFAULTS = ["models.md", "external_sources.yaml"] as const;
const SKILL_ASSET_CHECKS: Record<(typeof ALL_SKILLS)[number], string[]> = {
  "overmind-task-to-br": [
    "feature_br_summary_TEMPLATE.md",
    "feature_br_summary_GOLDEN_EXAMPLE.md",
    "missing_br_data_TEMPLATE.md",
    "missing_br_data_GOLDEN_EXAMPLE.md"
  ],
  "overmind-repo-br-scan": ["feature_br_summary_TEMPLATE.md"],
  "overmind-br-clarification": ["feature_br_summary_TEMPLATE.md"],
  "overmind-requirements-ears": [
    "reqirements_ears_TEMPLATE.md",
    "reqirements_ears_GOLDEN_EXAMPLE.md"
  ],
  "overmind-ears-review": [
    "requirements_ears_review_TEMPLATE.md",
    "requirements_ears_review_GOLDEN_EXAMPLE.md"
  ],
  "overmind-stack-blueprint": [
    "project_stack_blueprint_be_TEMPLATE.md",
    "project_stack_blueprint_fe_TEMPLATE.md",
    "project_stack_blueprint_mobile_TEMPLATE.md",
    "project_stack_blueprint_be_GOLDEN_EXAMPLE.md",
    "project_stack_blueprint_fe_GOLDEN_EXAMPLE.md",
    "project_stack_blueprint_mobile_GOLDEN_EXAMPLE.md"
  ],
  "overmind-agents-md": [
    "project_agents_md_claude_md_be_TEMPLATE.md",
    "project_agents_md_claude_md_fe_TEMPLATE.md",
    "project_agents_md_claude_md_mobile_TEMPLATE.md",
    "project_agents_md_claude_md_be_GOLDEN_EXAMPLE.md",
    "project_agents_md_claude_md_fe_GOLDEN_EXAMPLE.md",
    "project_agents_md_claude_md_mobile_GOLDEN_EXAMPLE.md"
  ],
  "overmind-common-contract": [
    "common_contract_definition_TEMPLATE.md",
    "common_contract_definition_GOLDEN_EXAMPLE.md"
  ],
  "overmind-contract-delta": [
    "feature_contract_delta_TEMPLATE.md",
    "feature_contract_delta_GOLDEN_EXAMPLE.md"
  ],
  "overmind-surface-map": [
    "project_surface_struct_resp_map_be_TEMPLATE.md",
    "project_surface_struct_resp_map_fe_TEMPLATE.md",
    "project_surface_struct_resp_map_be_GOLDEN_EXAMPLE.md",
    "project_surface_struct_resp_map_fe_GOLDEN_EXAMPLE.md"
  ],
  "overmind-surface-map-enrich": [],
  "overmind-technical-requirements": [
    "technical_requirements_TEMPLATE.md",
    "technical_requirements_GOLDEN_EXAMPLE.md"
  ],
  "overmind-implementation-slices": [
    "implementation_slices_TEMPLATE.md",
    "implementation_slices_GOLDEN_EXAMPLE.md"
  ],
  "overmind-prerequisite-gaps": [
    "prerequisite_gaps_TEMPLATE.md",
    "prerequisite_gaps_GOLDEN_EXAMPLE.md"
  ],
  "overmind-implementation-plan": [
    "implementation_plan_TEMPLATE.md",
    "implementation_plan_GOLDEN_EXAMPLE.md"
  ],
  "overmind-plan-semantic-review": [
    "implementation_plan_semantic_review_TEMPLATE.md",
    "implementation_plan_semantic_review_GOLDEN_EXAMPLE.md"
  ],
  "overmind-contract-reconciliation": [
    "common_contract_definition_TEMPLATE.md",
    "common_contract_definition_GOLDEN_EXAMPLE.md"
  ]
};

function assertWorkspaceUnwritten(root: string): void {
  assert.deepEqual(readdirSync(root), []);
}

function escapeRegExp(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function runInstallerBin(cwd: string, input: string, args = ["init"]) {
  return spawnSync(process.execPath, [installerBinPath(), ...args], {
    cwd,
    input,
    encoding: "utf8"
  });
}

function listShellFiles(root: string, options: { prune?: Set<string> } = {}): string[] {
  const found: string[] = [];
  if (!existsSync(root)) return found;
  for (const entry of readdirSync(root)) {
    const fullPath = path.join(root, entry);
    const stat = statSync(fullPath);
    if (stat.isDirectory()) {
      if (options.prune?.has(entry)) continue;
      found.push(...listShellFiles(fullPath, options));
    } else if (entry.endsWith(".sh")) {
      found.push(fullPath);
    }
  }
  return found;
}

test("classifyInstallTarget identifies clean installs, updates, and refused targets", () => {
  withTempRoot((root) => {
    const missing = path.join(root, "missing");
    assert.deepEqual(classifyInstallTarget(missing), { kind: "clean-install" });

    const empty = path.join(root, "empty");
    mkdirSync(empty);
    assert.deepEqual(classifyInstallTarget(empty), { kind: "clean-install" });

    const metadataOnly = path.join(root, "metadata-only");
    mkdirSync(metadataOnly);
    writeFileSync(path.join(metadataOnly, "asdlc_metadata.yaml"), "projects:\n");
    assert.deepEqual(classifyInstallTarget(metadataOnly), { kind: "update" });

    const populatedWorkspace = path.join(root, "populated-workspace");
    mkdirSync(populatedWorkspace);
    writeFileSync(path.join(populatedWorkspace, "asdlc_metadata.yaml"), "projects:\n");
    mkdirSync(path.join(populatedWorkspace, "projects"));
    assert.deepEqual(classifyInstallTarget(populatedWorkspace), { kind: "update" });

    const nonWorkspace = path.join(root, "non-workspace");
    mkdirSync(nonWorkspace);
    writeFileSync(path.join(nonWorkspace, "notes.txt"), "keep\n");
    assert.deepEqual(classifyInstallTarget(nonWorkspace), { kind: "refuse-not-empty" });

    const fileTarget = path.join(root, "target-file");
    writeFileSync(fileTarget, "not a directory\n");
    assert.deepEqual(classifyInstallTarget(fileTarget), { kind: "refuse-not-directory" });

    const emptySymlinkTarget = path.join(root, "empty-symlink-target");
    const emptySymlink = path.join(root, "empty-symlink");
    mkdirSync(emptySymlinkTarget);
    symlinkSync(emptySymlinkTarget, emptySymlink);
    assert.deepEqual(classifyInstallTarget(emptySymlink), { kind: "clean-install" });

    const workspaceSymlinkTarget = path.join(root, "workspace-symlink-target");
    const workspaceSymlink = path.join(root, "workspace-symlink");
    mkdirSync(workspaceSymlinkTarget);
    writeFileSync(path.join(workspaceSymlinkTarget, "asdlc_metadata.yaml"), "projects:\n");
    symlinkSync(workspaceSymlinkTarget, workspaceSymlink);
    assert.deepEqual(classifyInstallTarget(workspaceSymlink), { kind: "update" });

    const fileSymlink = path.join(root, "file-symlink");
    symlinkSync(fileTarget, fileSymlink);
    assert.deepEqual(classifyInstallTarget(fileSymlink), { kind: "refuse-not-directory" });

    const danglingSymlink = path.join(root, "dangling-symlink");
    symlinkSync(path.join(root, "missing-real-target"), danglingSymlink);
    assert.deepEqual(classifyInstallTarget(danglingSymlink), { kind: "refuse-not-directory" });
  });
});

test("resolveInstallTarget expands home and resolves relative paths against the invoking cwd", () => {
  withTempRoot((root) => {
    assert.equal(resolveInstallTarget("~"), homedir());
    assert.equal(resolveInstallTarget("~/workspace"), path.join(homedir(), "workspace"));
    assert.equal(
      resolveInstallTarget("relative/workspace", root),
      path.join(root, "relative", "workspace")
    );
  });
});

test("resolveInstallTarget rejects unsupported leading-tilde paths", () => {
  assert.throws(() => resolveInstallTarget("~junk-workspace-test"), /Unsupported home path syntax/);
  assert.throws(() => resolveInstallTarget("~user/asdlc"), /Unsupported home path syntax/);
});

test("installProject requires an explicit target directory", () => {
  const installWithoutTarget = installProject as unknown as () => ReturnType<typeof installProject>;

  assert.throws(() => installWithoutTarget(), /requires an explicit projectRoot/);
});

for (const missing of ["SKILL.md", "assets"] as const) {
  test(`installProject writes no runner targets when overmind-plan-semantic-review ${missing} is missing`, () => {
    const payload = path.join(packagedSkillSourceDir("overmind-plan-semantic-review"), missing);
    const backup = `${payload}.bak`;
    renameSync(payload, backup);
    try {
      withProject((root) => {
        assert.throws(() => installProject(root), /Skill payload missing/);
        for (const skillName of ALL_SKILLS)
          for (const runnerDir of RUNNER_DIRS) {
            assert.equal(existsSync(path.join(root, runnerDir, "skills", skillName)), false);
          }
      });
    } finally {
      renameSync(backup, payload);
    }
  });
}

test("overmind init installs the full workspace bootstrap payload", () => {
  withProject((root) => {
    const result = installProject(root);

    assert.equal(existsSync(path.join(root, ".overmind", "overmind.js")), true);
    assert.equal(result.cliPath, path.join(root, ".overmind", "overmind.js"));

    for (const skillName of ALL_SKILLS) {
      for (const runnerDir of RUNNER_DIRS) {
        const skillDir = path.join(root, runnerDir, "skills", skillName);
        assert.equal(
          existsSync(path.join(skillDir, "SKILL.md")),
          true,
          `SKILL.md missing for ${skillName}/${runnerDir}`
        );
        if (SKILL_ASSET_CHECKS[skillName].length > 0) {
          assert.equal(
            existsSync(path.join(skillDir, "assets")),
            true,
            `assets/ missing for ${skillName}/${runnerDir}`
          );
        }
        for (const assetName of SKILL_ASSET_CHECKS[skillName]) {
          assert.equal(
            existsSync(path.join(skillDir, "assets", assetName)),
            true,
            `${assetName} missing for ${skillName}/${runnerDir}`
          );
        }
      }
    }

    const expectedSkillPaths = ALL_SKILLS.flatMap((skillName) =>
      RUNNER_DIRS.map((runnerDir) => path.join(root, runnerDir, "skills", skillName))
    );
    assert.deepEqual(result.skillPaths, expectedSkillPaths);

    for (const templateName of RUNTIME_TEMPLATES) {
      const target = path.join(root, ".templates", templateName);
      assert.equal(
        readFileSync(target, "utf8"),
        readFileSync(packagedTemplateSourcePath(templateName), "utf8")
      );
    }
    assert.deepEqual(
      result.templatePaths,
      RUNTIME_TEMPLATES.map((templateName) => path.join(root, ".templates", templateName))
    );

    for (const setupName of SETUP_DEFAULTS) {
      const target = path.join(root, ".setup", setupName);
      assert.equal(
        readFileSync(target, "utf8"),
        readFileSync(packagedSetupSourcePath(setupName), "utf8")
      );
    }
    assert.deepEqual(
      result.setupPaths,
      SETUP_DEFAULTS.map((setupName) => path.join(root, ".setup", setupName))
    );

    assert.equal(
      readFileSync(path.join(root, "asdlc_metadata.yaml"), "utf8"),
      'meta:\n  description: "this repo is for asdlc projects management"\nprojects:\n'
    );
    assert.equal(existsSync(path.join(root, "projects")), true);
    assert.equal(existsSync(result.quickrunPath), true);
    assert.equal(result.quickrunPath, path.join(root, "quickrun.md"));
    assert.equal(existsSync(path.join(root, ".commands")), false);
    assert.equal(existsSync(path.join(root, ".helper")), false);
    assert.equal(existsSync(path.join(root, ".rules")), false);
    assert.equal(existsSync(path.join(root, ".golden_examples")), false);
  });
});

test("fresh install exposes project init skills with migrated rule parity", () => {
  withProject((root) => {
    installProject(root);
    const stackSuccessLine =
      "Project stack blueprint class session is finished for <target_class>. Nothing else to do now; press Ctrl-C so orchestrator can continue project init";
    const commonSuccessLine =
      "Common contract definition phase is finished. Nothing else to do now; press Ctrl-C so Overmind can finalize project initialization";
    const commonInfeasibleLine =
      "common contract definition gate cannot pass with current repository evidence. Please provide instructions what to do, or adjust requirements and rerun this phase";

    for (const runnerDir of RUNNER_DIRS) {
      const stackSkillDir = path.join(root, runnerDir, "skills", "overmind-stack-blueprint");
      const stackText = readFileSync(path.join(stackSkillDir, "SKILL.md"), "utf8");
      assert.match(
        stackText,
        /node \.overmind\/overmind\.js context stack-blueprint <project> --class <backend\|frontend\|mobile>/
      );
      assert.match(stackText, /Run the exact `gate_command` from context after every write/);
      assert.match(stackText, /Do not silently choose a default/);
      assert.match(
        stackText,
        /Do not write `project_stack_blueprint_<class>\.md` until the operator explicitly approves/
      );
      assert.match(stackText, /Cross-Class Transport\/Contract Approach/);
      assert.match(stackText, /<to be defined during first feature implementation plan>/);
      assert.equal(stackText.includes(stackSuccessLine), true);

      const commonSkillDir = path.join(root, runnerDir, "skills", "overmind-common-contract");
      const commonText = readFileSync(path.join(commonSkillDir, "SKILL.md"), "utf8");
      assert.match(commonText, /node \.overmind\/overmind\.js context common-contract <project>/);
      assert.match(commonText, /Run the exact `gate_command` from context after every write/);
      assert.match(commonText, /contract-local alignment status/);
      assert.match(commonText, /Do not invent contract surfaces/);
      assert.match(commonText, /source_repo_count` from context/);
      assert.match(commonText, /Cross-Class Transport\/Contract Approach Mirror/);
      assert.equal(commonText.includes(commonSuccessLine), true);
      assert.equal(
        commonText.includes("press Ctrl-C so orchestrator can start the next phase"),
        false
      );
      assert.equal(commonText.includes(commonInfeasibleLine), true);
    }
  });
});

test("overmind init preserves operator setup defaults and metadata on reinstall", () => {
  withProject((root) => {
    installProject(root);
    const customModels = "task_to_br | codex | custom-model\n";
    const customSources = "sources:\n  - name: local-kb\n    type: stack_knowledge_base\n";
    const customMetadata = "meta:\n  version: custom\nprojects:\n  - project: existing\n";
    writeFileSync(path.join(root, ".setup", "models.md"), customModels);
    writeFileSync(path.join(root, ".setup", "external_sources.yaml"), customSources);
    writeFileSync(path.join(root, "asdlc_metadata.yaml"), customMetadata);
    writeFileSync(
      path.join(root, ".templates", "feature_br_summary_TEMPLATE.md"),
      "stale template\n"
    );

    installProject(root);

    assert.equal(readFileSync(path.join(root, ".setup", "models.md"), "utf8"), customModels);
    assert.equal(
      readFileSync(path.join(root, ".setup", "external_sources.yaml"), "utf8"),
      customSources
    );
    assert.equal(readFileSync(path.join(root, "asdlc_metadata.yaml"), "utf8"), customMetadata);
    assert.equal(
      readFileSync(path.join(root, ".templates", "feature_br_summary_TEMPLATE.md"), "utf8"),
      readFileSync(packagedTemplateSourcePath("feature_br_summary_TEMPLATE.md"), "utf8")
    );
    assert.equal(existsSync(path.join(root, ".commands")), false);
    assert.equal(existsSync(path.join(root, ".helper")), false);
    assert.equal(existsSync(path.join(root, ".rules")), false);
    assert.equal(existsSync(path.join(root, ".golden_examples")), false);
    assert.equal(
      readFileSync(path.join(root, ".overmind", "overmind.js"), "utf8").includes(
        "ASDLC_PROJECTS_DIR_DEFAULT"
      ),
      false
    );
  });
});

for (const templateName of RUNTIME_TEMPLATES) {
  test(`installProject fails before writing workspace files when ${templateName} is missing`, () => {
    const sourcePath = packagedTemplateSourcePath(templateName);
    const backup = `${sourcePath}.bak`;
    renameSync(sourcePath, backup);
    try {
      withProject((root) => {
        assert.throws(() => installProject(root), /Runtime template source not found/);
        assertWorkspaceUnwritten(root);
      });
    } finally {
      renameSync(backup, sourcePath);
    }
  });
}

for (const setupName of SETUP_DEFAULTS) {
  test(`installProject fails before writing workspace files when ${setupName} is missing`, () => {
    const sourcePath = packagedSetupSourcePath(setupName);
    const backup = `${sourcePath}.bak`;
    renameSync(sourcePath, backup);
    try {
      withProject((root) => {
        assert.throws(() => installProject(root), /Setup default source not found/);
        assertWorkspaceUnwritten(root);
      });
    } finally {
      renameSync(backup, sourcePath);
    }
  });
}

test("installed CLI executes and runtime templates land at coordinator default paths", () => {
  withProject((root) => {
    installProject(root);
    const result = spawnSync(process.execPath, [path.join(root, ".overmind", "overmind.js")], {
      cwd: root,
      encoding: "utf8"
    });
    assert.equal(result.status, 2);
    assert.match(result.stderr, /overmind <run\|project create\|project add-class\|project init/);
    assert.equal(
      existsSync(path.join(root, ".templates", "init_progress_definition_TEMPLATE.yaml")),
      true
    );
    assert.equal(existsSync(path.join(root, ".templates", "feature_br_summary_TEMPLATE.md")), true);
  });
});

test("generated quickrun and install-bin output name TypeScript commands only", () => {
  withProject((root) => {
    installProject(root);
    const quickrun = readFileSync(path.join(root, "quickrun.md"), "utf8");
    for (const expected of [
      "## First-Time Happy Path",
      "Use this path when starting from an empty ASDLC workspace:",
      "node .overmind/overmind.js project create",
      "node .overmind/overmind.js project add-class",
      "node .overmind/overmind.js project reconcile --path projects/<project-id>",
      "node .overmind/overmind.js project init --path projects/<project-id>",
      "Continue with common contract definition? [Y/n]",
      "answer no to pause cleanly and resume step 2 later",
      "node .overmind/overmind.js worker register",
      "node .overmind/overmind.js worker assign",
      "node .overmind/overmind.js run",
      "node .overmind/overmind.js status",
      "node .overmind/overmind.js context task-to-br",
      "node .overmind/overmind.js gate task-to-br",
      "`project create`: create a new project entry and folder under `projects/`.",
      "`run --path projects/<project-id>`: run the next workflow step for a specific project.",
      "`context task-to-br ...`: build the model context for turning the task into a business-requirements brief."
    ]) {
      assert.match(quickrun, new RegExp(escapeRegExp(expected)));
    }
    assert.doesNotMatch(quickrun, /Repeat project init/);
    assert.doesNotMatch(quickrun, /\.sh\b/);
    // `run` is the single feature-creation entrypoint; `scaffold feature` is gone.
    assert.doesNotMatch(quickrun, /scaffold feature/);
    assert.match(quickrun, /node \.overmind\/overmind\.js run --path projects\/<project-id>/);

    const output = runInstallerBin(root, `${root}\n`);
    assert.equal(output.status, 0);
    assert.match(output.stdout, new RegExp(`Overmind workspace updated: ${escapeRegExp(root)}`));
    assert.match(output.stdout, /CLI: \.overmind\/overmind\.js/);
    assert.match(output.stdout, /Runtime templates:/);
    assert.match(output.stdout, /Setup defaults:/);
    assert.match(output.stdout, /Quick run: quickrun\.md/);
    assert.doesNotMatch(output.stdout, /\.sh\b/);
    assert.equal(output.stderr, "");
  });
});

test("overmind init prompt installs at answered path instead of the child cwd", () => {
  withTempRoot((root) => {
    const childCwd = path.join(root, "child-cwd");
    const target = path.join(root, "answered-workspace");
    mkdirSync(childCwd);

    const output = runInstallerBin(childCwd, `${target}\n`);

    assert.equal(output.status, 0);
    assert.match(output.stdout, /ASDLC workspace path:/);
    assert.match(
      output.stdout,
      new RegExp(`Overmind workspace bootstrapped: ${escapeRegExp(target)}`)
    );
    assert.equal(existsSync(path.join(target, ".overmind", "overmind.js")), true);
    assert.equal(existsSync(path.join(target, "asdlc_metadata.yaml")), true);
    assert.deepEqual(readdirSync(childCwd), []);
    assert.equal(output.stderr, "");
  });
});

test("overmind init rejects extra arguments with usage and no prompt", () => {
  withTempRoot((root) => {
    const target = path.join(root, "should-not-be-read");

    const output = runInstallerBin(root, `${target}\n`, ["init", target]);

    assert.equal(output.status, 2);
    assert.equal(output.stdout, "");
    assert.match(output.stderr, /ERROR: Usage: overmind init/);
    assert.equal(existsSync(target), false);
  });
});

test("overmind init validates package payload before creating a missing target", () => {
  withTempRoot((root) => {
    const target = path.join(root, "missing-target");
    const cliPath = bundledCliPath();
    const backup = `${cliPath}.bak`;
    renameSync(cliPath, backup);
    try {
      const output = runInstallerBin(root, `${target}\n`);

      assert.equal(output.status, 2);
      assert.match(output.stderr, /Bundled overmind CLI not found/);
      assert.equal(existsSync(target), false);
    } finally {
      renameSync(backup, cliPath);
    }
  });
});

test("overmind init re-prompts for file targets without writing", () => {
  withTempRoot((root) => {
    const target = path.join(root, "target-file");
    writeFileSync(target, "operator file\n");

    const output = runInstallerBin(root, `${target}\n\n`);

    assert.equal(output.status, 0);
    assert.match(output.stderr, new RegExp(`non-directory target: ${escapeRegExp(target)}`));
    assert.match(output.stdout, /No ASDLC workspace target selected; nothing installed\./);
    assert.equal(readFileSync(target, "utf8"), "operator file\n");
  });
});

test("overmind init re-prompts for dangling symlink targets without raw mkdir errors", () => {
  withTempRoot((root) => {
    const target = path.join(root, "dangling-symlink");
    symlinkSync(path.join(root, "missing-real-target"), target);

    const output = runInstallerBin(root, `${target}\n\n`);

    assert.equal(output.status, 0);
    assert.match(output.stderr, new RegExp(`non-directory target: ${escapeRegExp(target)}`));
    assert.doesNotMatch(output.stderr, /EEXIST/);
    assert.match(output.stdout, /No ASDLC workspace target selected; nothing installed\./);
  });
});

test("overmind init installs through a symlink to an empty directory", () => {
  withTempRoot((root) => {
    const realTarget = path.join(root, "real-workspace");
    const linkTarget = path.join(root, "linked-workspace");
    mkdirSync(realTarget);
    symlinkSync(realTarget, linkTarget);

    const output = runInstallerBin(root, `${linkTarget}\n`);

    assert.equal(output.status, 0);
    assert.match(
      output.stdout,
      new RegExp(`Overmind workspace bootstrapped: ${escapeRegExp(linkTarget)}`)
    );
    assert.equal(existsSync(path.join(realTarget, ".overmind", "overmind.js")), true);
    assert.equal(existsSync(path.join(realTarget, "asdlc_metadata.yaml")), true);
  });
});

test("overmind init blank or closed input exits zero and writes nothing", () => {
  withTempRoot((root) => {
    const blankCwd = path.join(root, "blank-cwd");
    const closedCwd = path.join(root, "closed-cwd");
    mkdirSync(blankCwd);
    mkdirSync(closedCwd);

    const blank = runInstallerBin(blankCwd, "\n");
    assert.equal(blank.status, 0);
    assert.match(blank.stdout, /No ASDLC workspace target selected; nothing installed\./);
    assert.deepEqual(readdirSync(blankCwd), []);
    assert.equal(blank.stderr, "");

    const closed = runInstallerBin(closedCwd, "");
    assert.equal(closed.status, 0);
    assert.match(closed.stdout, /No ASDLC workspace target selected; nothing installed\./);
    assert.deepEqual(readdirSync(closedCwd), []);
    assert.equal(closed.stderr, "");
  });
});

test("overmind init re-prompts for non-empty non-workspace answers", () => {
  withTempRoot((root) => {
    const childCwd = path.join(root, "child-cwd");
    const badTarget = path.join(root, "non-workspace");
    const validTarget = path.join(root, "valid-workspace");
    mkdirSync(childCwd);
    mkdirSync(badTarget);
    writeFileSync(path.join(badTarget, "notes.txt"), "operator data\n");

    const output = runInstallerBin(childCwd, `${badTarget}\n${validTarget}\n`);

    assert.equal(output.status, 0);
    assert.match(
      output.stderr,
      new RegExp(`non-empty non-workspace directory: ${escapeRegExp(badTarget)}`)
    );
    assert.match(
      output.stdout,
      new RegExp(`Overmind workspace bootstrapped: ${escapeRegExp(validTarget)}`)
    );
    assert.deepEqual(readdirSync(badTarget), ["notes.txt"]);
    assert.equal(readFileSync(path.join(badTarget, "notes.txt"), "utf8"), "operator data\n");
    assert.equal(existsSync(path.join(badTarget, ".overmind")), false);
    assert.equal(existsSync(path.join(validTarget, ".overmind", "overmind.js")), true);
  });
});

test("overmind init re-prompts for unsupported leading-tilde answers without writing", () => {
  withTempRoot((root) => {
    const childCwd = path.join(root, "child-cwd");
    mkdirSync(childCwd);

    const output = runInstallerBin(childCwd, "~junk-workspace-test\n\n");

    assert.equal(output.status, 0);
    assert.match(output.stderr, /Unsupported home path syntax: ~junk-workspace-test/);
    assert.match(output.stdout, /No ASDLC workspace target selected; nothing installed\./);
    assert.deepEqual(readdirSync(childCwd), []);
    assert.equal(existsSync(path.join(childCwd, "~junk-workspace-test")), false);
  });
});

test("overmind init prompt reports update for an existing workspace", () => {
  withProject((root) => {
    installProject(root);

    const output = runInstallerBin(path.dirname(root), `${root}\n`);

    assert.equal(output.status, 0);
    assert.match(output.stdout, new RegExp(`Overmind workspace updated: ${escapeRegExp(root)}`));
    assert.equal(output.stderr, "");
  });
});

test("overmind init prompt update refreshes payload and preserves operator-owned files", () => {
  withProject((root) => {
    installProject(root);
    const customModels = "task_to_br | codex | custom-update-model\n";
    const customSources = "sources:\n  - name: update-kb\n    type: stack_knowledge_base\n";
    const customMetadata = "meta:\n  version: update-custom\nprojects:\n  - project: kept\n";
    const projectFile = path.join(root, "projects", "kept", "notes.md");
    const staleSkillFile = path.join(root, ".codex", "skills", "overmind-task-to-br", "stale.txt");
    mkdirSync(path.dirname(projectFile), { recursive: true });
    writeFileSync(path.join(root, ".setup", "models.md"), customModels);
    writeFileSync(path.join(root, ".setup", "external_sources.yaml"), customSources);
    writeFileSync(path.join(root, "asdlc_metadata.yaml"), customMetadata);
    writeFileSync(projectFile, "operator project content\n");
    writeFileSync(staleSkillFile, "stale package file\n");
    writeFileSync(
      path.join(root, ".templates", "feature_br_summary_TEMPLATE.md"),
      "stale template\n"
    );
    writeFileSync(path.join(root, "quickrun.md"), "stale quickrun\n");

    const output = runInstallerBin(path.dirname(root), `${root}\n`);

    assert.equal(output.status, 0);
    assert.match(output.stdout, new RegExp(`Overmind workspace updated: ${escapeRegExp(root)}`));
    assert.equal(readFileSync(path.join(root, ".setup", "models.md"), "utf8"), customModels);
    assert.equal(
      readFileSync(path.join(root, ".setup", "external_sources.yaml"), "utf8"),
      customSources
    );
    assert.equal(readFileSync(path.join(root, "asdlc_metadata.yaml"), "utf8"), customMetadata);
    assert.equal(readFileSync(projectFile, "utf8"), "operator project content\n");
    assert.equal(existsSync(staleSkillFile), false);
    assert.equal(
      readFileSync(path.join(root, ".templates", "feature_br_summary_TEMPLATE.md"), "utf8"),
      readFileSync(packagedTemplateSourcePath("feature_br_summary_TEMPLATE.md"), "utf8")
    );
    assert.match(readFileSync(path.join(root, "quickrun.md"), "utf8"), /# ASDLC Quick Run/);
    assert.equal(output.stderr, "");
  });
});

test("fresh install and update both deploy the built coordinator bundle at .overmind/overmind.js", () => {
  withProject((root) => {
    const cliPath = path.join(root, ".overmind", "overmind.js");
    const bundle = readFileSync(bundledCliPath(), "utf8");
    // The post-session mutable-artifact enforcement (CRP-165) lives in the bundled
    // coordinator; its diagnostic literal survives esbuild bundling as a marker.
    assert.ok(bundle.includes("Post-session gate"), "source bundle must contain the enforcement");

    // Fresh install copies the current bundle verbatim.
    installProject(root);
    assert.equal(readFileSync(cliPath, "utf8"), bundle);
    assert.ok(readFileSync(cliPath, "utf8").includes("Post-session gate"));

    // An update over a stale CLI refreshes it back to the current bundle, without
    // introducing a new runtime command or CLI flag (payload copy only).
    writeFileSync(cliPath, "// stale coordinator bundle\n");
    installProject(root);
    assert.equal(readFileSync(cliPath, "utf8"), bundle);
    assert.ok(readFileSync(cliPath, "utf8").includes("Post-session gate"));
  });
});

test("packaged runtime templates match the canonical overmind/templates source", () => {
  // The installer ships its own copy of each runtime template; keep it byte-identical
  // to the canonical source so installed workspaces never receive a stale workflow
  // definition (e.g. missing the CRP-165 post-session gate completion conditions).
  for (const templateName of RUNTIME_TEMPLATES) {
    assert.equal(
      readFileSync(packagedTemplateSourcePath(templateName), "utf8"),
      readFileSync(canonicalTemplateSourcePath(templateName), "utf8"),
      `${templateName} drifted from overmind/templates/${templateName}`
    );
  }
});

function typeADefinition(): string {
  const raw = readFileSync(
    packagedTemplateSourcePath("init_progress_definition_TEMPLATE.yaml"),
    "utf8"
  );
  return raw
    .replace("  project_classes: []", '  project_classes: ["backend"]')
    .replace('  project_type_code: ""', '  project_type_code: "A"')
    .replace('  project_type_label: ""', '  project_type_label: "New project"')
    .replace(
      "  class_repo_paths: {}",
      '  class_repo_paths:\n    backend:\n      state: "deferred"\n      path: ""\n      policy: "A"'
    );
}

/** A complete plan-semantic-review ledger that passes the installed `plan-semantic-review` gate. */
function passingPlanSemanticReviewLedger(): string {
  return `# Implementation Plan Semantic Review

## 1. Document Meta
- feature_id: F-1
- feature_title: Feature
- source_implementation_plan: projects/proj/feat/implementation_plan.md
- source_project_definition: projects/proj/init_progress_definition.yaml
- source_requirements_ears: projects/proj/feat/requirements_ears.md
- source_technical_requirements: projects/proj/feat/technical_requirements.md
- review_status: complete
- last_updated: 2026-07-16

## 2. Review Guidance
- completion_rule: complete

## 3. Findings Ledger
- no_findings: true
`;
}

test("installed coordinator rejects a review whose normative artifact fails before checkpointing", () => {
  withProject((root) => {
    installProject(root);

    // A minimal init-complete, repo-less (deferred policy A) project.
    const projectDir = path.join(root, "projects", "proj");
    mkdirSync(projectDir, { recursive: true });
    writeFileSync(path.join(projectDir, "init_progress_definition.yaml"), typeADefinition());
    writeFileSync(path.join(projectDir, "common_contract_definition.md"), "# contract\n");
    writeFileSync(path.join(projectDir, "project_stack_blueprint_backend.md"), "# blueprint\n");
    writeFileSync(path.join(projectDir, "project_agents_md_claude_md_backend.md"), "# agents\n");

    // A complete feature seeded so `--resume 8.4` reopens it from the cache with a
    // single confirmation. Its plan-semantic-review ledger passes, but its
    // placeholder implementation_plan.md fails the implementation-plan gate.
    const featureDir = path.join(projectDir, "feat");
    mkdirSync(featureDir, { recursive: true });
    const placeholders = [
      "user_br_input.md",
      "requirements_ears.md",
      "requirements_ears_review.md",
      "feature_contract_delta.md",
      "project_surface_struct_resp_map_backend.md",
      "technical_requirements.md",
      "implementation_slices.md",
      "prerequisite_gaps.md",
      "implementation_plan.md"
    ];
    writeFileSync(
      path.join(featureDir, "feature_br_summary.md"),
      "## 1. Document Meta\n- feature_title: Alpha\n- ready_to_ears: true\n"
    );
    for (const artifact of placeholders) {
      writeFileSync(path.join(featureDir, artifact), `# ${artifact}\n`);
    }
    writeFileSync(
      path.join(featureDir, "implementation_plan_semantic_review.md"),
      passingPlanSemanticReviewLedger()
    );
    writeFileSync(
      path.join(projectDir, ".overmind_feature_state.json"),
      JSON.stringify({ featurePath: "projects/proj/feat" })
    );

    // Stub model execution: a no-op `codex` on PATH that exits 0 without editing files.
    const binDir = path.join(root, "stub-bin");
    mkdirSync(binDir, { recursive: true });
    const codexStub = path.join(binDir, "codex");
    writeFileSync(codexStub, "#!/bin/sh\nexit 0\n");
    chmodSync(codexStub, 0o755);

    const run = spawnSync(
      process.execPath,
      [
        path.join(root, ".overmind", "overmind.js"),
        "run",
        "--path",
        "projects/proj",
        "--resume",
        "8.4"
      ],
      {
        cwd: root,
        encoding: "utf8",
        input: "y\n", // confirm step 8.4 only
        env: { ...process.env, PATH: `${binDir}${path.delimiter}${process.env.PATH ?? ""}` }
      }
    );

    // The installed coordinator ran the stubbed session, re-gated the mutable set,
    // and rejected step 8.4 with the plan artifact/gate diagnostic; the after-8.4
    // completion checkpoint is never reached. The placeholder plan makes the
    // implementation-plan gate fail as a runtime error (exit 2), so the process
    // exit preserves the blocking classification.
    assert.equal(run.status, 2);
    const combined = `${run.stdout}\n${run.stderr}`;
    assert.match(
      combined,
      /Post-session gate 'implementation-plan' failed for implementation_plan\.md/
    );
    assert.doesNotMatch(combined, /Checkpoint commit.*after step 8\.4/);
  });
});

test("repository and installer payload contain no shell files", () => {
  const repoRoot = path.resolve(packageRoot(), "..", "..");
  const gitWorktree = spawnSync("git", ["rev-parse", "--is-inside-work-tree"], {
    cwd: repoRoot,
    encoding: "utf8"
  });

  if (gitWorktree.status === 0 && gitWorktree.stdout.trim() === "true") {
    const versionedShellFiles = spawnSync("git", ["ls-files", "*.sh"], {
      cwd: repoRoot,
      encoding: "utf8"
    });
    assert.equal(versionedShellFiles.status, 0);
    assert.equal(versionedShellFiles.stdout.trim(), "");
  }

  assert.deepEqual(
    ["packages", "overmind", "tests"].flatMap((entry) =>
      listShellFiles(path.join(repoRoot, entry), { prune: new Set(["node_modules", "dist"]) })
    ),
    []
  );
  assert.deepEqual(listShellFiles(path.join(packageRoot(), "_data")), []);
});

test("plan-semantic-review skill asks once per ledger decision round", () => {
  withProject((root) => {
    installProject(root);
    const question =
      "Which finding numbers should I apply to implementation_plan.md? (examples: 1,3 | all | none | postpone 2 | reject 4)";
    for (const runnerDir of RUNNER_DIRS) {
      const skillText = readFileSync(
        path.join(root, runnerDir, "skills", "overmind-plan-semantic-review", "SKILL.md"),
        "utf8"
      );
      assert.equal(skillText.split(question).length - 1, 1);
      assert.match(skillText, /ask exactly once for this decision round/);
      assert.match(skillText, /this section does not trigger a second ask action/);
    }
  });
});

test("overmind init keeps overmind.js as the only CLI; runner skill folders contain no CLI copy", () => {
  withProject((root) => {
    installProject(root);

    const sharedCliPath = path.join(root, ".overmind", "overmind.js");
    assert.equal(existsSync(sharedCliPath), true);

    for (const runnerDir of RUNNER_DIRS) {
      for (const skillName of ALL_SKILLS) {
        const skillDir = path.join(root, runnerDir, "skills", skillName);
        assert.equal(existsSync(skillDir), true);
        assert.equal(
          existsSync(path.join(skillDir, "overmind.js")),
          false,
          `overmind.js should not be in skill dir ${skillName}/${runnerDir}`
        );
      }
      assert.equal(existsSync(path.join(root, runnerDir, "overmind.js")), false);
    }
  });
});

test("installProject throws and writes no runner skill when overmind-task-to-br SKILL.md is missing", () => {
  const skillSourceDir = packagedSkillSourceDir("overmind-task-to-br");
  const skillMd = path.join(skillSourceDir, "SKILL.md");
  const backup = `${skillMd}.bak`;

  renameSync(skillMd, backup);
  try {
    withProject((root) => {
      assert.throws(() => installProject(root), /Skill payload missing/);
      // Validation fails before any runner target is written.
      for (const skillName of ALL_SKILLS) {
        for (const runnerDir of RUNNER_DIRS) {
          assert.equal(existsSync(path.join(root, runnerDir, "skills", skillName)), false);
        }
      }
    });
  } finally {
    renameSync(backup, skillMd);
  }
});

test("installProject throws and writes no runner skill when overmind-repo-br-scan SKILL.md is missing", () => {
  const skillSourceDir = packagedSkillSourceDir("overmind-repo-br-scan");
  const skillMd = path.join(skillSourceDir, "SKILL.md");
  const backup = `${skillMd}.bak`;

  renameSync(skillMd, backup);
  try {
    withProject((root) => {
      assert.throws(() => installProject(root), /Skill payload missing/);
      // Validation fails before any runner target is written.
      for (const skillName of ALL_SKILLS) {
        for (const runnerDir of RUNNER_DIRS) {
          assert.equal(existsSync(path.join(root, runnerDir, "skills", skillName)), false);
        }
      }
    });
  } finally {
    renameSync(backup, skillMd);
  }
});

test("installProject throws and writes no runner skill when overmind-br-clarification assets are missing", () => {
  const skillSourceDir = packagedSkillSourceDir("overmind-br-clarification");
  const assetsDir = path.join(skillSourceDir, "assets");
  const backup = `${assetsDir}.bak`;

  renameSync(assetsDir, backup);
  try {
    withProject((root) => {
      assert.throws(() => installProject(root), /Skill payload missing/);
      for (const skillName of ALL_SKILLS) {
        for (const runnerDir of RUNNER_DIRS) {
          assert.equal(existsSync(path.join(root, runnerDir, "skills", skillName)), false);
        }
      }
    });
  } finally {
    renameSync(backup, assetsDir);
  }
});

test("installProject throws and writes no runner skill when overmind-requirements-ears assets are missing", () => {
  const skillSourceDir = packagedSkillSourceDir("overmind-requirements-ears");
  const assetsDir = path.join(skillSourceDir, "assets");
  const backup = `${assetsDir}.bak`;

  renameSync(assetsDir, backup);
  try {
    withProject((root) => {
      assert.throws(() => installProject(root), /Skill payload missing/);
      for (const skillName of ALL_SKILLS) {
        for (const runnerDir of RUNNER_DIRS) {
          assert.equal(existsSync(path.join(root, runnerDir, "skills", skillName)), false);
        }
      }
    });
  } finally {
    renameSync(backup, assetsDir);
  }
});

test("installProject throws and writes no runner skill when overmind-ears-review assets are missing", () => {
  const skillSourceDir = packagedSkillSourceDir("overmind-ears-review");
  const assetsDir = path.join(skillSourceDir, "assets");
  const backup = `${assetsDir}.bak`;

  renameSync(assetsDir, backup);
  try {
    withProject((root) => {
      assert.throws(() => installProject(root), /Skill payload missing/);
      for (const skillName of ALL_SKILLS) {
        for (const runnerDir of RUNNER_DIRS) {
          assert.equal(existsSync(path.join(root, runnerDir, "skills", skillName)), false);
        }
      }
    });
  } finally {
    renameSync(backup, assetsDir);
  }
});

for (const payloadEntry of ["SKILL.md", "assets"] as const) {
  test(`installProject throws and writes no runner skill when overmind-contract-delta ${payloadEntry} is missing`, () => {
    const skillSourceDir = packagedSkillSourceDir("overmind-contract-delta");
    const payloadPath = path.join(skillSourceDir, payloadEntry);
    const backup = `${payloadPath}.bak`;

    renameSync(payloadPath, backup);
    try {
      withProject((root) => {
        assert.throws(() => installProject(root), /Skill payload missing/);
        for (const skillName of ALL_SKILLS) {
          for (const runnerDir of RUNNER_DIRS) {
            assert.equal(existsSync(path.join(root, runnerDir, "skills", skillName)), false);
          }
        }
      });
    } finally {
      renameSync(backup, payloadPath);
    }
  });
}

for (const payloadEntry of ["SKILL.md", "assets"] as const) {
  test(`installProject throws and writes no runner skill when overmind-surface-map ${payloadEntry} is missing`, () => {
    const skillSourceDir = packagedSkillSourceDir("overmind-surface-map");
    const payloadPath = path.join(skillSourceDir, payloadEntry);
    const backup = `${payloadPath}.bak`;

    renameSync(payloadPath, backup);
    try {
      withProject((root) => {
        assert.throws(() => installProject(root), /Skill payload missing/);
        for (const skillName of ALL_SKILLS) {
          for (const runnerDir of RUNNER_DIRS) {
            assert.equal(existsSync(path.join(root, runnerDir, "skills", skillName)), false);
          }
        }
      });
    } finally {
      renameSync(backup, payloadPath);
    }
  });
}

test("fresh install exposes surface-map skill, per-class assets, class commands, and track final lines only in SKILL.md", () => {
  withProject((root) => {
    installProject(root);
    const successLine =
      "Repo surface and execution context <track> phase is finished. Nothing else to do now; press Ctrl-C so orchestrator can start the next phase";
    const infeasibleLine =
      "repo surface and execution context <track> gate cannot pass with current repository evidence. Please provide instructions what to do, or adjust requirements and rerun this phase";

    for (const runnerDir of RUNNER_DIRS) {
      const skillDir = path.join(root, runnerDir, "skills", "overmind-surface-map");
      const skillText = readFileSync(path.join(skillDir, "SKILL.md"), "utf8");
      assert.match(
        skillText,
        /node \.overmind\/overmind\.js context surface-map <feature-path> --class <class>/
      );
      assert.match(
        skillText,
        /node \.overmind\/overmind\.js gate surface-map <feature-path> --class <class>/
      );
      assert.equal(skillText.includes(successLine), true);
      assert.equal(skillText.includes(infeasibleLine), true);
      for (const asset of [
        "project_surface_struct_resp_map_be_TEMPLATE.md",
        "project_surface_struct_resp_map_fe_TEMPLATE.md",
        "project_surface_struct_resp_map_be_GOLDEN_EXAMPLE.md",
        "project_surface_struct_resp_map_fe_GOLDEN_EXAMPLE.md"
      ]) {
        assert.equal(existsSync(path.join(skillDir, "assets", asset)), true, asset);
      }
    }
  });
});

test("fresh install exposes contract-delta skill, assets, commands, and final lines only in SKILL.md", () => {
  withProject((root) => {
    installProject(root);
    const successLine =
      "Feature contract delta phase is finished. Nothing else to do now; press Ctrl-C so orchestrator can start the next phase";
    const infeasibleLine =
      "feature contract delta gate cannot pass with current EARS/common-contract inputs. Please provide instructions what to do, or adjust requirements and rerun this phase";

    for (const runnerDir of RUNNER_DIRS) {
      const skillDir = path.join(root, runnerDir, "skills", "overmind-contract-delta");
      const skillText = readFileSync(path.join(skillDir, "SKILL.md"), "utf8");
      assert.match(
        skillText,
        /node \.overmind\/overmind\.js context contract-delta <feature-path>/
      );
      assert.match(skillText, /node \.overmind\/overmind\.js gate contract-delta <feature-path>/);
      assert.equal(skillText.includes(successLine), true);
      assert.equal(skillText.includes(infeasibleLine), true);
      assert.equal(
        existsSync(path.join(skillDir, "assets", "feature_contract_delta_TEMPLATE.md")),
        true
      );
      assert.equal(
        existsSync(path.join(skillDir, "assets", "feature_contract_delta_GOLDEN_EXAMPLE.md")),
        true
      );
    }
  });
});

test("fresh install exposes contract-reconciliation skill, assets, commands, and final lines only in SKILL.md", () => {
  withProject((root) => {
    installProject(root);
    const successLine =
      "Contract reconciliation phase is finished. Nothing else to do now; press Ctrl-C so orchestrator can start the next phase";
    const infeasibleLine =
      "contract reconciliation gate cannot pass with current repository evidence. Please provide instructions what to do, or adjust inputs and rerun this phase";

    for (const runnerDir of RUNNER_DIRS) {
      const skillDir = path.join(root, runnerDir, "skills", "overmind-contract-reconciliation");
      const skillText = readFileSync(path.join(skillDir, "SKILL.md"), "utf8");
      assert.match(
        skillText,
        /node \.overmind\/overmind\.js context contract-reconciliation <project-path> --class <class>/
      );
      assert.match(
        skillText,
        /node \.overmind\/overmind\.js gate contract-reconciliation <project-path>/
      );
      // Inlined durable rule content and ownership constraints.
      assert.match(skillText, /Out-of-scope classes are untouchable/);
      assert.match(skillText, /Do not modify `init_progress_definition\.yaml`/);
      assert.match(skillText, /approve, reject, or revise/);
      assert.equal(skillText.includes(successLine), true);
      assert.equal(skillText.includes(infeasibleLine), true);
      assert.equal(
        existsSync(path.join(skillDir, "assets", "common_contract_definition_TEMPLATE.md")),
        true
      );
      assert.equal(
        existsSync(path.join(skillDir, "assets", "common_contract_definition_GOLDEN_EXAMPLE.md")),
        true
      );
      assert.equal(existsSync(path.join(skillDir, "overmind.js")), false);
    }
  });
});

for (const missing of ["SKILL.md", "assets"] as const) {
  test(`installProject writes no runner targets when overmind-contract-reconciliation ${missing} is missing`, () => {
    const payload = path.join(packagedSkillSourceDir("overmind-contract-reconciliation"), missing);
    const backup = `${payload}.bak`;
    renameSync(payload, backup);
    try {
      withProject((root) => {
        assert.throws(() => installProject(root), /Skill payload missing/);
        for (const skillName of ALL_SKILLS)
          for (const runnerDir of RUNNER_DIRS) {
            assert.equal(existsSync(path.join(root, runnerDir, "skills", skillName)), false);
          }
      });
    } finally {
      renameSync(backup, payload);
    }
  });
}

test("fresh install runs task-to-br capture and context from golden summary plus story source", () => {
  withProject((root) => {
    installProject(root);
    const featureDir = path.join(root, "projects", "project-a", "feature-alpha");
    mkdirSync(featureDir, { recursive: true });
    const goldenSummary = readFileSync(
      path.join(
        root,
        ".claude",
        "skills",
        "overmind-task-to-br",
        "assets",
        "feature_br_summary_GOLDEN_EXAMPLE.md"
      ),
      "utf8"
    );
    writeFileSync(path.join(featureDir, "feature_br_summary.md"), goldenSummary);
    writeFileSync(
      path.join(featureDir, "story.md"),
      "As an operator I need standalone task-to-BR capture.\n"
    );
    assert.equal(existsSync(path.join(featureDir, "user_br_input.md")), false);

    const capture = spawnSync(
      process.execPath,
      [
        path.join(root, ".overmind", "overmind.js"),
        "capture",
        "task-to-br",
        "projects/project-a/feature-alpha",
        "--source-file",
        "story.md"
      ],
      { cwd: root, encoding: "utf8" }
    );

    assert.equal(capture.status, 0);
    assert.match(capture.stdout, /captured task-to-BR input:/);
    assert.equal(existsSync(path.join(featureDir, "user_br_input.md")), true);

    const run = spawnSync(
      process.execPath,
      [
        path.join(root, ".overmind", "overmind.js"),
        "context",
        "task-to-br",
        "projects/project-a/feature-alpha"
      ],
      { cwd: root, encoding: "utf8" }
    );

    assert.equal(run.status, 0);
    assert.match(run.stdout, /# task-to-br context/);
    assert.match(run.stdout, /As an operator I need standalone task-to-BR capture\./);
    assert.match(run.stdout, /feature_br_template_asset: assets\/feature_br_summary_TEMPLATE\.md/);
    assert.doesNotMatch(run.stdout, /\.claude\/skills/);
    assert.match(
      run.stdout,
      /gate_command: node \.overmind\/overmind\.js gate task-to-br projects\/project-a\/feature-alpha/
    );
    assert.match(
      run.stdout,
      /required_source_refs: projects\/project-a\/feature-alpha\/user_br_input\.md; projects\/project-a\/feature-alpha\/story\.md/
    );
  });
});

const TASK_TO_BR_GOLDEN_SOURCE_REFS =
  "- source_refs: projects/auth-platform/self-service-password-reset/user_br_input.md; jira:JIRA-AUTH-241";

test("fresh install places the task-to-BR source-binding contract in both runner skill dirs", () => {
  withProject((root) => {
    installProject(root);

    for (const runnerDir of RUNNER_DIRS) {
      const skillDir = path.join(root, runnerDir, "skills", "overmind-task-to-br");
      const skill = readFileSync(path.join(skillDir, "SKILL.md"), "utf8");
      assert.match(skill, /### Captured Source Binding/);
      assert.match(skill, /required_source_refs/);
      assert.match(skill, /Replace an `\[UNFILLED\]` placeholder rather than appending around it/);

      const golden = readFileSync(
        path.join(skillDir, "assets", "feature_br_summary_GOLDEN_EXAMPLE.md"),
        "utf8"
      );
      assert.equal(golden.includes(TASK_TO_BR_GOLDEN_SOURCE_REFS), true);
    }
  });
});

test("update install replaces a stale task-to-BR source-binding payload", () => {
  withProject((root) => {
    installProject(root);

    for (const runnerDir of RUNNER_DIRS) {
      const skillDir = path.join(root, runnerDir, "skills", "overmind-task-to-br");
      writeFileSync(path.join(skillDir, "SKILL.md"), "stale skill without source binding\n");
      writeFileSync(
        path.join(skillDir, "assets", "feature_br_summary_GOLDEN_EXAMPLE.md"),
        "- source_refs: JIRA-AUTH-241\n"
      );
    }

    installProject(root);

    for (const runnerDir of RUNNER_DIRS) {
      const skillDir = path.join(root, runnerDir, "skills", "overmind-task-to-br");
      const skill = readFileSync(path.join(skillDir, "SKILL.md"), "utf8");
      assert.match(skill, /### Captured Source Binding/);

      const golden = readFileSync(
        path.join(skillDir, "assets", "feature_br_summary_GOLDEN_EXAMPLE.md"),
        "utf8"
      );
      assert.equal(golden.includes(TASK_TO_BR_GOLDEN_SOURCE_REFS), true);
    }
  });
});

const TERMINAL_LEDGER_SKILLS = ["overmind-task-to-br", "overmind-br-clarification"] as const;

function assertTerminalLedgerContract(skill: string): void {
  assert.match(skill, /### Ledger Terminal State/);
  assert.match(skill, /`## 7\. Loop Decision -> unresolved_after_stop`[^\n]*exactly `none`/);
  assert.match(skill, /preserve every pre-existing `gate_result` line and value exactly/);
}

test("fresh install places the terminal-ledger contract in both runner skill dirs", () => {
  withProject((root) => {
    installProject(root);

    for (const runnerDir of RUNNER_DIRS) {
      for (const skillName of TERMINAL_LEDGER_SKILLS) {
        const skillPath = path.join(root, runnerDir, "skills", skillName, "SKILL.md");
        assertTerminalLedgerContract(readFileSync(skillPath, "utf8"));
      }
    }
  });
});

test("update install replaces a stale terminal-ledger skill payload", () => {
  withProject((root) => {
    installProject(root);

    for (const runnerDir of RUNNER_DIRS) {
      for (const skillName of TERMINAL_LEDGER_SKILLS) {
        writeFileSync(
          path.join(root, runnerDir, "skills", skillName, "SKILL.md"),
          "stale skill without terminal ledger rules\n"
        );
      }
    }

    installProject(root);

    for (const runnerDir of RUNNER_DIRS) {
      for (const skillName of TERMINAL_LEDGER_SKILLS) {
        const skillPath = path.join(root, runnerDir, "skills", skillName, "SKILL.md");
        assertTerminalLedgerContract(readFileSync(skillPath, "utf8"));
      }
    }
  });
});

test("installed coordinator bundle rejects a stale terminal ledger and accepts none", () => {
  withProject((root) => {
    installProject(root);
    const cliPath = path.join(root, ".overmind", "overmind.js");
    const featurePath = "projects/project-a/feature-alpha";
    const featureDir = path.join(root, "projects", "project-a", "feature-alpha");
    mkdirSync(featureDir, { recursive: true });

    const goldenSummary = readFileSync(
      path.join(
        root,
        ".claude",
        "skills",
        "overmind-task-to-br",
        "assets",
        "feature_br_summary_GOLDEN_EXAMPLE.md"
      ),
      "utf8"
    );
    writeFileSync(path.join(featureDir, "feature_br_summary.md"), goldenSummary);
    writeFileSync(path.join(featureDir, "story.md"), "As a user I need a password reset link.\n");

    const ledgerPath = path.join(featureDir, "missing_br_data.md");
    const ledger = (unresolvedAfterStop: string): string => `# Missing Business Data

## 1. Gate Status
- gate_result: failed

## 3. Unresolved Items Ledger (Rised)
- rised_item_1: source=## 15. Open Questions -> critical_questions; rised=true; unresolved_item=Is forced MFA re-verification required after reset?

## 6. Latest User Answers
- answers: This was recorded in ## 7. Business Rules and Decision Logic - BR-1.

## 7. Loop Decision
- unresolved_after_stop: ${unresolvedAfterStop}
`;
    writeFileSync(ledgerPath, ledger("Waiting for user input."));

    const capture = spawnSync(
      process.execPath,
      [cliPath, "capture", "task-to-br", featurePath, "--source-file", "story.md"],
      { cwd: root, encoding: "utf8" }
    );
    assert.equal(capture.status, 0);

    const context = spawnSync(process.execPath, [cliPath, "context", "task-to-br", featurePath], {
      cwd: root,
      encoding: "utf8"
    });
    assert.equal(context.status, 0);
    const requiredRefs = /required_source_refs: (.+)/.exec(context.stdout)?.[1];
    const summaryPath = path.join(featureDir, "feature_br_summary.md");
    writeFileSync(
      summaryPath,
      readFileSync(summaryPath, "utf8").replace(
        TASK_TO_BR_GOLDEN_SOURCE_REFS,
        `- source_refs: ${requiredRefs}`
      )
    );

    const stale = spawnSync(process.execPath, [cliPath, "gate", "task-to-br", featurePath], {
      cwd: root,
      encoding: "utf8"
    });
    assert.equal(stale.status, 1);
    assert.match(
      stale.stdout,
      /missing: missing_br_data\.md -> ## 7\. Loop Decision -> unresolved_after_stop must be exactly `none`/
    );

    writeFileSync(ledgerPath, ledger("none"));
    const repaired = spawnSync(process.execPath, [cliPath, "gate", "task-to-br", featurePath], {
      cwd: root,
      encoding: "utf8"
    });
    assert.equal(repaired.status, 0);
    assert.match(repaired.stdout, /business-context gate passed/);
    // The historical gate result survives a read-only gate run.
    assert.match(readFileSync(ledgerPath, "utf8"), /- gate_result: failed/);
  });
});

test("fresh install task-to-BR run repairs source_refs and passes the gate", () => {
  withProject((root) => {
    installProject(root);
    const cliPath = path.join(root, ".overmind", "overmind.js");
    const featurePath = "projects/project-a/feature-alpha";
    const featureDir = path.join(root, "projects", "project-a", "feature-alpha");
    mkdirSync(featureDir, { recursive: true });

    const goldenSummary = readFileSync(
      path.join(
        root,
        ".claude",
        "skills",
        "overmind-task-to-br",
        "assets",
        "feature_br_summary_GOLDEN_EXAMPLE.md"
      ),
      "utf8"
    );
    writeFileSync(path.join(featureDir, "feature_br_summary.md"), goldenSummary);
    writeFileSync(
      path.join(featureDir, "missing_br_data.md"),
      `# Missing Business Data

## 2. Missing Business Fields
- none

## 3. Unresolved Items Ledger (Rised)
- rised_item_1: source=## 15. Open Questions -> critical_questions; rised=false; unresolved_item=Is forced MFA re-verification required after reset?

## 6. Latest User Answers
- answers: [UNFILLED]

## 7. Loop Decision
- unresolved_after_stop: Pending business clarification.
`
    );
    writeFileSync(path.join(featureDir, "story.md"), "As a user I need a password reset link.\n");
    assert.equal(existsSync(path.join(featureDir, "user_br_input.md")), false);

    const capture = spawnSync(
      process.execPath,
      [cliPath, "capture", "task-to-br", featurePath, "--source-file", "story.md"],
      { cwd: root, encoding: "utf8" }
    );
    assert.equal(capture.status, 0);

    const context = spawnSync(process.execPath, [cliPath, "context", "task-to-br", featurePath], {
      cwd: root,
      encoding: "utf8"
    });
    assert.equal(context.status, 0);
    const requiredRefs = /required_source_refs: (.+)/.exec(context.stdout)?.[1];
    assert.equal(requiredRefs, `${featurePath}/user_br_input.md; ${featurePath}/story.md`);

    const beforeRepair = spawnSync(process.execPath, [cliPath, "gate", "task-to-br", featurePath], {
      cwd: root,
      encoding: "utf8"
    });
    assert.equal(beforeRepair.status, 1);
    assert.match(
      beforeRepair.stdout,
      /missing: ## 1\. Document Meta -> source_refs must include the captured source reference:/
    );

    const summaryPath = path.join(featureDir, "feature_br_summary.md");
    writeFileSync(
      summaryPath,
      readFileSync(summaryPath, "utf8").replace(
        TASK_TO_BR_GOLDEN_SOURCE_REFS,
        `- source_refs: ${requiredRefs}`
      )
    );

    const afterRepair = spawnSync(process.execPath, [cliPath, "gate", "task-to-br", featurePath], {
      cwd: root,
      encoding: "utf8"
    });
    assert.equal(afterRepair.status, 0);
    assert.match(afterRepair.stdout, /business-context gate passed/);
  });
});

test("fresh install exposes repo-br-scan context command after install", () => {
  withProject((root) => {
    installProject(root);
    assert.equal(
      existsSync(path.join(root, ".claude", "skills", "overmind-repo-br-scan", "SKILL.md")),
      true
    );
    assert.equal(
      existsSync(path.join(root, ".codex", "skills", "overmind-repo-br-scan", "SKILL.md")),
      true
    );
  });
});

test("fresh install exposes br-clarification skill and shared readiness CLI", () => {
  withProject((root) => {
    installProject(root);
    for (const runnerDir of RUNNER_DIRS) {
      const skillDir = path.join(root, runnerDir, "skills", "overmind-br-clarification");
      assert.equal(existsSync(path.join(skillDir, "SKILL.md")), true);
      assert.equal(
        existsSync(path.join(skillDir, "assets", "feature_br_summary_TEMPLATE.md")),
        true
      );
      const skillText = readFileSync(path.join(skillDir, "SKILL.md"), "utf8");
      assert.match(skillText, /If no unresolved questions exist, ask no questions\./);
      assert.match(
        skillText,
        /Run `node \.overmind\/overmind\.js gate br-clarification <feature-path>`/
      );
      assert.match(skillText, /add `rised=false` to the affected `rised_item_N` entry/);
      assert.match(skillText, /After every gate run, show the gate command output to the operator/);
      assert.match(
        skillText,
        /rule 3: BR clarification is complete for EARS readiness \.\.\. PASS/
      );
    }

    const result = spawnSync(
      process.execPath,
      [path.join(root, ".overmind", "overmind.js"), "readiness"],
      { cwd: root, encoding: "utf8" }
    );
    assert.equal(result.status, 2);
    assert.match(result.stderr, /capture\|context\|gate\|sync\|readiness/);
  });
});

test("fresh install exposes requirements-ears skill, assets, and final lines only in SKILL.md", () => {
  withProject((root) => {
    installProject(root);
    const successLine =
      "BR->requirement-EARS phase is finished. Nothing else to do now; press Ctrl-C so orchestrator can start the next phase";
    const infeasibleLine =
      "based on provided reasons, EARS gate cannot pass with current BR input. Please provide instructions what to do, or adjust requirements and rerun this phase";

    for (const runnerDir of RUNNER_DIRS) {
      const skillDir = path.join(root, runnerDir, "skills", "overmind-requirements-ears");
      assert.equal(existsSync(path.join(skillDir, "SKILL.md")), true);
      assert.equal(existsSync(path.join(skillDir, "assets", "reqirements_ears_TEMPLATE.md")), true);
      assert.equal(
        existsSync(path.join(skillDir, "assets", "reqirements_ears_GOLDEN_EXAMPLE.md")),
        true
      );
      const skillText = readFileSync(path.join(skillDir, "SKILL.md"), "utf8");
      assert.match(
        skillText,
        /node \.overmind\/overmind\.js context requirements-ears <feature-path>/
      );
      assert.match(
        skillText,
        /node \.overmind\/overmind\.js gate requirements-ears <feature-path>/
      );
      assert.match(skillText, /requirements_ears\.md/);
      assert.match(skillText, /feature_br_summary\.md/);
      assert.equal(skillText.includes(successLine), true);
      assert.equal(skillText.includes(infeasibleLine), true);
    }
  });
});

test("fresh install exposes ears-review skill, assets, commands, and final lines only in SKILL.md", () => {
  withProject((root) => {
    installProject(root);
    const successLine =
      "requirements_ears extra review phase is finished. Nothing else to do now; press Ctrl-C so orchestrator can start the next phase";
    const infeasibleLine =
      "based on provided reasons, requirements_ears extra review cannot be completed with current BR/EARS input. Please provide instructions what to do, or adjust artifacts and rerun this phase";

    for (const runnerDir of RUNNER_DIRS) {
      const skillDir = path.join(root, runnerDir, "skills", "overmind-ears-review");
      assert.equal(existsSync(path.join(skillDir, "SKILL.md")), true);
      assert.equal(
        existsSync(path.join(skillDir, "assets", "requirements_ears_review_TEMPLATE.md")),
        true
      );
      assert.equal(
        existsSync(path.join(skillDir, "assets", "requirements_ears_review_GOLDEN_EXAMPLE.md")),
        true
      );
      const skillText = readFileSync(path.join(skillDir, "SKILL.md"), "utf8");
      assert.match(skillText, /node \.overmind\/overmind\.js context ears-review <feature-path>/);
      assert.match(skillText, /node \.overmind\/overmind\.js gate ears-review <feature-path>/);
      assert.match(skillText, /requirements_ears\.md/);
      assert.match(skillText, /requirements_ears_review\.md/);
      assert.match(skillText, /feature_br_summary\.md/);
      assert.match(skillText, /Here is the finding: <concise gap summary for the current finding>/);
      assert.equal(skillText.includes(successLine), true);
      assert.equal(skillText.includes(infeasibleLine), true);

      // Dual-source contract: raw backstop, narrowing sweep, and mandatory citations.
      assert.match(skillText, /user_br_input\.md/);
      assert.match(skillText, /Mandatory Raw-Input Narrowing Sweep/);
      assert.match(skillText, /ACTIVE/);
      assert.match(skillText, /source_user_br_input_reference/);
      // No new ears-review CLI command or flag was introduced.
      assert.doesNotMatch(skillText, /context ears-review <feature-path> --/);
      assert.doesNotMatch(skillText, /gate ears-review <feature-path> --/);

      const templateText = readFileSync(
        path.join(skillDir, "assets", "requirements_ears_review_TEMPLATE.md"),
        "utf8"
      );
      assert.match(templateText, /- source_user_br_input: \[UNFILLED\]/);
      assert.match(templateText, /- source_user_br_input_reference:/);

      const goldenText = readFileSync(
        path.join(skillDir, "assets", "requirements_ears_review_GOLDEN_EXAMPLE.md"),
        "utf8"
      );
      assert.match(goldenText, /- source_user_br_input: /);
      assert.match(goldenText, /ACTIVE qualifier narrows duplicate-account prohibition/);
      assert.match(goldenText, /- source_user_br_input_reference: user_br_input\.md ->/);
      assert.match(goldenText, /- source_user_br_input_reference: none/);
    }
  });
});

test("installed ears-review contract requires a three-location finding for the ACTIVE duplicate scenario", () => {
  withProject((root) => {
    installProject(root);

    // Concrete smoke scenario: raw input forbids duplicates for the same user and account
    // type without a status qualifier, while summary and EARS narrow it to ACTIVE accounts.
    const featureDir = path.join(root, "projects", "smoke", "duplicate-accounts");
    mkdirSync(featureDir, { recursive: true });
    writeFileSync(
      path.join(featureDir, "user_br_input.md"),
      "## 2. Epic/Story Input\n- epic_or_story: |\n  The system must never let a user hold two accounts of the same account type.\n"
    );
    writeFileSync(
      path.join(featureDir, "feature_br_summary.md"),
      "## 7. Business Rules and Decision Logic\n- BR-4: Reject a new account when the user already has an ACTIVE account of the same type.\n"
    );
    writeFileSync(
      path.join(featureDir, "requirements_ears.md"),
      "Requirement 12: WHEN a user requests a new account of a type for which an ACTIVE account exists, the system SHALL reject the request.\n"
    );

    for (const runnerDir of RUNNER_DIRS) {
      const skillDir = path.join(root, runnerDir, "skills", "overmind-ears-review");
      const skillText = readFileSync(path.join(skillDir, "SKILL.md"), "utf8");
      // The deployed skill instructs the ACTIVE duplicate narrowing to become a finding that
      // cites all three locations (raw, summary reference, affected EARS requirement).
      assert.match(skillText, /duplicate accounts for the same user and account type/);
      assert.match(skillText, /qualifier as an unsupported narrowing/);
      assert.match(skillText, /source_user_br_input_reference/);
      assert.match(skillText, /source_br_summary_reference/);
      assert.match(skillText, /related_requirement_targets/);

      const goldenText = readFileSync(
        path.join(skillDir, "assets", "requirements_ears_review_GOLDEN_EXAMPLE.md"),
        "utf8"
      );
      // The golden example demonstrates the same regression with concrete three-location citations.
      const activeFinding = goldenText
        .split(/^### /m)
        .find((block) => /ACTIVE qualifier narrows duplicate-account prohibition/.test(block));
      assert.ok(activeFinding, "golden example must include the ACTIVE-narrowing finding");
      assert.match(activeFinding, /- source_user_br_input_reference: user_br_input\.md ->/);
      assert.match(activeFinding, /- source_br_summary_reference: feature_br_summary\.md ->/);
      assert.match(activeFinding, /- related_requirement_targets: Requirement 12/);
    }
  });
});

test("fresh install copies overmind-surface-map-enrich to .codex/skills/ and .claude/skills/", () => {
  withProject((root) => {
    installProject(root);

    for (const runnerDir of RUNNER_DIRS) {
      const skillDir = path.join(root, runnerDir, "skills", "overmind-surface-map-enrich");
      assert.equal(
        existsSync(path.join(skillDir, "SKILL.md")),
        true,
        `SKILL.md missing for overmind-surface-map-enrich/${runnerDir}`
      );
    }
  });
});

test("installProject throws before writing runner targets when overmind-surface-map-enrich SKILL.md is missing", () => {
  const skillSourceDir = packagedSkillSourceDir("overmind-surface-map-enrich");
  const skillMd = path.join(skillSourceDir, "SKILL.md");
  const backup = `${skillMd}.bak`;

  renameSync(skillMd, backup);
  try {
    withProject((root) => {
      assert.throws(() => installProject(root), /Skill payload missing/);
      for (const skillName of ALL_SKILLS) {
        for (const runnerDir of RUNNER_DIRS) {
          assert.equal(existsSync(path.join(root, runnerDir, "skills", skillName)), false);
        }
      }
    });
  } finally {
    renameSync(backup, skillMd);
  }
});

test("fresh install copies overmind-technical-requirements with assets to supported runners", () => {
  withProject((root) => {
    installProject(root);
    for (const runnerDir of RUNNER_DIRS) {
      const skillDir = path.join(root, runnerDir, "skills", "overmind-technical-requirements");
      assert.equal(existsSync(path.join(skillDir, "SKILL.md")), true);
      assert.equal(
        existsSync(path.join(skillDir, "assets", "technical_requirements_TEMPLATE.md")),
        true
      );
      assert.equal(
        existsSync(path.join(skillDir, "assets", "technical_requirements_GOLDEN_EXAMPLE.md")),
        true
      );
    }
  });
});

test("installProject writes no runner targets when overmind-technical-requirements SKILL.md is missing", () => {
  const skillMd = path.join(packagedSkillSourceDir("overmind-technical-requirements"), "SKILL.md");
  const backup = `${skillMd}.bak`;
  renameSync(skillMd, backup);
  try {
    withProject((root) => {
      assert.throws(() => installProject(root), /Skill payload missing/);
      for (const skillName of ALL_SKILLS) {
        for (const runnerDir of RUNNER_DIRS) {
          assert.equal(existsSync(path.join(root, runnerDir, "skills", skillName)), false);
        }
      }
    });
  } finally {
    renameSync(backup, skillMd);
  }
});

test("fresh install copies overmind-implementation-slices with assets to supported runners", () => {
  withProject((root) => {
    installProject(root);
    for (const runnerDir of RUNNER_DIRS) {
      const skillDir = path.join(root, runnerDir, "skills", "overmind-implementation-slices");
      assert.equal(existsSync(path.join(skillDir, "SKILL.md")), true);
      assert.equal(
        existsSync(path.join(skillDir, "assets", "implementation_slices_TEMPLATE.md")),
        true
      );
      assert.equal(
        existsSync(path.join(skillDir, "assets", "implementation_slices_GOLDEN_EXAMPLE.md")),
        true
      );
      assert.equal(existsSync(path.join(skillDir, "overmind.js")), false);
    }
  });
});

test("installProject writes no runner targets when overmind-implementation-slices SKILL.md is missing", () => {
  const skillMd = path.join(packagedSkillSourceDir("overmind-implementation-slices"), "SKILL.md");
  const backup = `${skillMd}.bak`;
  renameSync(skillMd, backup);
  try {
    withProject((root) => {
      assert.throws(() => installProject(root), /Skill payload missing/);
      for (const skillName of ALL_SKILLS) {
        for (const runnerDir of RUNNER_DIRS) {
          assert.equal(existsSync(path.join(root, runnerDir, "skills", skillName)), false);
        }
      }
    });
  } finally {
    renameSync(backup, skillMd);
  }
});

test("fresh install copies overmind-prerequisite-gaps with assets to supported runners", () => {
  withProject((root) => {
    installProject(root);
    for (const runnerDir of RUNNER_DIRS) {
      const skillDir = path.join(root, runnerDir, "skills", "overmind-prerequisite-gaps");
      assert.equal(existsSync(path.join(skillDir, "SKILL.md")), true);
      assert.equal(
        existsSync(path.join(skillDir, "assets", "prerequisite_gaps_TEMPLATE.md")),
        true
      );
      assert.equal(
        existsSync(path.join(skillDir, "assets", "prerequisite_gaps_GOLDEN_EXAMPLE.md")),
        true
      );
      assert.equal(existsSync(path.join(skillDir, "overmind.js")), false);
    }
  });
});

for (const missing of ["SKILL.md", "assets"] as const) {
  test(`installProject writes no runner targets when overmind-prerequisite-gaps ${missing} is missing`, () => {
    const payload = path.join(packagedSkillSourceDir("overmind-prerequisite-gaps"), missing);
    const backup = `${payload}.bak`;
    renameSync(payload, backup);
    try {
      withProject((root) => {
        assert.throws(() => installProject(root), /Skill payload missing/);
        for (const skillName of ALL_SKILLS)
          for (const runnerDir of RUNNER_DIRS) {
            assert.equal(existsSync(path.join(root, runnerDir, "skills", skillName)), false);
          }
      });
    } finally {
      renameSync(backup, payload);
    }
  });
}

test("fresh install copies overmind-implementation-plan with assets to supported runners", () => {
  withProject((root) => {
    installProject(root);
    for (const runnerDir of RUNNER_DIRS) {
      const skillDir = path.join(root, runnerDir, "skills", "overmind-implementation-plan");
      assert.equal(existsSync(path.join(skillDir, "SKILL.md")), true);
      assert.equal(
        existsSync(path.join(skillDir, "assets", "implementation_plan_TEMPLATE.md")),
        true
      );
      assert.equal(
        existsSync(path.join(skillDir, "assets", "implementation_plan_GOLDEN_EXAMPLE.md")),
        true
      );
      assert.equal(existsSync(path.join(skillDir, "overmind.js")), false);
    }
  });
});

for (const missing of ["SKILL.md", "assets"] as const) {
  test(`installProject writes no runner targets when overmind-implementation-plan ${missing} is missing`, () => {
    const payload = path.join(packagedSkillSourceDir("overmind-implementation-plan"), missing);
    const backup = `${payload}.bak`;
    renameSync(payload, backup);
    try {
      withProject((root) => {
        assert.throws(() => installProject(root), /Skill payload missing/);
        for (const skillName of ALL_SKILLS)
          for (const runnerDir of RUNNER_DIRS) {
            assert.equal(existsSync(path.join(root, runnerDir, "skills", skillName)), false);
          }
      });
    } finally {
      renameSync(backup, payload);
    }
  });
}

// --- CRP-166: terminal feature-gate chain in the installed runtime -----------

/**
 * Seed a feature whose deterministic artifacts are deliberately defective, so
 * the installed chain has real work to classify. `requirements_ears.md` carries
 * the measured invalid `WHEN ..., THEN THE ... SHALL ...` pattern and
 * `implementation_plan.md` begins directly with a step, having lost the
 * template's `# Implementation Plan` header.
 */
function seedTerminalChainFeature(root: string): string {
  const featureDir = path.join(root, "projects", "project-a", "feature-alpha");
  mkdirSync(featureDir, { recursive: true });
  writeFileSync(
    path.join(root, "projects", "project-a", "init_progress_definition.yaml"),
    readFileSync(
      path.join(root, ".templates", "init_progress_definition_TEMPLATE.yaml"),
      "utf8"
    ).replace("  project_classes: []", '  project_classes: ["backend"]')
  );
  writeFileSync(
    path.join(featureDir, "requirements_ears.md"),
    `# Requirements (EARS)

## Requirements

### Requirement 12 - Duplicate accounts
**User Story:** As a user, I want no duplicate accounts, so that billing stays correct.

**Acceptance Criteria (EARS):**
- WHEN a duplicate account is submitted, THEN THE System SHALL reject the request.

**Verification:** API test.
`
  );
  writeFileSync(
    path.join(featureDir, "technical_requirements.md"),
    `## 4. Requirement Coverage and Gaps
### Requirement: REQ-1
- gap_status: pending
- gap_to_close: implement
## 5. Impacted Components
### Component: Backend Order Service
- repo: backend
- gap_to_close: implement
`
  );
  writeFileSync(
    path.join(featureDir, "prerequisite_gaps.md"),
    `#### Prerequisite: A
- status: scheduled_in_slices
- slice_ref: slice-1
- surface_kind: none
- surface_identity: none
`
  );
  writeFileSync(
    path.join(featureDir, "implementation_plan.md"),
    `### Step 1.1 Deliver operator login page [REQ-1]
#### Repo: backend
#### Depends on: none
#### Evidence: gap/TECH_REQ-1, comp/backend-order-service, slice/slice-1
#### Preserved Surface: none
- [ ] Plan and discuss the step
- [ ] Implement the login endpoint
- [ ] Review step implementation
`
  );
  return featureDir;
}

/**
 * Materialize the coordinator's shared valid-feature fixture (CRP-166): a feature
 * whose other deterministic artifacts genuinely pass their gates, so the only
 * failure is the plan's missing `# Implementation Plan` header and step `8.3`
 * owns the repair. Read as data across the workspace boundary, the same way the
 * packaged-template parity test reaches the canonical `overmind/templates`.
 */
function validFeatureFixtureDir(): string {
  return path.resolve(
    packageRoot(),
    "..",
    "asdlc-coordinator",
    "test",
    "fixtures",
    "valid-feature"
  );
}

function seedValidFeature(root: string, options: { withPlanHeader?: boolean } = {}): string {
  const source = validFeatureFixtureDir();
  const projectDir = path.join(root, "projects", "project-a");
  const featureDir = path.join(projectDir, "feature-alpha");
  mkdirSync(featureDir, { recursive: true });
  for (const entry of readdirSync(source)) {
    if (entry === "README.md") continue;
    const target =
      entry === "init_progress_definition.yaml"
        ? path.join(projectDir, entry)
        : path.join(featureDir, entry);
    writeFileSync(target, readFileSync(path.join(source, entry), "utf8"));
  }
  if (options.withPlanHeader) {
    const planPath = path.join(featureDir, "implementation_plan.md");
    writeFileSync(planPath, `# Implementation Plan\n${readFileSync(planPath, "utf8")}`);
  }
  return featureDir;
}

function runGateAll(cliPath: string, root: string) {
  return spawnSync(process.execPath, [cliPath, "gate", "all", "projects/project-a/feature-alpha"], {
    cwd: root,
    encoding: "utf8"
  });
}

test("fresh install and update ship the terminal chain and refresh quickrun without new payload", () => {
  withProject((root) => {
    const bundle = readFileSync(bundledCliPath(), "utf8");
    // The terminal chain and the implementation-plan header sentinel both survive
    // bundling; their literals are the markers that the shipped CLI carries them.
    assert.ok(bundle.includes("gate all summary:"), "bundle must contain the terminal chain");
    assert.ok(bundle.includes("must start with exact header: # Implementation Plan"));

    installProject(root);
    const cliPath = path.join(root, ".overmind", "overmind.js");
    assert.equal(readFileSync(cliPath, "utf8"), bundle);
    assert.match(readFileSync(path.join(root, "quickrun.md"), "utf8"), /gate all projects\//);

    // An update refreshes both without adding a skill, helper, template, or setup payload.
    const skillsBefore = readdirSync(path.join(root, ".claude", "skills")).sort();
    const templatesBefore = readdirSync(path.join(root, ".templates")).sort();
    const setupBefore = readdirSync(path.join(root, ".setup")).sort();
    writeFileSync(cliPath, "// stale coordinator bundle\n");
    writeFileSync(path.join(root, "quickrun.md"), "stale quickrun\n");

    installProject(root);

    assert.equal(readFileSync(cliPath, "utf8"), bundle);
    assert.match(readFileSync(path.join(root, "quickrun.md"), "utf8"), /gate all projects\//);
    assert.deepEqual(readdirSync(path.join(root, ".claude", "skills")).sort(), skillsBefore);
    assert.deepEqual(readdirSync(path.join(root, ".templates")).sort(), templatesBefore);
    assert.deepEqual(readdirSync(path.join(root, ".setup")).sort(), setupBefore);
    assert.equal(existsSync(path.join(root, ".helper")), false);
    assert.equal(existsSync(path.join(root, ".commands")), false);
  });
});

test("installed gate all classifies a feature identically to the source coordinator", () => {
  withProject((root) => {
    installProject(root);
    seedTerminalChainFeature(root);

    const installed = runGateAll(path.join(root, ".overmind", "overmind.js"), root);
    const source = runGateAll(bundledCliPath(), root);

    assert.equal(installed.status, source.status);
    assert.equal(installed.stdout, source.stdout);
    assert.equal(installed.stderr, source.stderr);
    // The aggregate is a real classification, not a vacuous pass.
    assert.notEqual(installed.status, 0);
    assert.match(installed.stdout, /gate all summary: \d+ passed, \d+ failed, \d+ skipped/);
  });
});

test("installed gate all rejects an earlier invalid artifact and names its owning step", () => {
  withProject((root) => {
    installProject(root);
    seedTerminalChainFeature(root);

    const result = runGateAll(path.join(root, ".overmind", "overmind.js"), root);

    // The measured invalid EARS pattern fails, and step 5 owns the earliest failure,
    // so an installed run cannot report plan completion or reach its after-review
    // checkpoint until that artifact is repaired.
    assert.match(result.stdout, /failed {2}requirements-ears {2}requirements_ears\.md/);
    assert.match(result.stderr, /--resume 5/);
    // Later gates still ran: the report is complete rather than fail-fast.
    assert.match(result.stdout, /implementation-plan {2}implementation_plan\.md/);
  });
});

test("installed gate all pins the plan-header defect to repair owner 8.3", () => {
  withProject((root) => {
    installProject(root);
    seedValidFeature(root);
    const cliPath = path.join(root, ".overmind", "overmind.js");

    const failing = runGateAll(cliPath, root);

    // Every gate before the plan passes or skips, so 8.3 is the earliest failure
    // and the guidance an operator is handed is the one that repairs the defect.
    assert.equal(failing.status, 1);
    assert.match(
      failing.stdout,
      /missing: implementation_plan\.md must start with exact header: # Implementation Plan/
    );
    assert.match(failing.stderr, /--resume 8\.3/);
    assert.doesNotMatch(failing.stdout, /^failed {2}(?!implementation-plan)/m);
    assert.match(failing.stdout, /gate all summary: 4 passed, 1 failed, 9 skipped/);
  });
});

test("installed gate all passes once the plan header is restored", () => {
  withProject((root) => {
    installProject(root);
    seedValidFeature(root, { withPlanHeader: true });

    const repaired = runGateAll(path.join(root, ".overmind", "overmind.js"), root);

    assert.equal(repaired.status, 0);
    assert.match(repaired.stdout, /gate all summary: 5 passed, 0 failed, 9 skipped/);
    assert.equal(repaired.stderr, "");
  });
});

/**
 * Flow-end enforcement, not just standalone dispatch. Declining the optional
 * `8.4` review drives the installed feature flow to its plan-completion boundary
 * without invoking any model, so this fails if the bundle ever loses the hook
 * while `gate all` keeps working.
 *
 * The extra placeholder artifacts exist only so artifact-presence scanning reads
 * the feature as complete and selection resolves straight from the cache: the
 * installed CLI builds a fresh readline interface per prompt, so a piped-stdin
 * smoke can drive exactly one question. Their gates fail too, which is the point
 * — an earlier invalid artifact must block terminal success.
 */
test("installed run blocks plan completion when terminal validation fails", () => {
  withProject((root) => {
    installProject(root);
    const featureDir = seedValidFeature(root);
    const projectDir = path.join(root, "projects", "project-a");
    writeFileSync(
      path.join(featureDir, "feature_br_summary.md"),
      "## 1. Document Meta\n- feature_title: Operator task management\n- ready_to_ears: true\n"
    );
    for (const artifact of [
      "user_br_input.md",
      "feature_contract_delta.md",
      "implementation_slices.md"
    ]) {
      writeFileSync(path.join(featureDir, artifact), `# ${artifact}\n`);
    }
    writeFileSync(path.join(projectDir, "common_contract_definition.md"), "ok\n");
    writeFileSync(
      path.join(projectDir, ".overmind_feature_state.json"),
      JSON.stringify({ featurePath: path.relative(root, featureDir) })
    );

    const run = spawnSync(
      process.execPath,
      [
        path.join(root, ".overmind", "overmind.js"),
        "run",
        "--path",
        "projects/project-a",
        "--resume",
        "8.4"
      ],
      { cwd: root, encoding: "utf8", input: "n\n" }
    );
    const output = `${run.stdout}${run.stderr}`;

    // The flow reached its plan-completion boundary and the chain blocked it.
    assert.equal(run.status, 1);
    assert.match(output, /Start step 8\.4/);
    assert.match(run.stderr, /terminal-gate-chain:/);
    assert.match(
      run.stderr,
      /implementation_plan\.md must start with exact header: # Implementation Plan/
    );
    assert.match(run.stderr, /overmind run --path projects\/project-a --resume 4\.1/);
    // No completion notice and no after-review checkpoint.
    assert.doesNotMatch(output, /Execution finished/);
    assert.doesNotMatch(output, /after step 8\.4 \(semantic review\)/);
  });
});

test("fresh install propagates task-to-BR and requirements-EARS semantic-preservation rules to both runners", () => {
  withProject((root) => {
    installProject(root);

    for (const runnerDir of RUNNER_DIRS) {
      const taskToBrDir = path.join(root, runnerDir, "skills", "overmind-task-to-br");
      const taskToBrSkill = readFileSync(path.join(taskToBrDir, "SKILL.md"), "utf8");
      assert.match(taskToBrSkill, /### Ambiguity Scan Scope/);
      assert.match(taskToBrSkill, /`fast`, `better`, `simple`, `as needed`, `TBD`, `etc\.`/);
      assert.match(
        taskToBrSkill,
        /Every explicit source prohibition[^\n]*`### 2\.3 Explicitly stated in source -> stated_constraints` or `### 5\.2 Out of scope -> out_of_scope_items`/
      );
      assert.match(
        taskToBrSkill,
        /answered `rised=true` ledger item whose `source=` locator list names that field/
      );

      const brGolden = readFileSync(
        path.join(taskToBrDir, "assets", "feature_br_summary_GOLDEN_EXAMPLE.md"),
        "utf8"
      );
      assert.match(
        brGolden,
        /- stated_constraints:[^\n]*no new identity provider and no SMS delivery channel/
      );
      assert.match(brGolden, /- out_of_scope_items:[^\n]*SMS delivery channel/);
      assert.match(
        brGolden,
        /- config_expectations:[^\n]*no new identity-provider or SMS configuration/
      );

      const ledgerGolden = readFileSync(
        path.join(taskToBrDir, "assets", "missing_br_data_GOLDEN_EXAMPLE.md"),
        "utf8"
      );
      assert.match(
        ledgerGolden,
        /source=### Negative and rejection cases -> rejection_cases, ## 7\. Business Rules and Decision Logic -> BR-4; rised=false/
      );

      const earsDir = path.join(root, runnerDir, "skills", "overmind-requirements-ears");
      const earsSkill = readFileSync(path.join(earsDir, "SKILL.md"), "utf8");
      assert.match(earsSkill, /### Broad and Specific Requirement Precedence/);
      assert.match(
        earsSkill,
        /replaces the broader requirement only when the BR summary explicitly states/
      );
      assert.equal(earsSkill.includes("Prefer narrower requirements"), false);
      assert.match(earsSkill, /### Final Coverage Sweep/);
      assert.match(earsSkill, /### 12\.5 Testing and quality -> required_test_levels/);

      const earsGolden = readFileSync(
        path.join(earsDir, "assets", "reqirements_ears_GOLDEN_EXAMPLE.md"),
        "utf8"
      );
      assert.match(
        earsGolden,
        /contains invalid task data, THEN THE Example Task Tracking Service SHALL reject/
      );
      assert.match(
        earsGolden,
        /missing a title, THEN THE Example Task Tracking Service SHALL reject/
      );
      assert.match(earsGolden, /Out of scope:[^\n]*time-tracking analytics reports/);
      assert.match(
        earsGolden,
        /\*\*Verification:\*\* Backend automated API tests[^\n]*invalid task data generally and the missing-title case/
      );
    }
  });
});
