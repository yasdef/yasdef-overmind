## Context

Slices 1 and 2 established `workspace/`, `sequencing/`, the declarative step catalog, `InteractionPort`, and the generic `executeStep` runner. The live operator path still duplicates those contracts in `overmind/scripts/project_mgmt/project_add_feature_e2e.sh`; step 3 additionally shells out to `overmind/scripts/feature_br_scaffold.sh` and scrapes stdout for the feature path. This slice replaces that imperative shell with a TypeScript feature-flow use case while preserving the observable decisions and guidance covered by `tests/ai_scripts/project_add_feature_e2e_tests.sh`.

The cutover must leave the workflow runnable between Slices 3 and 4. Project attach/reconciliation execution remains in legacy staged scripts until Slice 4, while `overmind run` only detects that work and refuses with guidance. The target reconciliation state is `class_repo_paths.<class>.contract_reconciled`; however, Slice 4 owns writing that field and the surviving legacy flow writes `.contract_reconciled_<class>` markers. Slice 3 therefore needs a short-lived compatibility read so the guidance it prints can actually unblock a run.

## Goals / Non-Goals

**Goals:**

- Make `overmind run [--path <project>] [--resume <step>]` the complete feature-workflow entrypoint.
- Preserve project/feature selection, resume constraints, phase confirmations, optional-step behavior, phase-7 class decisions, failure guidance, and checkpoint timing.
- Compose `ProgressReport`, `STEP_CATALOG`, `executeStep`, and `InteractionPort`; keep action semantics out of the orchestrator.
- Add a deterministic scaffold primitive with a typed created-feature result and a standalone CLI verb.
- Prove parity from the shell suites before deleting the scripts, tests, staging entries, and old docs.

**Non-Goals:**

- Executing deferred repo attach, reconciliation, reconciliation commits, or introducing the reconciliation skill; those belong to Slice 4.
- Changing skill bodies, gates, workflow artifact formats, runner configuration, or the model-session contracts from Slice 2.
- Adding auto-advance profiles, new scaffold input flags, multi-runner behavior, or runtime dependencies.
- Editing deployed `.commands/`, `.rules/`, `.templates/`, `.golden_examples/`, `.helper/`, or `.setup/` runtime workspaces directly.

## Decisions

### D1 - One feature-flow use case owns selection and phase progression

`orchestrator/run-feature-flow.ts` receives resolved ports/dependencies and returns a typed `PhaseOutcome`: `completed`, `skippedOptional`, `stoppedByOperator`, `finished`, or `failed { resumeStep, diagnostics }`. The CLI owns rendering and process exit codes. The use case asks `sequencing/` for progress and catalog resolution and calls `executeStep`; it never branches on model skill names, invokes `overmind gate`, or reimplements session guards.

This keeps the functional core reusable by the extension. Retaining numeric shell return codes or a CLI-centric loop was rejected because either would leak adapter mechanics into the core.

### D2 - Project work is detected before feature selection, not executed

The run evaluates project-scope progress before reading or writing feature state. Pending initialization steps produce step-specific guidance; deferred `class_repo_paths.<class>.state` values and unreconciled ready classes produce guidance naming the surviving legacy staged attach/reconciliation scripts. No feature menu, scaffold write, model session, or checkpoint runs after refusal.

Until Slice 4, a ready class is considered reconciled when either the target `contract_reconciled: true` field exists or its legacy `.contract_reconciled_<class>` marker exists. This is a read-only transition bridge required to keep the operator path runnable after following Slice 3 guidance. Slice 4 removes marker recognition when it introduces the field writer and `overmind project reconcile`; no marker is created by new TypeScript code.

### D3 - Feature selection consumes typed progress reports

Feature discovery evaluates each child feature and retains unfinished features with their typed next-step data. It does not parse `overmind status` output. One unfinished feature is still presented through the same mode decision as multiple unfinished features; project auto-selection preserves the existing zero/one/many behavior through `InteractionPort`.

Resume resolution uses the catalog's ids and aliases. The constraint matrix remains: a non-step-3 resume cannot start a new feature, step 3 cannot continue one, a non-step-3 resume without unfinished or cached context fails, and step 8.4 may reopen a valid completed cached feature.

### D4 - State cache is JSON with a single canonical relative path

`state/feature-state.ts` reads and writes `<project>/.overmind_feature_state.json` containing one workspace-relative `featurePath`. Reads validate that the resolved directory remains inside the workspace and under the selected project. Invalid JSON, escape attempts, or missing directories produce stale-state diagnostics/notices and are ignored. Writes occur only after successful selection or scaffold. The old `.project_add_feature_e2e_state.env` is not read or migrated, so the next run asks once and establishes the JSON state.

### D5 - Scaffold is a capture primitive and catalog action

`capture/scaffold-feature.ts` resolves a project through `workspace/`, reads project metadata through `parse/`, obtains non-empty feature id/title from `InteractionPort`, normalizes the title to the existing lowercase underscore form, appends an injected Unix timestamp, and renders `.templates/feature_br_summary_TEMPLATE.md` into `<feature>/feature_br_summary.md`. It returns `{ featurePath, outputPath, diagnostics }`; the orchestrator persists `featurePath` directly.

The deterministic action registry maps `scaffold-feature` to this function, so catalog step 3 runs through `executeStep` like every other action. `overmind scaffold feature --path <project>` is a thin standalone adapter over the same primitive. Stdout remains operator-readable but is not an API. What is rejected is a **bespoke launcher** and stdout scraping: the primitive is dispatched through the deterministic action registry and returns a typed result.

Step 3 is nonetheless the **project→feature transition**, and this is a genuine scope boundary, not an incidental step-id branch: unlike steps 4.1–8.4, which operate on an existing `featurePath`, step 3 consumes a *project* path and *produces* the feature. The orchestrator therefore invokes it through a thin **project-scoped** scaffold entry that dispatches the registered primitive and adopts its typed `featurePath`, ahead of the **feature-scoped** phase loop. The "no orchestrator step-id branching" rule governs that feature phase loop (4.1–8.4) — which the executor and orchestrator honor — while step 3's scoped entry names the project→feature boundary rather than forcing a project-scoped operation into the feature loop.

### D6 - Optional and phase-7 decisions are orchestrator policy

For normal required/optional steps, the orchestrator confirms through `InteractionPort` before execution. Declining a required step returns `stoppedByOperator`; declining an optional step returns `skippedOptional` and continues when a later required step exists, otherwise returns `finished`. Input closure is a clean stop.

Step 7 uses the per-class view from `ProgressReport`: the operator can analyze one pending class, refresh, or move forward. Each selected class is one generic executor call with a single-class binding. Moving forward reports remaining classes. The orchestrator branches on catalog metadata (`perClass`) and typed progress, not on skill implementation.

### D7 - Checkpoints use an explicit-root, best-effort git port

`git/` exposes repo-scoped operations whose every call receives the runtime root. `not-a-worktree`, unavailable git, add failure, commit failure, and a clean tree are typed results rendered as notices; none blocks the run. The orchestrator requests checkpoints before 5.1, 7.1, and 8.4 and after 8.4 when that step completes or is cleanly declined. Commit commands run without hook-dependent behavior, preserving the migration's local/hook-free contract.

### D8 - CLI adapter maps typed outcomes and owns restart text

`cli/run.ts` parses only `--path`, `--resume`, and help for `run`; unknown/missing option values are errors. It creates the TTY, runner, filesystem, clock, and git adapters, loads `.setup/models.md`, and resolves the model phases required by the planned catalog execution before any feature action. Runner-config diagnostics therefore fail at startup without scaffold, agent, or checkpoint side effects. The adapter renders diagnostics, maps stopped/finished outcomes to exit 0 and failures to exit 1, and includes the exact replacement command `overmind run --path <project> --resume <step>` for execution failures.

### D9 - Parity is scenario-inventory driven, followed by clean deletion

Before implementation, the existing e2e and scaffold test functions are classified by responsibility-map row and assigned to a TypeScript test. Slice 2 runner tests remain the proof for prompt/config/guard internals; Slice 3 tests focus on their orchestration and preserve all observable shell families, including guard/failure propagation through the executor. Preflight execution tests are retargeted to refusal/guidance because execution moved to Slice 4.

After the inventory has no unowned row, delete `project_add_feature_e2e.sh`, `feature_br_scaffold.sh`, `project_add_feature_e2e_tests.sh`, and `init_br_scaffold_tests.sh`; remove their source staging entries and update `QUICKRUN.md` and `overmind/README.md`. Direct runtime workspace files are untouched.

Parity is measured at the level of **distinct behavior families**, not a 1:1 port of the deleted shell test functions (which accreted around a mock-scanner harness and are heavily redundant). The one-pass checklist sweep of the 91+5 deleted functions was **completed** in this change: every distinct behavior resolves to a retained Slice 1/2 test, a new Slice 3 test, a Slice 4 project-flow deferral (detection only in Slice 3), or a recorded retirement/divergence, and the gaps the sweep surfaced were closed with TypeScript tests. The behavior-parity gate is therefore **closed** and the shell deletion is justified by an executed sweep — see `design_docs/e2e_orchestrator_migration/05_parity_reconciliation.md ## Sweep result`. Only the formal `02_responsibility_translation_map.md ## Full parity gate` write-up and the extension-doc revision remain, tracked as a distinct Slice 5 CRP.

## Risks / Trade-offs

- **Parity surface is larger than the core loop** -> Build the scenario/translation-row inventory first and block deletion on every row being owned, retired by an architecture decision, or covered by Slice 1/2 tests.
- **Temporary marker recognition could become permanent** -> Isolate it behind the project-pending detector, add a removal note/task for Slice 4, and never write markers from TypeScript.
- **Resume selection and scanner progress can disagree** -> Treat an explicit valid resume as the start override after project/feature validation; otherwise derive the start step only from typed `nextStep()`.
- **Checkpoint commands may affect unrelated runtime-root changes** -> Preserve the shell's `git add -A` semantics exactly and keep checkpoints best-effort; changing commit scope is outside this parity slice.
- **Filesystem time makes scaffold tests flaky** -> Inject clock and filesystem/interaction dependencies; test deterministic names and collisions without sleeping.
- **Deleting shell tests could hide runner regressions** -> Retain Slice 2 unit tests and add TypeScript scenario tests before deletion; run the root aggregate after staging/doc cleanup.

## Migration Plan

1. Build the row-by-row responsibility and shell-test scenario inventory for map rows 1-17, 21-23; identify Slice 1/2 coverage and Slice 3 owners before code changes.
2. Add the feature state, scaffold primitive/action registration, and explicit-root git adapter with focused tests.
3. Add project-pending detection and the feature-flow use case over injected sequencing/executor/interaction dependencies.
4. Add `run` and `scaffold feature` CLI adapters and port the full e2e/scaffold scenario inventory to TypeScript.
5. Switch staging and operator docs, delete the replaced scripts/tests, and run `npm run verify` with runtime dependencies still empty.

Rollback is a single change revert: restore the shell scripts/tests/staging/docs and remove the new verbs/modules. The JSON cache is safe to leave behind because the restored shell ignores it, and the new flow never mutates project reconciliation state.

## Open Questions

None blocking. Exact internal dependency-object names and test-file grouping are implementation details; the typed boundaries and behavior above are fixed.
