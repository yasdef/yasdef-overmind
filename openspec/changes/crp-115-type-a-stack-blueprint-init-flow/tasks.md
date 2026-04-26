## 1. CRP-114 Dependency

- [x] 1.1 Confirm Gap 5 `project_stack_blueprint_be_TEMPLATE.md`, `project_stack_blueprint_fe_TEMPLATE.md`, and `project_stack_blueprint_mobile_TEMPLATE.md` exist from CRP-114
- [x] 1.2 Confirm `check_project_stack_blueprint_quality.sh` exists and validates backend, frontend, and mobile stack blueprints
- [x] 1.3 Confirm CRP-115 implementation does not add workflow-state or approval-tracking fields to CRP-114 templates

## 2. Project Setup Metadata

- [x] 2.1 Update project setup metadata handling to support optional per-class `stack_guidance_sources`
- [x] 2.2 Ensure absence of `stack_guidance_sources` remains valid for type `A`
- [x] 2.3 Ensure type `B` and `C` project setup behavior remains unchanged
- [x] 2.4 Add or update tests proving per-class guidance sources can be recorded independently
- [x] 2.5 Add or update tests proving missing guidance metadata does not block project setup

## 3. Init Progress Step 1.1

- [x] 3.1 Update `overmind/templates/init_progress_definition_TEMPLATE.yaml` to add Step `1.1` between Step `1` and Step `2`
- [x] 3.2 Add `required_if` conditions so Step `1.1` requires one stack-family `project_stack_blueprint_<class>.md` per active class only for project type `A`
- [x] 3.3 Ensure Step `1.1` is non-blocking for project types `B` and `C`
- [x] 3.4 Add tests proving type `A` Step `1.1` blocks until every active-class stack blueprint exists and passes quality
- [x] 3.5 Add tests proving type `B` and `C` init can proceed without stack blueprints

## 4. Stack-Family Authoring Command And Rule

- [x] 4.1 Add `overmind/scripts/init_project_stack_blueprints.sh`
- [x] 4.2 Add `overmind/rules/project_stack_blueprint_authoring_rule.md`
- [x] 4.3 Make the command read `init_progress_definition.yaml`, `project_type_code`, active `project_classes`, and optional per-class `stack_guidance_sources`
- [x] 4.4 Make the command no-op for project types `B` and `C`
- [x] 4.5 Make the command process each active type `A` class independently
- [x] 4.6 Make the command write only approved Gap 5 stack blueprint content
- [x] 4.7 Make the command run `check_project_stack_blueprint_quality.sh` after writing each final blueprint
- [x] 4.8 Make the command support revising an existing stack blueprint through the same approval and quality-validation path

## 5. Guidance And Fallback Authoring Flow

- [x] 5.1 Add prompt/rule behavior that extracts Gap 5 stack blueprint conventions from configured MCP/knowledge-base guidance when available
- [x] 5.2 Add fallback behavior for missing or unavailable guidance sources
- [x] 5.3 Present backend fallback proposals as Java/Spring Boot default and Node.js alternative
- [x] 5.4 Present frontend fallback proposals as React default and Angular alternative
- [x] 5.5 Present mobile fallback proposals as native Android Kotlin and iOS Swift default and Flutter/Dart alternative
- [x] 5.6 Require explicit user approval before writing final `project_stack_blueprint_<class>.md`
- [x] 5.7 Allow user overrides before final approval
- [x] 5.8 Keep proposal-source and approval tracking in authoring flow output/logging, not in blueprint template fields
- [x] 5.9 Confirm the authoring flow asks only for stable Gap 5 blueprint conventions, not feature-specific constraints, feature work, API schemas, or implementation-plan details

## 6. Step 2 Integration

- [x] 6.1 Update `overmind/scripts/init_common_contract_definition.sh` so type `A` requires completed Step `1.1` stack blueprints before model invocation
- [x] 6.2 Bind active-class stack blueprint paths into Step `2` prompt/context as read-only inputs for type `A`
- [x] 6.3 Ensure Step `2` snapshots and verifies blueprints remain unchanged after model invocation
- [x] 6.4 Update Step `2` rule/prompt text so blueprints are project context only, not API contract schema definitions or Step `7` structural evidence
- [x] 6.5 Ensure type `B` and `C` Step `2` behavior remains unchanged

## 7. Tests

- [x] 7.1 Add `tests/ai_scripts/init_project_stack_blueprints_tests.sh`
- [x] 7.2 Add tests for guidance-backed authoring prompt/context
- [x] 7.3 Add tests for fallback prompt/context when guidance metadata is absent
- [x] 7.4 Add tests that final blueprint is not written before user approval
- [x] 7.5 Add tests that invalid generated blueprint output does not complete Step `1.1`
- [x] 7.6 Add tests that revising an existing blueprint requires approval and passes quality validation
- [x] 7.7 Add tests that authoring output includes Gap 5 structure without workflow-state, proposal, or approval fields
- [x] 7.8 Update `tests/ai_scripts/project_setup_asdlc_tests.sh` for optional per-class guidance metadata
- [x] 7.9 Update `tests/ai_scripts/init_common_contract_definition_tests.sh` for type `A` blueprint read-only context

## 8. Verification

- [x] 8.1 Run `bash tests/ai_scripts/check_project_stack_blueprint_quality_tests.sh`
- [x] 8.2 Run `bash tests/ai_scripts/init_project_stack_blueprints_tests.sh`
- [x] 8.3 Run `bash tests/ai_scripts/project_setup_asdlc_tests.sh`
- [x] 8.4 Run `bash tests/ai_scripts/init_common_contract_definition_tests.sh`
- [x] 8.5 Confirm CRP-115 does not implement Step `7` blueprint consumption
