import { mkdirSync, readFileSync, readdirSync, rmSync, writeFileSync } from "node:fs";
import path from "node:path";
import test from "node:test";
import assert from "node:assert/strict";

import { resolveStep, STEP_CATALOG } from "../src/sequencing/step-catalog.js";
import {
  CLASS_GATE_NAMES,
  GATE_REGISTRY,
  NON_CLASS_GATE_REGISTRY,
  TERMINAL_FEATURE_GATES,
  TERMINAL_REPAIR_STEPS,
  type GateValidator
} from "../src/validate/gate-registry.js";
import { runTerminalGateChain } from "../src/validate/terminal-gate-chain.js";

import { seedCompleteFeature, withWorkspace, type Workspace } from "./orchestrator-fixtures.js";

const pass: GateValidator = () => ({ exitCode: 0, passMessage: "ok", problems: [] });
const recoverable =
  (problem: string): GateValidator =>
  () => ({
    exitCode: 1,
    passMessage: "",
    problems: [problem]
  });
const runtimeError =
  (message: string): GateValidator =>
  () => ({
    exitCode: 2,
    passMessage: "",
    problems: [],
    errorMessage: message
  });

/** Every terminal gate stubbed to pass, so a test overrides only what it studies. */
function passingRegistry(
  overrides: Record<string, GateValidator> = {}
): Record<string, GateValidator> {
  const registry: Record<string, GateValidator> = {};
  for (const definition of TERMINAL_FEATURE_GATES) registry[definition.gate] = pass;
  return { ...registry, ...overrides };
}

function chain(
  workspace: Workspace,
  featureDir: string,
  overrides?: Record<string, GateValidator>
): ReturnType<typeof runTerminalGateChain> {
  return runTerminalGateChain(
    featureDir,
    workspace.root,
    overrides === undefined ? {} : { registry: overrides }
  );
}

/** Recursive path -> bytes snapshot, for proving the chain writes nothing. */
function snapshot(root: string): Map<string, string> {
  const files = new Map<string, string>();
  const walk = (dir: string): void => {
    for (const entry of readdirSync(dir, { withFileTypes: true })) {
      const full = path.join(dir, entry.name);
      if (entry.isDirectory()) walk(full);
      else if (entry.isFile()) files.set(full, readFileSync(full, "utf8"));
    }
  };
  walk(root);
  return files;
}

// --- Registry and catalog contract (task 1.5, 1.6) ---------------------------

test("terminal gate definitions declare the exact feature chain in phase order", () => {
  assert.deepEqual(
    TERMINAL_FEATURE_GATES.map((definition) => [
      definition.order,
      definition.gate,
      definition.artifact,
      definition.repairStep
    ]),
    [
      [1, "repo-br-scan", "feature_br_summary.md", "4.1"],
      [2, "task-to-br", "feature_br_summary.md", "4.1"],
      [3, "br-clarification", "feature_br_summary.md", "4.2"],
      [4, "requirements-ears", "requirements_ears.md", "5"],
      [5, "ears-review", "requirements_ears_review.md", "5.1"],
      [6, "contract-delta", "feature_contract_delta.md", "6"],
      [7, "surface-map", "project_surface_struct_resp_map_<class>.md", "7"],
      [8, "technical-requirements", "technical_requirements.md", "8"],
      [9, "implementation-slices", "implementation_slices.md", "8.1"],
      [10, "prerequisite-gaps", "prerequisite_gaps.md", "8.2"],
      [11, "implementation-plan", "implementation_plan.md", "8.3"],
      [12, "plan-semantic-review", "implementation_plan_semantic_review.md", "8.4"]
    ]
  );
  assert.equal(
    TERMINAL_FEATURE_GATES.find((definition) => definition.gate === "repo-br-scan")?.predicate,
    "hasReadyClassRepo"
  );
  assert.equal(
    TERMINAL_FEATURE_GATES.find((definition) => definition.gate === "surface-map")?.classExpanded,
    true
  );
  // The chain is derived from the gate definitions and ordered by the declared
  // slot, so duplicate slots would resolve arbitrarily under sorting rather than
  // failing loudly. Pin uniqueness instead of re-checking registration, which
  // deriving from one inventory already makes structurally true.
  const orders = TERMINAL_FEATURE_GATES.map((definition) => definition.order);
  assert.deepEqual(orders, [...new Set(orders)], "terminal pipeline slots must be unique");
  assert.deepEqual(
    orders,
    [...orders].sort((left, right) => left - right),
    "derived chain must be ordered by declared slot"
  );
});

test("every feature session backed by a registered gate declares terminal metadata", () => {
  // Feature-scoped catalog steps only: steps 1, 1.1, and 2 are project-scope.
  const projectScopeSteps = new Set(["1", "1.1", "2"]);
  const terminalGates = new Set(TERMINAL_FEATURE_GATES.map((definition) => definition.gate));
  const projectScopeGates: string[] = [];

  for (const step of STEP_CATALOG) {
    for (const action of step.actions) {
      if (action.kind !== "session") continue;
      if (!GATE_REGISTRY[action.skillName]) continue;
      if (projectScopeSteps.has(step.id)) {
        projectScopeGates.push(action.skillName);
        continue;
      }
      assert.ok(
        terminalGates.has(action.skillName),
        `feature session '${action.skillName}' (step ${step.id}) has no terminal metadata`
      );
    }
  }

  // Project-scope gate definitions never enter the feature chain.
  for (const gate of projectScopeGates) {
    assert.equal(terminalGates.has(gate), false, `${gate} is project-scope`);
  }
  assert.deepEqual([...projectScopeGates].sort(), [
    "agents-md",
    "common-contract",
    "stack-blueprint"
  ]);
});

test("every terminal repair-step token resolves through the production resume path", () => {
  for (const definition of TERMINAL_FEATURE_GATES) {
    const resolved = resolveStep(definition.repairStep);
    assert.deepEqual(resolved.diagnostics, [], `${definition.repairStep} produced diagnostics`);
    assert.equal(resolved.stepId, definition.repairStep);
  }
  assert.deepEqual(TERMINAL_REPAIR_STEPS, [
    "4.1",
    "4.2",
    "5",
    "5.1",
    "6",
    "7",
    "8",
    "8.1",
    "8.2",
    "8.3",
    "8.4"
  ]);
});

test("the class gate resolves the same validator through --class dispatch and terminal fan-out", () => {
  // A class gate invoked without a class is a configuration failure, not a pass.
  const result = GATE_REGISTRY["surface-map"]!({ featurePath: "x", runtimeRoot: "y" });
  assert.equal(result.exitCode, 2);

  // Both dispatch maps are views of one inventory: a non-class gate resolves to
  // the identical validator instance in each, and class gates appear only in the
  // full registry, so `--class` dispatch and terminal fan-out cannot diverge.
  for (const [name, validator] of Object.entries(NON_CLASS_GATE_REGISTRY)) {
    assert.equal(GATE_REGISTRY[name], validator);
  }
  assert.deepEqual(CLASS_GATE_NAMES, ["surface-map"]);
  for (const name of CLASS_GATE_NAMES) {
    assert.ok(GATE_REGISTRY[name], `${name} must resolve for --class dispatch`);
    assert.equal(NON_CLASS_GATE_REGISTRY[name], undefined);
  }
  assert.deepEqual(
    Object.keys(GATE_REGISTRY).sort(),
    [...Object.keys(NON_CLASS_GATE_REGISTRY), ...CLASS_GATE_NAMES].sort()
  );
});

// --- Applicability (task 6.1) ------------------------------------------------

test("an unresolvable feature path exits two before any validator runs", async () => {
  await withWorkspace({}, async (workspace) => {
    const missing = chain(workspace, path.join(workspace.projectDir, "no-such-feature"));
    assert.equal(missing.exitCode, 2);
    assert.deepEqual(missing.entries, []);
    assert.match(missing.diagnostics[0]!.reason, /Feature path directory not found/);

    // The project root itself is not a feature.
    const projectLevel = chain(workspace, workspace.projectDir);
    assert.equal(projectLevel.exitCode, 2);
    assert.match(projectLevel.diagnostics[0]!.reason, /projects\/<project-id>\/<feature-folder>/);
  });
});

test("a feature with no recognized artifact exits two instead of a vacuous pass", async () => {
  await withWorkspace({}, async (workspace) => {
    const featureDir = path.join(workspace.projectDir, "empty-feature");
    mkdirSync(featureDir, { recursive: true });
    const result = chain(workspace, featureDir, passingRegistry());
    assert.equal(result.exitCode, 2);
    assert.equal(result.passed, 0);
    assert.equal(result.failed, 0);
    assert.ok(result.skipped > 0);
    assert.match(result.diagnostics[0]!.reason, /No deterministic feature artifact was validated/);
  });
});

test("existing artifacts select their gates and absent optional ledgers are skipped", async () => {
  await withWorkspace({}, async (workspace) => {
    const featureDir = seedCompleteFeature(workspace.projectDir, "done-1");
    // Remove both optional review ledgers; absence alone must not fail the chain.
    for (const ledger of [
      "requirements_ears_review.md",
      "implementation_plan_semantic_review.md"
    ]) {
      rmSync(path.join(featureDir, ledger));
    }
    const result = chain(workspace, featureDir, passingRegistry());
    assert.equal(result.exitCode, 0);

    const byGate = new Map(result.entries.map((entry) => [entry.gate, entry]));
    assert.equal(byGate.get("ears-review")!.status, "skipped");
    assert.match(byGate.get("ears-review")!.skipReason!, /requirements_ears_review\.md not found/);
    assert.equal(byGate.get("plan-semantic-review")!.status, "skipped");
    assert.equal(byGate.get("requirements-ears")!.status, "passed");
  });
});

test("a malformed existing artifact entry reaches its owning validator instead of being skipped", async () => {
  await withWorkspace({}, async (workspace) => {
    const featureDir = seedCompleteFeature(workspace.projectDir, "done-1");
    // Replace the plan file with a directory of the same name.
    rmSync(path.join(featureDir, "implementation_plan.md"));
    mkdirSync(path.join(featureDir, "implementation_plan.md"));

    let sawPlanInvocation = false;
    const result = chain(
      workspace,
      featureDir,
      passingRegistry({
        "implementation-plan": () => {
          sawPlanInvocation = true;
          return runtimeError("not a file")({ featurePath: "", runtimeRoot: "" });
        }
      })
    );
    const entry = result.entries.find((candidate) => candidate.gate === "implementation-plan")!;
    assert.equal(sawPlanInvocation, true);
    assert.notEqual(entry.status, "skipped");
    assert.equal(entry.status, "failed");
  });
});

test("repo-br-scan follows the current ready-repository state, not step 4.1 history", async () => {
  // No class repository is ready: the scan gate is skipped and the rest still run.
  await withWorkspace(
    { definition: { classRepoPaths: { backend: { state: "deferred", policy: "A" } } } },
    async (workspace) => {
      const featureDir = seedCompleteFeature(workspace.projectDir, "done-1");
      const result = chain(workspace, featureDir, passingRegistry());
      const entry = result.entries.find((candidate) => candidate.gate === "repo-br-scan")!;
      assert.equal(entry.status, "skipped");
      assert.match(entry.skipReason!, /ready/);
      assert.equal(result.exitCode, 0);
      assert.ok(result.passed > 0);
    }
  );

  // A repository attached and reconciled after BR scanning makes the gate
  // applicable again, and its recoverable failure is owned by step 4.1.
  await withWorkspace({}, async (workspace) => {
    const featureDir = seedCompleteFeature(workspace.projectDir, "done-1");
    const result = chain(
      workspace,
      featureDir,
      passingRegistry({
        "repo-br-scan": recoverable("## 13. Existing-System Context is not populated")
      })
    );
    const entry = result.entries.find((candidate) => candidate.gate === "repo-br-scan")!;
    assert.equal(entry.status, "failed");
    assert.equal(result.exitCode, 1);
    assert.equal(result.repairStep, "4.1");
  });
});

test("existing surface maps fan out by class in stable order and absent classes are skipped", async () => {
  await withWorkspace({}, async (workspace) => {
    const featureDir = seedCompleteFeature(workspace.projectDir, "done-1");
    // seedCompleteFeature writes the backend map only; add mobile, leave frontend absent.
    writeFileSync(path.join(featureDir, "project_surface_struct_resp_map_mobile.md"), "# x\n");

    const invoked: Array<string | undefined> = [];
    const result = chain(
      workspace,
      featureDir,
      passingRegistry({
        "surface-map": ({ klass }) => {
          invoked.push(klass);
          return pass({ featurePath: "", runtimeRoot: "" });
        }
      })
    );

    assert.deepEqual(invoked, ["backend", "mobile"]);
    const surfaceEntries = result.entries.filter((entry) => entry.gate === "surface-map");
    assert.deepEqual(
      surfaceEntries.map((entry) => [entry.klass, entry.status]),
      [
        ["backend", "passed"],
        ["frontend", "skipped"],
        ["mobile", "passed"]
      ]
    );
    assert.equal(surfaceEntries[0]!.artifact, "project_surface_struct_resp_map_backend.md");
  });
});

test("the chain reports entries in stable pipeline order", async () => {
  await withWorkspace({}, async (workspace) => {
    const featureDir = seedCompleteFeature(workspace.projectDir, "done-1");
    const result = chain(workspace, featureDir, passingRegistry());
    const orders = result.entries.map((entry) => entry.order);
    assert.deepEqual(
      orders,
      [...orders].sort((a, b) => a - b)
    );
    assert.deepEqual(
      result.entries.map((entry) => entry.gate),
      [
        "repo-br-scan",
        "task-to-br",
        "br-clarification",
        "requirements-ears",
        "ears-review",
        "contract-delta",
        "surface-map",
        "surface-map",
        "surface-map",
        "technical-requirements",
        "implementation-slices",
        "prerequisite-gaps",
        "implementation-plan",
        "plan-semantic-review"
      ]
    );
  });
});

// --- Aggregation (task 6.2, 2.5) ---------------------------------------------

test("an all-pass run over at least one applicable gate aggregates to exit zero", async () => {
  await withWorkspace({}, async (workspace) => {
    const featureDir = seedCompleteFeature(workspace.projectDir, "done-1");
    const result = chain(workspace, featureDir, passingRegistry());
    assert.equal(result.exitCode, 0);
    assert.equal(result.failed, 0);
    assert.equal(result.repairStep, undefined);
    assert.equal(result.passed + result.skipped, result.entries.length);
  });
});

test("multiple recoverable failures aggregate to exit one and keep every diagnostic", async () => {
  await withWorkspace({}, async (workspace) => {
    const featureDir = seedCompleteFeature(workspace.projectDir, "done-1");
    const result = chain(
      workspace,
      featureDir,
      passingRegistry({
        "requirements-ears": recoverable("invalid EARS bullet"),
        "implementation-plan": recoverable("missing header")
      })
    );
    assert.equal(result.exitCode, 1);
    assert.equal(result.failed, 2);
    // The earliest failing pipeline phase owns the repair.
    assert.equal(result.repairStep, "5");
    assert.equal(result.diagnostics.length, 2);
    assert.match(result.diagnostics[0]!.reason, /invalid EARS bullet/);
    assert.match(result.diagnostics[1]!.reason, /missing header/);
  });
});

test("a runtime failure takes precedence over recoverable failures without reordering repair", async () => {
  await withWorkspace({}, async (workspace) => {
    const featureDir = seedCompleteFeature(workspace.projectDir, "done-1");
    const result = chain(
      workspace,
      featureDir,
      passingRegistry({
        "requirements-ears": recoverable("invalid EARS bullet"),
        "implementation-plan": runtimeError("gate cannot run")
      })
    );
    assert.equal(result.exitCode, 2);
    assert.equal(result.failed, 2);
    // Severity does not reorder ownership: step 5 is still the earliest failure.
    assert.equal(result.repairStep, "5");
  });
});

test("later gates still run after an earlier failure", async () => {
  await withWorkspace({}, async (workspace) => {
    const featureDir = seedCompleteFeature(workspace.projectDir, "done-1");
    const ran: string[] = [];
    const record =
      (name: string, validator: GateValidator): GateValidator =>
      (invocation) => {
        ran.push(name);
        return validator(invocation);
      };
    const registry = passingRegistry();
    for (const gate of Object.keys(registry)) registry[gate] = record(gate, registry[gate]!);
    registry["requirements-ears"] = record("requirements-ears", recoverable("boom"));

    chain(workspace, featureDir, registry);
    assert.ok(ran.indexOf("requirements-ears") < ran.indexOf("implementation-plan"));
    assert.ok(ran.includes("plan-semantic-review"));
  });
});

test("an unregistered terminal gate is a runtime failure, not a silent skip", async () => {
  await withWorkspace({}, async (workspace) => {
    const featureDir = seedCompleteFeature(workspace.projectDir, "done-1");
    const registry = passingRegistry();
    delete registry["implementation-plan"];
    const result = chain(workspace, featureDir, registry);
    assert.equal(result.exitCode, 2);
    const entry = result.entries.find((candidate) => candidate.gate === "implementation-plan")!;
    assert.equal(entry.status, "failed");
    assert.match(entry.result!.errorMessage!, /not registered/);
  });
});

test("a throwing validator is classified as a runtime failure", async () => {
  await withWorkspace({}, async (workspace) => {
    const featureDir = seedCompleteFeature(workspace.projectDir, "done-1");
    const result = chain(
      workspace,
      featureDir,
      passingRegistry({
        "contract-delta": () => {
          throw new Error("parser exploded");
        }
      })
    );
    assert.equal(result.exitCode, 2);
    const entry = result.entries.find((candidate) => candidate.gate === "contract-delta")!;
    assert.match(entry.result!.errorMessage!, /parser exploded/);
  });
});

test("the chain writes nothing and supplies no clarification progress sink", async () => {
  await withWorkspace({}, async (workspace) => {
    const featureDir = seedCompleteFeature(workspace.projectDir, "done-1");
    const before = snapshot(workspace.root);

    const sinks: Array<((line: string) => void) | undefined> = [];
    const result = chain(
      workspace,
      featureDir,
      passingRegistry({
        "br-clarification": (invocation) => {
          sinks.push(invocation.onProgress);
          return pass(invocation);
        }
      })
    );
    assert.equal(result.exitCode, 0);
    assert.deepEqual(sinks, [undefined]);

    const after = snapshot(workspace.root);
    assert.deepEqual([...after.keys()].sort(), [...before.keys()].sort());
    for (const [file, content] of before) assert.equal(after.get(file), content);
  });
});
