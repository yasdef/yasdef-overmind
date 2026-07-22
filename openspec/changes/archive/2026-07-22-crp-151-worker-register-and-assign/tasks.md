## 1. Worker registry module

- [x] 1.1 Add `packages/asdlc-coordinator/src/workers/registry.ts` with typed parse of `workers.yaml` (top-level `project_id`, `workers:` collection, `- uuid/class/status/registered_at` entries), injected clock/UUID ports, and a typed result (`diagnostics` + `changedPaths` + new UUID); no git port.
- [x] 1.2 Implement class validation (`backend|frontend|mobile|infrastructure` by name or `1`–`4`), project_id requirement from `init_progress_definition.yaml` `meta_info.project_id`, and registry create-if-absent with `project_id` + empty `workers:`.
- [x] 1.3 Implement `project_id` match enforcement, `workers: []` inline-empty normalization, unique-lowercase-UUID generation with collision retry, and content-preserving append.
- [x] 1.4 Add `packages/asdlc-coordinator/test/workers/registry.test.ts` covering class-by-name/number, unsupported-class re-prompt, create-on-first-registration, project_id mismatch (no mutation), UUID collision retry, byte-preservation of existing entries, and the typed result (success reports `workers.yaml` in `changedPaths` + UUID; each failure carries a diagnostic and empty `changedPaths`).

## 2. Assignment-time plan-shape validator

- [x] 2.1 Add `packages/asdlc-coordinator/src/validate/worker-assignment.ts` enforcing ≥1 `### Step` and exactly one supported `#### Repo:` per step, distinct from `validate/implementation-plan.ts`, returning stable typed diagnostics.
- [x] 2.2 Add `packages/asdlc-coordinator/test/validate/worker-assignment.test.ts` for no-step rejection, missing/duplicate/unsupported repo rejection, and the ready case.

## 3. Worker assignment module

- [x] 3.1 Add `packages/asdlc-coordinator/src/workers/assignment.ts` that reads distinct plan repo classes, validates the worker registry shape, filters `status: active` workers per class, and returns a typed result (`diagnostics` + `changedPaths` + resolved per-class assignments); no git port.
- [x] 3.2 Implement per-class resolution: single auto-select, multi via `InteractionPort.select`, and no-active-worker missing marker with non-success outcome.
- [x] 3.3 Implement cross-feature `#### Depends on:` hold evaluation against the sibling `implementation_plan.md` (dependency step present, ≥1 checklist item, all checked) writing `hold: depends on <feature>/<step>`.
- [x] 3.4 Implement in-place plan rewrite that inserts/replaces only `#### Assigned:` lines after the step metadata/evidence block, preserving all other content, with re-assignment replacing prior lines (no duplicates); call the plan-shape validator first.
- [x] 3.5 Add `packages/asdlc-coordinator/test/workers/assignment.test.ts` covering single/multi selection, missing worker, dependency hold, re-assignment replacement, byte-preservation, not-ready rejection before rewrite, and the typed result (rewrite reports `implementation_plan.md` in `changedPaths`; not-ready reports empty `changedPaths`; missing-worker/hold diagnostics drive the non-success outcome).

## 4. CLI wiring

- [x] 4.1 Add a `worker` branch to `runCli` in `packages/asdlc-coordinator/src/cli/run.ts` dispatching `register` → `--path` and `assign` → `--feature-path`, rendering typed results with correct exit codes (non-success on markers/holds).
- [x] 4.2 Extend `CliAdapterOverrides` with clock/UUID seams (reuse the existing interaction seam; no git seam — worker primitives do no git); wire production defaults; update the top-level usage string to include `worker register|assign`.
- [x] 4.3 Add CLI tests for both verbs, including argument errors, help/usage, and non-success exit on availability issues and holds.

## 5. Shell removal and docs

- [x] 5.1 Delete `overmind/scripts/project_mgmt/project_register_worker.sh`, `overmind/scripts/feature_assing_workers.sh`, and `overmind/scripts/common_libs/check_implementation_plan_readiness.sh`.
- [x] 5.2 Delete the three corresponding shell test suites under `tests/ai_scripts/` and remove their staging from `overmind/scripts/project_mgmt/project_setup_first_init_machine.sh`.
- [x] 5.3 Do **not** modify `tests/ai_scripts/project_setup_asdlc_tests.sh` (owned by unit D) or `tests/ai_scripts/project_setup_update_project_tests.sh` (owned by unit B); their stale copy/stage/assert references to the three deleted scripts are handled by those owning units. Grep the tree to confirm the only remaining references to `project_register_worker.sh`, `feature_assing_workers.sh`, and `check_implementation_plan_readiness.sh` are those two unit-B/D-owned suites, and record the coordinated-landing dependency (see design Risks).
- [x] 5.4 Update `overmind/README.md`, `QUICKRUN.md`, and generated quick-run guidance to name `overmind worker register` / `overmind worker assign` instead of the shell commands.

## 6. Verification

- [x] 6.1 Run the new package tests, then `npm run typecheck`, `npm run lint`, `npm run format:check`, `npm run build`, `npm test`.
- [x] 6.2 Run `npm run verify` and `git diff --check`. Confirm no dangling references to the three deleted scripts remain **except** in the unit-B/D-owned suites named in 5.3; those two suites are expected to fail until B/D land, so coordinate this change's landing with them (do not fix them here).
- [x] 6.3 Assert `packages/asdlc-coordinator/package.json` still has `"dependencies": {}` (no runtime dependency introduced by the worker modules).
- [x] 6.4 Run strict OpenSpec validation for this change (`openspec validate crp-151-worker-register-and-assign --strict`).
