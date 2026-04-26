## Why

After the Gap 5 project stack blueprint artifact contract exists, type `A` projects need a concrete project-init path that chooses one approved stack choices and baseline conventions per active class. At this early point the user may only know that the project has backend, frontend, and/or mobile classes, so the flow must not require concrete repository structure.

## What Changes

- Add project-init Step `1.1`, required only for project type `A`, after project type/classes are selected and before Step `2` creates `common_contract_definition.md`.
- Extend Step `1` project setup metadata so startup can record optional per-class stack guidance sources, such as configured MCP-backed guidance.
- Add a stack-family blueprint authoring command/rule that reads `init_progress_definition.yaml`, processes each active class separately, and no-ops for project types `B` and `C`.
- Make the authoring flow source-aware:
  - when configured per-class guidance is present and available, extract high-level stack-family options from that source,
  - otherwise present bounded model fallback proposals for user discussion and approval.
- Use conservative fallback proposals: backend defaults to Java/Spring Boot with Node.js as the main alternative; frontend defaults to React with Angular as the main alternative; mobile defaults to native Android Kotlin and iOS Swift with Flutter/Dart as the main alternative.
- Require explicit user approval before writing final `project_stack_blueprint_<class>.md` artifacts and keep proposal-source/approval tracking in the Step `1.1` authoring flow rather than in the CRP-114 template contract.
- Run the CRP-114 stack-family blueprint quality helper before Step `1.1` is considered complete.
- Update Step `2` inputs and conditions so, for project type `A`, `common_contract_definition.md` is created only after approved per-class stack-family blueprints exist and treats them as read-only project context, not as API contract schema definitions or surface-map evidence.

## Capabilities

### New Capabilities

- `overmind-type-a-stack-blueprint-init-flow`: Project type `A` init SHALL create one approved Gap 5 stack blueprint per active project class before project-level contract definition proceeds.
- `overmind-stack-guidance-source-metadata`: Project setup SHALL support optional per-class stack guidance source metadata for type `A` projects without making MCP availability mandatory.
- `overmind-stack-blueprint-authoring-flow`: Stack-family blueprint authoring SHALL use configured guidance when available, fall back to bounded model proposals when absent, and require user approval before writing final artifacts.
- `overmind-type-a-contract-definition-blueprint-context`: Step `2` SHALL treat approved type `A` stack-family blueprints as read-only project context and SHALL NOT treat them as contract schema definitions or Step `7` structural evidence.

### Modified Capabilities

(none - no existing specs)

## Impact

- Depends on `crp-114-type-a-stack-blueprint-artifact-contract`.
- `overmind/templates/init_progress_definition_TEMPLATE.yaml`
- `overmind/scripts/init_project_stack_blueprints.sh`

- `overmind/scripts/project_mgmt/project_setup_add_new_project.sh`
- `overmind/scripts/init_common_contract_definition.sh`
- `tests/ai_scripts/project_setup_asdlc_tests.sh`
- `tests/ai_scripts/init_project_stack_blueprints_tests.sh`
- `tests/ai_scripts/init_common_contract_definition_tests.sh`
