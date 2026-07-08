import assert from "node:assert/strict";
import { mkdirSync, mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";

import { runCli, type CliAdapterOverrides } from "../src/cli/run.js";
import {
  InteractionClosedError,
  type InteractionPort,
  type SelectRequest
} from "../src/interaction/index.js";

interface Captured {
  stdout: string;
  stderr: string;
}

class WorkerInteraction implements InteractionPort {
  constructor(private readonly script: string[]) {}

  async confirm(): Promise<boolean> {
    return true;
  }

  async input(): Promise<string> {
    const value = this.script.shift();
    if (!value) throw new Error("no scripted input left");
    return value;
  }

  async select<T extends string>(request: SelectRequest<T>): Promise<T> {
    const value = this.script.shift();
    return (value ?? request.options[0]!.value) as T;
  }
}

class ClosedInteraction implements InteractionPort {
  async confirm(): Promise<boolean> {
    throw new InteractionClosedError();
  }

  async input(): Promise<string> {
    throw new InteractionClosedError();
  }

  async select<T extends string>(): Promise<T> {
    throw new InteractionClosedError();
  }
}

function capture(): {
  streams: { stdout: { write: (s: string) => boolean }; stderr: { write: (s: string) => boolean } };
  out: Captured;
} {
  const out: Captured = { stdout: "", stderr: "" };
  return {
    streams: {
      stdout: { write: (s: string) => ((out.stdout += s), true) },
      stderr: { write: (s: string) => ((out.stderr += s), true) }
    },
    out
  };
}

async function run(
  argv: string[],
  cwd: string,
  overrides: CliAdapterOverrides = {}
): Promise<{ code: number; out: Captured }> {
  const { streams, out } = capture();
  const code = await runCli(["node", "overmind", ...argv], streams, cwd, overrides);
  return { code, out };
}

function projectFixture(): { root: string; project: string; feature: string } {
  const root = mkdtempSync(path.join(tmpdir(), "worker-cli-"));
  const project = path.join(root, "projects", "project-a");
  const feature = path.join(project, "feature-a");
  mkdirSync(feature, { recursive: true });
  writeFileSync(
    path.join(project, "init_progress_definition.yaml"),
    `meta_info:\n  project_id: project-a\n`
  );
  return { root, project, feature };
}

test("worker help and argument errors render usage", async () => {
  const { root } = projectFixture();

  assert.equal((await run(["worker"], root)).code, 2);
  const registerHelp = await run(["worker", "register", "--help"], root);
  assert.equal(registerHelp.code, 0);
  assert.match(registerHelp.out.stdout, /worker register --path/);
  assert.equal((await run(["worker", "register"], root)).code, 2);
  assert.equal((await run(["worker", "assign", "--feature-path"], root)).code, 2);
});

test("worker register renders typed success output", async () => {
  const { root, project } = projectFixture();

  const result = await run(["worker", "register", "--path", project], root, {
    interaction: new WorkerInteraction(["backend"]),
    clock: { now: () => 123 },
    uuid: { next: () => "11111111-1111-1111-1111-111111111111" }
  });

  assert.equal(result.code, 0);
  assert.match(
    result.out.stdout,
    /new worker registered with uuid: 11111111-1111-1111-1111-111111111111 - copy and pass this unique id to developer so he'll register worker on he's side/
  );
  assert.match(readFileSync(path.join(project, "workers.yaml"), "utf8"), /class: "backend"/);
});

test("worker register treats EOF as a clean stop", async () => {
  const { root, project } = projectFixture();

  const result = await run(["worker", "register", "--path", project], root, {
    interaction: new ClosedInteraction(),
    clock: { now: () => 123 },
    uuid: { next: () => "11111111-1111-1111-1111-111111111111" }
  });

  assert.equal(result.code, 0);
  assert.match(result.out.stdout, /Execution stopped: user input stream closed/);
  assert.equal(result.out.stderr, "");
});

test("worker assign returns non-success on worker availability issues", async () => {
  const { root, project, feature } = projectFixture();
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
  writeFileSync(
    path.join(feature, "implementation_plan.md"),
    `### Step 1.1 Build UI
#### Repo: frontend
#### Depends on: none
- [ ] Implement UI
`
  );

  const result = await run(["worker", "assign", "--feature-path", feature], root, {
    interaction: new WorkerInteraction([])
  });

  assert.equal(result.code, 1);
  assert.match(result.out.stdout, /error: no active worker for frontend/);
  assert.match(result.out.stderr, /no active worker for frontend/);
});

test("worker assign rejects a project-root path before registry lookup", async () => {
  const { root, project } = projectFixture();
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

  const result = await run(["worker", "assign", "--feature-path", project], root, {
    interaction: new WorkerInteraction([])
  });

  assert.equal(result.code, 1);
  assert.match(result.out.stderr, /projects\/<project-id>\/<feature-folder>/);
  assert.doesNotMatch(result.out.stderr, /workers\.yaml not found/);
});

test("worker assign returns non-success on dependency holds", async () => {
  const { root, project, feature } = projectFixture();
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

  const result = await run(["worker", "assign", "--feature-path", feature], root, {
    interaction: new WorkerInteraction([])
  });

  assert.equal(result.code, 1);
  assert.match(result.out.stdout, /hold: depends on feature-dep\/1.1/);
  assert.match(result.out.stderr, /dependency hold/);
});

test("worker assign treats EOF during multi-worker selection as a clean stop", async () => {
  const { root, project, feature } = projectFixture();
  writeFileSync(
    path.join(project, "workers.yaml"),
    `project_id: project-a
workers:
  - uuid: backend-1
    class: backend
    status: active
    registered_at: old
  - uuid: backend-2
    class: backend
    status: active
    registered_at: old
`
  );
  writeFileSync(
    path.join(feature, "implementation_plan.md"),
    `### Step 1.1 Build API
#### Repo: backend
#### Depends on: none
- [ ] Implement API
`
  );

  const result = await run(["worker", "assign", "--feature-path", feature], root, {
    interaction: new ClosedInteraction()
  });

  assert.equal(result.code, 0);
  assert.match(result.out.stdout, /Execution stopped: user input stream closed/);
  assert.equal(result.out.stderr, "");
});
