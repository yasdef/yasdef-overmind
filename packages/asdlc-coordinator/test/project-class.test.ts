import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";
import assert from "node:assert/strict";

import { manageProjectClassMembership } from "../src/capture/project-class.js";
import type { ProjectGitPort } from "../src/git/index.js";
import { StubInteraction } from "./orchestrator-fixtures.js";

function definition(repoBlock: string, classes = "backend"): string {
  return `meta_info:
  project_id: "p1"
  project_classes: [${classes}]
  project_type_code: "B"
  project_type_label: "Existing project with partial context"
  class_repo_paths:
${repoBlock}
steps:
  - id: "1"
`;
}

function withProject(
  content: string,
  run: (ctx: { root: string; projectDir: string; definitionPath: string }) => Promise<void> | void
): Promise<void> {
  const root = mkdtempSync(path.join(tmpdir(), "overmind-project-class-"));
  const projectDir = path.join(root, "projects", "p1");
  mkdirSync(projectDir, { recursive: true });
  const definitionPath = path.join(projectDir, "init_progress_definition.yaml");
  writeFileSync(definitionPath, content);
  return Promise.resolve(run({ root, projectDir, definitionPath })).finally(() =>
    rmSync(root, { recursive: true, force: true })
  );
}

function git(status: ReturnType<ProjectGitPort["worktreeStatus"]> = { kind: "unavailable" }): {
  port: ProjectGitPort;
  commits: Array<{ paths: string[]; message: string }>;
} {
  const commits: Array<{ paths: string[]; message: string }> = [];
  return {
    commits,
    port: {
      worktreeStatus: () => status,
      changedPaths: () => ({ kind: "ok", paths: [] }),
      commitOwnedPaths: (_root, paths, message) => {
        commits.push({ paths, message });
        return { kind: "committed" };
      }
    }
  };
}

const ADD_ACTION_LABEL = "Add a class";
const ADD_UNAVAILABLE_ACTION_LABEL = "Add a class (none available)";
const CHANGE_ACTION_LABEL = "Change an existing class";
const CHANGE_UNAVAILABLE_ACTION_LABEL = "Change an existing class (nothing to reset)";
const DONE_ACTION_LABEL = "Done";

function actionLabels({
  canAdd = true,
  canReset = true
}: {
  canAdd?: boolean;
  canReset?: boolean;
} = {}): string[] {
  return [
    canAdd ? ADD_ACTION_LABEL : ADD_UNAVAILABLE_ACTION_LABEL,
    canReset ? CHANGE_ACTION_LABEL : CHANGE_UNAVAILABLE_ACTION_LABEL,
    DONE_ACTION_LABEL
  ];
}

test("adds a missing class as deferred policy A in canonical order", async () => {
  await withProject(
    definition(
      `    frontend:
      state: "deferred"
      path: ""
      policy: "A"`,
      "frontend"
    ),
    async ({ projectDir, definitionPath }) => {
      const interaction = new StubInteraction(["add", "mobile"]);
      const result = await manageProjectClassMembership({
        projectRoot: projectDir,
        projectPathRel: "projects/p1",
        interaction,
        git: git().port,
        emit: () => {}
      });
      assert.equal(result.kind, "changed");
      const content = readFileSync(definitionPath, "utf8");
      assert.match(content, /project_classes:\n    - frontend\n    - mobile/);
      assert.match(content, /mobile:\n      state: "deferred"\n      path: ""\n      policy: "A"/);
      assert.doesNotMatch(content, /Enter repo path|policy: "B"/);
    }
  );
});

test("adds a class to a classless definition with inline empty collections", async () => {
  await withProject(
    `meta_info:
  project_id: "p1"
  project_classes: []
  project_type_code: "B"
  project_type_label: "Existing project with partial context"
  class_repo_paths: {}
steps:
  - id: "1"
`,
    async ({ projectDir, definitionPath }) => {
      const result = await manageProjectClassMembership({
        projectRoot: projectDir,
        projectPathRel: "projects/p1",
        interaction: new StubInteraction(["add", "backend"]),
        git: git().port,
        emit: () => {}
      });
      assert.equal(result.kind, "changed");
      const content = readFileSync(definitionPath, "utf8");
      assert.match(content, /project_classes:\n    - backend/);
      assert.match(
        content,
        /class_repo_paths:\n    backend:\n      state: "deferred"\n      path: ""\n      policy: "A"/
      );
    }
  );
});

test("reset requires confirmation and clears contract_reconciled", async () => {
  await withProject(
    definition(`    backend:
      state: "ready"
      path: "/repo/wrong"
      policy: "C"
      contract_reconciled: true`),
    async ({ projectDir, definitionPath }) => {
      const before = readFileSync(definitionPath, "utf8");
      const emitted: string[] = [];
      const interaction = new StubInteraction(["change", "backend", false, "done"]);
      const declined = await manageProjectClassMembership({
        projectRoot: projectDir,
        projectPathRel: "projects/p1",
        interaction,
        git: git().port,
        emit: (line) => emitted.push(line)
      });
      assert.equal(declined.kind, "noChange");
      assert.deepEqual(interaction.selectRequests, [
        ["add", "change", "done"],
        ["backend"],
        ["add", "change", "done"]
      ]);
      assert.ok(emitted.some((line) => line.includes("Class change declined")));
      assert.equal(readFileSync(definitionPath, "utf8"), before);

      const accepted = await manageProjectClassMembership({
        projectRoot: projectDir,
        projectPathRel: "projects/p1",
        interaction: new StubInteraction(["change", "backend", true]),
        git: git().port,
        emit: () => {}
      });
      assert.equal(accepted.kind, "changed");
      const content = readFileSync(definitionPath, "utf8");
      assert.match(content, /backend:\n      state: "deferred"\n      path: ""\n      policy: "A"/);
      assert.doesNotMatch(content, /contract_reconciled/);
    }
  );
});

test("change hides classes that are already deferred policy A without a repository", async () => {
  await withProject(
    definition(
      `    backend:
      state: "deferred"
      path: ""
      policy: "A"
    frontend:
      state: "ready"
      path: "/repo/front"
      policy: "C"`,
      "backend, frontend"
    ),
    async ({ projectDir }) => {
      const interaction = new StubInteraction(["change", "frontend", true]);
      const result = await manageProjectClassMembership({
        projectRoot: projectDir,
        projectPathRel: "projects/p1",
        interaction,
        git: git().port,
        emit: () => {}
      });
      assert.equal(result.kind, "changed");
      assert.deepEqual(interaction.selectRequests, [["add", "change", "done"], ["frontend"]]);
      assert.deepEqual(interaction.selectLabels[0], actionLabels());
    }
  );
});

test("change with no resettable classes reports and returns to the action menu", async () => {
  await withProject(
    definition(
      `    backend:
      state: "deferred"
      path: ""
      policy: "A"
    frontend:
      state: "deferred"
      path: ""
      policy: "A"
    infrastructure:
      state: "deferred"
      path: ""
      policy: "A"`,
      "backend, frontend, infrastructure"
    ),
    async ({ projectDir, definitionPath }) => {
      const emitted: string[] = [];
      const interaction = new StubInteraction(["change", "add", "mobile"]);
      const result = await manageProjectClassMembership({
        projectRoot: projectDir,
        projectPathRel: "projects/p1",
        interaction,
        git: git().port,
        emit: (line) => emitted.push(line)
      });
      assert.equal(result.kind, "changed");
      assert.deepEqual(interaction.selectRequests, [
        ["add", "change", "done"],
        ["add", "change", "done"],
        ["mobile"]
      ]);
      assert.deepEqual(interaction.selectLabels[0], actionLabels({ canReset: false }));
      assert.deepEqual(interaction.selectLabels[1], actionLabels({ canReset: false }));
      assert.ok(
        emitted.some((line) =>
          line.includes("No existing project classes need reset; every class is already deferred")
        )
      );
      assert.match(readFileSync(definitionPath, "utf8"), /    mobile:\n      state: "deferred"/);
    }
  );
});

test("done exits when no addable or resettable classes remain", async () => {
  await withProject(
    definition(
      `    backend:
      state: "deferred"
      path: ""
      policy: "A"
    frontend:
      state: "deferred"
      path: ""
      policy: "A"
    mobile:
      state: "deferred"
      path: ""
      policy: "A"
    infrastructure:
      state: "deferred"
      path: ""
      policy: "A"`,
      "backend, frontend, mobile, infrastructure"
    ),
    async ({ projectDir, definitionPath }) => {
      const before = readFileSync(definitionPath, "utf8");
      const emitted: string[] = [];
      const interaction = new StubInteraction(["change", "add", "done"]);
      const result = await manageProjectClassMembership({
        projectRoot: projectDir,
        projectPathRel: "projects/p1",
        interaction,
        git: git().port,
        emit: (line) => emitted.push(line)
      });
      assert.equal(result.kind, "noChange");
      assert.deepEqual(interaction.selectRequests, [
        ["add", "change", "done"],
        ["add", "change", "done"],
        ["add", "change", "done"]
      ]);
      const unavailableLabels = actionLabels({ canAdd: false, canReset: false });
      assert.deepEqual(interaction.selectLabels, [
        unavailableLabels,
        unavailableLabels,
        unavailableLabels
      ]);
      assert.deepEqual(interaction.log, ["select:change", "select:add", "select:done"]);
      assert.ok(
        emitted.every((line) => !line.includes("No class membership changes are available"))
      );
      assert.ok(
        emitted.some((line) =>
          line.includes("No existing project classes need reset; every class is already deferred")
        )
      );
      assert.ok(emitted.some((line) => line.includes("No project classes are available to add.")));
      assert.equal(readFileSync(definitionPath, "utf8"), before);
    }
  );
});

test("dirty project blocks membership change before writing", async () => {
  await withProject(
    definition(`    backend:
      state: "deferred"
      path: ""
      policy: "A"`),
    async ({ projectDir, definitionPath }) => {
      const before = readFileSync(definitionPath, "utf8");
      const interaction = new StubInteraction(["add", "frontend"]);
      const result = await manageProjectClassMembership({
        projectRoot: projectDir,
        projectPathRel: "projects/p1",
        interaction,
        git: git({ kind: "dirty", paths: ["stray.txt"] }).port,
        emit: () => {}
      });
      assert.equal(result.kind, "failed");
      assert.deepEqual(interaction.log, []);
      assert.equal(readFileSync(definitionPath, "utf8"), before);
    }
  );
});

test("accepted git-backed change can be committed once", async () => {
  await withProject(
    definition(`    backend:
      state: "deferred"
      path: ""
      policy: "A"`),
    async ({ projectDir }) => {
      const fakeGit = git({ kind: "clean" });
      const result = await manageProjectClassMembership({
        projectRoot: projectDir,
        projectPathRel: "projects/p1",
        interaction: new StubInteraction(["add", "frontend", true]),
        git: fakeGit.port,
        emit: () => {}
      });
      assert.equal(result.kind, "changed");
      assert.deepEqual(fakeGit.commits, [
        {
          paths: ["init_progress_definition.yaml"],
          message: "Update project class membership"
        }
      ]);
    }
  );
});
