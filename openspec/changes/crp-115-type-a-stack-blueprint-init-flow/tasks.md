## 1. CRP-114 Dependency

- [ ] 1.1 Confirm minimal `project_stack_blueprint_be_TEMPLATE.md`, `project_stack_blueprint_fe_TEMPLATE.md`, and `project_stack_blueprint_mobile_TEMPLATE.md` exist from CRP-114
- [ ] 1.2 Confirm `check_project_stack_blueprint_quality.sh` exists and validates backend, frontend, and mobile stack-family blueprints
- [ ] 1.3 Confirm CRP-115 implementation does not add workflow-state fields or structural evidence fields to CRP-114 templates

## 2. Project Setup Metadata

- [ ] 2.1 Update project setup metadata handling to support optional per-class `stack_guidance_sources`
- [ ] 2.2 Ensure absence of `stack_guidance_sources` remains valid for type `A`
- [ ] 2.3 Ensure type `B` and `C` project setup behavior remains unchanged
- [ ] 2.4 Add or update tests proving per-class guidance sources can be recorded independently
- [ ] 2.5 Add or update tests proving missing guidance metadata does not block project setup

## 3. Init Progress Step 1.1

- [ ] 3.1 Update `overmind/templates/init_progress_definition_TEMPLATE.yaml` to add Step `1.1` between Step `1` and Step `2`
- [ ] 3.2 Add `required_if` conditions so Step `1.1` requires one stack-family `project_stack_blueprint_<class>.md` per active class only for project type `A`
- [ ] 3.3 Ensure Step `1.1` is non-blocking for project types `B` and `C`
- [ ] 3.4 Add tests proving type `A` Step `1.1` blocks until every active-class stack-family blueprint exists and passes quality
- [ ] 3.5 Add tests proving type `B` and `C` init can proceed without stack-family blueprints

## 4. Stack-Family Authoring Command And Rule

- [ ] 4.1 Add `overmind/scripts/init_project_stack_blueprints.sh`
- [ ] 4.2 Add `overmind/rules/project_stack_blueprint_authoring_rule.md`
- [ ] 4.3 Make the command read `init_progress_definition.yaml`, `project_type_code`, active `project_classes`, and optional per-class `stack_guidance_sources`
- [ ] 4.4 Make the command no-op for project types `B` and `C`
- [ ] 4.5 Make the command process each active type `A` class independently
- [ ] 4.6 Make the command write only approved high-level stack-family choices
- [ ] 4.7 Make the command run `check_project_stack_blueprint_quality.sh` after writing each final blueprint
- [ ] 4.8 Make the command support revising an existing stack-family blueprint through the same approval and quality-validation path

## 5. Guidance And Fallback Authoring Flow

- [ ] 5.1 Add prompt/rule behavior that extracts high-level stack-family options from configured MCP/knowledge-base guidance when available
- [ ] 5.2 Add fallback behavior for missing or unavailable guidance sources
- [ ] 5.3 Present backend fallback proposals as Java/Spring Boot default and Node.js alternative
- [ ] 5.4 Present frontend fallback proposals as React default and Angular alternative
- [ ] 5.5 Present mobile fallback proposals as native Android Kotlin and iOS Swift default and Flutter/Dart alternative
- [ ] 5.6 Require explicit user approval before writing final `project_stack_blueprint_<class>.md`
- [ ] 5.7 Allow user overrides before final approval
- [ ] 5.8 Keep proposal-source and approval tracking in authoring flow output/logging, not in blueprint template fields
- [ ] 5.9 Confirm the authoring flow does not ask for constraints, baseline surfaces, path convention strategy, folder paths, package roots, layer bindings, or archetypes

## 6. Step 2 Integration

- [ ] 6.1 Update `overmind/scripts/init_common_contract_definition.sh` so type `A` requires completed Step `1.1` stack-family blueprints before model invocation
- [ ] 6.2 Bind active-class stack-family blueprint paths into Step `2` prompt/context as read-only inputs for type `A`
- [ ] 6.3 Ensure Step `2` snapshots and verifies blueprints remain unchanged after model invocation
- [ ] 6.4 Update Step `2` rule/prompt text so blueprints are project context only, not API contract schema definitions or Step `7` structural evidence
- [ ] 6.5 Ensure type `B` and `C` Step `2` behavior remains unchanged

## 7. Tests

- [ ] 7.1 Add `tests/ai_scripts/init_project_stack_blueprints_tests.sh`
- [ ] 7.2 Add tests for guidance-backed authoring prompt/context
- [ ] 7.3 Add tests for fallback prompt/context when guidance metadata is absent
- [ ] 7.4 Add tests that final blueprint is not written before user approval
- [ ] 7.5 Add tests that invalid generated blueprint output does not complete Step `1.1`
- [ ] 7.6 Add tests that revising an existing blueprint requires approval and passes quality validation
- [ ] 7.7 Add tests that authoring output does not include path strategy, layer bindings, archetypes, constraints, or baseline surfaces
- [ ] 7.8 Update `tests/ai_scripts/project_setup_asdlc_tests.sh` for optional per-class guidance metadata
- [ ] 7.9 Update `tests/ai_scripts/init_common_contract_definition_tests.sh` for type `A` blueprint read-only context

## 8. Verification

- [ ] 8.1 Run `bash tests/ai_scripts/check_project_stack_blueprint_quality_tests.sh`
- [ ] 8.2 Run `bash tests/ai_scripts/init_project_stack_blueprints_tests.sh`
- [ ] 8.3 Run `bash tests/ai_scripts/project_setup_asdlc_tests.sh`
- [ ] 8.4 Run `bash tests/ai_scripts/init_common_contract_definition_tests.sh`
- [ ] 8.5 Confirm CRP-115 does not implement Step `7` blueprint consumption
