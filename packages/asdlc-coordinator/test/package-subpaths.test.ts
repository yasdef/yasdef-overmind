import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import path from "node:path";
import test from "node:test";

interface PackageManifest {
  exports: Record<string, { types: string; default: string }>;
}

const packageRoot = path.resolve(import.meta.dirname, "../..");

test("workspace and sequencing are public typed package subpaths", async () => {
  const manifest = JSON.parse(
    readFileSync(path.join(packageRoot, "package.json"), "utf8")
  ) as PackageManifest;

  assert.deepEqual(manifest.exports["./workspace"], {
    types: "./dist/src/workspace/index.d.ts",
    default: "./dist/src/workspace/index.js"
  });
  assert.deepEqual(manifest.exports["./sequencing"], {
    types: "./dist/src/sequencing/index.d.ts",
    default: "./dist/src/sequencing/index.js"
  });

  const workspace = (await import("asdlc-coordinator/workspace")) as Record<string, unknown>;
  const sequencing = (await import("asdlc-coordinator/sequencing")) as Record<string, unknown>;
  assert.equal(typeof workspace.detectRuntimeRoot, "function");
  assert.equal(typeof sequencing.evaluate, "function");
  assert.equal(typeof sequencing.toFeatureSummary, "function");
});

test("workspace and sequencing source graphs exclude cli and orchestrator", () => {
  const visited = new Set<string>();
  const visit = (sourcePath: string): void => {
    if (visited.has(sourcePath)) return;
    visited.add(sourcePath);
    const source = readFileSync(sourcePath, "utf8");
    assert.doesNotMatch(sourcePath, /\/(?:cli|orchestrator)\//);
    for (const match of source.matchAll(/from\s+["'](\.[^"']+)["']/g)) {
      const specifier = match[1]!;
      const dependency = path.resolve(path.dirname(sourcePath), specifier.replace(/\.js$/, ".ts"));
      visit(dependency);
    }
  };
  for (const directory of ["workspace", "sequencing"]) {
    visit(path.join(packageRoot, "src", directory, "index.ts"));
  }
});
