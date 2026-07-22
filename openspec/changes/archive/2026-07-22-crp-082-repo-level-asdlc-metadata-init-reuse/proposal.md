## Why

Several `overmind` init scripts still ask for `project_type_code` interactively because the repository has no canonical place to persist that decision once and reuse it later. That causes repeated prompts, inconsistent project typing across steps, and brittle fallback behavior in scripts that should operate from already-initialized repo metadata.

## What Changes

- Add repo-level ASDLC metadata to `overmind/init_progress_definition.yaml` under a top-level `meta_info` block, including `project_classes`, `project_type_code`, and `project_type_label`.
- Add `overmind/scripts/init_asdlc_in_this_repo.sh` to initialize repo metadata once by:
  - selecting project type with the same strict chooser semantics already used in BR scaffold flow
  - selecting one or more project classes (`backend`, `frontend`, `mobile`)
  - persisting normalized values back into `overmind/init_progress_definition.yaml`
- Update repo-wide init scripts to reuse `meta_info.project_type_code` instead of prompting again, including:
  - `overmind/scripts/init_br_scaffold.sh`
  - `overmind/scripts/init_repo_structure_summary.sh`
  - `overmind/scripts/init_project_tech_summary_be.sh`
  - `overmind/scripts/init_contracts_inventory.sh`
- Keep feature-local `feature_br_summary.md` project type fields for artifact traceability, but populate them from canonical repo metadata instead of asking independently.
- Replace ad hoc prompt fallbacks with deterministic fail-fast behavior that tells the user to run `overmind/scripts/init_asdlc_in_this_repo.sh` when required repo metadata is missing or invalid.
- Add regression tests for metadata initialization, deterministic persistence, multi-class selection, downstream reuse, and fail-fast behavior.

## Capabilities

### New Capabilities
- `overmind-repo-asdlc-metadata-bootstrap`: Initialize and persist canonical repo-level project metadata in `overmind/init_progress_definition.yaml`, including project type and one-or-more project classes, for reuse by downstream `overmind` init scripts.

### Modified Capabilities
- `overmind-feature-br-structuring-bootstrap`: BR scaffold initialization SHALL consume canonical repo metadata for project type instead of re-asking the user, while preserving feature-level traceability fields in `feature_br_summary.md`.
- `overmind-bootstrap-progress-checklist`: `overmind/init_progress_definition.yaml` SHALL support a top-level repo metadata block without breaking existing step-definition and scanner-driven checklist behavior.

## Impact

- Affected config:
  - `overmind/init_progress_definition.yaml`
- Affected scripts:
  - `overmind/scripts/init_asdlc_in_this_repo.sh`
  - `overmind/scripts/init_br_scaffold.sh`
  - `overmind/scripts/init_repo_structure_summary.sh`
  - `overmind/scripts/init_project_tech_summary_be.sh`
  - `overmind/scripts/init_contracts_inventory.sh`
- Affected tests:
  - `tests/ai_scripts/init_br_scaffold_tests.sh`
  - `tests/ai_scripts/init_repo_structure_summary_tests.sh`
  - `tests/ai_scripts/init_project_tech_summary_be_tests.sh`
  - `tests/ai_scripts/init_contracts_inventory_tests.sh`
  - new script tests for `init_asdlc_in_this_repo.sh`
- No new CLI flags/options are required by this change.
