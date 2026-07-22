import { cpSync, mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";
import test from "node:test";
import assert from "node:assert/strict";

import { getOvermindVersion } from "../src/version.js";

const bundlePath = fileURLToPath(new URL("../overmind.js", import.meta.url));
const packageJsonPath = fileURLToPath(new URL("../../package.json", import.meta.url));

function expectedVersion(): string {
  return (JSON.parse(readFileSync(packageJsonPath, "utf8")) as { version: string }).version;
}

test("bundled overmind.js reports the package version for --version", () => {
  const result = spawnSync(process.execPath, [bundlePath, "--version"], { encoding: "utf8" });
  assert.equal(result.status, 0);
  assert.equal(result.stdout, `${expectedVersion()}\n`);
});

test("bundled overmind.js reports the package version for -v", () => {
  const result = spawnSync(process.execPath, [bundlePath, "-v"], { encoding: "utf8" });
  assert.equal(result.status, 0);
  assert.equal(result.stdout, `${expectedVersion()}\n`);
});

test("bundled overmind.js reports its version when copied to a directory with no package.json", () => {
  const workDir = mkdtempSync(path.join(tmpdir(), "overmind-bundle-"));
  const copiedBinPath = path.join(workDir, "overmind.js");
  try {
    cpSync(bundlePath, copiedBinPath);
    const result = spawnSync(process.execPath, [copiedBinPath, "--version"], {
      cwd: workDir,
      encoding: "utf8"
    });
    assert.equal(result.status, 0);
    assert.equal(result.stdout, `${expectedVersion()}\n`);
  } finally {
    rmSync(workDir, { recursive: true, force: true });
  }
});

test("getOvermindVersion falls back to a runtime package.json read outside the esbuild bundle", () => {
  // This test runs against the plain tsc build (dist/test + dist/src), where
  // __OVERMIND_BUNDLED_VERSION__ is never defined, so it exercises the
  // createRequire fallback in src/version.ts rather than the bundled constant.
  assert.equal(getOvermindVersion(), expectedVersion());
});
