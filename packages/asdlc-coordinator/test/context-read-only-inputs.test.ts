import { realpathSync } from "node:fs";
import assert from "node:assert/strict";
import test from "node:test";

import { buildTechnicalRequirementsContext } from "../src/context/index.js";

import { withRunnerWorkspace } from "./runner-fixtures.js";

test("technical-requirements context exposes typed readOnlyInputs while keeping text stable", async () => {
  await withRunnerWorkspace(async ({ root, featurePath }) => {
    const workspaceRoot = realpathSync(root);
    const result = buildTechnicalRequirementsContext(featurePath, root);

    assert.equal(result.exitCode, 0);
    assert.equal(
      result.text,
      `# technical-requirements context

## Runtime Paths
- workspace_root: ${workspaceRoot}
- project_root: projects/project-a
- feature_root: ${featurePath}
- progress_definition: projects/project-a/init_progress_definition.yaml
- requirements_ears_source: ${featurePath}/requirements_ears.md
- common_contract_definition_source: projects/project-a/common_contract_definition.md
- target_artifact: ${featurePath}/technical_requirements.md
- gate_command: node .overmind/overmind.js gate technical-requirements ${featurePath}

## Skill Assets
- technical_requirements_template_asset: assets/technical_requirements_TEMPLATE.md
- technical_requirements_golden_example_asset: assets/technical_requirements_GOLDEN_EXAMPLE.md

## Read-Only Inputs
- read_only_input: projects/project-a/init_progress_definition.yaml
- read_only_input: ${featurePath}/requirements_ears.md
- read_only_input: projects/project-a/common_contract_definition.md
- read_only_input: ${featurePath}/project_surface_struct_resp_map_backend.md

## Active Surface-Map Classes
- backend: ${featurePath}/project_surface_struct_resp_map_backend.md

## Allowed Write Surface
- ${featurePath}/technical_requirements.md
`
    );

    assert.ok(result.text);
    const renderedReadOnlyInputs = result.text
      .split("\n")
      .filter((line) => line.startsWith("- read_only_input: "))
      .map((line) => line.replace("- read_only_input: ", ""));

    assert.deepEqual(result.readOnlyInputs, renderedReadOnlyInputs);
  });
});
