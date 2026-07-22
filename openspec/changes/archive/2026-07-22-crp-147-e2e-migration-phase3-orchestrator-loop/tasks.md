## 1. Responsibility and parity inventory

- [x] 1.1 Map `design_docs/e2e_orchestrator_migration/02_responsibility_translation_map.md` rows 1-17 and 21-23 to a Slice 1/2 owner, a Slice 3 module/test, or an explicit retirement decision; block implementation on any unowned behavior
- [x] 1.2 Cover every distinct behavior family in `tests/ai_scripts/project_add_feature_e2e_tests.sh` (collapsing the redundant mock-scanner variants) with retained runner coverage, a new TypeScript orchestrator test, or the Slice 4 project-flow suite; retarget attach/reconciliation execution scenarios to Slice 3 detection-and-guidance assertions. Full auditable reconciliation is deferred to the Slice 5 parity CRP (`design_docs/e2e_orchestrator_migration/05_parity_reconciliation.md`)
- [x] 1.3 Cover every distinct behavior family in `tests/ai_scripts/init_br_scaffold_tests.sh` with a TypeScript scaffold primitive or CLI test; full auditable reconciliation deferred to the Slice 5 parity CRP (`design_docs/e2e_orchestrator_migration/05_parity_reconciliation.md`)
- [x] 1.4 Audit all source, setup-test, and versioned-doc references to `project_add_feature_e2e.sh`, `feature_br_scaffold.sh`, and `.project_add_feature_e2e_state.env`; record each staging/assertion/guidance location that must change at cutover

## 2. Feature state cache (`feature-state-cache`)

- [x] 2.1 Add `state/feature-state.ts` with typed read/write results for `<project>/.overmind_feature_state.json` containing one canonical workspace-relative `featurePath`; export it from module/package barrels
- [x] 2.2 Validate cached JSON shape, directory existence, workspace containment, and selected-project containment; return stale diagnostics/notices for malformed, missing, or escaping paths without throwing
- [x] 2.3 Persist state atomically after successful existing-feature selection and successful scaffold creation; ignore `.project_add_feature_e2e_state.env`
- [x] 2.4 Add tests for valid load, selected/scaffold persistence, malformed JSON, missing directory, path escape, cross-project path, and ignored legacy state

## 3. Scaffold primitive and command (`feature-scaffold`)

- [x] 3.1 Implement `capture/scaffold-feature.ts` over the existing workspace/parser modules with injected clock and `InteractionPort` dependencies (the filesystem is accessed directly via `node:fs`, consistent with the rest of the core — `parse/`, `sequencing/`, `workspace/`, `state/`; the injected side-effect seams are interaction, agent spawn, the git runner, and the clock); return typed feature/output paths and diagnostics
- [x] 3.2 Preserve scaffold validation and rendering parity: project path/definition/template checks, supported project type code/label, required trimmed feature id/title retries, placeholder replacement, and `ready_to_ears: false`
- [x] 3.3 Preserve folder naming parity (lowercase, non-alphanumeric runs to underscores, trim/collapse, non-empty normalized title, injected Unix timestamp) and reject an existing target without overwrite
- [x] 3.4 Register `scaffold-feature` in the generic executor's deterministic action registry so catalog step 3 returns the primitive's typed result without executor step-id branching or an orchestrator bespoke launcher; step 3 is the project-scoped scaffold boundary (project→feature transition) that still dispatches the registered primitive through `executeStep`, ahead of the feature-scoped phase loop (4.1-8.4, which carries no step-id branch)
- [x] 3.5 Add `overmind scaffold feature --path <project>` dispatch using the same primitive and TTY adapter; keep the command surface to the required `--path` option and human-readable created/updated notices
- [x] 3.6 Add primitive, deterministic-dispatch, and CLI tests covering all scenarios inventoried from `init_br_scaffold_tests.sh`, including staged-workspace/path failures, metadata rendering, input retry, naming, collision, and typed path consumption

## 4. Project pending-work detector

- [x] 4.1 Add a typed project preflight projection over initialization progress and parsed `classRepoPaths` that reports pending init, deferred attach, and ready-but-unreconciled classes without executing project lifecycle work
- [x] 4.2 Add the Slice 3 transition read: accept either `contract_reconciled: true` or a legacy `.contract_reconciled_<class>` marker for a ready class, never write markers, and isolate the bridge for removal in Slice 4
- [x] 4.3 Render actionable step-specific initialization and legacy attach/reconciliation guidance, and prove no feature menu, cache write, scaffold, agent run, or checkpoint occurs after refusal
- [x] 4.4 Add tests for each pending-work family, multiple affected classes, field/marker reconciliation success, and malformed project data diagnostics

## 5. Feature selection and resume resolution

- [x] 5.1 Implement typed project auto-selection and interactive multi-project selection through `InteractionPort`, preserving zero/one/many and clean-finish semantics
- [x] 5.2 Discover project feature children and evaluate unfinished/completed status from `ProgressReport`/`nextStep()` without invoking or parsing `overmind status`
- [x] 5.3 Implement the start-new/continue menus and persist a selected unfinished feature, including status text in the interaction options
- [x] 5.4 Implement resume resolution from catalog ids/aliases and the constraint matrix: non-3 resume rejects new, resume 3 rejects continue, unsupported resume fails, non-3 resume without context fails, and resume 8.4 reopens a valid completed cache
- [x] 5.5 Add selection/resume tests for all default, override, stale-cache, completed-cache, no-unfinished, and conflicting-choice scenarios from the parity inventory

## 6. Feature orchestrator loop (`feature-orchestrator`)

- [x] 6.1 Define `PhaseOutcome` and `orchestrator/run-feature-flow.ts` with injected sequencing, executor, interaction, state, scaffold, and checkpoint dependencies; keep CLI rendering/exit codes outside the use case
- [x] 6.2 Run catalog steps linearly from explicit resume or precise `nextStep()`, dispatch every action through `executeStep`, stop on the first failed action, and never invoke `overmind gate` or branch on skill names
- [x] 6.3 Preserve required/optional confirmations: required decline/input closure stops cleanly; optional decline skips to later required work or finishes when none remains
- [x] 6.4 Implement the phase-7 per-class loop from typed progress with analyze-one, refresh, and move-forward choices; execute one single-class binding at a time and report remaining classes
- [x] 6.5 Preserve composite-step behavior for 4.1 and 4.2 through catalog/executor results, including running repo-br-scan before task-to-BR when a class repo is ready, emitting the `hasReadyClassRepo` skip notice while still running task-to-BR when none is ready, and propagating readiness-check failures
- [x] 6.6 Add stub-agent/interaction orchestration tests for phase ordering, both step-4.1 `hasReadyClassRepo` branches, optional paths, required decline, input closure, composite failure, phase-7 choices/classes, guard/output failures propagated from the executor, and no reopening of earlier optional steps

## 7. Git adapter and checkpoint policy (`checkpoint-commits`)

- [x] 7.1 Add an explicit-root `git/` adapter with typed unavailable/non-worktree/clean/add-failed/commit-failed/committed results and no ambient-cwd behavior
- [x] 7.2 Add best-effort orchestrator checkpoints at the runtime root before 5.1, 7.1, and 8.4 and after successful or cleanly declined 8.4, preserving `git add -A` scope and boundary labels
- [x] 7.3 Ensure clean, missing-git, non-worktree, add-failure, and commit-failure results render notices and never alter the phase outcome
- [x] 7.4 Add adapter/orchestrator tests for explicit root, dirty commit, clean notice, non-repo skip, command failures, and the two 8.4 boundaries

## 8. CLI composition and diagnostics

- [x] 8.1 Add `run` argument parsing for only `--path`, `--resume`, and help, with actionable diagnostics for unknown options, missing values, invalid paths, and unsupported aliases
- [x] 8.2 Compose the TTY interaction, config/agent runner, workspace/sequencing/executor, state, scaffold, and git adapters in `cli/run.ts`; load `.setup/models.md` and resolve all model phases required by the planned catalog execution before any feature action; expose required package barrels without runtime dependencies
- [x] 8.3 Map `stoppedByOperator`/`finished` to exit 0 and failed outcomes to exit 1; render core diagnostics and exact restart guidance `overmind run --path <project> --resume <step>`
- [x] 8.4 Add CLI tests for successful completion, clean stop, project preflight refusal, malformed/missing runner config and unregistered command startup refusal with no scaffold/agent/checkpoint side effects, failed step diagnostics/restart command, resume parsing, and standalone scaffold dispatch

## 9. Full parity suite

- [x] 9.1 Port all feature-selection, scanner/progress, resume, optional-step, required-stop, phase-7, checkpoint, and restart-guidance scenario families from `project_add_feature_e2e_tests.sh` to TypeScript tests over stub ports
- [x] 9.2 Confirm Slice 2 tests continue to own model config, prompt parity, agent launch, sync/context order, read-only guards, required outputs, and deterministic checks; add only missing integration assertions instead of duplicating those units
- [x] 9.3 Reconcile the completed TypeScript tests against the behavior families from tasks 1.1-1.3 and resolve every gap before shell deletion; the one-pass sweep is complete and the behavior-parity gate is closed (`design_docs/e2e_orchestrator_migration/05_parity_reconciliation.md ## Sweep result`), with only the formal `02` write-up left for the distinct Slice 5 CRP

## 10. Clean cutover, staging, and docs

- [x] 10.1 Remove `project_add_feature_e2e.sh` and `feature_br_scaffold.sh` staging from `overmind/scripts/project_mgmt/project_setup_first_init_machine.sh`; update generated QUICKRUN content to `overmind run`, `overmind scaffold feature`, `.overmind_feature_state.json`, and the separated legacy project-level flow
- [x] 10.2 Update `tests/ai_scripts/project_setup_asdlc_tests.sh` and `tests/ai_scripts/project_setup_update_project_tests.sh` fixtures/assertions so setup no longer copies or expects the deleted scripts and validates the bundled TypeScript entrypoints/guidance
- [x] 10.3 Update `overmind/README.md`, `QUICKRUN.md` if versioned, `overmind/init_progress_definition_data_model.md`, `overmind/init_progress_definition_sequence_diagram.md`, and any other active audit hit to the new entrypoints and state cache; update `AGENTS.md` only if its path/command conventions are affected
- [x] 10.4 Delete `overmind/scripts/project_mgmt/project_add_feature_e2e.sh`, `overmind/scripts/feature_br_scaffold.sh`, `tests/ai_scripts/project_add_feature_e2e_tests.sh`, and `tests/ai_scripts/init_br_scaffold_tests.sh` only after tasks 9.1-9.3 prove parity
- [x] 10.5 Audit the repository for stale active references to the deleted scripts/state file and confirm deployed runtime directories were not patched directly

## 11. Verification

- [x] 11.1 Run focused TypeScript tests for feature state, scaffold, pending-work detection, feature orchestration, checkpoints, and CLI behavior
- [x] 11.2 Run surviving setup shell suites, including `bash tests/ai_scripts/project_setup_asdlc_tests.sh` and `bash tests/ai_scripts/project_setup_update_project_tests.sh`, after staging assertions change
- [x] 11.3 Run root `npm run verify` and resolve typecheck, lint, format-check, build, TypeScript-test, and surviving-shell-test failures
- [x] 11.4 Confirm `packages/asdlc-coordinator` runtime `dependencies` remains empty and `overmind.js` still bundles as a standalone runtime artifact
- [x] 11.5 Confirm every Slice 3 responsibility-map row and distinct behavior family has a named TypeScript owner/test or a recorded retirement/divergence — the one-pass checklist sweep of the 91+5 deleted shell functions is complete and the behavior-parity gate is closed (`design_docs/e2e_orchestrator_migration/05_parity_reconciliation.md ## Sweep result`); only the formal `02` write-up and extension-doc revision remain as a distinct Slice 5 CRP
