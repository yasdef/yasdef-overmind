import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import assert from "node:assert/strict";
import test from "node:test";

import { runCli } from "../src/cli/run.js";
import { validateAgentsMd, validateAgentsMdContent } from "../src/validate/agents-md.js";

const backendGolden = fileURLToPath(
  new URL(
    "../../../../overmind/golden_examples/project_agents_md_claude_md_be_GOLDEN_EXAMPLE.md",
    import.meta.url
  )
);
const frontendGolden = fileURLToPath(
  new URL(
    "../../../../overmind/golden_examples/project_agents_md_claude_md_fe_GOLDEN_EXAMPLE.md",
    import.meta.url
  )
);

async function withProject(fn: (projectDir: string) => void | Promise<void>): Promise<void> {
  const root = mkdtempSync(path.join(tmpdir(), "overmind-agents-md-"));
  const projectDir = path.join(root, "projects", "p1");
  mkdirSync(projectDir, { recursive: true });
  try {
    await fn(projectDir);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
}

function validBackendAgentsMd(): string {
  return readFileSync(backendGolden, "utf8");
}

function validFrontendAgentsMd(): string {
  return readFileSync(frontendGolden, "utf8");
}

function headingOnlyBackendAgentsMd(): string {
  return [
    "## 1. Document Meta",
    "## Stack Baseline",
    "## Target Project Shape",
    "## Layer Responsibilities",
    "## Mission",
    "## Non-Negotiable Engineering Rules",
    "## Coding Standards",
    "## Testing Standard",
    "## Linting and Quality Gates",
    "## Definition of Done",
    "## Decision Guidance for Agents"
  ].join("\n\n");
}

test("agents-md gate accepts complete backend and frontend artifacts", async () => {
  await withProject((projectDir) => {
    const backend = path.join(projectDir, "project_agents_md_claude_md_backend.md");
    writeFileSync(backend, validBackendAgentsMd());
    assert.equal(validateAgentsMd(backend).exitCode, 0);

    const frontend = path.join(projectDir, "project_agents_md_claude_md_frontend.md");
    writeFileSync(frontend, validFrontendAgentsMd());
    assert.equal(validateAgentsMd(frontend).exitCode, 0);
  });
});

test("agents-md gate reports meta failures", () => {
  const missingProject = validBackendAgentsMd().replace("- project: checkout-platform\n", "");
  assert.match(
    validateAgentsMdContent(missingProject).join("\n"),
    /missing or unfilled meta key: project/
  );

  const badKind = validBackendAgentsMd().replace(
    "artifact_kind: project_agents_md_claude_md",
    "artifact_kind: other"
  );
  assert.match(validateAgentsMdContent(badKind).join("\n"), /artifact_kind must be/);

  const badDate = validBackendAgentsMd().replace("last_updated: 2026-07-13", "last_updated: now");
  assert.match(validateAgentsMdContent(badDate).join("\n"), /last_updated must use YYYY-MM-DD/);

  const badClass = validBackendAgentsMd().replace("class: backend", "class: desktop");
  assert.match(validateAgentsMdContent(badClass).join("\n"), /unsupported class value: desktop/);
});

test("agents-md gate continues reporting class-independent meta failures after bad class", () => {
  const missingClassAndBadDate = validBackendAgentsMd()
    .replace("- class: backend\n", "")
    .replace("last_updated: 2026-07-13", "last_updated: 13-07-2026");
  const missingClassProblems = validateAgentsMdContent(missingClassAndBadDate).join("\n");
  assert.match(missingClassProblems, /missing or unfilled meta key: class/);
  assert.match(missingClassProblems, /last_updated must use YYYY-MM-DD format/);
  assert.doesNotMatch(missingClassProblems, /unsupported class value/);

  const unsupportedClassAndBadDate = validBackendAgentsMd()
    .replace("class: backend", "class: desktop")
    .replace("last_updated: 2026-07-13", "last_updated: 13-07-2026");
  const unsupportedClassProblems = validateAgentsMdContent(unsupportedClassAndBadDate).join("\n");
  assert.match(unsupportedClassProblems, /unsupported class value: desktop/);
  assert.match(unsupportedClassProblems, /last_updated must use YYYY-MM-DD format/);
});

test("agents-md gate reports required-section and class-specific failures", () => {
  const missingDone = validBackendAgentsMd().replace(
    "## Definition of Done\n\n- The change preserves",
    "## Done\n\n- The change preserves"
  );
  assert.match(validateAgentsMdContent(missingDone).join("\n"), /missing section: ## Definition/);
  assert.match(validateAgentsMdContent(missingDone).join("\n"), /unexpected top-level section/);

  const backendWithUiSection = `${validBackendAgentsMd()}\n## Applied Visual Style Contract\n\n- none\n`;
  assert.match(validateAgentsMdContent(backendWithUiSection).join("\n"), /forbidden for backend/);

  const unexpected = `${validFrontendAgentsMd()}\n## Release Notes\n\n- none\n`;
  assert.match(validateAgentsMdContent(unexpected).join("\n"), /unexpected top-level section/);

  const unfilled = validBackendAgentsMd().replace("Java 21", "[UNFILLED]");
  assert.match(validateAgentsMdContent(unfilled).join("\n"), /\[UNFILLED\] placeholders/);
});

test("agents-md gate rejects required sections with empty bodies", () => {
  const problems = validateAgentsMdContent(headingOnlyBackendAgentsMd()).join("\n");
  assert.match(problems, /section has no body content: ## 1\. Document Meta/);
  assert.match(problems, /section has no body content: ## Stack Baseline/);
  assert.match(problems, /section has no body content: ## Testing Standard/);
});

test("agents-md gate requires Testing Standard to contain a percentage", () => {
  const withoutPercentage = validBackendAgentsMd().replace("80%", "eighty percent");
  assert.match(
    validateAgentsMdContent(withoutPercentage).join("\n"),
    /## Testing Standard must include a percentage coverage floor/
  );
});

test("agents-md gate distinguishes exit codes", async () => {
  await withProject((projectDir) => {
    assert.equal(validateAgentsMd("").exitCode, 2);
    assert.equal(
      validateAgentsMd(path.join(projectDir, "project_agents_md_claude_md_backend.md")).exitCode,
      2
    );
    assert.equal(validateAgentsMd(projectDir).exitCode, 2);

    const empty = path.join(projectDir, "project_agents_md_claude_md_backend.md");
    writeFileSync(empty, "\n");
    assert.equal(validateAgentsMd(empty).exitCode, 1);
  });
});

test("agents-md gate CLI uses standard rendering", async () => {
  await withProject(async (projectDir) => {
    const target = path.join(projectDir, "project_agents_md_claude_md_backend.md");
    writeFileSync(target, validBackendAgentsMd());
    const out = { stdout: "", stderr: "" };
    const code = await runCli(
      ["node", "overmind", "gate", "agents-md", target],
      {
        stdout: { write: (value: string) => ((out.stdout += value), true) },
        stderr: { write: (value: string) => ((out.stderr += value), true) }
      },
      projectDir
    );
    assert.equal(code, 0, out.stdout + out.stderr);
    assert.match(out.stdout, /quality gate passed/);
  });
});
