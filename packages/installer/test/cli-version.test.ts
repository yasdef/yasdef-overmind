import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";
import test from "node:test";
import assert from "node:assert/strict";

const installerBinPath = fileURLToPath(new URL("../src/bin/overmind.js", import.meta.url));
const packageJsonPath = fileURLToPath(new URL("../../package.json", import.meta.url));

function expectedVersion(): string {
  return (JSON.parse(readFileSync(packageJsonPath, "utf8")) as { version: string }).version;
}

test("installer overmind.js reports the package version for --version", () => {
  const result = spawnSync(process.execPath, [installerBinPath, "--version"], { encoding: "utf8" });
  assert.equal(result.status, 0);
  assert.equal(result.stdout, `${expectedVersion()}\n`);
});

test("installer overmind.js reports the package version for -v", () => {
  const result = spawnSync(process.execPath, [installerBinPath, "-v"], { encoding: "utf8" });
  assert.equal(result.status, 0);
  assert.equal(result.stdout, `${expectedVersion()}\n`);
});
