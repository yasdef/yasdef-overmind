import {
  mkdirSync,
  mkdtempSync,
  readFileSync,
  readdirSync,
  renameSync,
  rmSync,
  writeFileSync
} from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";
import assert from "node:assert/strict";

import {
  createProject,
  normalizeProjectName,
  type ProjectCreationResult,
  type TempFilePort
} from "../../src/capture/project.js";
import {
  RepoGitProjectInitAdapter,
  type GitRunner,
  type ProjectInitGitPort,
  type ProjectInitResult
} from "../../src/git/index.js";
import { StubInteraction } from "../orchestrator-fixtures.js";

class RecordingTemp implements TempFilePort {
  public readonly writes: string[] = [];

  writeAtomic(targetPath: string, content: string): void {
    this.writes.push(targetPath);
    const tmp = `${targetPath}.tmp`;
    writeFileSync(tmp, content);
    renameSync(tmp, targetPath);
  }
}

class RecordingProjectGit implements ProjectInitGitPort {
  public readonly calls: Array<{ root: string; definition: string }> = [];

  constructor(
    private readonly result: ProjectInitResult = {
      kind: "ok",
      appliedFallbackName: true,
      appliedFallbackEmail: true
    }
  ) {}

  initAndCommitDefinition(root: string, definitionFileName: string): ProjectInitResult {
    this.calls.push({ root, definition: definitionFileName });
    return this.result;
  }
}

function withRuntime(run: (root: string) => Promise<void> | void): Promise<void> | void {
  const root = mkdtempSync(path.join(tmpdir(), "overmind-project-create-"));
  mkdirSync(path.join(root, "projects"), { recursive: true });
  mkdirSync(path.join(root, ".templates"), { recursive: true });
  writeFileSync(path.join(root, "asdlc_metadata.yaml"), 'meta:\n  version: "1"\nprojects:\n\n\n');
  writeFileSync(
    path.join(root, ".templates", "init_progress_definition_TEMPLATE.yaml"),
    'meta_info:\n  project_id: ""\nsteps:\n  - id: "1"\n'
  );
  const done = Promise.resolve(run(root));
  return done.finally(() => rmSync(root, { recursive: true, force: true }));
}

async function create(
  root: string,
  script: Array<boolean | string>,
  git = new RecordingProjectGit()
): Promise<{
  result: ProjectCreationResult;
  temp: RecordingTemp;
  git: RecordingProjectGit;
}> {
  const temp = new RecordingTemp();
  const result = await createProject(root, {
    interaction: new StubInteraction(script),
    clock: { now: () => "2026-07-09T12:00:00Z" },
    uuid: { next: () => "uuid-1" },
    temp,
    git
  });
  return { result, temp, git };
}

test("project name normalization matches the shell slug format", () => {
  assert.equal(normalizeProjectName("  My New Project! "), "my_new_project");
  assert.equal(normalizeProjectName("A--B__c"), "a_b_c");
  assert.equal(normalizeProjectName("!!!"), "");
});

test("createProject captures type and class membership without repository prompts", async () => {
  await withRuntime(async (root) => {
    const errors: string[] = [];
    const temp = new RecordingTemp();
    const git = new RecordingProjectGit();
    const result = await createProject(root, {
      interaction: new StubInteraction([
        'My "New" Project',
        "b",
        "frontend",
        "backend",
        "__done__"
      ]),
      clock: { now: () => "2026-07-09T12:00:00Z" },
      uuid: { next: () => "uuid-1" },
      temp,
      git,
      emitError: (line) => errors.push(line)
    });

    assert.equal(result.diagnostics.length, 0);
    assert.deepEqual(errors, []);
    assert.equal(result.projectId, "my_new_project-uuid-1");
    assert.equal(result.changedPaths.length, 3);
    assert.ok(result.projectFolder);
    assert.ok(result.definitionPath);
    assert.deepEqual(git.calls, [
      { root: result.projectFolder, definition: "init_progress_definition.yaml" }
    ]);
    assert.deepEqual(temp.writes, [result.definitionPath, path.join(root, "asdlc_metadata.yaml")]);

    const definition = readFileSync(result.definitionPath, "utf8");
    assert.match(definition, /^meta_info:\n/);
    assert.match(definition, /  project_id: "my_new_project-uuid-1"/);
    assert.match(definition, /  project_classes:\n    - backend\n    - frontend/);
    assert.match(definition, /  project_type_code: "B"/);
    assert.match(definition, /  project_type_label: "Existing project with partial context"/);
    assert.match(
      definition,
      /    backend:\n      state: "deferred"\n      path: ""\n      policy: "A"/
    );
    assert.match(
      definition,
      /    frontend:\n      state: "deferred"\n      path: ""\n      policy: "A"/
    );
    assert.match(definition, /\nsteps:\n  - id: "1"\n/);

    const metadata = readFileSync(path.join(root, "asdlc_metadata.yaml"), "utf8");
    assert.equal(
      metadata,
      'meta:\n  version: "1"\nprojects:\n  - project: my_new_project-uuid-1\n    name: "My \\"New\\" Project"\n    internal_folder: "my_new_project-uuid-1"\n    created_at: "2026-07-09T12:00:00Z"\n'
    );
  });
});

test("createProject re-prompts type and class selection until valid", async () => {
  await withRuntime(async (root) => {
    const interaction = new StubInteraction(["Name", "Z", "3", "backend", "__done__"]);
    const result = await createProject(root, {
      interaction,
      clock: { now: () => "2026-07-09T12:00:00Z" },
      uuid: { next: () => "id" },
      temp: new RecordingTemp(),
      git: new RecordingProjectGit()
    });

    assert.equal(result.diagnostics.length, 0);
    assert.ok(interaction.selectRequests[0]!.includes("backend"));
    assert.ok(interaction.selectRequests[0]!.includes("__done__"));
    assert.equal(interaction.selectRequests[1]!.includes("backend"), false);

    const definition = readFileSync(result.definitionPath!, "utf8");
    assert.match(definition, /  project_type_code: "C"/);
    assert.match(definition, /  project_classes:\n    - backend/);
  });
});

test("createProject writes explicit empty collections with no classes", async () => {
  await withRuntime(async (root) => {
    const { result } = await create(root, ["Name", "A", "__done__"]);

    assert.equal(result.diagnostics.length, 0);
    const definition = readFileSync(result.definitionPath!, "utf8");
    assert.match(definition, /  project_classes: \[\]\n/);
    assert.match(definition, /  class_repo_paths: \{\}\n/);
  });
});

test("createProject preserves unrelated template content before steps", async () => {
  await withRuntime(async (root) => {
    writeFileSync(
      path.join(root, ".templates", "init_progress_definition_TEMPLATE.yaml"),
      '# License header\nmeta_info:\n  project_id: ""\n  placeholder: true\nx-template-note: "preserve me"\nsteps:\n  - id: "1"\n'
    );

    const { result } = await create(root, ["Name", "A", "backend", "__done__"]);

    assert.equal(result.diagnostics.length, 0);
    const definition = readFileSync(result.definitionPath!, "utf8");
    assert.match(definition, /^# License header\nmeta_info:\n/);
    assert.doesNotMatch(definition, /placeholder: true/);
    assert.match(definition, /\nx-template-note: "preserve me"\nsteps:\n/);
  });
});

test("createProject rejects empty and symbol-only names before mutation", async () => {
  await withRuntime(async (root) => {
    const before = readFileSync(path.join(root, "asdlc_metadata.yaml"), "utf8");
    const blank = await create(root, ["   "]);
    assert.match(blank.result.diagnostics[0]!.reason, /cannot be empty/);
    const symbols = await create(root, ["!!!"]);
    assert.match(symbols.result.diagnostics[0]!.reason, /letter or digit/);
    assert.equal(readFileSync(path.join(root, "asdlc_metadata.yaml"), "utf8"), before);
  });
});

test("createProject fails without mutation on malformed metadata and existing folder", async () => {
  await withRuntime(async (root) => {
    const metadataPath = path.join(root, "asdlc_metadata.yaml");
    writeFileSync(metadataPath, "meta:\nprojects:\nother:\n");
    const malformed = await create(root, ["Name"]);
    assert.match(malformed.result.diagnostics[0]!.reason, /projects.*final section/);
    assert.equal(readFileSync(metadataPath, "utf8"), "meta:\nprojects:\nother:\n");

    writeFileSync(metadataPath, "meta:\nprojects:\n");
    mkdirSync(path.join(root, "projects", "name-uuid-1"));
    const existing = await create(root, ["Name", "A", "backend", "__done__"]);
    assert.match(existing.result.diagnostics[0]!.reason, /already exists/);
    assert.equal(readFileSync(metadataPath, "utf8"), "meta:\nprojects:\n");
  });
});

test("git failure reports a diagnostic, cleans the folder, and leaves metadata unchanged", async () => {
  await withRuntime(async (root) => {
    const before = readFileSync(path.join(root, "asdlc_metadata.yaml"), "utf8");
    const git = new RecordingProjectGit({ kind: "commitFailed", exitCode: 1, stderr: "nope" });
    const { result } = await create(root, ["Name", "A", "backend", "__done__"], git);
    assert.match(result.diagnostics[0]!.reason, /initial project git commit/);
    assert.equal(result.changedPaths.length, 0);
    assert.equal(readFileSync(path.join(root, "asdlc_metadata.yaml"), "utf8"), before);
    assert.equal(readdirSync(path.join(root, "projects")).length, 0);
  });
});

test("RepoGitProjectInitAdapter applies fallback identity only when unset", () => {
  const calls: string[][] = [];
  const runner: GitRunner = (_root, args) => {
    calls.push(args);
    if (args[0] === "--version") return { status: 0, stdout: "git\n", stderr: "" };
    if (args.join(" ") === "config user.name") return { status: 1, stdout: "", stderr: "" };
    if (args.join(" ") === "config user.email") return { status: 1, stdout: "", stderr: "" };
    return { status: 0, stdout: "", stderr: "" };
  };
  const result = new RepoGitProjectInitAdapter(runner).initAndCommitDefinition(
    "/p",
    "init_progress_definition.yaml"
  );
  assert.deepEqual(result, { kind: "ok", appliedFallbackName: true, appliedFallbackEmail: true });
  assert.ok(calls.some((args) => args.join(" ") === "config user.name Overmind ASDLC"));
  assert.ok(
    calls.some((args) => args.join(" ") === "config user.email overmind-asdlc@local.invalid")
  );

  const preserveCalls: string[][] = [];
  const preserveRunner: GitRunner = (_root, args) => {
    preserveCalls.push(args);
    if (args[0] === "--version") return { status: 0, stdout: "git\n", stderr: "" };
    if (args.join(" ") === "config user.name")
      return { status: 0, stdout: "Configured\n", stderr: "" };
    if (args.join(" ") === "config user.email")
      return { status: 0, stdout: "configured@example.test\n", stderr: "" };
    return { status: 0, stdout: "", stderr: "" };
  };
  const preserved = new RepoGitProjectInitAdapter(preserveRunner).initAndCommitDefinition(
    "/p",
    "init_progress_definition.yaml"
  );
  assert.deepEqual(preserved, {
    kind: "ok",
    appliedFallbackName: false,
    appliedFallbackEmail: false
  });
  assert.equal(
    preserveCalls.some((args) => args.join(" ").startsWith("config user.name ")),
    false
  );
  assert.equal(
    preserveCalls.some((args) => args.join(" ").startsWith("config user.email ")),
    false
  );
});
