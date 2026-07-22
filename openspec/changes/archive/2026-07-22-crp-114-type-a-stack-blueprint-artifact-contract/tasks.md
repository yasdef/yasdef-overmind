## 1. Stack-Family Blueprint Templates

- [x] 1.1 Add `overmind/templates/project_stack_blueprint_be_TEMPLATE.md` with Gap 5 backend blueprint structure
- [x] 1.2 Add `overmind/templates/project_stack_blueprint_fe_TEMPLATE.md` with Gap 5 frontend blueprint structure
- [x] 1.3 Add `overmind/templates/project_stack_blueprint_mobile_TEMPLATE.md` with Gap 5 mobile blueprint structure
- [x] 1.4 Ensure each template includes Meta, Stack Choices, and Layer Bindings sections
- [x] 1.5 Ensure templates define structure only and do not include proposal source, approval state, behavior rules, or feature-specific implementation content

## 2. Blueprint Rule And Golden Examples

- [x] 2.1 Add `overmind/rules/project_stack_blueprint_rule.md` defining stack-family blueprint purpose, allowed content, and boundaries
- [x] 2.2 Add rule text requiring stable stack choices, layer bindings, and baseline user-reachable inventory while forbidding implementation slices, implementation-plan tasks, and API contract schema governance
- [x] 2.3 Add `overmind/golden_examples/project_stack_blueprint_be_GOLDEN_EXAMPLE.md` with a valid backend stack-family blueprint
- [x] 2.4 Add `overmind/golden_examples/project_stack_blueprint_fe_GOLDEN_EXAMPLE.md` with a valid frontend stack-family blueprint
- [x] 2.5 Add `overmind/golden_examples/project_stack_blueprint_mobile_GOLDEN_EXAMPLE.md` with a valid mobile stack-family blueprint

## 3. Quality Helper

- [x] 3.1 Add `overmind/scripts/helper/check_project_stack_blueprint_quality.sh` with stable exit codes `0`, `1`, and `2`
- [x] 3.2 Validate required top-level sections and reject `[UNFILLED]` placeholders
- [x] 3.3 Validate required meta fields and supported class values
- [x] 3.4 Validate `last_updated` is present in `YYYY-MM-DD` format
- [x] 3.5 Validate stack choices, class-specific layer blocks, folder paths, and archetypes
- [x] 3.6 Confirm helper validates structure only and does not make product or architecture taste judgments

## 4. Quality Tests

- [x] 4.1 Add `tests/ai_scripts/check_project_stack_blueprint_quality_tests.sh`
- [x] 4.2 Add passing tests for valid backend, frontend, and mobile stack-family blueprints
- [x] 4.3 Add failing tests for missing required metadata and unsupported class values
- [x] 4.4 Add failing tests for invalid `last_updated` date shape
- [x] 4.5 Add failing tests for missing stack choices, layer blocks, baseline tokens, and unfilled placeholders

## 5. Verification

- [x] 5.1 Run `bash tests/ai_scripts/check_project_stack_blueprint_quality_tests.sh`
- [x] 5.2 Confirm CRP-114 implementation does not add Step `1.1`, MCP lookup, fallback stack proposal flow, or Step `7` blueprint consumption
