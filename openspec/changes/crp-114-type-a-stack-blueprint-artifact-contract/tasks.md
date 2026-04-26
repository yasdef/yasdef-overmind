## 1. Stack-Family Blueprint Templates

- [ ] 1.1 Add `overmind/templates/project_stack_blueprint_be_TEMPLATE.md` with minimal backend stack-family blueprint structure
- [ ] 1.2 Add `overmind/templates/project_stack_blueprint_fe_TEMPLATE.md` with minimal frontend stack-family blueprint structure
- [ ] 1.3 Add `overmind/templates/project_stack_blueprint_mobile_TEMPLATE.md` with minimal mobile stack-family blueprint structure
- [ ] 1.4 Ensure each template includes only class, approved stack-family choice, and last updated date
- [ ] 1.5 Ensure templates do not include concrete repo paths, package roots, layer bindings, archetypes, baseline surfaces, approval state, source metadata, or behavior rules

## 2. Blueprint Rule And Golden Examples

- [ ] 2.1 Add `overmind/rules/project_stack_blueprint_rule.md` defining stack-family blueprint purpose, allowed content, and boundaries
- [ ] 2.2 Add rule text forbidding constraints, path strategies, layer bindings, baseline user-reachable inventory, implementation slices, implementation-plan tasks, and API contract schema governance
- [ ] 2.3 Add `overmind/golden_examples/project_stack_blueprint_be_GOLDEN_EXAMPLE.md` with a valid backend stack-family blueprint
- [ ] 2.4 Add `overmind/golden_examples/project_stack_blueprint_fe_GOLDEN_EXAMPLE.md` with a valid frontend stack-family blueprint
- [ ] 2.5 Add `overmind/golden_examples/project_stack_blueprint_mobile_GOLDEN_EXAMPLE.md` with a valid mobile stack-family blueprint

## 3. Quality Helper

- [ ] 3.1 Add `overmind/scripts/helper/check_project_stack_blueprint_quality.sh` with stable exit codes `0`, `1`, and `2`
- [ ] 3.2 Validate required top-level sections and reject `[UNFILLED]` placeholders
- [ ] 3.3 Validate required meta fields and supported class values
- [ ] 3.4 Validate `last_updated` is present in `YYYY-MM-DD` format
- [ ] 3.5 Validate approved stack-family choice is populated
- [ ] 3.6 Confirm helper does not require folder paths, archetypes, layer blocks, path strategy, constraints, or baseline user-reachable inventory

## 4. Quality Tests

- [ ] 4.1 Add `tests/ai_scripts/check_project_stack_blueprint_quality_tests.sh`
- [ ] 4.2 Add passing tests for valid backend, frontend, and mobile stack-family blueprints
- [ ] 4.3 Add failing tests for missing required metadata and unsupported class values
- [ ] 4.4 Add failing tests for invalid `last_updated` date shape
- [ ] 4.5 Add failing tests for missing stack-family choice and unfilled placeholders
- [ ] 4.6 Add tests proving structural fields removed from scope are not required

## 5. Verification

- [ ] 5.1 Run `bash tests/ai_scripts/check_project_stack_blueprint_quality_tests.sh`
- [ ] 5.2 Confirm CRP-114 implementation does not add Step `1.1`, MCP lookup, fallback stack proposal flow, or Step `7` blueprint consumption
