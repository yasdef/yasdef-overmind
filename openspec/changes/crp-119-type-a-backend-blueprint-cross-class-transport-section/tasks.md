## 1. Backend Blueprint Template §5

- [ ] 1.1 Extend `overmind/templates/project_stack_blueprint_be_TEMPLATE.md` with a required §5 section titled "Cross-Class Transport/Contract Approach"
- [ ] 1.2 Add three §5 fields: `transport_protocol`, `schema_format`, `user_approved`
- [ ] 1.3 Add an inline reference example showing the populated shape (concrete `transport_protocol` and `schema_format`, `user_approved: true`)
- [ ] 1.4 Add an inline reference example showing the placeholdered shape (literal `<to be defined during first feature implementation plan>` for both fields, `user_approved: false`)
- [ ] 1.5 Confirm the template defines structure only and does not include MCP/inference proposal logic, approval-conversation transcripts, or downstream mirror content

## 2. Frontend And Mobile Templates Stay §5-Free

- [ ] 2.1 Confirm `overmind/templates/project_stack_blueprint_fe_TEMPLATE.md` does not contain any §5 section
- [ ] 2.2 Confirm `overmind/templates/project_stack_blueprint_mobile_TEMPLATE.md` does not contain any §5 section

## 3. Blueprint Rule

- [ ] 3.1 Update `overmind/rules/project_stack_blueprint_rule.md` to define §5 semantics for backend blueprints only
- [ ] 3.2 State that backend is the sole holder of §5 and that frontend/mobile blueprints SHALL NOT carry it
- [ ] 3.3 State that multi-backend type `A` projects carry §5 independently per active backend blueprint
- [ ] 3.4 State that the §5 placeholder is the literal `<to be defined during first feature implementation plan>`, distinct from Step `7`'s `<to be defined during implementation>` sentinel
- [ ] 3.5 State that valid §5 has exactly two shapes: fully populated with `user_approved: true`, or fully placeholdered with `user_approved: false`
- [ ] 3.6 State that the §5 contract is a no-op for type `A` projects with no in-project cross-class peer (no active backend, or exactly one active backend with no other active class) and for project types `B` and `C`
- [ ] 3.7 State that §5 carries protocol and schema format only; per-endpoint contract shape stays in `common_contract_definition.md` and `feature_contract_delta.md`

## 4. Quality Helper §5 Rules

- [ ] 4.1 Extend `overmind/scripts/helper/check_project_stack_blueprint_quality.sh` to require §5 in every backend blueprint when the project has at least one in-project cross-class peer (another active backend, an active frontend, or an active mobile class)
- [ ] 4.2 Reject §5 when present in any frontend or mobile blueprint
- [ ] 4.3 Require `transport_protocol`, `schema_format`, and `user_approved` to be present and non-empty
- [ ] 4.4 Reject the mixed state where one of `transport_protocol` and `schema_format` is concrete and the other is the placeholder
- [ ] 4.5 Reject `user_approved: true` when either `transport_protocol` or `schema_format` is the placeholder
- [ ] 4.6 Confirm the §5 rules use stable exit codes `0` for success, `1` for recoverable artifact quality issue, `2` for helper/runtime failure
- [ ] 4.7 Confirm §5 validation is deterministic and does not make product, architecture taste, or MCP availability judgments
- [ ] 4.8 Confirm the §5 rules do not require §5 when the project has no in-project cross-class peer (no active backend, or exactly one active backend with no other active class)

## 5. Init Progress Step `1.1` Condition

- [ ] 5.1 Update `overmind/templates/init_progress_definition_TEMPLATE.yaml` Step `1.1` finished-only-if conditions, type `A` only
- [ ] 5.2 Add a condition stating that, when the project has at least one in-project cross-class peer for the backend, every active backend blueprint has a §5 section that is either fully populated and `user_approved: true`, or fully placeholdered
- [ ] 5.3 Confirm the condition is a no-op for type `A` projects with no in-project cross-class peer (no active backend, or exactly one active backend with no other active class)
- [ ] 5.4 Confirm type `B` and type `C` Step `1.1` flows are unchanged

## 6. Quality Tests

- [ ] 6.1 Update `tests/ai_scripts/check_project_stack_blueprint_quality_tests.sh` to cover §5 rules
- [ ] 6.2 Add a passing test for a backend blueprint with §5 fully populated and `user_approved: true`
- [ ] 6.3 Add a passing test for a backend blueprint with §5 fully placeholdered and `user_approved: false`
- [ ] 6.4 Add a failing test for a backend blueprint missing §5
- [ ] 6.5 Add a failing test for a frontend blueprint that carries a §5 section
- [ ] 6.6 Add a failing test for a mobile blueprint that carries a §5 section
- [ ] 6.7 Add a failing test for a backend §5 with concrete `transport_protocol` and placeholdered `schema_format`
- [ ] 6.8 Add a failing test for a backend §5 with placeholdered `transport_protocol` and concrete `schema_format`
- [ ] 6.9 Add a failing test for a backend §5 with `user_approved: true` paired with any placeholder field
- [ ] 6.10 Add a passing test for a multi-backend type `A` project where every active backend blueprint independently carries a valid §5
- [ ] 6.11 Add a passing test for a type `A` project with no active backend class (no §5 anywhere)
- [ ] 6.11a Add a passing test for a type `A` project with exactly one active backend and no other active class (no §5 required on the lone backend blueprint)
- [ ] 6.12 Confirm type `B` and type `C` runs of the quality helper are unchanged

## 7. Verification

- [ ] 7.1 Run `bash tests/ai_scripts/check_project_stack_blueprint_quality_tests.sh`
- [ ] 7.2 Confirm CRP-119 does not add MCP/inference derivation, approval-conversation logic, or downstream mirroring into `common_contract_definition.md` or `feature_contract_delta.md` (those land in CRP-120)
