## Why

The Step `7` surface map (`project_surface_struct_resp_map_*.md`) and the Step `8` `technical_requirements.md` treat the presence of any source code as evidence that a capability "exists in the repo." In practice this conflates two very different things:

- **Transport layer**: API clients, hooks, services, repositories, helpers — the wiring that other code can call.
- **User-reachable surface**: routes, pages, screens, CLI commands, scheduled jobs — entry points an operator or end user can actually invoke without writing code.

A feature can have full transport-layer coverage with zero user-reachable surface, yet today the artifacts report it as a single `current_state` line and Step `8.2` plans on top of that "exists" reading. That silently elides obvious prerequisite work.

Real example from the live project: the frontend repo had `loginAdmin / getAdminToken / clearAdminSession` helpers in `src/api/auth.ts` (transport) but no `/admin/login` page (user-reachable). The surface map listed those helpers as evidence, the technical requirements wrote "the frontend login flow," and the implementation plan jumped straight to a protected workspace route with no sign-in plan step. The pre-existing `crp-097` and `crp-098` gates passed because every gap token resolved, yet the plan was incorrect by construction.

This change fixes that conflation at its source so the downstream gate added by `crp-109` can detect missing user-reachable prerequisites deterministically.

## What Changes

- Update the frontend/backend/mobile surface-map templates so every Section 3 layer block and every Section 4 surface block records two explicit subfields:
  - `transport_layer`: internal callable code (clients, services, hooks, repositories, helpers).
  - `user_reachable_surface`: entry points an operator can invoke without code edits (routes, pages, screens, CLI commands, scheduled jobs, public HTTP endpoints).
- Update `technical_requirements_TEMPLATE.md` so each requirement's `current_state` field is split into the same two subfields, with an explicit `none` marker when one side is empty.
- Update `feature_repo_surface_and_exec_context_rule.md` and `technical_requirements_rule.md` to require the split, define what counts as user-reachable per project class, and forbid restating transport-layer coverage as user-reachable presence.
- Extend the surface-map and technical-requirements quality helpers to fail when:
  - any Section 3 or Section 4 block is missing one of the two subfields, or
  - any `current_state` line conflates both (single free-text line) without explicit subfields.
- Update golden examples to demonstrate the split with at least one realistic "transport exists, user-reachable missing" case.

## Capabilities

### New Capabilities

- `overmind-surface-map-transport-user-reachable-split`: Surface-map artifacts SHALL record, per layer and per surface block, both the transport-layer presence and the user-reachable-surface presence as distinct subfields.
- `overmind-technical-requirements-current-state-split`: Each `### Requirement:` block in `technical_requirements.md` SHALL record `current_state` with explicit `transport_layer` and `user_reachable_surface` subfields, never as a single conflated line.

### Modified Capabilities

- `overmind-feature-repo-surface-and-exec-context`: The Step `7` rule SHALL require the transport vs user-reachable split for every layer and surface block.
- `overmind-technical-requirements-shared-feature-artifact`: The Step `8` rule SHALL require the transport vs user-reachable split for every requirement's current state.

## Impact

- Affected scripts:
  - `overmind/scripts/feature_repo_surface_and_exec_context.sh`
  - `overmind/scripts/feature_technical_requirements.sh`
  - `overmind/scripts/helper/check_repo_surface_and_exec_context_quality.sh` (add if missing)
  - `overmind/scripts/helper/check_technical_requirements_quality.sh`
- Affected rule/template/example artifacts:
  - `overmind/rules/feature_repo_surface_and_exec_context_rule.md`
  - `overmind/rules/technical_requirements_rule.md`
  - `overmind/templates/project_surface_struct_resp_map_fe_TEMPLATE.md`
  - `overmind/templates/project_surface_struct_resp_map_be_TEMPLATE.md`
  - `overmind/templates/technical_requirements_TEMPLATE.md`
  - `overmind/golden_examples/project_surface_struct_resp_map_fe_GOLDEN_EXAMPLE.md` (add or update)
  - `overmind/golden_examples/project_surface_struct_resp_map_be_GOLDEN_EXAMPLE.md` (add or update)
  - `overmind/golden_examples/technical_requirements_GOLDEN_EXAMPLE.md` (add or update)
- Affected tests:
  - `tests/ai_scripts/feature_repo_surface_and_exec_context_tests.sh`
  - `tests/ai_scripts/feature_technical_requirements_tests.sh`
- Process impact:
  - Surface maps and technical requirements stop reporting transport-layer presence as user-reachable presence.
  - This is the precondition for the Step `8.1.5` prerequisite-gap gate introduced by `crp-109` to detect missing user-reachable prerequisites deterministically.
