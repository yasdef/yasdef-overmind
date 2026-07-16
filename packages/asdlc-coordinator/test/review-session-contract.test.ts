import assert from "node:assert/strict";
import path from "node:path";
import test from "node:test";

import { buildEarsReviewContext, buildPlanSemanticReviewContext } from "../src/context/index.js";
import {
  EARS_REVIEW_MUTABLE_GATES,
  PLAN_SEMANTIC_REVIEW_MUTABLE_GATES,
  STEP_CATALOG,
  type Action
} from "../src/sequencing/index.js";

import { withRunnerWorkspace } from "./runner-fixtures.js";

function sessionAction(stepId: string, skillName: string): Extract<Action, { kind: "session" }> {
  const step = STEP_CATALOG.find((candidate) => candidate.id === stepId);
  assert.ok(step, `Missing step ${stepId}`);
  const action = step.actions.find(
    (candidate): candidate is Extract<Action, { kind: "session" }> =>
      candidate.kind === "session" && candidate.skillName === skillName
  );
  assert.ok(action, `Missing session action ${skillName} on step ${stepId}`);
  return action;
}

test("EARS review contract maps both mutable artifacts to their owning gates", () => {
  assert.deepEqual(EARS_REVIEW_MUTABLE_GATES, [
    { artifact: "requirements_ears.md", gate: "requirements-ears" },
    { artifact: "requirements_ears_review.md", gate: "ears-review" }
  ]);
});

test("plan semantic review contract maps both mutable artifacts to their owning gates", () => {
  assert.deepEqual(PLAN_SEMANTIC_REVIEW_MUTABLE_GATES, [
    { artifact: "implementation_plan.md", gate: "implementation-plan" },
    { artifact: "implementation_plan_semantic_review.md", gate: "plan-semantic-review" }
  ]);
});

test("step 5.1 catalog action consumes the shared EARS mutable set", () => {
  const action = sessionAction("5.1", "ears-review");
  assert.equal(action.postSessionGates, EARS_REVIEW_MUTABLE_GATES);
});

test("step 8.4 catalog action consumes the shared plan mutable set", () => {
  const action = sessionAction("8.4", "plan-semantic-review");
  assert.equal(action.postSessionGates, PLAN_SEMANTIC_REVIEW_MUTABLE_GATES);
});

test("step 5.1 retains CRP-163 dual-source read-only guard alongside the mutable gate set", () => {
  const action = sessionAction("5.1", "ears-review");
  const guard = action.readOnlyGuards.find((candidate) => candidate.mode === "mustExistUnchanged");
  assert.ok(guard && guard.mode === "mustExistUnchanged");
  assert.deepEqual(guard.files, ["feature_br_summary.md", "user_br_input.md"]);
  // The read-only source guard coexists with the mutable gate set without widening writes.
  assert.equal(action.postSessionGates, EARS_REVIEW_MUTABLE_GATES);
});

test("EARS review context renders its allowed-write surface from the shared contract", () => {
  withRunnerWorkspace(({ root, featurePath }) => {
    const result = buildEarsReviewContext(featurePath, root);
    assert.equal(result.exitCode, 0);
    const text = result.text ?? "";
    const surface = text
      .split("## Allowed Write Surface")[1]!
      .split("##")[0]!
      .split("\n")
      .filter((line) => line.startsWith("- "))
      .map((line) => line.slice(2).trim());
    assert.deepEqual(
      surface,
      EARS_REVIEW_MUTABLE_GATES.map((entry) => entry.artifact)
    );
  });
});

test("EARS review context exposes a mutable runtime target for every contract entry", () => {
  withRunnerWorkspace(({ root, featurePath, featureDir }) => {
    const result = buildEarsReviewContext(featurePath, root);
    assert.equal(result.exitCode, 0);
    const runtimePaths = (result.text ?? "").split("## Runtime Paths")[1]!.split("##")[0]!;
    // Drift guard (CRP-165 review finding 4): the EARS runtime target lines are
    // maintained separately from the shared contract, so adding or renaming an
    // entry must keep a matching runtime target in the briefing.
    for (const entry of EARS_REVIEW_MUTABLE_GATES) {
      assert.ok(
        runtimePaths.includes(path.join(featureDir, entry.artifact)),
        `EARS context is missing a runtime target for ${entry.artifact}`
      );
    }
  });
});

test("plan semantic review context renders mutable targets and write surface from the shared contract", () => {
  withRunnerWorkspace(({ root, featurePath }) => {
    const result = buildPlanSemanticReviewContext(featurePath, root);
    assert.equal(result.exitCode, 0);
    const text = result.text ?? "";
    for (const entry of PLAN_SEMANTIC_REVIEW_MUTABLE_GATES) {
      assert.match(text, new RegExp(`- mutable_target: .*/${entry.artifact.replace(".", "\\.")}`));
    }
    const surface = text
      .split("## Allowed Write Surface")[1]!
      .split("\n")
      .filter((line) => line.startsWith("- "))
      .map((line) => line.slice(2).trim());
    assert.equal(surface.length, PLAN_SEMANTIC_REVIEW_MUTABLE_GATES.length);
    for (const entry of PLAN_SEMANTIC_REVIEW_MUTABLE_GATES) {
      assert.ok(
        surface.some((line) => line.endsWith(`/${entry.artifact}`)),
        `write surface must include ${entry.artifact}`
      );
    }
  });
});
