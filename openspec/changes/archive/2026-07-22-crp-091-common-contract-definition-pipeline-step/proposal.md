## Why

Step 2 in `overmind/init_progress_definition_sequence_diagram.md` and `overmind/templates/init_progress_definition_TEMPLATE.yaml` already expects `common_contract_definition.md`, but the repository still has no concrete scaffold for producing it. This leaves a documented pipeline phase without a deterministic script, rule, helper gate, model entry, template, or golden example, so Step 2 cannot run consistently from ASDLC project workspaces.

## What Changes

- Add a new Overmind pipeline phase keyed as `common_contract_definition` to generate `common_contract_definition.md` for Step 2 (`Create Cross-Project Contract Inventory and Common Contracts Definition`).
- Add a new init script under `overmind/scripts/` for this phase, using the canonical path `overmind/scripts/init_common_contract_definition.sh`.
- Require the init script to run only against a specific ASDLC project folder under `asdlc/projects/<project-id>`, passed explicitly as `--path <project-folder>`.
- Enforce staged-runtime execution for this phase: the command MUST be executed from `asdlc/.commands/init_common_contract_definition.sh`; running from repository path MUST fail fast with exact message `init asdlc repo first, run this script only from asldc/.commands`.
- Make the script load `<project-folder>/init_progress_definition.yaml` from the selected project root, read configured repository paths from `meta_info.class_repo_paths`, and use those repo paths as the authoritative input set for model analysis.
- Validate `--path` as a strict project-root selector: accept only `asdlc/projects/<project-id>`, reject `asdlc/projects/` parent path, reject project subfolders, and reject unrelated directories.
- Add a new model setup row in `overmind/setup/models.md` for the `common_contract_definition` phase, with first-init staging this file into `asdlc/.setup/models.md` so staged command runtime is self-sufficient.
- Add a new rule file under `overmind/rules/` to define how the model reconciles shared and cross-project contracts from one or more repositories into a single common baseline.
- Add a deterministic helper quality gate under `overmind/scripts/helper/` to validate the generated `common_contract_definition.md`.
- Save the generated output directly into the selected project folder as `<project-folder>/common_contract_definition.md`.
- Add `overmind/templates/common_contract_definition_TEMPLATE.md` and `overmind/golden_examples/common_contract_definition_GOLDEN_EXAMPLE.md` as the canonical output contract for this artifact.
- Document that implementation work for this phase scaffold MUST use the local `overmind-new-pipeline-step` skill so script, rule, helper, models, template, golden example, docs, and tests stay aligned with the repository phase pattern.
- Update `overmind/README.md` and script tests under `tests/ai_scripts/` for the new project-scoped `--path` invocation contract and phase behavior.

## Capabilities

### New Capabilities

- `overmind-common-contract-definition-bootstrap`: Deterministic Step-2 pipeline bootstrap that reads ASDLC project metadata, analyzes configured repository paths, and produces project-scoped `common_contract_definition.md`.
- `overmind-common-contract-definition-quality-gate`: Canonical template, golden example, and helper validation contract for `common_contract_definition.md`.

### Modified Capabilities

- None.

## Impact

- Affected scripts and rules:
  - `overmind/scripts/init_common_contract_definition.sh`
  - `overmind/rules/common_contract_definition_rule.md`
  - `overmind/scripts/helper/check_common_contract_definition_quality.sh`
  - `overmind/setup/models.md`
  - `overmind/scripts/project_mgmt/project_setup_first_init_machine.sh`
- Affected templates/examples:
  - `overmind/templates/common_contract_definition_TEMPLATE.md`
  - `overmind/golden_examples/common_contract_definition_GOLDEN_EXAMPLE.md`
- Affected runtime project artifacts:
  - `asdlc/projects/<project-id>/init_progress_definition.yaml`
  - `asdlc/projects/<project-id>/common_contract_definition.md`
- Affected staged runtime assets:
  - `asdlc/.commands/init_common_contract_definition.sh`
  - `asdlc/.rules/common_contract_definition_rule.md`
  - `asdlc/.helper/check_common_contract_definition_quality.sh`
  - `asdlc/.setup/models.md`
- Affected docs/tests:
  - `overmind/README.md`
  - `tests/ai_scripts/`
- Introduces one new explicit CLI parameter for this new entrypoint only: `--path <project-folder>`.
