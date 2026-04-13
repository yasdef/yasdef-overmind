## 1. Add the common-contract-definition scaffold files

- [x] 1.1 Add `overmind/templates/common_contract_definition_TEMPLATE.md` and `overmind/golden_examples/common_contract_definition_GOLDEN_EXAMPLE.md` for the Step-2 artifact contract.
- [x] 1.2 Add `overmind/rules/common_contract_definition_rule.md` to define the model-owned reconciliation rules for shared/common contracts across configured repositories.
- [x] 1.3 Add `overmind/scripts/helper/check_common_contract_definition_quality.sh` with deterministic pass/fail/runtime exit behavior.

## 2. Implement the project-scoped init phase

- [x] 2.1 Add `overmind/scripts/init_common_contract_definition.sh`, require `--path <asdlc/projects/<project-id>>`, and enforce staged-only invocation from `asdlc/.commands/` with exact repo-path fail-fast message `init asdlc repo first, run this script only from asldc/.commands`.
- [x] 2.2 Validate the selected project folder strictly as `asdlc/projects/<project-id>` (reject parent `projects/`, subfolders, and unrelated paths), require root-level `<project>/init_progress_definition.yaml`, and extract usable repository paths from `meta_info.class_repo_paths`.
- [x] 2.3 Load the `common_contract_definition` model configuration from staged `asdlc/.setup/models.md` (sourced from `overmind/setup/models.md`), run Codex against the selected repositories, and write `<project>/common_contract_definition.md`.
- [x] 2.4 Implement this phase using the local `overmind-new-pipeline-step` skill so the full scaffold surface stays aligned.

## 3. Update setup, docs, and tests

- [x] 3.1 Add the `common_contract_definition` row to `overmind/setup/models.md`.
- [x] 3.2 Update `overmind/scripts/project_mgmt/project_setup_first_init_machine.sh` to stage `init_common_contract_definition.sh` and include staged `.setup/models.md`.
- [x] 3.3 Update `overmind/README.md` with staged-command-only phase description and explicit `--path` usage contract.
- [x] 3.4 Add tests under `tests/ai_scripts/` for required path handling, staged-only invocation with exact fail-fast guidance string, ASDLC project-folder validation (including parent/subfolder rejection), root-level `init_progress_definition.yaml` requirement, metadata/repo-path loading, helper behavior, and artifact generation into the selected project folder.

## 4. Validate change readiness

- [x] 4.1 Run the relevant `tests/ai_scripts/` suite(s) for the new phase and helper.
- [x] 4.2 Run `openspec status --change crp-091-common-contract-definition-pipeline-step` and confirm the change is apply-ready.
