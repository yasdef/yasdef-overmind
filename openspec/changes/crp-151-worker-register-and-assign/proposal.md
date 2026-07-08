## Why

Worker registration and plan assignment are still owned by three pre-TypeScript shell scripts (`project_register_worker.sh`, `feature_assing_workers.sh`, `check_implementation_plan_readiness.sh`) that mutate `workers.yaml` and `implementation_plan.md` through `awk`/`grep`. This is Unit A of `design_docs/e2e_orchestrator_migration/06_sh_remove_plan.md`: move the worker lifecycle into deterministic TypeScript coordinator modules and delete the shell — Overmind has never been installed, so the scripts are behavior reference, not a deployed contract to preserve.

## What Changes

- Add a typed worker registry module (`workers/registry.ts`) that parses `workers.yaml`, validates the top-level `project_id`/`workers:` shape, generates a unique lowercase-UUID worker entry for a chosen class, and appends it while preserving unrelated content.
- Add a typed assignment module (`workers/assignment.ts`) that reads plan repo classes, filters active workers by class, resolves one worker per class (single auto-select, multi prompt), applies cross-feature dependency holds, and rewrites `#### Assigned:` lines in `implementation_plan.md` without disturbing other content.
- Add an assignment-time plan-shape validator (`validate/worker-assignment.ts`) covering the `check_implementation_plan_readiness.sh` contract (at least one `### Step`, every step has exactly one supported `#### Repo:`), kept distinct from the full implementation-plan quality gate.
- Add CLI verbs `overmind worker register --path <project>` and `overmind worker assign --feature-path <feature>`, wired through the existing `runCli` dispatch with injected interaction/clock/UUID ports. Each primitive returns a typed result (diagnostics + changed paths) that the CLI renders without scraping printed text.
- Delete `overmind/scripts/project_mgmt/project_register_worker.sh`, `overmind/scripts/feature_assing_workers.sh`, `overmind/scripts/common_libs/check_implementation_plan_readiness.sh`, and their three shell test suites; remove their command staging in `project_setup_first_init_machine.sh`.
- Update `overmind/README.md`, `QUICKRUN.md`, and generated quick-run guidance to name the new worker verbs instead of the shell commands.

## Capabilities

### New Capabilities

- `worker-registration`: register one active class worker into a project's `workers.yaml` deterministically, with worker-class validation, UUID uniqueness, and content preservation.
- `worker-assignment`: resolve active workers per plan repo class and write `#### Assigned:` lines into a feature's `implementation_plan.md`, including multi-worker selection, missing-worker markers, dependency holds, and an assignment-time plan-shape check.

### Modified Capabilities

<!-- None. The worker lifecycle has no prior TypeScript spec; these are new capabilities. -->

## Impact

- Adds `packages/asdlc-coordinator/src/workers/` (`registry.ts`, `assignment.ts`) and `packages/asdlc-coordinator/src/validate/worker-assignment.ts`, plus package tests.
- Extends CLI dispatch in `packages/asdlc-coordinator/src/cli/` and the `overmind` usage string with `worker register|assign`.
- Deletes three shell files and three `tests/ai_scripts/` suites; removes their staging from `project_setup_first_init_machine.sh`.
- Reuses the existing `InteractionPort` and an injected clock/UUID seam (as in `capture/scaffold-feature.ts`); the worker primitives perform no git work, so no git port is wired. No runtime `dependencies` added to `packages/asdlc-coordinator` (kept `{}`).
- Touches operator docs (`README.md`, `QUICKRUN.md`) and generated quick-run guidance only for the two new verbs.
