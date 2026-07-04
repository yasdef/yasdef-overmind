import { chmodSync, mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import assert from "node:assert/strict";
import test from "node:test";

import { loadRunnerConfig, resolveRunnerPhase } from "../src/config/index.js";

function withTempDir(fn: (root: string) => void): void {
  const root = mkdtempSync(path.join(tmpdir(), "overmind-config-"));
  try {
    fn(root);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
}

test("loadRunnerConfig parses a well-formed models table", () => {
  withTempDir((root) => {
    const modelsPath = path.join(root, "models.md");
    writeFileSync(
      modelsPath,
      "feature_contract_delta | codex | gpt-5.4 | --config | model_reasoning_effort='high'\n"
    );

    const config = loadRunnerConfig(modelsPath);
    const resolved = resolveRunnerPhase(config, "feature_contract_delta");

    assert.deepEqual(resolved.diagnostics, []);
    assert.deepEqual(resolved.config, {
      command: "codex",
      model: "gpt-5.4",
      args: ["--config", "model_reasoning_effort='high'"]
    });
  });
});

test("loadRunnerConfig ignores comments and short rows and first phase match wins", () => {
  withTempDir((root) => {
    const modelsPath = path.join(root, "models.md");
    writeFileSync(
      modelsPath,
      [
        "# comment",
        "feature_contract_delta | codex",
        "feature_contract_delta | codex | gpt-5.4",
        "FEATURE_CONTRACT_DELTA | codex | ignored-second-match"
      ].join("\n")
    );

    const config = loadRunnerConfig(modelsPath);
    const resolved = resolveRunnerPhase(config, "feature_contract_delta");

    assert.deepEqual(resolved.diagnostics, []);
    assert.equal(config.phases.size, 1);
    assert.deepEqual(resolved.config, { command: "codex", model: "gpt-5.4", args: [] });
  });
});

test("loadRunnerConfig degrades missing file with diagnostics", () => {
  withTempDir((root) => {
    const modelsPath = path.join(root, "missing.md");
    const config = loadRunnerConfig(modelsPath);
    const resolved = resolveRunnerPhase(config, "feature_contract_delta");

    assert.equal(resolved.config, undefined);
    assert.match(resolved.diagnostics[0]!.reason, /Models file not found/);
    // Even with the file missing, the diagnostic names the affected phase and row shape.
    assert.match(resolved.diagnostics[0]!.reason, /feature_contract_delta \| codex \| <model>/);
    assert.match(resolved.diagnostics[0]!.reason, /required phase 'feature_contract_delta'/);
    assert.equal(resolved.diagnostics[0]!.source, modelsPath);
  });
});

test("loadRunnerConfig degrades a models path that is a directory with diagnostics", () => {
  withTempDir((root) => {
    const modelsPath = path.join(root, "models.md");
    mkdirSync(modelsPath);

    const config = loadRunnerConfig(modelsPath);
    const resolved = resolveRunnerPhase(config, "feature_contract_delta");

    assert.equal(resolved.config, undefined);
    assert.match(resolved.diagnostics[0]!.reason, /Unable to read models file/);
    assert.match(resolved.diagnostics[0]!.reason, /required phase 'feature_contract_delta'/);
    assert.equal(resolved.diagnostics[0]!.source, modelsPath);
  });
});

test("loadRunnerConfig degrades an unreadable models file with diagnostics", (t) => {
  if (process.platform === "win32" || (process.getuid?.() ?? 0) === 0) {
    t.skip("POSIX permissions from a non-root user are required for this case.");
    return;
  }

  withTempDir((root) => {
    const modelsPath = path.join(root, "models.md");
    writeFileSync(modelsPath, "feature_contract_delta | codex | gpt-5.4\n");
    chmodSync(modelsPath, 0o000);

    try {
      const config = loadRunnerConfig(modelsPath);
      const resolved = resolveRunnerPhase(config, "feature_contract_delta");

      assert.equal(resolved.config, undefined);
      assert.match(resolved.diagnostics[0]!.reason, /Unable to read models file/);
      assert.match(resolved.diagnostics[0]!.reason, /required phase 'feature_contract_delta'/);
      assert.equal(resolved.diagnostics[0]!.source, modelsPath);
    } finally {
      chmodSync(modelsPath, 0o600);
    }
  });
});

test("resolveRunnerPhase reports absent or skipped-short phases without throwing", () => {
  withTempDir((root) => {
    const modelsPath = path.join(root, "models.md");
    writeFileSync(
      modelsPath,
      ["feature_contract_delta | codex | gpt-5.4", "repo_analyse | codex"].join("\n")
    );

    const config = loadRunnerConfig(modelsPath);
    const missing = resolveRunnerPhase(config, "task_to_br");
    const shortOnly = resolveRunnerPhase(config, "repo_analyse");

    assert.match(missing.diagnostics[0]!.reason, /Invalid or missing 'task_to_br' entry/);
    assert.match(shortOnly.diagnostics[0]!.reason, /Invalid or missing 'repo_analyse' entry/);
  });
});

test("resolveRunnerPhase rejects non-codex commands", () => {
  withTempDir((root) => {
    const modelsPath = path.join(root, "models.md");
    writeFileSync(modelsPath, "feature_contract_delta | claude | sonnet\n");

    const config = loadRunnerConfig(modelsPath);
    const resolved = resolveRunnerPhase(config, "feature_contract_delta");

    assert.equal(resolved.config, undefined);
    assert.match(resolved.diagnostics[0]!.reason, /Unsupported command 'claude'/);
  });
});
