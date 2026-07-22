import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import assert from "node:assert/strict";
import test from "node:test";

import { runCli } from "../src/cli/run.js";
import { evaluate } from "../src/sequencing/index.js";
import { validateStackBlueprint } from "../src/validate/stack-blueprint.js";

const backendGolden = fileURLToPath(
  new URL(
    "../../../../packages/installer/_data/skills/overmind-stack-blueprint/assets/project_stack_blueprint_be_GOLDEN_EXAMPLE.md",
    import.meta.url
  )
);
const initTemplate = fileURLToPath(
  new URL(
    "../../../../packages/installer/_data/templates/init_progress_definition_TEMPLATE.yaml",
    import.meta.url
  )
);

async function withProject(fn: (projectDir: string) => void | Promise<void>): Promise<void> {
  const root = mkdtempSync(path.join(tmpdir(), "overmind-stack-blueprint-"));
  const projectDir = path.join(root, "projects", "p1");
  mkdirSync(projectDir, { recursive: true });
  try {
    await fn(projectDir);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
}

function validBackendBlueprint(): string {
  return readFileSync(backendGolden, "utf8");
}

function typeADefinition(): string {
  return readFileSync(initTemplate, "utf8")
    .replace("  project_classes: []", '  project_classes: ["backend"]')
    .replace('  project_type_code: ""', '  project_type_code: "A"')
    .replace(
      "  class_repo_paths: {}",
      '  class_repo_paths:\n    backend:\n      state: "ready"\n      path: "/tmp/backend"\n      policy: "C"'
    );
}

test("stack-blueprint gate accepts a complete backend blueprint", async () => {
  await withProject((projectDir) => {
    const target = path.join(projectDir, "project_stack_blueprint_backend.md");
    writeFileSync(target, validBackendBlueprint());
    const result = validateStackBlueprint(target);
    assert.equal(result.exitCode, 0, result.problems.join("\n"));
  });
});

test("stack-blueprint gate reports recoverable content issues", async () => {
  await withProject((projectDir) => {
    const target = path.join(projectDir, "project_stack_blueprint_backend.md");
    writeFileSync(
      target,
      validBackendBlueprint().replace("- language: Java 21", "- language: [UNFILLED]")
    );
    const result = validateStackBlueprint(target);
    assert.equal(result.exitCode, 1);
    assert.match(result.problems.join("\n"), /missing or unfilled stack choice: language/);
  });
});

test("stack-blueprint gate distinguishes cannot-run failures", async () => {
  await withProject((projectDir) => {
    assert.equal(validateStackBlueprint("").exitCode, 2);
    assert.equal(
      validateStackBlueprint(path.join(projectDir, "project_stack_blueprint_backend.md")).exitCode,
      2
    );
  });
});

test("stack-blueprint gate CLI uses standard rendering", async () => {
  await withProject(async (projectDir) => {
    const target = path.join(projectDir, "project_stack_blueprint_backend.md");
    writeFileSync(target, validBackendBlueprint());
    const out = { stdout: "", stderr: "" };
    const code = await runCli(
      ["node", "overmind", "gate", "stack-blueprint", target],
      {
        stdout: { write: (value: string) => ((out.stdout += value), true) },
        stderr: { write: (value: string) => ((out.stderr += value), true) }
      },
      projectDir
    );
    assert.equal(code, 0, out.stdout + out.stderr);
    assert.match(out.stdout, /quality gate passed/);
  });
});

test("type-A step 1.1 stays pending until the agents-md sibling artifact exists", async () => {
  const root = mkdtempSync(path.join(tmpdir(), "overmind-stack-blueprint-step-"));
  const projectDir = path.join(root, "projects", "p1");
  mkdirSync(projectDir, { recursive: true });
  writeFileSync(path.join(projectDir, "init_progress_definition.yaml"), typeADefinition());
  writeFileSync(
    path.join(projectDir, "project_stack_blueprint_backend.md"),
    validBackendBlueprint()
  );
  try {
    let report = evaluate(root, projectDir);
    assert.equal(report.steps.find((step) => step.stepId === "1.1")!.state, "pending");

    writeFileSync(path.join(projectDir, "project_agents_md_claude_md_backend.md"), "# agents\n");
    report = evaluate(root, projectDir);
    assert.equal(report.steps.find((step) => step.stepId === "1.1")!.state, "done");
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});
