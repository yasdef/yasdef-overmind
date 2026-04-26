## Why

Project type `A` starts before a repository exists. At that point the user can usually identify active classes such as backend and frontend, but cannot honestly provide concrete repository structure, folder paths, archetypes, baseline routes, screens, jobs, or other surface-map evidence.

Overmind still needs a small durable artifact that records the approved stack family choice per active class before later init phases proceed. CRP-114 defines that minimal artifact contract only. It must not pretend to be a repo-scan substitute.

## What Changes

- Add per-class stack-family blueprint templates for backend, frontend, and mobile.
- Keep templates structure-only: class metadata, last updated date, and one approved high-level stack family choice.
- Define a concise rule that keeps this artifact limited to approved stack-family selection.
- Add a structural quality helper that validates only required fields, supported class values, date shape, and populated stack-family choice.
- Add golden examples showing valid backend, frontend, and mobile stack-family blueprint shape.
- Add focused tests for valid artifacts, missing metadata, unsupported class values, missing stack-family choice, invalid date shape, and unfilled placeholders.

## Capabilities

### New Capabilities

- `overmind-stack-blueprint-artifact-contract`: Overmind SHALL define a minimal per-class project stack-family blueprint artifact contract for backend, frontend, and mobile classes.
- `overmind-stack-blueprint-quality-gate`: Overmind SHALL validate stack-family blueprints for structural completeness without requiring repository paths, layer bindings, archetypes, or baseline user-reachable inventory.

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
