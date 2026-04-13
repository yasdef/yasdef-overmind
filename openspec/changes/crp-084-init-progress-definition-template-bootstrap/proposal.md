## Why

`overmind/init_progress_definition.yaml` is currently committed as a static repository artifact, but it mixes reusable workflow structure with repo-specific metadata that should be initialized per repository. This makes bootstrap ownership unclear and prevents `init_asdlc_in_this_repo.sh` from being the single deterministic initializer for progress-definition state.

## What Changes

- Move the canonical progress-definition structure into a template artifact (for example under `overmind/templates/`) instead of keeping `overmind/init_progress_definition.yaml` as a pre-seeded static file.
- Update `overmind/scripts/init_asdlc_in_this_repo.sh` to create `overmind/init_progress_definition.yaml` in the repo Overmind root from the template when missing.
- Add fail-fast behavior when `overmind/init_progress_definition.yaml` already exists: script exits non-zero and prints `init_progress_definition.yaml already exists, remove it completely if you need re-generate it`.
- Keep `init_asdlc_in_this_repo.sh` responsible for filling `meta_info` from user input (`project_type_code`, `project_type_label`, and `project_classes`) during initialization.
- Update scanner/consumer scripts and docs where assumptions currently require a pre-existing static `overmind/init_progress_definition.yaml`.
- Add or update shell tests to cover template-based file creation, metadata injection, and fail-fast behavior when `overmind/init_progress_definition.yaml` already exists.

## Capabilities

### New Capabilities

- `overmind-init-progress-definition-template-bootstrap`: Define template-driven initialization of `overmind/init_progress_definition.yaml`, including template materialization in repo root and initial user-driven `meta_info` population.

### Modified Capabilities

- `overmind-repo-asdlc-metadata-bootstrap`: Repo ASDLC initializer SHALL create `overmind/init_progress_definition.yaml` from template when absent, SHALL persist validated `meta_info` values from user input, and SHALL fail fast with canonical regeneration guidance when `overmind/init_progress_definition.yaml` already exists.
- `overmind-bootstrap-progress-checklist`: Progress scanner and step-state flow SHALL continue to read `overmind/init_progress_definition.yaml`, with compatibility for files generated from the new template bootstrap path.

## Impact

- Affected template/config artifacts:
  - new template for progress definition under `overmind/templates/` (name to be finalized in design)
  - generated `overmind/init_progress_definition.yaml`
- Affected scripts:
  - `overmind/scripts/init_asdlc_in_this_repo.sh`
  - `overmind/scripts/init_progress_scanner.sh` (compatibility checks only, if needed)
  - any helper scripts that assume static presence of `overmind/init_progress_definition.yaml`
- Affected tests:
  - `tests/ai_scripts/init_asdlc_in_this_repo_tests.sh`
  - `tests/ai_scripts/init_progress_scanner_tests.sh`
  - additional targeted script tests for template-generation path and existing-file fail-fast behavior
- Affected docs:
  - `overmind/README.md` and any onboarding/process notes that currently describe `overmind/init_progress_definition.yaml` as a static committed artifact.
