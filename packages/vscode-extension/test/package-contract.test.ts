import assert from "node:assert/strict";
import { readFileSync, readdirSync } from "node:fs";
import path from "node:path";
import test from "node:test";

interface ExtensionManifest {
  publisher?: string;
  engines?: { vscode?: string };
  main?: string;
  activationEvents?: string[];
  contributes?: {
    views?: Record<string, Array<{ id: string }>>;
  };
  dependencies?: Record<string, string>;
}

const packageRoot = path.resolve(import.meta.dirname, "../..");

test("extension source imports coordinator only through reusable subpaths", () => {
  const sources = readdirSync(path.join(packageRoot, "src"), { withFileTypes: true })
    .filter((entry) => entry.isFile() && entry.name.endsWith(".ts"))
    .map((entry) => readFileSync(path.join(packageRoot, "src", entry.name), "utf8"));
  const imports = sources.flatMap((source) =>
    [...source.matchAll(/from\s+["'](asdlc-coordinator[^"']*)["']/g)].map((match) => match[1])
  );
  assert.deepEqual([...new Set(imports)].sort(), [
    "asdlc-coordinator/sequencing",
    "asdlc-coordinator/workspace"
  ]);
  assert.doesNotMatch(sources.join("\n"), /asdlc-coordinator\/(?:cli|orchestrator)/);
});

test("manifest contributes an activating read-only dashboard entrypoint", () => {
  const manifest = JSON.parse(
    readFileSync(path.join(packageRoot, "package.json"), "utf8")
  ) as ExtensionManifest;
  assert.equal(manifest.publisher, "yasdef");
  assert.match(manifest.engines?.vscode ?? "", /^\^/);
  assert.equal(manifest.main, "./dist/src/extension.js");
  assert.ok(manifest.activationEvents?.includes("onView:overmind.dashboard"));
  assert.ok(
    Object.values(manifest.contributes?.views ?? {})
      .flat()
      .some((view) => view.id === "overmind.dashboard")
  );
  assert.deepEqual(Object.keys(manifest.dependencies ?? {}), ["asdlc-coordinator"]);

  const entrypoint = readFileSync(path.join(packageRoot, manifest.main), "utf8");
  assert.match(entrypoint, /export function activate\s*\(/);
  assert.match(entrypoint, /onDidChangeTreeData/);
  assert.match(entrypoint, /createFileSystemWatcher/);
  assert.match(entrypoint, /onDidCreate/);
  assert.match(entrypoint, /onDidChange/);
  assert.match(entrypoint, /onDidDelete/);
  assert.doesNotMatch(JSON.stringify(manifest.contributes), /commands|menus/);
});
