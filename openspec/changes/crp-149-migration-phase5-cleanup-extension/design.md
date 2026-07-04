## Context

`design_docs/e2e_orchestrator_migration/04_migration_plan.md ## Slice 5 — Cleanup + extension enablement` is the last slice: end-state hygiene plus the first extension consumption proof. It is deliberately after Slice 3 and Slice 4. Two of its four deliverables are safety-critical decisions already discharged: `05_parity_reconciliation.md ## Sweep result — behavior-parity gate CLOSED (Slice 3)` executed the one-pass behavior sweep before the `crp-147` shell deletions, and Slice 4 landed the rows 18–20 execution tests. `05_parity_reconciliation.md ## Remaining Slice 5 CRP scope` therefore scopes this change as **documentation/enablement, not safety-critical**: fold the closed result into the formal `02` gate, retire the rows 18–20 detection-only caveat, revise the extension design docs, plus the mechanical orphan/doc cleanup and the minimal dashboard.

The reusable core already exists: `packages/asdlc-coordinator/src/workspace/` resolves runtime root, discovers/validates projects, and finds feature folders; `src/sequencing/` computes `ProgressReport` (per-step state for every declared step, missing artifacts) as established in Slice 1, whose acceptance criterion already proved the extension `FeatureSummary` fields derivable by pure projection. `packages/vscode-extension` currently only re-exports `getBundledOvermindPath`; this slice makes it consume the read model. The extension design docs (`design_docs/overmind_vscode_extention/`, dated 2026-06-24) predate the migration and still describe a `.commands/*.sh` launcher.

Constraints: the zero-runtime-dependency rule for `asdlc-coordinator`; the extension's only dependency stays `asdlc-coordinator`; no new CLI flags (this slice adds none); no edits to deployed runtime folders except through the normal staging source; `npm run verify` plus the surviving `tests/ai_scripts/*.sh` suites as the completion gate; and the working-rule to revise docs in place rather than fork variants.

## Goals / Non-Goals

**Goals:**

- Add a minimal read-only VS Code dashboard in `packages/vscode-extension` — activation plus a contributed read-only view — that imports `workspace/` + `sequencing/`, obtains the `FeatureSummary` by reusing the existing `sequencing/toFeatureSummary()` export (no second projection), renders it, and has tests (reused projection and view/render path) that make reuse claim 5 a passing check rather than prose.
- Remove now-orphaned `common_libs` helpers, their staging entries, and dedicated tests behind a no-active-reference audit; keep every still-used helper.
- Sweep `README.md`, `QUICKRUN.md`, and repository command references for dead references to deleted scripts and superseded workflows.
- Revise the three extension design docs to the shipped `overmind` verbs per the supersession mapping and remove the banners.
- Fold the executed sweep into `02_responsibility_translation_map.md ## Full parity gate`, mark it closed, and retire the rows 18–20 detection-only caveat; audit every row owned-or-retired.

**Non-Goals:**

- Interactive extension surfaces — webview forms, the Create-Feature capture form, terminal-hosted `overmind run` wiring, and any mutating command — and a full extension-host end-to-end test harness. Slice 5 ships a *minimal read-only* dashboard: activation plus a contributed read-only view that renders the projection, with the view/render path covered by in-process tests, not a launched extension host.
- Any change to `ProgressReport`, `sequencing/`, or `workspace/` semantics; the dashboard consumes them unchanged. New public exports, if needed for the projection, add no orchestrator coupling.
- Re-running or re-litigating the behavior-parity sweep — it is closed at the behavior level in Slice 3; this slice only records that fact formally.
- Any new deletion of feature/project/scanner/attach/reconciliation scripts (those are Slices 1–4); Slice 5 removes only leftover orphans surfaced by the audit.
- New CLI verbs or flags, new runtime dependencies, remote CI, or git hooks.

## Decisions

### D1 — The dashboard is a contributed read-only view over a pure projection, not a new scanner

Add a read model in `packages/vscode-extension/src` that calls the imported `workspace/` resolution and `sequencing/` computation and obtains the `FeatureSummary` (`readiness`, `completedSteps`, `totalSteps`, `missingArtifacts`, per `design_docs/overmind_vscode_extention/technical_requirements.md ## 7. Dashboard Data Contract`) by **reusing the existing `sequencing/toFeatureSummary(report)` export** — the projection Slice 1 already implemented and published in `packages/asdlc-coordinator/src/sequencing/projections.ts`. The extension SHALL NOT re-map `ProgressReport` into its own `FeatureSummary`: a second projection would drift from the canonical one and quietly weaken the very reuse claim this slice exists to prove. The read model is glue (resolve → `ProgressReport` → `toFeatureSummary`) plus a view. On top of it, the extension activates and contributes one minimal read-only view that renders that summary; the view is a thin presenter and contributes no mutating command, form, or terminal.

The render/provider path is unit-tested in-process against `ProgressReport`-backed inputs — a launched VS Code extension host is deliberately excluded so `npm run verify` stays self-contained and dependency-light. Because the extension host is not launched, manifest correctness is guarded **statically**: `package.json` is made a valid VS Code extension manifest (`publisher`, `engines.vscode`, `main` → an `activate`-exporting module, `contributes` for the read-only view, `activationEvents`) and a static test asserts those fields and the exported `activate` so verify fails on a malformed or non-activating manifest. This honors the migration plan's "minimal read-only dashboard" as a real (renderable) surface while keeping the slice low-risk.

Alternative rejected: shipping only a projection function with no contributed view would under-deliver the plan's "dashboard" deliverable. Alternative rejected: re-deriving progress in the extension (a second scanner) would reintroduce exactly the joined/omitted-step drift Slice 1 removed and would break reuse claim 5. Consuming `ProgressReport` unchanged is what makes the "extension for free" claim true.

### D2 — Zero orchestrator/CLI coupling requires dedicated subpath exports

Today `asdlc-coordinator` publishes only the `.` export, and its root barrel `src/index.ts` re-exports `cli/run.js` and `orchestrator/index.js` alongside `workspace/` and `sequencing/`. So importing anything from the package root pulls the whole barrel — zero-coupling consumption is *not* achievable through the current entrypoint, no matter how careful the extension's own import list is. This slice therefore adds dedicated subpath exports to `asdlc-coordinator/package.json` — at minimum `asdlc-coordinator/workspace` and `asdlc-coordinator/sequencing` — pointing at modules whose transitive imports exclude `cli/` and `orchestrator/`. The root `.` export stays as-is for existing consumers.

The extension imports **only** those subpaths (`toFeatureSummary` is exported from `sequencing`), never the root barrel, never `orchestrator/`/`cli/`, and never spawns the `overmind` CLI. `asdlc-coordinator` remains its sole runtime dependency (matching definition-of-done item 5). A test inspects the extension's import specifiers to prove it references only the two subpaths. Any additional resolution/read helper the extension needs is exposed through the `workspace`/`sequencing` subpaths, not by reaching into internal modules or adding an orchestrator seam.

Alternative rejected: keeping only the `.` barrel and trusting the extension not to touch cli/orchestrator symbols — the barrel still evaluates those modules at import time, so the coupling is real regardless of which symbols are named. Alternative rejected: shelling out to `overmind status` and parsing stdout — it would couple the extension to the CLI text contract, reintroduce staleness, and violate the in-process reuse the migration is proving.

### D3 — Diagnostics render, they do not throw

The read model surfaces `Diagnostic` values already carried by `ProgressReport` (the errors-as-values convention from Slice 1) into a degraded-but-renderable view. Data-level problems (malformed/missing definition inputs) never throw at the dashboard boundary; they appear as diagnostics beside a still-usable `FeatureSummary`. This matches definition-of-done item 6: the CLI and the extension render the same diagnostic values.

### D4 — Orphan removal is audit-gated by functional consumers; tombstones stay

The Slice 5 functional-consumer audit resolved the command libraries as follows:

| Command library | Functional production consumer / disposition |
|---|---|
| `class_repo_paths.sh` | Retained: `init_common_contract_definition.sh` loads it. |
| `check_implementation_plan_readiness.sh` | Retained: `feature_assing_workers.sh` executes it. |
| `project_setup_common.sh` | Retained: `project_setup_add_new_project.sh` and `project_setup_update_project.sh` source it. |
| `list_committed_sibling_features.sh` | Removed: no active runtime, setup, or update script invokes it. |
| `sync_repo_to_default_branch.sh` | Removed: no active runtime, setup, or update script invokes it. |

`common_libs` helpers are removed only when an explicit audit shows no **functional production consumer** — an active runtime/setup/update script that sources, executes, or otherwise invokes the helper. Invocation counts however it happens: `feature_assing_workers.sh`, for example, runs `check_implementation_plan_readiness.sh` as an executable child process (`[[ -x ... ]]` then invoke), never sourcing it, so a "sources it" test alone would wrongly mark that live helper as orphaned. Liveness deliberately excludes the candidate's own `STAGED_COMMAND_LIB_FILES` staging entry and its own dedicated test suite: those are the plumbing deleted *with* the helper, so counting them would make the condition self-blocking (every candidate is trivially "referenced" by its own staging line and test). `project_setup_first_init_machine.sh` currently stages five `STAGED_COMMAND_LIB_FILES` (`class_repo_paths.sh`, `check_implementation_plan_readiness.sh`, `list_committed_sibling_features.sh`, `project_setup_common.sh`, `sync_repo_to_default_branch.sh`); each is kept or removed strictly by whether a functional consumer remains, with the consumer recorded for retained helpers. The default is retention: when in doubt, a helper stays.

Deleting a helper is not enough to remove it from workspaces already deployed. `stage_command_libs()` only *copies* the configured `STAGED_COMMAND_LIB_FILES` into the workspace; it has no removal loop, unlike `stage_commands()` which sweeps `OBSOLETE_STAGED_COMMAND_FILES`. So an orphan deleted from source and from the staging list would linger forever in every existing workspace's staged libs. This slice therefore adds an update-mode cleanup for removed command libs via an **explicit `OBSOLETE_STAGED_COMMAND_LIB_FILES` tombstone list** swept by `stage_command_libs()`/`stage_commands()` — deleting only the named stale libs — covering every helper removed here, with a direct-upgrade regression test (stage the old helper into a fixture workspace, run update mode, assert it is gone). A blanket managed-manifest sweep (delete anything not in the managed set) is deliberately **rejected** here: the staged `common_libs` directory has no unmanaged-file removal today (unlike support-asset staging at the two "remove unmanaged staged support asset" points) and is not declared package-owned, so a blanket sweep would newly delete operator-placed files. A sweep is permissible only if this change first establishes an explicit ownership contract for that directory; absent that, tombstones are required. These tombstone entries follow the same retain-until-proven rule as the command tombstones.

The `OBSOLETE_STAGED_COMMAND_FILES` tombstones are a separate mechanism and are **retained**. In update mode they delete already-staged legacy scripts (e.g. `project_add_feature_e2e.sh`, `project_contract_reconciliation.sh`) from a deployed workspace. Pruning a tombstone would let a workspace that upgrades directly from an older release keep executable legacy scripts staged, because nothing proves every deployed workspace already ran that one-time cleanup. They may be pruned only once a versioned workspace-migration mechanism proves the cleanup ran everywhere — out of scope here.

Alternative rejected: bulk-deleting `common_libs` on the assumption that Slices 1–4 orphaned everything — several helpers (readiness, sibling-feature listing, repo-path coherence) back non-e2e commands and have dedicated `tests/ai_scripts/*` suites named in `CLAUDE.md`, so removal must be per-file and evidence-based. Alternative rejected: pruning tombstones as "dead bookkeeping" — they are load-bearing for direct upgrades, not dead.

### D5 — Docs are revised in place per the supersession mapping

The versioned operator docs — root `README.md` (there is no `overmind/README.md`; the migration plan's reference resolves to root `README.md`, which still carries stale legacy-reconciliation language now that `overmind project reconcile` shipped in Slice 4), `QUICKRUN.md`, and repository command references — are edited in place to drop dead script references and describe only shipped `overmind` verbs and surviving scripts. The three extension docs are revised using the exact replacement table in `03_target_architecture.md ### Supersession of the extension design docs`: Run Scanner and scanner freshness/stale-state caveats → `overmind status` / in-process `sequencing/`, with refresh implemented as fresh recomputation and no terminal scanner action or persisted stale scanner state; Create Feature → `overmind scaffold feature`; Continue E2E → terminal-hosted `overmind run`; Requirement 7 script allow-list / "script missing or not executable" → an `overmind` CLI verb allow-list with a `.overmind/overmind.js` / bundled-core availability check; Requirement 9 "mutation paths call ASDLC scripts" → mutation paths call coordinator primitives or CLI verbs. The old plan's `Create Project` terminal action has no shipped coordinator primitive or `overmind` verb, so the revised docs remove it from the executable action plan and mark it postponed until such a shared surface exists; this slice neither invents a verb nor preserves `.commands/project_setup_add_new_project.sh` as an extension launcher. The supersession banners are then removed. Per the working rules, docs are updated, not duplicated. If any canonical test command/path/convention shifts, `AGENTS.md` is updated in the same change.

### D6 — Parity closure is a documentation fold, not a re-audit

The behavior-parity gate is already closed in `05_parity_reconciliation.md ## Sweep result — behavior-parity gate CLOSED (Slice 3)`. This slice edits `02_responsibility_translation_map.md ## Full parity gate` to record it closed with the Slice 3 sweep as evidence, and updates rows 18–20 to point at their Slice 4 execution tests instead of the "detection only" caveat. A row-by-row audit confirms every row is owned-or-retired (the "any missing row blocks the migration" discipline). No shell suites are re-run to re-establish parity; they were deleted under the executed sweep, and re-deriving parity is explicitly out of scope.

### D7 — Slice 5 adds no runtime code paths to the coordinator flows

Beyond any public-export surfacing needed for D2, this slice introduces no new orchestrator, runner, CLI, or capture behavior. The verify gate for this slice is: extension read-model tests pass, the coordinator's runtime `dependencies` list stays empty, the surviving shell suites and `npm run verify` are green, and the design-doc/parity edits are internally consistent. This keeps Slice 5 a low-risk closing slice, as its plan intends.

## Risks / Trade-offs

- **Over-aggressive orphan removal deletes a still-used helper** → gate every deletion on the no-active-reference audit (D4), default to retention, and re-run the named `tests/ai_scripts/*` suites from `CLAUDE.md` after removal.
- **A doc sweep misses a dead reference** → grep the deleted-script names across `README.md`, `QUICKRUN.md`, repository command references, and the extension docs as an explicit audit step, and assert no active doc names a deleted flow.
- **The extension re-implements the projection and drifts from the canonical one** → reuse `sequencing/toFeatureSummary()` (D1), forbid a second `ProgressReport → FeatureSummary` mapping, and add a review/test check that no duplicate derivation exists.
- **The extension reaches past the intended seams and leaks orchestrator coupling** → import only `workspace/`/`sequencing/` public exports and add a test/import check that the extension references no `orchestrator/` or `cli/` module and keeps `asdlc-coordinator` as its sole runtime dependency (D2).
- **A deleted helper is stranded in already-deployed workspaces** → add an explicit `OBSOLETE_STAGED_COMMAND_LIB_FILES` tombstone sweep covering every removed helper, with a direct-upgrade regression test, since `stage_command_libs()` only copies (D4).
- **A blanket cleanup sweep deletes operator files from staged `common_libs`** → remove only tombstoned filenames; the directory preserves unmanaged content and is not package-owned, so a managed-manifest sweep is used only behind an explicit ownership contract (D4). A regression test asserts an unmanaged operator file survives.
- **The extension ships an invalid VS Code manifest** → make `package.json` a real extension manifest (`publisher`, `engines.vscode`, `contributes`, `activationEvents`, `main` → `activate`) and add a static manifest/activation validation test that fails `npm run verify` on any missing field.
- **The dashboard is built from the superseded launcher plan** → sequence the extension-doc revision before dashboard implementation (Migration Plan step 1) and make that ordering a spec scenario.
- **The parity fold contradicts `05`** → mirror `05_parity_reconciliation.md ## Remaining Slice 5 CRP scope` verbatim in intent when writing the `02` closure, and cross-check rows 18–20 against the Slice 4 test names.

## Migration Plan

1. **First**, revise the three extension design docs per the supersession mapping and remove the banners — this must precede dashboard implementation so the extension is built against the corrected plan (`04_migration_plan.md`: "Extension implementation must not restart from the old plan before this revision lands").
2. Add the mandatory `asdlc-coordinator/workspace` and `asdlc-coordinator/sequencing` package subpath exports and isolation tests, then add the extension dashboard consuming only those subpaths and **reusing the existing `sequencing/toFeatureSummary()` export** for the projection, plus a contributed read-only view, with tests for the reused projection, the total-over-declared-steps property, the diagnostic-carrying degraded path, and the view/render path.
3. Run the functional-consumer audit over `common_libs` helpers and staging entries; remove orphans and their dedicated tests, keep still-consumed helpers with recorded consumers, add the update-mode command-lib cleanup as an explicit `OBSOLETE_STAGED_COMMAND_LIB_FILES` tombstone sweep (no blanket managed-manifest deletion, to preserve unmanaged operator files) with a direct-upgrade regression test, and **retain the `OBSOLETE_STAGED_COMMAND_FILES` tombstones**.
4. Sweep `README.md`, `QUICKRUN.md`, and repository command references for dead references (active operator-facing guidance only; tombstones/cleanup tests/historical records exempt); update `AGENTS.md` if a canonical command/path/convention shifts.
5. Fold the executed sweep into `02_responsibility_translation_map.md ## Full parity gate`, mark it closed, retire the rows 18–20 detection-only caveat, and audit every row owned-or-retired.
6. Run the surviving `tests/ai_scripts/*.sh` suites plus `npm run verify`, confirm the coordinator's runtime `dependencies` stays empty, run `openspec validate crp-149-migration-phase5-cleanup-extension --strict`, and run `git diff --check`.

Rollback before release is a plain code/doc revert; this slice deletes no behavior and mutates no operator project state, so there is nothing to migrate back.

## Open Questions

- None. The dashboard data contract, the supersession replacement table, the parity closure text, and the orphan/doc cleanup are all fixed by `04_migration_plan.md ## Slice 5 — Cleanup + extension enablement`, `05_parity_reconciliation.md ## Remaining Slice 5 CRP scope`, and `03_target_architecture.md ### Supersession of the extension design docs`. The exact orphan set is resolved by the audit inside the slice, not by a design decision.
