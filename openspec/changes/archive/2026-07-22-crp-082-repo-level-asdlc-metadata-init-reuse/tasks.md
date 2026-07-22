## 1. Add canonical repo ASDLC metadata contract and initializer

- [x] 1.1 Add top-level `meta_info` defaults to `overmind/init_progress_definition.yaml` without breaking existing step definitions.
- [x] 1.2 Add a shared shell helper for repo metadata mapping, normalization, reading, validation, and fail-fast guidance.
- [x] 1.3 Implement `overmind/scripts/init_asdlc_in_this_repo.sh` to select project type, capture one-or-more project classes, and persist normalized metadata deterministically.
- [x] 1.4 Add script tests for `init_asdlc_in_this_repo.sh` covering valid selections, invalid input retry, multi-class persistence, and deterministic re-runs.

## 2. Reuse canonical repo metadata in BR scaffold flow

- [x] 2.1 Update `overmind/scripts/init_br_scaffold.sh` to read `project_type_code` and `project_type_label` from `meta_info` instead of prompting.
- [x] 2.2 Keep `feature_br_summary.md` project type fields populated from canonical repo metadata for feature-local traceability.
- [x] 2.3 Update `tests/ai_scripts/init_br_scaffold_tests.sh` for metadata reuse and fail-fast behavior when repo metadata is missing or invalid.

## 3. Remove repeated project-type prompts from downstream initializers

- [x] 3.1 Update `overmind/scripts/init_repo_structure_summary.sh` to read canonical repo project type from `meta_info` and fail fast when unavailable.
- [x] 3.2 Update `overmind/scripts/init_project_tech_summary_be.sh` to read canonical repo project type from `meta_info` and fail fast when unavailable.
- [x] 3.3 Update `overmind/scripts/init_contracts_inventory.sh` to read canonical repo project type from `meta_info` and fail fast when unavailable.
- [x] 3.4 Update the corresponding shell tests to cover canonical metadata reuse and fail-fast guidance instead of interactive fallback prompts.

## 4. Preserve scanner compatibility and refresh docs

- [x] 4.1 Add scanner regression coverage proving top-level `meta_info` does not interfere with step parsing or checklist output.
- [x] 4.2 Update `overmind/README.md` and any direct user-facing guidance so repo metadata initialization is described as the prerequisite for project-type-dependent init scripts.
- [x] 4.3 Run targeted shell test suites for the new initializer, BR scaffold, repo structure summary, backend tech summary, contracts inventory, and progress scanner.
