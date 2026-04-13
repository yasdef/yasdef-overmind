## Why

`init_progress_scanner.sh` currently makes the user provide a project folder as a positional argument and then optionally add `--feature_path` to target feature-scoped artifacts. That split is harder to use at the feature handoff level, where the user already knows the target feature folder and still expects the scanner to include project-level setup status in the same checklist.

## What Changes

- Change `overmind/scripts/project_mgmt/init_progress_scanner.sh` invocation from `<project-path> [--feature_path <path>]` to a single required flag: `--path <path/to/feature>`.
- Remove the scanner-specific `--feature_path` flag and the mandatory positional project-path argument.
- Require the scanner to resolve the selected feature folder from `--path`, infer its owning ASDLC project folder, and read project metadata from that project root.
- Keep project-level checklist evaluation anchored at the project root while evaluating feature-level checklist entries against the selected feature path.
- Keep grouped scanner output semantics intact so one run still shows both `PROJECT LEVEL TASKS` and `FEATURE LEVEL TASKS <feature>` for the selected feature context.
- Update staged-command usage text, docs, and tests so scanner examples and validation target feature-level entrypoints instead of project-level entrypoints.
- **BREAKING**: existing scanner calls that pass `<project-path>` and/or `--feature_path` will no longer match the canonical CLI contract.

## Capabilities

### New Capabilities

- None.

### Modified Capabilities

- `overmind-bootstrap-progress-checklist`: Progress scanner requirements SHALL accept a feature-targeted `--path` input, infer the owning project context from that feature path, and continue rendering one checklist that includes both project-level and selected-feature status.
- `overmind-feature-path-override`: Scanner-specific path-selection requirements SHALL replace `--feature_path` plus positional project targeting with a single `--path` feature-targeting contract, while preserving invocation-scoped feature resolution semantics.

## Impact

- Affected scripts:
  - `overmind/scripts/project_mgmt/init_progress_scanner.sh`
  - `overmind/scripts/project_mgmt/project_setup_first_init_machine.sh`
- Affected tests:
  - `tests/ai_scripts/init_progress_scanner_tests.sh`
  - `tests/ai_scripts/project_setup_asdlc_tests.sh`
- Affected docs:
  - `overmind/README.md`
- Affected staged command usage:
  - `<asdlc>/.commands/init_progress_scanner.sh --path <path/to/feature>`
