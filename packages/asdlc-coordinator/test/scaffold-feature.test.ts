import { existsSync, mkdirSync, readFileSync, readdirSync } from "node:fs";
import path from "node:path";
import test from "node:test";
import assert from "node:assert/strict";

import { normalizeFeatureFolderName, scaffoldFeature } from "../src/capture/scaffold-feature.js";
import { defaultStepExecutorDeps, executeStep, type StepBindings } from "../src/runner/index.js";
import { STEP_CATALOG } from "../src/sequencing/index.js";
import { StubInteraction, withWorkspace } from "./orchestrator-fixtures.js";

const clock = (value: number) => ({ now: () => value });

const step3 = STEP_CATALOG.find((step) => step.id === "3")!;

test("valid scaffold creates a populated summary and returns typed paths", async () => {
  await withWorkspace({}, async ({ root, projectDir, projectPathRel }) => {
    const result = await scaffoldFeature(root, projectPathRel, {
      interaction: new StubInteraction(["FEAT-1", "Add OAuth Login"]),
      clock: clock(1234)
    });
    assert.equal(result.diagnostics.length, 0);
    assert.ok(result.featurePath);
    assert.ok(result.outputPath);
    assert.equal(result.featurePath, path.join(projectPathRel, "add_oauth_login-1234"));
    assert.equal(result.outputPath, path.join(result.featurePath, "feature_br_summary.md"));

    const summary = readFileSync(path.join(root, result.outputPath), "utf8");
    assert.match(summary, /- feature_id: FEAT-1/);
    assert.match(summary, /- feature_title: Add OAuth Login/);
    assert.match(summary, /- project_type_code: B/);
    assert.match(summary, /- project_type_label: Existing project with partial context/);
    assert.match(summary, /- ready_to_ears: false/);
    assert.doesNotMatch(summary, /\{\{PROJECT_TYPE_CODE\}\}/);
    // scaffold does not depend on the created folder pre-existing.
    assert.ok(existsSync(path.join(projectDir, "add_oauth_login-1234")));
  });
});

test("executeStep dispatches the registered scaffold primitive for catalog step 3", async () => {
  await withWorkspace({}, async ({ root, projectDir, projectPathRel }) => {
    const bindings: StepBindings = {
      step: step3,
      runtimeRoot: root,
      featurePath: projectPathRel,
      projectPath: projectPathRel,
      overmindCliPath: "x"
    };
    const deps = {
      ...defaultStepExecutorDeps,
      interaction: new StubInteraction(["FEAT-1", "Registered Path"]),
      clock: clock(42)
    };
    const result = await executeStep(step3, bindings, deps);
    assert.equal(result.ok, true);
    const created = result.actionResults.find((action) => action.featurePath)?.featurePath;
    assert.equal(created, path.join(projectPathRel, "registered_path-42"));
    assert.ok(existsSync(path.join(projectDir, "registered_path-42", "feature_br_summary.md")));
  });
});

test("executeStep step 3 fails clearly without scaffold ports instead of a silent no-op", async () => {
  const bindings: StepBindings = {
    step: step3,
    runtimeRoot: "/nowhere",
    featurePath: "projects/p",
    projectPath: "projects/p",
    overmindCliPath: "x"
  };
  const result = await executeStep(step3, bindings, defaultStepExecutorDeps);
  assert.equal(result.ok, false);
  assert.ok(result.diagnostics.some((d) => /scaffold-feature requires/.test(d.reason)));
});

test("title normalization matches the shell's deterministic form", () => {
  assert.equal(normalizeFeatureFolderName("  Add OAuth / Login! "), "add_oauth_login");
  assert.equal(normalizeFeatureFolderName("A--B__c"), "a_b_c");
  assert.equal(normalizeFeatureFolderName("!!!"), "");
});

test("a title with no alphanumeric content returns a diagnostic and creates no folder", async () => {
  await withWorkspace({}, async ({ root, projectDir, projectPathRel }) => {
    const before = readdirSync(projectDir).length;
    const result = await scaffoldFeature(root, projectPathRel, {
      interaction: new StubInteraction(["FEAT-1", "!!!"]),
      clock: clock(1234)
    });
    assert.ok(result.diagnostics.some((d) => /at least one letter or digit/.test(d.reason)));
    assert.equal(result.featurePath, undefined);
    assert.equal(readdirSync(projectDir).length, before);
  });
});

test("an existing target folder is a collision, never overwritten", async () => {
  await withWorkspace({}, async ({ root, projectDir, projectPathRel }) => {
    // First scaffold to occupy the deterministic name.
    await scaffoldFeature(root, projectPathRel, {
      interaction: new StubInteraction(["FEAT-1", "Feature X"]),
      clock: clock(1234)
    });
    const marker = path.join(projectDir, "feature_x-1234", "feature_br_summary.md");
    const original = readFileSync(marker, "utf8");
    const result = await scaffoldFeature(root, projectPathRel, {
      interaction: new StubInteraction(["FEAT-2", "Feature X"]),
      clock: clock(1234)
    });
    assert.ok(result.diagnostics.some((d) => /already exists/.test(d.reason)));
    assert.equal(readFileSync(marker, "utf8"), original);
  });
});

test("an empty interactive value is retried until non-empty", async () => {
  await withWorkspace({}, async ({ root, projectPathRel }) => {
    const interaction = new StubInteraction(["   ", "FEAT-1", "Title"]);
    const result = await scaffoldFeature(root, projectPathRel, { interaction, clock: clock(1) });
    assert.equal(result.diagnostics.length, 0);
    assert.ok(result.notices.includes("Input cannot be empty."));
  });
});

test("a path with no init_progress_definition.yaml in its ancestry is rejected", async () => {
  await withWorkspace({}, async ({ root }) => {
    // A directory under the workspace whose ancestry has no project definition.
    const orphan = path.join(root, "projects", "no-def");
    mkdirSync(orphan, { recursive: true });
    const result = await scaffoldFeature(root, path.join("projects", "no-def"), {
      interaction: new StubInteraction([]),
      clock: clock(1)
    });
    assert.ok(
      result.diagnostics.some((d) =>
        /project-level folder containing init_progress_definition\.yaml/.test(d.reason)
      )
    );
    assert.equal(result.featurePath, undefined);
  });
});

test("bad project path and unsupported metadata yield actionable diagnostics", async () => {
  await withWorkspace(
    { definition: { typeCode: "Z", classRepoPaths: { backend: { state: "ready" } } } },
    async ({ root, projectPathRel }) => {
      const missing = await scaffoldFeature(root, path.join(projectPathRel, "nope"), {
        interaction: new StubInteraction([]),
        clock: clock(1)
      });
      assert.ok(missing.diagnostics.some((d) => /not found/.test(d.reason)));

      const badMeta = await scaffoldFeature(root, projectPathRel, {
        interaction: new StubInteraction(["FEAT-1", "Title"]),
        clock: clock(1)
      });
      assert.ok(badMeta.diagnostics.some((d) => /Unable to load project metadata/.test(d.reason)));
    }
  );
});
