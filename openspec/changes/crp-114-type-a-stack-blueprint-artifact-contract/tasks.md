## 1. Blueprint Templates

- [ ] 1.1 Add `overmind/templates/project_stack_blueprint_be_TEMPLATE.md` with the required four-section backend blueprint structure
- [ ] 1.2 Add `overmind/templates/project_stack_blueprint_fe_TEMPLATE.md` with the required four-section frontend blueprint structure
- [ ] 1.3 Add `overmind/templates/project_stack_blueprint_mobile_TEMPLATE.md` with the required four-section mobile blueprint structure
- [ ] 1.4 Ensure each template includes durable artifact metadata only: class, repo/service identity, planned repo path, class-specific package/root metadata, and last updated date
- [ ] 1.5 Ensure each template uses placeholders/comments only and does not include concrete project values, default stack choices, approval state, or behavior rules
- [ ] 1.6 Ensure each template uses class-appropriate layer bindings aligned to the existing surface-map taxonomy

## 2. Blueprint Rule And Golden Examples

- [ ] 2.1 Add `overmind/rules/project_stack_blueprint_rule.md` defining blueprint purpose, allowed evidence, required sections, and class-specific layer expectations
- [ ] 2.2 Add rule text forbidding feature-specific surfaces, implementation slices, implementation-plan tasks, and API contract schema governance in blueprints
- [ ] 2.3 Add rule text that blueprints remain concise structural references and must be updated when stable stack conventions change
- [ ] 2.4 Add `overmind/golden_examples/project_stack_blueprint_be_GOLDEN_EXAMPLE.md` with a valid backend blueprint
- [ ] 2.5 Add `overmind/golden_examples/project_stack_blueprint_fe_GOLDEN_EXAMPLE.md` with a valid frontend blueprint
- [ ] 2.6 Add `overmind/golden_examples/project_stack_blueprint_mobile_GOLDEN_EXAMPLE.md` with a valid mobile blueprint

## 3. Quality Helper

- [ ] 3.1 Add `overmind/scripts/helper/check_project_stack_blueprint_quality.sh` with stable exit codes `0`, `1`, and `2`
- [ ] 3.2 Validate required top-level sections and reject `[UNFILLED]` placeholders
- [ ] 3.3 Validate required meta fields and supported class values
- [ ] 3.4 Validate `last_updated` is present in `YYYY-MM-DD` format
- [ ] 3.5 Validate required stack choice categories are populated or literal `none` where applicable
- [ ] 3.6 Validate class-specific layer blocks and required `folder_paths`, `archetypes`, and `user_reachable_pattern` fields
- [ ] 3.7 Validate baseline user-reachable inventory entries are concrete tokens or literal `none`, rejecting prose descriptions

## 4. Quality Tests

- [ ] 4.1 Add `tests/ai_scripts/check_project_stack_blueprint_quality_tests.sh`
- [ ] 4.2 Add passing tests for valid backend, frontend, and mobile blueprints
- [ ] 4.3 Add failing tests for missing required metadata and unsupported class values
- [ ] 4.4 Add failing tests for missing required layer blocks and missing required layer fields
- [ ] 4.5 Add failing tests for invalid `last_updated` date shape
- [ ] 4.6 Add tests for valid token inventory, valid `none` inventory, and invalid prose inventory

## 5. Verification

- [ ] 5.1 Run `bash tests/ai_scripts/check_project_stack_blueprint_quality_tests.sh`
- [ ] 5.2 Run existing related script tests if template/rule conventions are touched outside the new files
- [ ] 5.3 Confirm CRP-114 implementation does not add Step `1.1`, MCP lookup, fallback stack proposal flow, or Step `7` blueprint consumption
