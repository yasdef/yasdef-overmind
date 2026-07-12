import { writeFileSync } from "node:fs";
import path from "node:path";
import assert from "node:assert/strict";
import test from "node:test";

import { runCli } from "../src/cli/run.js";

import { withWorkspace } from "./orchestrator-fixtures.js";

interface Captured {
  stdout: string;
  stderr: string;
}

function capture(): {
  streams: { stdout: { write: (s: string) => boolean }; stderr: { write: (s: string) => boolean } };
  out: Captured;
} {
  const out: Captured = { stdout: "", stderr: "" };
  return {
    streams: {
      stdout: { write: (s) => ((out.stdout += s), true) },
      stderr: { write: (s) => ((out.stderr += s), true) }
    },
    out
  };
}

async function run(argv: string[], cwd: string): Promise<{ code: number; out: Captured }> {
  const { streams, out } = capture();
  const code = await runCli(["node", "overmind", ...argv], streams, cwd);
  return { code, out };
}

test("agents-md context emits target, gate, assets, source blueprint, and absent status", async () => {
  await withWorkspace(
    {
      definition: {
        typeCode: "A",
        classes: ["frontend"]
      }
    },
    async ({ root, projectDir, projectPathRel }) => {
      writeFileSync(path.join(projectDir, "project_stack_blueprint_frontend.md"), "# blueprint\n");

      const { code, out } = await run(
        ["context", "agents-md", projectPathRel, "--class", "frontend"],
        root
      );

      assert.equal(code, 0, out.stderr);
      assert.match(out.stdout, /target_class: frontend/);
      assert.match(
        out.stdout,
        /target_agents_md: projects\/p\/project_agents_md_claude_md_frontend\.md/
      );
      assert.match(
        out.stdout,
        /gate_command: node \.overmind\/overmind\.js gate agents-md projects\/p\/project_agents_md_claude_md_frontend\.md/
      );
      assert.match(
        out.stdout,
        /agents_md_template_asset: assets\/project_agents_md_claude_md_fe_TEMPLATE\.md/
      );
      assert.match(
        out.stdout,
        /agents_md_golden_example_asset: assets\/project_agents_md_claude_md_fe_GOLDEN_EXAMPLE\.md/
      );
      assert.match(out.stdout, /external_sources_status: unavailable/);
      assert.match(out.stdout, /agents_md_status: absent/);
      assert.match(out.stdout, /read_only_input: projects\/p\/init_progress_definition\.yaml/);
      assert.match(
        out.stdout,
        /read_only_input: projects\/p\/project_stack_blueprint_frontend\.md/
      );
      assert.match(
        out.stdout,
        /Allowed Write Surface\n- projects\/p\/project_agents_md_claude_md_frontend\.md/
      );
    }
  );
});

test("agents-md context reports present status", async () => {
  await withWorkspace(
    {
      definition: {
        typeCode: "A",
        classes: ["backend"]
      }
    },
    async ({ root, projectDir, projectPathRel }) => {
      writeFileSync(path.join(projectDir, "project_stack_blueprint_backend.md"), "# blueprint\n");
      writeFileSync(path.join(projectDir, "project_agents_md_claude_md_backend.md"), "# agents\n");

      const { code, out } = await run(
        ["context", "agents-md", projectPathRel, "--class", "backend"],
        root
      );

      assert.equal(code, 0, out.stderr);
      assert.match(out.stdout, /agents_md_status: present/);
    }
  );
});

test("agents-md context rejects non-type-A projects", async () => {
  await withWorkspace(
    {
      definition: {
        typeCode: "B",
        classes: ["backend"]
      }
    },
    async ({ root, projectPathRel }) => {
      const { code, out } = await run(
        ["context", "agents-md", projectPathRel, "--class", "backend"],
        root
      );
      assert.equal(code, 2);
      assert.match(out.stderr, /derived from stack blueprints/);
    }
  );
});

test("agents-md context rejects inactive classes", async () => {
  await withWorkspace(
    {
      definition: {
        typeCode: "A",
        classes: ["backend"]
      }
    },
    async ({ root, projectPathRel }) => {
      const { code, out } = await run(
        ["context", "agents-md", projectPathRel, "--class", "frontend"],
        root
      );
      assert.equal(code, 2);
      assert.match(out.stderr, /not active in project_classes/);
    }
  );
});

test("agents-md context rejects missing source blueprints", async () => {
  await withWorkspace(
    {
      definition: {
        typeCode: "A",
        classes: ["mobile"]
      }
    },
    async ({ root, projectPathRel }) => {
      const { code, out } = await run(
        ["context", "agents-md", projectPathRel, "--class", "mobile"],
        root
      );
      assert.equal(code, 2);
      assert.match(out.stderr, /derived from the stack blueprint/);
      assert.match(out.stderr, /project_stack_blueprint_mobile\.md/);
    }
  );
});
