import assert from "node:assert/strict";
import { mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";

import { registerWorker } from "../../src/workers/registry.js";
import type { InteractionPort } from "../../src/interaction/index.js";

class ScriptedInteraction implements InteractionPort {
  public inputs: string[];

  constructor(inputs: string[]) {
    this.inputs = [...inputs];
  }

  async confirm(): Promise<boolean> {
    return true;
  }

  async select<T extends string>(): Promise<T> {
    throw new Error("select should not be used by registration");
  }

  async input(): Promise<string> {
    const next = this.inputs.shift();
    if (next === undefined) throw new Error("no scripted input left");
    return next;
  }
}

function projectFixture(): string {
  const dir = mkdtempSync(path.join(tmpdir(), "worker-registry-"));
  writeFileSync(
    path.join(dir, "init_progress_definition.yaml"),
    `meta_info:\n  project_id: project-a\n  project_classes: [backend]\n`
  );
  return dir;
}

test("register worker resolves class by number and creates workers.yaml", async () => {
  const project = projectFixture();
  const result = await registerWorker(project, {
    interaction: new ScriptedInteraction(["2"]),
    clock: { now: () => "2026-07-09T10:00:00Z" },
    uuid: { next: () => "ABCDEFAB-1234-1234-1234-ABCDEFABCDEF" }
  });

  assert.equal(result.ok, true);
  assert.equal(result.uuid, "abcdefab-1234-1234-1234-abcdefabcdef");
  assert.deepEqual(result.changedPaths, ["workers.yaml"]);
  assert.match(
    readFileSync(path.join(project, "workers.yaml"), "utf8"),
    /class: "frontend"\n    status: "active"\n    registered_at: "2026-07-09T10:00:00Z"/
  );
});

test("register worker re-prompts unsupported class and accepts class name", async () => {
  const project = projectFixture();
  const interaction = new ScriptedInteraction(["bogus", "backend"]);
  const result = await registerWorker(project, {
    interaction,
    clock: { now: () => 123 },
    uuid: { next: () => "11111111-1111-1111-1111-111111111111" }
  });

  assert.equal(result.ok, true);
  assert.equal(result.workerClass, "backend");
  assert.equal(interaction.inputs.length, 0);
});

test("register worker rejects project_id mismatch without mutation", async () => {
  const project = projectFixture();
  const registryPath = path.join(project, "workers.yaml");
  const original = "project_id: other\nworkers:\n";
  writeFileSync(registryPath, original);

  const result = await registerWorker(project, {
    interaction: new ScriptedInteraction(["backend"]),
    clock: { now: () => 123 },
    uuid: { next: () => "11111111-1111-1111-1111-111111111111" }
  });

  assert.equal(result.ok, false);
  assert.deepEqual(result.changedPaths, []);
  assert.match(result.diagnostics[0]!.reason, /does not match/);
  assert.equal(readFileSync(registryPath, "utf8"), original);
});

test("register worker retries UUID collisions and normalizes inline empty workers", async () => {
  const project = projectFixture();
  writeFileSync(path.join(project, "workers.yaml"), "project_id: project-a\nworkers: []\n");
  const uuids = ["aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"];
  writeFileSync(
    path.join(project, "workers.yaml"),
    "project_id: project-a\nworkers: []\n  - uuid: aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa\n    class: backend\n    status: active\n    registered_at: old\n"
  );

  const result = await registerWorker(project, {
    interaction: new ScriptedInteraction(["mobile"]),
    clock: { now: () => "new" },
    uuid: { next: () => uuids.shift() ?? "cccccccc-cccc-cccc-cccc-cccccccccccc" }
  });

  const content = readFileSync(path.join(project, "workers.yaml"), "utf8");
  assert.equal(result.ok, true);
  assert.equal(result.uuid, "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb");
  assert.match(content, /workers:\n  - uuid: aaaaaaaa/);
  assert.match(content, /  - uuid: bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb\n    class: "mobile"/);
});

test("register worker inserts inside workers block before later top-level keys", async () => {
  const project = projectFixture();
  const registryPath = path.join(project, "workers.yaml");
  writeFileSync(
    registryPath,
    `project_id: project-a
workers:
  - uuid: existing
    class: backend
    status: active
    registered_at: old
notes: keep me top level
`
  );

  const result = await registerWorker(project, {
    interaction: new ScriptedInteraction(["frontend"]),
    clock: { now: () => "new" },
    uuid: { next: () => "22222222-2222-2222-2222-222222222222" }
  });

  const content = readFileSync(registryPath, "utf8");
  assert.equal(result.ok, true);
  assert.match(
    content,
    /  - uuid: 22222222-2222-2222-2222-222222222222\n    class: "frontend"\n    status: "active"\n    registered_at: "new"\nnotes: keep me top level/
  );
});

test("register worker preserves existing entries and reports typed failure on malformed registry", async () => {
  const project = projectFixture();
  const registryPath = path.join(project, "workers.yaml");
  const original =
    "project_id: project-a\n# keep this comment\nworkers:\n  - uuid: 99999999-9999-9999-9999-999999999999\n    class: backend\n    status: active\n    registered_at: old\n";
  writeFileSync(registryPath, original);

  const success = await registerWorker(project, {
    interaction: new ScriptedInteraction(["frontend"]),
    clock: { now: () => "new" },
    uuid: { next: () => "88888888-8888-8888-8888-888888888888" }
  });
  const changed = readFileSync(registryPath, "utf8");
  assert.equal(success.ok, true);
  assert.equal(changed.startsWith(original), true);

  writeFileSync(registryPath, "project_id: project-a\n");
  const failure = await registerWorker(project, {
    interaction: new ScriptedInteraction(["frontend"]),
    clock: { now: () => "new" },
    uuid: { next: () => "77777777-7777-7777-7777-777777777777" }
  });
  assert.equal(failure.ok, false);
  assert.deepEqual(failure.changedPaths, []);
  assert.match(failure.diagnostics[0]!.reason, /missing workers/);
});
