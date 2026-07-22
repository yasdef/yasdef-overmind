import assert from "node:assert/strict";
import test from "node:test";

import { validateWorkerAssignmentPlanContent } from "../../src/validate/worker-assignment.js";

function validPlan(): string {
  return `# Repository Implementation Plan

### Step 1.1 Build API
#### Repo: backend
#### Depends on: none
#### Evidence: gap/TECH_REQ-1
- [ ] Implement API

### Step 1.2 Build UI
#### Repo: frontend
#### Depends on: sibling-feature/1.1
#### Evidence: gap/TECH_REQ-2
- [ ] Implement UI
`;
}

test("worker assignment validator rejects a plan with no steps", () => {
  const result = validateWorkerAssignmentPlanContent("# Plan\n", "plan");
  assert.equal(result.ok, false);
  assert.equal(result.steps.length, 0);
  assert.match(result.diagnostics[0]!.reason, /at least one ### Step/);
});

test("worker assignment validator rejects missing, duplicate, and unsupported repo metadata", () => {
  const cases = [
    [validPlan().replace("#### Repo: backend\n", ""), /exactly one/],
    [
      validPlan().replace("#### Repo: backend", "#### Repo: backend\n#### Repo: frontend"),
      /exactly one/
    ],
    [validPlan().replace("#### Repo: backend", "#### Repo: infrastructure"), /unsupported/]
  ] as const;

  for (const [content, expected] of cases) {
    const result = validateWorkerAssignmentPlanContent(content, "plan");
    assert.equal(result.ok, false);
    assert.match(result.diagnostics[0]!.reason, expected);
  }
});

test("worker assignment validator returns ready steps with repos and dependencies", () => {
  const result = validateWorkerAssignmentPlanContent(validPlan(), "plan");
  assert.equal(result.ok, true);
  assert.deepEqual(
    result.steps.map((step) => ({
      id: step.id,
      repo: step.repo,
      dependsOn: step.dependsOn
    })),
    [
      { id: "1.1", repo: "backend", dependsOn: [] },
      { id: "1.2", repo: "frontend", dependsOn: ["sibling-feature/1.1"] }
    ]
  );
});
