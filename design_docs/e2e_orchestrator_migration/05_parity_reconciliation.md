# E2E Orchestrator Migration — 5. Parity Reconciliation

Slice 3 (`crp-147-e2e-migration-phase3-orchestrator-loop`) replaced the shell feature workflow and, in
the same change, deleted `tests/ai_scripts/project_add_feature_e2e_tests.sh` (91 `test_*` functions) and
`tests/ai_scripts/init_br_scaffold_tests.sh` (5 `test_*` functions). This document records the
reconciliation *principle*, the deliberate divergences from the shell, the coverage snapshot, and the
**completed sweep result** that closes the behavior-parity gate for the deletion. The remaining formal
write-up and extension-doc work is a distinct Slice 5 CRP (see the end of this document).

It resolves the open item in `04_migration_plan.md ## Slice 5 — Cleanup + extension enablement`
("Audit against `02_responsibility_translation_map.md ## Full parity gate`: every row resolved") at the
behavior level; the formal `02` write-up is closed in Slice 5.

## Principle: behavioral parity, not test parity

The migration goal is that every observable operator decision and guidance survives — **behavioral**
parity — not a 1:1 re-implementation of the deleted shell tests. Those 91+5 functions accreted
step-by-step around a mock-scanner / mock-codex harness and carry heavy redundancy (for example, a
`test_scanner_step_<id>_*` per catalog step exercising the same run loop with a different mocked
`next step:` line). Porting them one-for-one would re-import exactly the noise this migration exists to
shed, and it contradicts the architecture's own stance:

- `02_responsibility_translation_map.md`: *"Nothing ports 1:1 — bash text-parsing seams … are replaced by
  typed in-process calls."*
- `03_target_architecture.md ## Decisions` (2): the scanner is a *"new implementation, not a
  behavior-parity port … old shell scanner tests inform the output format only."*

Therefore coverage is anchored to the **current architecture** — the `02` responsibility-map rows and the
four Slice 3 capability specs (`feature-orchestrator`, `feature-scaffold`, `feature-state-cache`,
`checkpoint-commits`) — and the deleted suites are consulted **once, as a checklist** to catch any dropped
observable, then discarded.

## Why an explicit reconciliation is still required

Deleting the suites removed the only executable proof of parity. Without a reconciliation, a genuine
behavior can slip silently — as one did: the Slice 3 review caught that a continued feature whose next
step is 3 was skipped to 4.1 and failed (see the step-3 divergence below). The reconciliation exists to
make such gaps visible, and to record where Slice 3 **intentionally** departs from the shell.

## Deliberate divergences from the shell (recorded)

These are intentional and must be treated as retirements/divergences (not regressions) by the Slice 5
audit and by any future reader comparing against `git` history of the deleted suites.

| Shell behavior | Slice 3 behavior | Rationale |
|---|---|---|
| Numeric rc protocol `0/10/20/30/40` | `PhaseOutcome` union (`completed \| skippedOptional \| stoppedByOperator \| finished \| failed`) | `03 ## Orchestrator flow-control` |
| stdout scraping of `Created feature folder:` / `Updated …` | typed scaffold result carries `featurePath`/`outputPath` | `03` decision 6; row 16 |
| `map_scanner_step_to_phase` remapping (legacy `4`→`5`, name-substring fallback) | catalog ids equal definition ids; no remap layer | `03` decision 2 |
| Continued feature whose next step is `3` re-runs `feature_br_scaffold.sh` (creates a new timestamped folder, abandoning the selection) | refuse with actionable guidance ("start a new feature to scaffold it") | shell wart; Slice 3 review finding 1 (operator-confirmed) |
| Step 4.1 runs with **no** y/n confirmation | every step (incl. 4.1 and the step-7 loop entry) confirms through `InteractionPort` | Slice 3 review (operator-confirmed); `03` decision 1 keeps per-phase y/n |
| Repo attach + contract reconciliation executed inline during the feature run | feature flow **detects** pending attach/reconciliation and refuses with guidance; execution is Slice 4 | `03` decision 3; rows 18–20 |
| Attach detection flags only a class with an explicit `state:` line ≠ ready (a state-less `class_repo_paths` entry is invisible) | any configured class whose state is not `ready` — including a missing/blank state — refuses with attach guidance | spec `feature-orchestrator` "any configured class repo state is not ready"; Slice 3 review finding 4 |
| `.project_add_feature_e2e_state.env` (env file) | `<project>/.overmind_feature_state.json` (JSON), legacy file ignored | `03` decision 4; row 15 |
| `.contract_reconciled_<class>` marker files as reconciliation status | `class_repo_paths.<class>.contract_reconciled` field, with a **read-only** transitional marker bridge (removed in Slice 4) | `03` decision 9; row 19 |
| Per-phase guards checked `.overmind/overmind.js` existence before launch (`fails_before_launch_when_overmind_cli_missing`) | no CLI-existence check — the bundled CLI is the running process | row 22; the launcher subprocess dissolved |
| Staged-location guard (`requires_staged_location`: must run from `<asdlc>/.commands/`) | runtime-root detection via `asdlc_metadata.yaml` from cwd/`--path` | row 1; `workspace/` |
| Each run printed the scanner checklist via `node .overmind/overmind.js status <feature>` (`selected_feature_scanner_checklist_is_stdout_visible`) | progress is computed in-process from `sequencing/`; the rendered checklist is the separate `overmind status` command | `02` "Deleted with no successor: Scanner stdout contract"; row 4 |

## Slice 3 coverage snapshot (responsibility row → owning tests)

"Slice 1/2" tests already existed and are retained as the proof for their mechanics; "Slice 3" tests were
added by `crp-147`.

| `02` row | Behavior | Owning TS module | Tests |
|---|---|---|---|
| 1 | runtime-root / workspace detection | `workspace/` | `workspace.test.ts` (Slice 1) |
| 2 | project discovery + validation | `workspace/` | `workspace.test.ts` (Slice 1) |
| 3 | definition metadata reads (+`contract_reconciled`) | `parse/project-definition` | `project-definition.test.ts`, `pending-work.test.ts` |
| 4 | next-step / status / project-prereq detection | `sequencing/`, `orchestrator/pending-work` | `sequencing.test.ts`, `pending-work.test.ts` |
| 5 | phase catalog (order, optional, aliases, composites 4.1/4.2) | `sequencing/step-catalog` | `sequencing.test.ts`, `step-executor.test.ts` |
| 6 | model config per phase | `config/runner-config` | `runner-config.test.ts` (Slice 2) |
| 7 | prompt assembly | `runner/prompt-builder` | `session-prompt-builder.test.ts` (Slice 2) |
| 8 | agent session launch | `runner/agent-runner` | `agent-runner.test.ts` (Slice 2) |
| 9 | pre-session repo sync (D7) | `sync/` | `*-sync.test.ts` (Slice 1/2) |
| 10 | read-only-input discovery | `context/` | `*-context.test.ts`, `context-read-only-inputs.test.ts` |
| 11 | deterministic post-run guards | `runner/guards` | `session-guards.test.ts`, `step-executor.test.ts` |
| 12 | br-clarification readiness | `readiness/` | `br-clarification-readiness.test.ts` |
| 13 | phase-7 per-class loop | `orchestrator/run-feature-flow` | `feature-orchestrator.test.ts` |
| 14 | interactive prompts / menus | `interaction/`, orchestrator flow | `interaction-port.test.ts`, `feature-selection.test.ts`, `feature-orchestrator.test.ts` |
| 15 | feature state cache | `state/feature-state` | `feature-state.test.ts` |
| 16 | feature scaffold (step 3) | `capture/scaffold-feature` (+ executor dispatch) | `scaffold-feature.test.ts` |
| 17 | checkpoint commits | `git/` | `checkpoint-commits.test.ts` |
| 18–20 | attach / reconciliation / commit unit | Slice 4 (project flow) | Slice 3 owns detection only: `pending-work.test.ts`, `cli-run.test.ts` |
| 21 | run loop / resume / flow-control / restart | `orchestrator/run-feature-flow` | `feature-orchestrator.test.ts`, `feature-selection.test.ts`, `cli-run.test.ts` |
| 22 | CLI entry (`run`, `scaffold`) | `cli/run` | `cli-run.test.ts` |
| 23 | diagnostics / error reporting | cross-cutting `types/Diagnostic` | asserted across the suites above |

## Sweep result — behavior-parity gate CLOSED (Slice 3)

The one-pass checklist sweep of the `git`-history `project_add_feature_e2e_tests.sh` (91 functions) and
`init_br_scaffold_tests.sh` (5 functions) was completed in `crp-147`. Collapsing the redundant families,
every distinct behavior resolves to one of:

- **Slice 1/2 mechanics** (the `test_phase{5,5.1,6,7,8.x}_*` guard / model-output / required-output /
  read-only / prompt-parity / codex-command / missing-skill families, `phase7_mobile_uses_fe_output_path`,
  the `phase7_1_prompt_*` families) → owned by the retained `session-guards`, `step-executor`,
  `session-prompt-builder`, `runner-config`, `agent-runner`, `*-context`, and `*-validator` suites.
- **Slice 3 orchestration** (4.1/4.2 composite, resume override + the per-step `resume_8.x` variants,
  optional decline/skip/finish, phase-7 loop + failure, checkpoints, selection/continue/new,
  stale/completed cache, restart guidance, project auto/multi/finish selection) → owned by
  `feature-orchestrator`, `feature-selection`, `feature-state`, `checkpoint-commits`, `cli-run`.
- **Slice 4 project flow** (rows 18–20: the `deferred_class_*`, `reconciliation_*`,
  `commit_reconciliation_*` families) → deferred; Slice 3 owns only **detection**, covered by
  `pending-work` + `cli-run` preflight tests.
- **Retirement / divergence** → recorded in the table above (rc protocol, stdout scraping, scanner remap,
  step-3 re-scaffold, CLI/staged-location checks, per-run scanner checklist, `.env`→`.json`, marker→field).

Gaps the sweep surfaced (behaviors that were implemented but untested, or a spec scenario without a test)
were closed with **TypeScript** tests in `crp-147`, not ported shell tests:

| Behavior family (shell scenario) | Added TS coverage |
|---|---|
| Continued feature whose next step is 3 (`scanner_step_3_resumes_scaffold…`) | `feature-orchestrator` refuse test (round-1 finding 1) |
| Project auto-select / multi-select / finish with no `--path` (`without_path_*`) | `cli-run` auto-select, multi-select-and-proceed (target discrimination), and finish tests |
| Scaffold missing `--path` (`requires_path_argument`) | `cli-run` scaffold-arg test |
| Pending step 1.1 stack-blueprint guidance (`scanner_step_1_1_*`) | `pending-work` 1.1 guidance test |
| Missing definition in ancestry (`fails_when_definition_missing…`) | `scaffold-feature` no-definition test |
| Completed cached feature friendly guidance (`completed_cached_feature_prints_friendly_new_feature_message`) | `feature-selection` "completed cached feature prints friendly guidance" test |
| Default run starts at typed next step (`default_resume_uses_scanner_next_step`) | `feature-orchestrator` default-start test |
| Phase-7 analyze failure stops with restart (`phase7_failure_stops…`) | `feature-orchestrator` phase-7-failure test |
| No pending class hides analyze option (`phase7_hides_analyze…`) | `feature-orchestrator` asserts the phase-7 select options exclude `analyze` when none pending (and include it when pending) |

With that, **behavior parity holds for every distinct family**, so the `02` Full parity gate is closed at
the behavior level and the `crp-147` shell deletion is justified by an executed sweep (not a deferral).

## Remaining Slice 5 CRP scope

The distinct Slice 5 change is now **documentation/enablement only**, not safety-critical:

1. Fold this behavior-level result into the formal `02_responsibility_translation_map.md ## Full parity
   gate` write-up and mark it closed there.
2. Confirm the Slice 4 project-flow work lands the rows 18–20 execution tests, retiring the "detection
   only" caveat for those rows.
3. Revise the extension design docs per `03 ### Supersession of the extension design docs`.
