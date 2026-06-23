import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";
import assert from "node:assert/strict";

import { runCli } from "../src/cli/run.js";

function capture(): { streams: { stdout: { write: (s: string) => boolean }; stderr: { write: (s: string) => boolean } }; out: () => string; err: () => string } {
  let out = "";
  let err = "";
  return {
    streams: {
      stdout: { write: (s: string) => { out += s; return true; } },
      stderr: { write: (s: string) => { err += s; return true; } }
    },
    out: () => out,
    err: () => err
  };
}

async function run(args: string[]): Promise<{ code: number; out: string; err: string }> {
  const cap = capture();
  const code = await runCli(["node", "overmind", ...args], cap.streams as never);
  return { code, out: cap.out(), err: cap.err() };
}

for (const verb of ["gate", "context", "sync"]) {
  test(`${verb} surface-map without --class is a usage error`, async () => {
    const { code, err } = await run([verb, "surface-map", "projects/p1/feature-a"]);
    assert.equal(code, 2);
    assert.match(err, /--class <backend\|frontend\|mobile>/);
  });

  test(`${verb} surface-map with an unknown --class is a usage error`, async () => {
    const { code, err } = await run([verb, "surface-map", "projects/p1/feature-a", "--class", "infra"]);
    assert.equal(code, 2);
    assert.match(err, /Invalid class 'infra'/);
  });

  test(`${verb} surface-map with --class but no value is a usage error`, async () => {
    const { code, err } = await run([verb, "surface-map", "projects/p1/feature-a", "--class"]);
    assert.equal(code, 2);
    assert.match(err, /Missing value for --class/);
  });
}

test("gate surface-map prints actionable recoverable output", async () => {
  const dir = mkdtempSync(path.join(tmpdir(), "overmind-surface-cli-"));
  try {
    const target = path.join(dir, "project_surface_struct_resp_map_backend.md");
    writeFileSync(target, "# incomplete\n");
    const { code, out } = await run(["gate", "surface-map", target, "--class", "backend"]);
    assert.equal(code, 1);
    assert.match(out, /missing: quality gate failed:/);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

// Valid classes dispatch to the registered handler (not the option parser): the
// error comes from the handler resolving a non-existent feature/target, never a
// `--class` usage error.
const dispatchExpectation: Record<string, RegExp> = {
  gate: /Target surface map artifact not found/,
  context: /Feature path directory not found/,
  sync: /Feature path directory not found/
};
for (const verb of ["gate", "context", "sync"]) {
  for (const klass of ["backend", "frontend", "mobile"]) {
    test(`${verb} surface-map --class ${klass} dispatches to its handler`, async () => {
      const { code, err } = await run([verb, "surface-map", "does-not-exist/feature", "--class", klass]);
      assert.equal(code, 2);
      assert.match(err, dispatchExpectation[verb]);
      assert.doesNotMatch(err, /Invalid class|Missing (value for|required option:) --class/);
    });
  }
}
