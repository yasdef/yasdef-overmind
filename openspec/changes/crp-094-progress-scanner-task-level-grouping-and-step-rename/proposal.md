## Why

The current init-progress scanner renders all steps as one flat checklist, even though steps `1` and `2` are project-level setup work while steps `3` through `7` are feature-level work. This makes the checklist harder to scan, and the current Step 2 label, `Create Cross-Project Contract Inventory and Common Contracts Definition`, is easy to misread as a broader multi-project task instead of a contract-definition step for the current project context.

## What Changes

- Update the canonical init-progress step contract so scanner output separates steps `1` and `2` under a visible project-level heading such as `---- PROJECT LEVEL TASKS ----`.
- Keep Step 1 as `Initialize Repo ASDLC Metadata`.
- Rename Step 2 from `Create Cross-Project Contract Inventory and Common Contracts Definition` to `Create Cross-Repository Contract Definition For This Project`.
- Update scanner output so steps `3` through `7` are rendered under a visible feature-level heading in the form `--- FEATURE LEVEL TASKS <name-of-feature> ---`.
- Keep checklist ordering and completion semantics unchanged; this change is about clearer task-level grouping and user-facing naming.

## Capabilities

### New Capabilities
- None.

### Modified Capabilities
- `overmind-bootstrap-progress-checklist`: Progress scanner output SHALL render explicit project-level and feature-level checklist sections while preserving ordered step evaluation and next-step semantics.
- `overmind-init-progress-definition-template-bootstrap`: The canonical init progress template SHALL use the revised Step 2 label and the step metadata needed for project-level versus feature-level checklist presentation.

## Impact

- Affected templates/config:
  - `overmind/templates/init_progress_definition_TEMPLATE.yaml`
- Affected scripts:
  - `overmind/scripts/project_mgmt/init_progress_scanner.sh`
- Affected tests:
  - `tests/ai_scripts/init_progress_scanner_tests.sh`
  - `tests/ai_scripts/project_setup_asdlc_tests.sh`
- Affected docs/examples:
  - `overmind/templates/step_state_TEMPLATE.md`
  - `overmind/golden_examples/step_state_GOLDEN_EXAMPLE.md`
  - `overmind/README.md`
- No new CLI flags/options are introduced.
