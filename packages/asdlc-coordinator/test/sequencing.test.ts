import { chmodSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import test from "node:test";
import assert from "node:assert/strict";

import {
  evaluate,
  formatCanonicalNextStep,
  formatChecklist,
  nextStep,
  parseDeclaredSteps,
  resolveStep,
  STEP_CATALOG,
  toFeatureSummary
} from "../src/sequencing/index.js";

const templatePath = fileURLToPath(
  new URL("../../../../overmind/templates/init_progress_definition_TEMPLATE.yaml", import.meta.url)
);

function definition(classes = '["backend"]', type = "B"): string {
  return readFileSync(templatePath, "utf8")
    .replace("  project_classes: []", `  project_classes: ${classes}`)
    .replace('  project_type_code: ""', `  project_type_code: "${type}"`)
    .replace(
      "  class_repo_paths: {}",
      `  class_repo_paths:\n    backend:\n      state: "ready"\n      path: "/tmp/backend"\n      policy: "C"`
    );
}

function withProject(run: (root: string, project: string, feature: string) => void): void {
  const root = mkdtempSync(path.join(tmpdir(), "sequencing-"));
  const project = path.join(root, "projects", "p");
  const feature = path.join(project, "feature-a");
  mkdirSync(feature, { recursive: true });
  writeFileSync(path.join(project, "init_progress_definition.yaml"), definition());
  try {
    run(root, project, feature);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
}

test("catalog ids exactly match definition and feature actions are concrete", () => {
  const declared = parseDeclaredSteps(templatePath);
  assert.deepEqual(
    STEP_CATALOG.map((step) => step.id),
    declared.steps.map((step) => step.id)
  );
  assert.ok(
    STEP_CATALOG.filter((step) => !["1", "1.1", "2"].includes(step.id)).every(
      (step) => step.actions.length > 0
    )
  );
  assert.deepEqual(STEP_CATALOG.find((step) => step.id === "3")!.actions, [
    { kind: "write", name: "scaffold-feature" }
  ]);
  const enrich = STEP_CATALOG.find((step) => step.id === "7.1")!.actions[0];
  assert.equal(enrich?.kind, "session");
  if (enrich?.kind === "session") assert.deepEqual(enrich.requiredOutputs, []);
  const scanActions = STEP_CATALOG.find((step) => step.id === "4.1")!.actions;
  assert.deepEqual(
    scanActions.map((action) => action.kind === "session" && action.skillName),
    ["repo-br-scan", "task-to-br"]
  );
  assert.equal(scanActions[0]?.kind === "session" && scanActions[0].runIf, "hasReadyClassRepo");
  assert.deepEqual(
    STEP_CATALOG.find((step) => step.id === "4.2")!.actions.map((action) => action.kind),
    ["session", "check"]
  );
});

test("evaluate reports every step, filters classes, projects next step and summary", () => {
  withProject((root, project, feature) => {
    writeFileSync(path.join(project, "common_contract_definition.md"), "complete\n");
    writeFileSync(
      path.join(feature, "feature_br_summary.md"),
      "## 1. Document Meta\n- feature_title: Alpha\n"
    );
    writeFileSync(path.join(feature, "user_br_input.md"), "input\n");
    const report = evaluate(root, project, feature);
    assert.equal(report.steps.length, STEP_CATALOG.length);
    assert.equal(report.steps.find((step) => step.stepId === "1.1")!.state, "done");
    assert.equal(report.steps.find((step) => step.stepId === "4.2")!.state, "pending");
    assert.equal(report.steps.find((step) => step.stepId === "8.3")!.state, "pending");
    assert.equal(nextStep(report)?.stepId, "4.2");
    const summary = toFeatureSummary(report);
    assert.equal(summary.readiness, "in_progress");
    assert.equal(summary.totalSteps, report.steps.length);
    assert.equal(
      summary.completedSteps,
      report.steps.filter((step) => step.state === "done").length
    );
    assert.deepEqual(summary.missingArtifacts, [
      ...new Set(report.steps.flatMap((step) => step.missingArtifacts))
    ]);
    assert.equal(
      report.steps.find((step) => step.stepId === "7")!.perClass?.[0]?.className,
      "backend"
    );
    assert.match(formatChecklist(report), /--- FEATURE LEVEL TASKS Alpha ---/);
  });
});

test("project prerequisites block feature work", () => {
  withProject((root, project, feature) => {
    const report = evaluate(root, project, feature);
    assert.equal(report.steps.find((step) => step.stepId === "2")!.state, "pending");
    assert.ok(
      report.steps
        .filter((step) => step.scope === "feature")
        .every((step) => step.state === "blocked" || step.state === "done")
    );
    assert.equal(toFeatureSummary(report).readiness, "blocked");
  });
});

test("check_key_value and 7.1 any-matching-artifact semantics are honored", () => {
  withProject((root, project, feature) => {
    writeFileSync(path.join(project, "common_contract_definition.md"), "complete\n");
    writeFileSync(
      path.join(feature, "feature_br_summary.md"),
      "## 1. Document Meta\n- ready_to_ears: true\n"
    );
    writeFileSync(
      path.join(feature, "project_surface_struct_resp_map_backend.md"),
      "## 1. Document Meta\n- was_enriched_with_mcp: true\n"
    );
    const report = evaluate(root, project, feature);
    assert.equal(report.steps.find((step) => step.stepId === "4.2")!.state, "done");
    assert.equal(report.steps.find((step) => step.stepId === "7.1")!.state, "done");
  });
});

test("an unreadable check_key_value artifact blocks only its step and emits a diagnostic", () => {
  withProject((root, project, feature) => {
    writeFileSync(path.join(project, "common_contract_definition.md"), "complete\n");
    const summaryPath = path.join(feature, "feature_br_summary.md");
    writeFileSync(summaryPath, "## 1. Document Meta\n- ready_to_ears: true\n");
    chmodSync(summaryPath, 0);
    try {
      const report = evaluate(root, project, feature);
      assert.equal(report.steps.find((step) => step.stepId === "4.2")!.state, "blocked");
      assert.ok(report.diagnostics.some((item) => item.stepId === "4.2"));
      assert.equal(report.steps.find((step) => step.stepId === "5")!.state, "pending");
    } finally {
      chmodSync(summaryPath, 0o600);
    }
  });
});

test("canonical line is byte exact and optional steps are skipped", () => {
  withProject((root, project, feature) => {
    writeFileSync(path.join(project, "common_contract_definition.md"), "complete\n");
    const report = evaluate(root, project, feature);
    assert.equal(
      formatCanonicalNextStep(report),
      "next step: 3 (Initialize and Enrich Business Requirements Structuring)"
    );
    for (const step of report.steps) if (!step.optional) step.state = "done";
    assert.equal(formatCanonicalNextStep(report), "next step: none");
  });
});

test("malformed or missing definition degrades to unknown without throwing", () => {
  const root = mkdtempSync(path.join(tmpdir(), "sequencing-bad-"));
  const project = path.join(root, "projects", "p");
  mkdirSync(project, { recursive: true });
  try {
    const report = evaluate(root, project);
    assert.equal(report.definitionParsed, false);
    assert.ok(report.diagnostics.length > 0);
    assert.ok(report.steps.some((step) => step.state === "blocked"));
    assert.equal(toFeatureSummary(report).readiness, "unknown");
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("catalog and definition mismatch degrades readiness to unknown", () => {
  withProject((root, project, feature) => {
    const definitionPath = path.join(project, "init_progress_definition.yaml");
    writeFileSync(
      definitionPath,
      definition().replace("  - step_number: 8.4", "  - step_number: 9")
    );

    const report = evaluate(root, project, feature);

    assert.equal(report.definitionParsed, false);
    assert.ok(
      report.diagnostics.some((item) =>
        item.reason.includes("Declared step ids do not match the sequencing catalog")
      )
    );
    assert.equal(toFeatureSummary(report).readiness, "unknown");
  });
});

test("resume aliases and dotted ids resolve without throws", () => {
  assert.equal(resolveStep("implementation-slices").stepId, "8.1");
  assert.equal(resolveStep("4").stepId, "5");
  assert.equal(resolveStep("unknown").diagnostics.length, 1);
});
