import assert from "node:assert/strict";
import { mkdtempSync, readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";

import { assignWorkers } from "../../src/workers/assignment.js";
import type { InteractionPort, SelectRequest } from "../../src/interaction/index.js";

class SelectInteraction implements InteractionPort {
  public requests: SelectRequest[] = [];

  constructor(private readonly selections: string[] = []) {}

  async confirm(): Promise<boolean> {
    return true;
  }

  async input(): Promise<string> {
    throw new Error("input should not be used by assignment");
  }

  async select<T extends string>(request: SelectRequest<T>): Promise<T> {
    this.requests.push(request);
    const selected = this.selections.shift();
    if (!selected) return request.options[0]!.value;
    return selected as T;
  }
}

function projectFixture(): { root: string; project: string; feature: string } {
  const root = mkdtempSync(path.join(tmpdir(), "worker-assignment-"));
  const project = path.join(root, "projects", "project-a");
  const feature = path.join(project, "feature-main");
  mkdirSync(feature, { recursive: true });
  writeFileSync(
    path.join(project, "init_progress_definition.yaml"),
    `meta_info:\n  project_id: project-a\n`
  );
  return { root, project, feature };
}

function plan(): string {
  return `# Repository Implementation Plan
Intro text stays.

### Step 1.1 Build API
#### Repo: backend
#### Depends on: none
#### Evidence: gap/TECH_REQ-1
- [ ] Implement API

### Step 1.2 Build UI
#### Repo: frontend
#### Depends on: none
#### Evidence: gap/TECH_REQ-2
- [ ] Implement UI
`;
}

function writeWorkers(project: string, extra = ""): void {
  writeFileSync(
    path.join(project, "workers.yaml"),
    `project_id: project-a
workers:
  - uuid: backend-1
    class: backend
    status: active
    registered_at: old
  - uuid: frontend-1
    class: frontend
    status: active
    registered_at: old
${extra}`
  );
}

test("assign workers auto-selects a single active worker per class and preserves unrelated content", async () => {
  const { root, project, feature } = projectFixture();
  writeWorkers(project);
  writeFileSync(path.join(feature, "implementation_plan.md"), plan());

  const result = await assignWorkers(feature, { interaction: new SelectInteraction(), cwd: root });
  const content = readFileSync(path.join(feature, "implementation_plan.md"), "utf8");

  assert.equal(result.ok, true);
  assert.deepEqual(result.changedPaths, ["implementation_plan.md"]);
  assert.match(content, /Intro text stays\./);
  assert.match(content, /#### Assigned: backend-1\n- \[ \] Implement API/);
  assert.match(content, /#### Assigned: frontend-1\n- \[ \] Implement UI/);
});

test("assign workers prompts when multiple active workers exist for a class", async () => {
  const { root, project, feature } = projectFixture();
  writeWorkers(
    project,
    `  - uuid: backend-2
    class: backend
    status: active
    registered_at: old
`
  );
  writeFileSync(path.join(feature, "implementation_plan.md"), plan());
  const interaction = new SelectInteraction(["backend-2"]);

  const result = await assignWorkers(feature, { interaction, cwd: root });

  assert.equal(result.ok, true);
  assert.equal(interaction.requests.length, 1);
  assert.equal(result.assignments.find((item) => item.className === "backend")?.value, "backend-2");
});

test("assign workers marks missing active worker and exits non-success after rewrite", async () => {
  const { root, project, feature } = projectFixture();
  writeWorkers(project, "");
  writeFileSync(
    path.join(project, "workers.yaml"),
    `project_id: project-a
workers:
  - uuid: backend-1
    class: backend
    status: active
    registered_at: old
`
  );
  writeFileSync(path.join(feature, "implementation_plan.md"), plan());

  const result = await assignWorkers(feature, { interaction: new SelectInteraction(), cwd: root });
  const content = readFileSync(path.join(feature, "implementation_plan.md"), "utf8");

  assert.equal(result.ok, false);
  assert.deepEqual(result.changedPaths, ["implementation_plan.md"]);
  assert.match(result.diagnostics[0]!.reason, /no active worker for frontend/);
  assert.match(content, /#### Assigned: error: no active worker for frontend/);
});

test("assign workers writes dependency hold markers for incomplete sibling steps", async () => {
  const { root, project, feature } = projectFixture();
  writeWorkers(project);
  const sibling = path.join(project, "feature-dep");
  mkdirSync(sibling);
  writeFileSync(
    path.join(sibling, "implementation_plan.md"),
    `### Step 1.1 Dependency
#### Repo: backend
- [x] Done
- [ ] Not done
`
  );
  writeFileSync(
    path.join(feature, "implementation_plan.md"),
    plan().replace("#### Depends on: none", "#### Depends on: feature-dep/1.1")
  );

  const result = await assignWorkers(feature, { interaction: new SelectInteraction(), cwd: root });
  const content = readFileSync(path.join(feature, "implementation_plan.md"), "utf8");

  assert.equal(result.ok, false);
  assert.match(content, /#### Assigned: hold: depends on feature-dep\/1.1/);
  assert.match(result.diagnostics[0]!.reason, /dependency hold/);
});

test("assign workers suppresses missing-worker diagnostics when every step for that class is held", async () => {
  const { root, project, feature } = projectFixture();
  writeFileSync(
    path.join(project, "workers.yaml"),
    `project_id: project-a
workers:
  - uuid: frontend-1
    class: frontend
    status: active
    registered_at: old
`
  );
  const sibling = path.join(project, "feature-dep");
  mkdirSync(sibling);
  writeFileSync(
    path.join(sibling, "implementation_plan.md"),
    `### Step 1.1 Dependency
#### Repo: backend
- [ ] Not done
`
  );
  writeFileSync(
    path.join(feature, "implementation_plan.md"),
    `### Step 1.1 Build API
#### Repo: backend
#### Depends on: feature-dep/1.1
- [ ] Implement API
`
  );

  const result = await assignWorkers(feature, { interaction: new SelectInteraction(), cwd: root });
  const content = readFileSync(path.join(feature, "implementation_plan.md"), "utf8");

  assert.equal(result.ok, false);
  assert.match(content, /#### Assigned: hold: depends on feature-dep\/1.1/);
  assert.deepEqual(
    result.diagnostics.map((diagnostic) => diagnostic.reason),
    ["dependency hold: depends on feature-dep/1.1"]
  );
});

test("assign workers replaces prior assignment lines and rejects not-ready plans before rewrite", async () => {
  const { root, project, feature } = projectFixture();
  writeWorkers(project);
  const readyWithOldAssignment = plan().replace(
    "#### Evidence: gap/TECH_REQ-1\n",
    "#### Evidence: gap/TECH_REQ-1\n#### Assigned: old-worker\n"
  );
  writeFileSync(path.join(feature, "implementation_plan.md"), readyWithOldAssignment);

  const result = await assignWorkers(feature, { interaction: new SelectInteraction(), cwd: root });
  const rewritten = readFileSync(path.join(feature, "implementation_plan.md"), "utf8");
  assert.equal(result.ok, true);
  assert.equal((rewritten.match(/#### Assigned:/g) ?? []).length, 2);
  assert.equal(rewritten.includes("old-worker"), false);

  const invalid = rewritten.replace("#### Repo: backend\n", "");
  writeFileSync(path.join(feature, "implementation_plan.md"), invalid);
  const failure = await assignWorkers(feature, { interaction: new SelectInteraction(), cwd: root });
  assert.equal(failure.ok, false);
  assert.deepEqual(failure.changedPaths, []);
  assert.equal(readFileSync(path.join(feature, "implementation_plan.md"), "utf8"), invalid);
});

test("assign workers rejects project-root paths before registry lookup", async () => {
  const { root, project } = projectFixture();
  writeWorkers(project);

  const result = await assignWorkers(project, { interaction: new SelectInteraction(), cwd: root });

  assert.equal(result.ok, false);
  assert.deepEqual(result.changedPaths, []);
  assert.match(result.diagnostics[0]!.reason, /projects\/<project-id>\/<feature-folder>/);
  assert.doesNotMatch(result.diagnostics[0]!.reason, /workers\.yaml not found/);
});
