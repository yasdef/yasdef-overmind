## Why

The E2E orchestrator migration has a typed workspace/sequencing core (Slice 1) and a generic action executor (Slice 2), but the live feature workflow still runs through the 3,451-line `project_add_feature_e2e.sh`. Slice 3 is the pivot that composes those modules into `overmind run`, proves behavioral parity against the shell e2e suite, and removes the replaced shell path in the same change.

## What Changes

- Add `overmind run [--path <project>] [--resume <step>]` as the feature-flow entrypoint: project and feature selection, new-vs-continue constraints, resume aliases, linear phase execution, optional-step decisions, phase-7 per-class handling, typed `PhaseOutcome` flow control, and exact restart guidance.
- Add project-level pending-work detection before feature execution. Pending initialization, deferred class-repo attachment, or unreconciled ready classes refuse the run with actionable legacy-script guidance; execution of that project-level work remains Slice 4.
- Add `<project>/.overmind_feature_state.json` with the shell state cache's single-feature lifecycle and stale-path handling. The old `.project_add_feature_e2e_state.env` is ignored.
- Add `capture/scaffold-feature.ts` and `overmind scaffold feature --path <project>` as the deterministic step-3 primitive. Operator input comes from options or `InteractionPort`, and the typed result carries the created feature path without stdout parsing.
- Add a repo-scoped git adapter and preserve best-effort runtime-root checkpoint commits before steps 5.1, 7.1, and 8.4 and after step 8.4.
- Port the behavioral scenarios from `tests/ai_scripts/project_add_feature_e2e_tests.sh` and `tests/ai_scripts/init_br_scaffold_tests.sh` to TypeScript tests using stub agent and interaction ports, including guards, decline paths, resume paths, phase-7 behavior, preflight refusal, and failure-guidance families.
- **BREAKING:** replace `.commands/project_add_feature_e2e.sh` with `overmind run` and `.commands/feature_br_scaffold.sh` with `overmind scaffold feature`; delete both source scripts and their shell tests, remove their staging entries, and update `QUICKRUN.md` and `overmind/README.md` to the new operator entrypoints.
- Keep `asdlc-coordinator` runtime dependencies empty and require a green `npm run verify` after the cutover.

## Capabilities

### New Capabilities

- `feature-orchestrator`: the `overmind run` feature-flow use case, operator decision semantics, project-work refusal, phase execution, typed outcomes, phase-7 class loop, restart guidance, and CLI exit behavior.
- `feature-state-cache`: the JSON feature-path cache, persistence on selection/scaffold, stale-path handling, and completed-feature reopening for `--resume 8.4`.
- `feature-scaffold`: deterministic feature capture through `capture/scaffold-feature.ts`, the standalone `overmind scaffold feature` verb, and step-3 executor registration with a typed created-path result.
- `checkpoint-commits`: the explicit-root git adapter and non-blocking feature-progress checkpoint policy.

### Modified Capabilities

<!-- None: openspec/specs/ contains no published capability specs. Slice 3 consumes the active Slice 1 and Slice 2 contracts without changing their requirements. -->

## Impact

- New or extended TypeScript modules under `packages/asdlc-coordinator/src/orchestrator/`, `state/`, `capture/`, `git/`, and `cli/`, with step-3 deterministic-action registration and exports.
- New TypeScript parity tests derived from the complete shell e2e and scaffold suites; surviving shell suites continue to run through root verification.
- Deleted `overmind/scripts/project_mgmt/project_add_feature_e2e.sh`, `overmind/scripts/feature_br_scaffold.sh`, and their canonical shell tests under `tests/ai_scripts/`.
- Updated setup staging and operator documentation; deployed runtime directories such as `.commands/` are not patched directly.
- No changes to skill bodies, gates, artifact formats, `.setup/models.md`, or the project-level attach/reconciliation implementation planned for Slice 4.
