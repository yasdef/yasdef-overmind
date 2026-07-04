import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";
import test from "node:test";
import assert from "node:assert/strict";

import { createFeatureFixture, goldenBasedValidSummary, jiraUserInput } from "./fixtures.js";

const bundlePath = fileURLToPath(new URL("../overmind.js", import.meta.url));

function withWorkspace(fn: (root: string) => void): void {
  const root = mkdtempSync(path.join(tmpdir(), "overmind-cli-"));
  try {
    fn(root);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
}

test("overmind gate task-to-br exits 0 for valid artifacts", () => {
  withWorkspace((root) => {
    const featureDir = createFeatureFixture(root);
    const result = spawnSync(process.execPath, [bundlePath, "gate", "task-to-br", featureDir], {
      cwd: root,
      encoding: "utf8"
    });
    assert.equal(result.status, 0);
    assert.match(result.stdout, /business-context gate passed/);
  });
});

test("overmind gate task-to-br exits 1 with one missing line per problem", () => {
  withWorkspace((root) => {
    const featureDir = createFeatureFixture(root, {
      summary: `# Feature Business Requirements Summary

## 1. Document Meta
- source_type: Story
- last_updated: [UNFILLED]
`
    });
    const result = spawnSync(process.execPath, [bundlePath, "gate", "task-to-br", featureDir], {
      cwd: root,
      encoding: "utf8"
    });
    assert.equal(result.status, 1);
    assert.match(result.stdout, /^business-context gate failed/m);
    assert.match(
      result.stdout,
      /^missing: ## 1\. Document Meta -> source_type must include User input/m
    );
    assert.match(result.stdout, /^missing: ## 1\. Document Meta -> last_updated is unfilled/m);
  });
});

test("overmind gate task-to-br exits 2 for usage/runtime errors", () => {
  withWorkspace((root) => {
    const missingFeature = path.join(root, "projects", "project-a", "missing-feature");
    const result = spawnSync(process.execPath, [bundlePath, "gate", "task-to-br", missingFeature], {
      cwd: root,
      encoding: "utf8"
    });
    assert.equal(result.status, 2);
    assert.match(result.stderr, /ERROR: Target BR summary not found:/);
  });
});

test("overmind gate task-to-br exits 2 when target path argument is missing", () => {
  withWorkspace((root) => {
    const result = spawnSync(process.execPath, [bundlePath, "gate", "task-to-br"], {
      cwd: root,
      encoding: "utf8"
    });
    assert.equal(result.status, 2);
    assert.match(result.stderr, /ERROR: Usage: overmind gate <step> <path>/);
  });
});

test("overmind gate rejects unknown steps with exit 2", () => {
  withWorkspace((root) => {
    const result = spawnSync(process.execPath, [bundlePath, "gate", "unknown", "."], {
      cwd: root,
      encoding: "utf8"
    });
    assert.equal(result.status, 2);
    assert.match(result.stderr, /ERROR: Unknown gate step: unknown/);
  });
});

test("overmind context task-to-br emits assembled context and Jira branch", () => {
  withWorkspace((root) => {
    const featureDir = createFeatureFixture(root, { userInput: jiraUserInput() });
    const setupDir = path.join(root, ".setup");
    mkdirSync(setupDir, { recursive: true });
    writeFileSync(
      path.join(setupDir, "external_sources.yaml"),
      `sources:
  - name: jira-main
    type: jira
  - name: knowledge-base
    type: stack_knowledge_base
`
    );

    const featurePath = path.relative(root, featureDir);
    const result = spawnSync(process.execPath, [bundlePath, "context", "task-to-br", featurePath], {
      cwd: root,
      encoding: "utf8"
    });
    assert.equal(result.status, 0);
    assert.match(result.stdout, /# task-to-br context/);
    assert.match(
      result.stdout,
      /target_br_artifact: projects\/project-a\/feature-alpha\/feature_br_summary\.md/
    );
    assert.match(result.stdout, /## Skill Assets/);
    assert.match(
      result.stdout,
      /feature_br_template_asset: assets\/feature_br_summary_TEMPLATE\.md/
    );
    assert.doesNotMatch(result.stdout, /\.claude\/skills/);
    assert.match(
      result.stdout,
      /gate_command: node \.overmind\/overmind\.js gate task-to-br projects\/project-a\/feature-alpha/
    );
    assert.match(result.stdout, /epic_story_source_file: jira:AUTH-241/);
    assert.match(result.stdout, /eligible_jira_mcp_source_names:/);
    assert.match(result.stdout, /  - jira-main/);
  });
});

test("overmind capture task-to-br writes user_br_input.md from a local story file", () => {
  withWorkspace((root) => {
    const featureDir = createFeatureFixture(root, {
      summary: goldenBasedValidSummary(),
      userInput: null,
      missingData: null
    });
    writeFileSync(path.join(root, "story.md"), "Wrong workspace-root story.\n");
    writeFileSync(path.join(featureDir, "story.md"), "As a user I need captured input.\n");

    const featurePath = path.relative(root, featureDir);
    const capture = spawnSync(
      process.execPath,
      [bundlePath, "capture", "task-to-br", featurePath, "--source-file", "story.md"],
      { cwd: root, encoding: "utf8" }
    );

    assert.equal(capture.status, 0);
    assert.match(
      capture.stdout,
      /captured task-to-BR input: projects\/project-a\/feature-alpha\/user_br_input\.md/
    );

    const userInputPath = path.join(featureDir, "user_br_input.md");
    assert.equal(existsSync(userInputPath), true);
    const userInput = readFileSync(userInputPath, "utf8");
    assert.match(userInput, /feature_id: FEAT-RESET-001/);
    assert.match(userInput, /feature_title: Self-service password reset/);
    assert.match(
      userInput,
      /epic_story_source_file: projects\/project-a\/feature-alpha\/story\.md/
    );
    assert.match(userInput, /As a user I need captured input\./);
    assert.doesNotMatch(userInput, /Wrong workspace-root story/);

    const context = spawnSync(
      process.execPath,
      [bundlePath, "context", "task-to-br", featurePath],
      {
        cwd: root,
        encoding: "utf8"
      }
    );
    assert.equal(context.status, 0);
    assert.match(context.stdout, /As a user I need captured input\./);
  });
});

test("overmind capture task-to-br writes Jira capture metadata", () => {
  withWorkspace((root) => {
    const featureDir = createFeatureFixture(root, {
      summary: goldenBasedValidSummary(),
      userInput: null,
      missingData: null
    });
    mkdirSync(path.join(root, ".setup"), { recursive: true });
    writeFileSync(path.join(root, ".setup", "external_sources.yaml"), "sources: []\n");

    const featurePath = path.relative(root, featureDir);
    const capture = spawnSync(
      process.execPath,
      [bundlePath, "capture", "task-to-br", featurePath, "--jira", "AUTH-241"],
      { cwd: root, encoding: "utf8" }
    );

    assert.equal(capture.status, 0);
    const userInput = readFileSync(path.join(featureDir, "user_br_input.md"), "utf8");
    assert.match(userInput, /jira_ticket: AUTH-241/);
    assert.match(userInput, /epic_story_source_file: jira:AUTH-241/);
    assert.match(userInput, /epic_or_story: \|/);

    const context = spawnSync(
      process.execPath,
      [bundlePath, "context", "task-to-br", featurePath],
      {
        cwd: root,
        encoding: "utf8"
      }
    );
    assert.equal(context.status, 0);
    assert.match(context.stdout, /epic_story_source_file: jira:AUTH-241/);
    assert.match(context.stdout, /eligible_jira_mcp_source_names:/);
  });
});

test("overmind capture task-to-br does not overwrite existing capture unless requested", () => {
  withWorkspace((root) => {
    const featureDir = createFeatureFixture(root, {
      summary: goldenBasedValidSummary(),
      userInput: null,
      missingData: null
    });
    writeFileSync(path.join(featureDir, "story-a.md"), "First story.\n");
    writeFileSync(path.join(featureDir, "story-b.md"), "Second story.\n");
    const featurePath = path.relative(root, featureDir);

    const first = spawnSync(
      process.execPath,
      [bundlePath, "capture", "task-to-br", featurePath, "--source-file", "story-a.md"],
      { cwd: root, encoding: "utf8" }
    );
    assert.equal(first.status, 0);

    const second = spawnSync(
      process.execPath,
      [bundlePath, "capture", "task-to-br", featurePath, "--source-file", "story-b.md"],
      { cwd: root, encoding: "utf8" }
    );
    assert.equal(second.status, 0);
    assert.match(second.stdout, /user BR input already captured/);
    assert.match(readFileSync(path.join(featureDir, "user_br_input.md"), "utf8"), /First story\./);

    const overwrite = spawnSync(
      process.execPath,
      [
        bundlePath,
        "capture",
        "task-to-br",
        featurePath,
        "--source-file",
        "story-b.md",
        "--overwrite"
      ],
      { cwd: root, encoding: "utf8" }
    );
    assert.equal(overwrite.status, 0);
    assert.match(readFileSync(path.join(featureDir, "user_br_input.md"), "utf8"), /Second story\./);
  });
});

test("overmind capture task-to-br rejects invalid input source arguments", () => {
  withWorkspace((root) => {
    const featureDir = createFeatureFixture(root, {
      summary: goldenBasedValidSummary(),
      userInput: null,
      missingData: null
    });
    const featurePath = path.relative(root, featureDir);

    const result = spawnSync(process.execPath, [bundlePath, "capture", "task-to-br", featurePath], {
      cwd: root,
      encoding: "utf8"
    });
    assert.equal(result.status, 2);
    assert.match(result.stderr, /Provide exactly one input source/);
  });
});

test("overmind context rejects unknown steps with exit 2", () => {
  withWorkspace((root) => {
    const result = spawnSync(process.execPath, [bundlePath, "context", "unknown", "."], {
      cwd: root,
      encoding: "utf8"
    });
    assert.equal(result.status, 2);
    assert.match(result.stderr, /ERROR: Unknown context step: unknown/);
  });
});
