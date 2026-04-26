## Why

Project type `A` starts before a repository exists. At that point Overmind still needs stable, user-approved structural conventions for each active class so a later type `A` surface-map flow can cite blueprint evidence instead of inventing repository facts.

CRP-114 defines the Gap 5 project stack blueprint artifact contract: planned repo identity, stack choices, layer bindings, and component archetypes. It is declarative substitute evidence for future type `A` surface-map generation, not a feature implementation plan.

## What Changes

- Add per-class project stack blueprint templates for backend, frontend, and mobile.
- Keep templates structure-only while defining Meta, Stack Choices, and Layer Bindings.
- Define a concise rule that keeps this artifact limited to stable project-level conventions.
- Add a structural quality helper that validates required fields, supported class values, date shape, stack choices, layer bindings, and baseline token shape.
- Add golden examples showing valid backend, frontend, and mobile Gap 5 blueprint shape.
- Add focused tests for valid artifacts, missing metadata, missing stack choices, missing layer blocks, invalid baseline tokens, invalid date shape, and unfilled placeholders.

## Capabilities

### New Capabilities

- `overmind-stack-blueprint-artifact-contract`: Overmind SHALL define a Gap 5 per-class project stack blueprint artifact contract for backend, frontend, and mobile classes.
- `overmind-stack-blueprint-quality-gate`: Overmind SHALL validate stack blueprints for structural completeness, including planned repo identity, stack choices, layer bindings, and archetypes.

### Modified Capabilities

(none - no existing specs)

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
