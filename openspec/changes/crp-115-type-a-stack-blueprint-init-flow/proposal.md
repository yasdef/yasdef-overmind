## Why

After the stack blueprint artifact contract exists, type `A` projects need a concrete project-init path that creates one approved blueprint per active class before project-level contract definition begins. Without this flow, brand-new projects still lack the structural evidence needed to unblock later surface-map generation.

## What Changes

- Add project-init Step `1.1`, required only for project type `A`, after project type/classes are selected and before Step `2` creates `common_contract_definition.md`.
- Extend Step `1` project setup metadata so startup can record optional per-class stack guidance sources, such as configured MCP-backed guidance.
- Add a blueprint authoring command/rule that reads `init_progress_definition.yaml`, processes each active class separately, and no-ops for project types `B` and `C`.
- Make the authoring flow source-aware:
  - use configured per-class stack guidance when present,
  - otherwise present bounded fallback proposals for user discussion and approval.
- Use conservative fallback proposals: backend defaults to Java/Spring Boot with Node.js as the main alternative; frontend defaults to React with Angular as the main alternative; mobile defaults to native Android Kotlin and iOS Swift with Flutter/Dart as the main alternative.
- Require explicit user approval before writing final `project_stack_blueprint_<class>.md` artifacts and keep proposal-source/approval tracking in the Step `1.1` authoring flow rather than in the CRP-114 template contract.
- Run the CRP-114 blueprint quality helper before Step `1.1` is considered complete.
- Update Step `2` inputs and conditions so, for project type `A`, `common_contract_definition.md` is created only after approved per-class blueprints exist and treats them as read-only project context, not as API contract schema definitions.

## Capabilities

### New Capabilities

- `overmind-type-a-stack-blueprint-init-flow`: Project type `A` init SHALL create one approved stack blueprint per active project class before project-level contract definition proceeds.
- `overmind-stack-guidance-source-metadata`: Project setup SHALL support optional per-class stack guidance source metadata for type `A` projects without making MCP availability mandatory.
- `overmind-stack-blueprint-authoring-flow`: Stack blueprint authoring SHALL use configured guidance when available, fall back to bounded model proposals when absent, and require user approval before writing final artifacts.
- `overmind-type-a-contract-definition-blueprint-context`: Step `2` SHALL treat approved type `A` stack blueprints as read-only project context and SHALL NOT treat them as contract schema definitions.

### Modified Capabilities

(none — no existing specs)

## Impact

- Depends on `crp-114-type-a-stack-blueprint-artifact-contract`.
- `overmind/templates/init_progress_definition_TEMPLATE.yaml`
- `overmind/scripts/init_project_stack_blueprints.sh`
- `overmind/rules/project_stack_blueprint_authoring_rule.md`
- `overmind/scripts/project_mgmt/project_setup_add_new_project.sh`
- `overmind/scripts/project_mgmt/project_setup_update_project.sh`
- `overmind/scripts/init_common_contract_definition.sh`
- `tests/ai_scripts/project_setup_asdlc_tests.sh`
- `tests/ai_scripts/init_project_stack_blueprints_tests.sh`
- `tests/ai_scripts/init_common_contract_definition_tests.sh`
