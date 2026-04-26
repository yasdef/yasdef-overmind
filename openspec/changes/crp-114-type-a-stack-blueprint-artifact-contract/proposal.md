## Why

Project type `A` represents a brand-new project with no repository to scan, but later planning phases still need stable per-class structural evidence. Before any init orchestration can create or consume that evidence, Overmind needs a deterministic stack blueprint artifact contract and quality gate.

## What Changes

- Add per-class stack blueprint templates for backend, frontend, and mobile.
- Keep templates structure-only: headings, required field names, and placeholders; concrete stack choices and project-specific values belong in final artifacts or golden examples, not templates.
- Define the required blueprint sections:
  - `§1 Meta` with class, repo/service identity, planned repo path, package/root metadata, and update date.
  - `§2 Stack Choices` with runtime/framework/build/datastore/messaging/observability/deployment/test-stack choices appropriate to the class.
  - `§3 Layer Bindings` aligned to the existing surface-map layer taxonomy, including folder paths, archetypes, and user-reachable pattern or `none`.
  - `§4 Baseline User-Reachable Inventory` with machine-parseable baseline tokens or literal `none`.
- Add a concise blueprint rule that defines blueprint scope and boundaries: structural conventions only, no feature work, no implementation plan, and no contract schema governance.
- Add a structural quality helper that validates required metadata, populated stack categories, expected layer blocks, and parseable baseline user-reachable tokens.
- Add golden examples showing valid backend, frontend, and mobile blueprint shape.
- Add focused tests for valid blueprints, missing required metadata, missing layer blocks, invalid user-reachable tokens, and valid `none` inventory.

## Capabilities

### New Capabilities

- `overmind-stack-blueprint-artifact-contract`: Overmind SHALL define a stable per-class project stack blueprint artifact contract for backend, frontend, and mobile classes.
- `overmind-stack-blueprint-quality-gate`: Overmind SHALL validate stack blueprints for structural completeness, expected layer blocks, and parseable baseline user-reachable inventory.

### Modified Capabilities

(none — no existing specs)

## Impact

- `overmind/templates/project_stack_blueprint_be_TEMPLATE.md`
- `overmind/templates/project_stack_blueprint_fe_TEMPLATE.md`
- `overmind/templates/project_stack_blueprint_mobile_TEMPLATE.md`
- `overmind/rules/project_stack_blueprint_rule.md`
- `overmind/golden_examples/project_stack_blueprint_be_GOLDEN_EXAMPLE.md`
- `overmind/golden_examples/project_stack_blueprint_fe_GOLDEN_EXAMPLE.md`
- `overmind/golden_examples/project_stack_blueprint_mobile_GOLDEN_EXAMPLE.md`
- `overmind/scripts/helper/check_project_stack_blueprint_quality.sh`
- `tests/ai_scripts/check_project_stack_blueprint_quality_tests.sh`
