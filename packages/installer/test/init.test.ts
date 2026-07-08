import {
  existsSync,
  mkdirSync,
  mkdtempSync,
  readdirSync,
  readFileSync,
  renameSync,
  rmSync,
  statSync,
  writeFileSync
} from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";
import test from "node:test";
import assert from "node:assert/strict";

import { installProject } from "../src/index.js";

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

function packagedSetupSourcePath(setupName: string): string {
  return path.join(packageRoot(), "_data", "setup", setupName);
}

function installerBinPath(): string {
  const moduleDir = path.dirname(fileURLToPath(import.meta.url));
  return path.resolve(moduleDir, "..", "src", "bin", "overmind.js");
}

function withProject(fn: (root: string) => void): void {
  const root = mkdtempSync(path.join(tmpdir(), "overmind-init-"));
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
  "overmind-task-to-br": ["feature_br_summary_TEMPLATE.md"],
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
      "Common contract definition phase is finished. Nothing else to do now; press Ctrl-C so orchestrator can start the next phase";
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
    assert.match(result.stderr, /overmind <run\|project create\|project init/);
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
      "node .overmind/overmind.js project create",
      "node .overmind/overmind.js project reconcile",
      "node .overmind/overmind.js project init",
      "node .overmind/overmind.js worker register",
      "node .overmind/overmind.js worker assign",
      "node .overmind/overmind.js run",
      "node .overmind/overmind.js scaffold feature",
      "node .overmind/overmind.js status",
      "node .overmind/overmind.js context task-to-br",
      "node .overmind/overmind.js gate task-to-br"
    ]) {
      assert.match(quickrun, new RegExp(escapeRegExp(expected)));
    }
    assert.doesNotMatch(quickrun, /\.sh\b/);

    const output = spawnSync(process.execPath, [installerBinPath(), "init"], {
      cwd: root,
      encoding: "utf8"
    });
    assert.equal(output.status, 0);
    assert.match(output.stdout, /Overmind workspace bootstrap complete\./);
    assert.match(output.stdout, /CLI: \.overmind\/overmind\.js/);
    assert.match(output.stdout, /Runtime templates:/);
    assert.match(output.stdout, /Setup defaults:/);
    assert.match(output.stdout, /Quick run: quickrun\.md/);
    assert.doesNotMatch(output.stdout, /\.sh\b/);
    assert.equal(output.stderr, "");
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
