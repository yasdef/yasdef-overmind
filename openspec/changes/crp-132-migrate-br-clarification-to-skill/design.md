## Context

Step 4.2 of the Overmind init/feature pipeline is "BR clarification + EARS readiness". Today it is two bash scripts run back-to-back by the e2e orchestrator (`project_add_feature_e2e.sh` phase 4.2 → `feature_user_br_clarification.sh`, then `feature_br_check_ears_readiness.sh`):

1. `feature_user_br_clarification.sh` (+ `user_br_clarification_rule.md` + `check_user_br_clarification_quality.sh`) — a **model loop**: it skips when `missing_br_data.md` has no non-rised items; otherwise it launches a Codex session that asks business-only follow-up questions, writes answers into `feature_br_summary.md`, tracks question state in `missing_br_data.md` via a `rised` flag, and reruns the helper gate until every `rised_item_N` is `rised=true`. The helper itself layers a `missing_br_data.md` non-rised check on top of the existing `overmind gate task-to-br`.
2. `feature_br_check_ears_readiness.sh` — **deterministic, no model, no rule**: it runs `overmind gate task-to-br`, conditionally runs `overmind gate repo-br-scan` when the project has `ready` `class_repo_paths`, then flips `ready_to_ears: false → true` in `## 1. Document Meta` (asserting it was `false` first).

This change is the fourth in the md+sh → skill+TS migration, after CRP-129 (`task-to-br` + the `asdlc-coordinator` core/CLI), CRP-130 (runner-skill install correction), and CRP-131 (`repo-br-scan` + the `sync` verb + the shared `repo/` ready-path/sync modules). The constraints from `design_docs/to_skills_migration/*` apply: clean break (no dual bash+TS path), the model owns the artifact loop, JS/TS owns deterministic mechanics, the gate is model-invoked with the `0/1/2` contract, and skills install only to the supported `.codex`/`.claude` runner targets sharing the single `.overmind/overmind.js` CLI.

## Goals / Non-Goals

**Goals:**
- Migrate the BR-clarification model loop to the `overmind-br-clarification` skill backed by a `br-clarification` gate + context builder in the core, with behavior parity to the old rule + helper.
- Migrate the deterministic EARS-readiness transition to a TS primitive in the core with parity to `feature_br_check_ears_readiness.sh` (both gate checks, the ready-class branch, the `ready_to_ears` flip + precondition).
- Fold the installer/setup/e2e wiring into this same change so no CRP-130-style follow-up is needed.
- Port both bash test suites to TS-runner + shell-suite coverage, then delete the migrated bash, rule, helper, and old tests (clean break).

**Non-Goals:**
- The cross-step TS orchestrator / state machine (`overmind run`); the e2e shell launcher stays the transitional sequencer.
- Migrating `project_add_feature_e2e.sh` / `project_setup_first_init_machine.sh` themselves to TS.
- `.github`/`.agents` runner fan-out (still deferred).
- Any change to other pipeline steps or to the shared `class_repo_paths` / `repo/` modules' behavior.

## Decisions

### D1 — Split the step into one skill (clarification) + one deterministic CLI verb (readiness)
The overview maps both 4.2 scripts to the single `overmind-br-clarification` skill, but the two halves have fundamentally different ownership. BR clarification is a model loop → it becomes the **skill** + a model-invoked **`gate br-clarification`**. EARS readiness was never a model phase (no rule, no prompt — pure mechanics) → it becomes a **deterministic CLI primitive**, invoked by the orchestrator *after* the skill session, exactly as the bash orchestrator ran the readiness script after the clarification script.

_Alternative considered:_ make the model perform the `ready_to_ears` flip as part of its skill loop. Rejected — it is a deterministic state transition with a strict precondition (`ready_to_ears` must be `false`) and two dependent gate checks; per the migration Ownership Rules, the model owns artifact *content*, TS owns deterministic mechanics and readiness calculations. Keeping the flip in TS preserves parity and keeps the gate non-mutating.

### D2 — Add a `readiness` CLI verb (not a 4th gate, not folded into `gate`)
The readiness transition mutates the artifact (`gate` must stay read-only) and composes two existing gates plus a flip. CRP-131 already established the precedent that the CLI surface grows a new top-level verb when a deterministic, non-gate operation is needed (it added `sync` alongside `capture|context|gate`). So readiness becomes `node .overmind/overmind.js readiness br-clarification <feature-path>`, dispatched via a new `readinessRegistry`, replacing the `readinessStub` placeholder in `readiness/index.ts`.

_Alternative considered:_ overload `gate br-clarification` to also flip `ready_to_ears` on pass. Rejected — gates are model-invoked in a repair loop and may run many times; a mutating gate would flip readiness mid-clarification and breaks the "gate is a pure check" contract.

### D3 — `validate/br-clarification.ts` composes the existing `task-to-br` validator
The old helper runs `overmind gate task-to-br` as its base and only adds the `missing_br_data.md` non-rised ledger check on top. The TS gate mirrors this: call `validateTaskToBr(targetPath)` first; on non-zero, surface its result verbatim; on pass, parse `## 3. Unresolved Items Ledger (Rised)` for `- rised_item_N:` entries and fail (`1`) if any is non-rised. This reuses the proven validator instead of duplicating business-context checks, and the "no non-rised items ⇒ pass immediately" case reproduces the bash skip behavior for free.

### D4 — Port the awk ledger/meta parsers faithfully to TS
The non-rised detection helper preserves the awk interpretation (`rised=false`, `non-rised`/`not-rised`, or a `rised_item_N` lacking an explicit `rised=true`/`rised: true` counts as unresolved) and the `## 1. Document Meta` `ready_to_ears` read/flip. The `br-clarification` validator still honors the base-first contract: invalid or missing `rised` markers are surfaced verbatim from `task-to-br`; the unresolved-ledger check runs after the base check passes and therefore handles explicit `rised=false` items. The helper lives under `parse/` (heading-scoped, quote-stripping, gap-tolerant) and is shared by the gate and readiness handler, with tests pinning the parser edge cases the awk handled (quoted examples ignored, only real ledger entries inspected).

### D5 — Readiness reuses the CRP-131 `repo/collect-ready-paths` module for the ready-class branch
`feature_br_check_ears_readiness.sh` sources `common_libs/class_repo_paths.sh` to decide whether to run the `repo-br-scan` gate. The TS readiness handler reuses the already-ported `repo/` module (no new repo logic), resolving `init_progress_definition.yaml` from the feature's parent project folder, exactly as the bash did.

### D6 — e2e phase 4.2 mirrors the phase 4.1 skill-launch pattern
Phase 4.1 already special-cases skill sessions (`run_repo_br_scan_skill` / `run_task_to_br_skill` with thin `build_*_prompt` launchers). Phase 4.2 follows the same shape: `run_br_clarification_skill` launches the model session, then the orchestrator runs the deterministic `readiness br-clarification` CLI step (not the model). The launcher prompt carries only runtime bindings + exact commands; the literal final-response line and gate exit-code handling live only in `SKILL.md` (single source of truth).

### D7 — Sequential one-at-a-time clarification UX + `skip for now`, with readiness as the completeness guard
The skill asks unresolved questions one at a time (an upfront list + brief process note, then one question per turn) instead of dumping them all at once, and lets the user reply `skip for now` to defer any question — a skipped item stays `rised=false`. `skip for now` is a *defer-within-the-loop* (answer the rest first, come back to it), **not** a way to finish the phase early. This is purely a SKILL.md interaction contract; the `validate/br-clarification.ts` gate is unchanged (it cannot distinguish "skipped" from "not yet asked" — both are `rised=false`), so a skipped item simply keeps the gate at exit `1`. Terminal behavior preserves the old hard-fail invariant: the model keeps working the loop (re-offering deferred questions in new rounds) and only completes — emitting the final response line and allowing the next phase — when the gate exits `0` with every item `rised=true`. If the operator ends the session with anything unresolved, the phase is simply incomplete and the readiness/next phase does not run (the `br-clarification` gate fails), exactly as `feature_user_br_clarification.sh` hard-failed on unresolved items so readiness never ran.

The old bash flow enforced completeness implicitly: `feature_user_br_clarification.sh` hard-failed (non-zero) if non-rised items remained, so the phase never reached the readiness script. A skill can stop incomplete without a non-zero orchestrator signal, which would otherwise let the deterministic readiness step flip `ready_to_ears` (the old readiness validated only the `task-to-br` rules, which ignore the ledger) and advance to EARS with open business questions. To preserve the invariant, the readiness handler evaluates the **`br-clarification` validator** (task-to-br base + unresolved-ledger check) instead of the bare `task-to-br` validator — a documented superset (see D8 for why this is a function call, not a CLI gate invocation). Net effect: `skip for now` defers a question without blocking unrelated work, but the feature cannot advance to EARS readiness until every clarification item is resolved.

_Alternative considered:_ have the e2e orchestrator run `gate br-clarification` between the skill session and readiness. Rejected — it would put a model-owned gate in the shell orchestrator (against the Ownership Rules); folding the check into the deterministic readiness primitive is cleaner and keeps the guard in one place.

### D8 — Readiness composes shared validator *functions*, never the `overmind gate` CLI verb
The readiness handler's precondition checks (D3/D7) call the shared validator functions directly — `validateBrClarification(targetPath)` and `validateRepoBrScan(targetPath)` imported from `validate/` — and inspect the returned `GateResult`. It SHALL NOT shell out to `node .overmind/overmind.js gate <step>`. This keeps two ownership rules from the migration guide both literally satisfied: rule 4 ("the gate is a model-invoked validator, not an orchestrator-invoked phase check") holds because the `overmind gate` **CLI verb** stays exclusively model-invoked; rule 2 ("JS/TS owns deterministic mechanics only: … validation … readiness calculations") covers readiness reusing the validator **module**. So there is no architecture exception to document — the distinction is CLI-gate-verb (model-only) vs. validator-function (shared deterministic reuse), and the migration guide is amended once to state this distinction explicitly (so future step migrations follow it instead of re-introducing a CLI-gate call).

_Why this differs from the bash:_ `feature_br_check_ears_readiness.sh` shelled out to `node .overmind/overmind.js gate task-to-br` / `gate repo-br-scan` only because bash cannot call a TypeScript function; that subprocess hop was a language limitation, not an architectural choice to preserve. Calling the validator in-process is faithful in outcome, avoids a `node` subprocess, and guarantees the readiness guard and the model's gate evaluate identical logic (same function), removing any drift between a separately installed CLI and the linked module.

_Alternative considered:_ keep the CLI-gate invocation and amend the migration guide to permit readiness primitives to call gates as non-repairing precondition checks. Rejected — it permanently weakens rule 4 and invites future steps to cargo-cult orchestrator gate-calls, when direct function reuse already achieves the goal with no rule tension.

## Risks / Trade-offs

- **[Adding a CLI verb broadens the public CLI surface]** → mitigated by precedent (CRP-131's `sync`) and by keeping `readiness` deterministic and step-keyed (`readiness <step> <path>`), consistent with the existing `<verb> <step> <path>` shape.
- **[Parser drift from the awk originals]** → mitigated by porting the awk parser edge cases and pinning them in TS tests before deleting the bash. Validator tests separately pin that invalid or missing `rised` markers remain base `task-to-br` structural failures, while explicit `rised=false` blocks BR clarification completion.
- **[Readiness flip is irreversible within a run]** → it asserts `ready_to_ears == false` before flipping (parity with bash) and errors otherwise, so a re-run after a partial failure cannot double-flip or silently corrupt the meta.
- **[e2e ordering regression]** → the shell-suite tests assert clarification skill runs before the readiness step and that the readiness step is deterministic (no Codex), guarding the phase order the bash guaranteed.

## Migration Plan

1. Land the TS core: `parse/` BR-summary helper, `validate/br-clarification.ts`, `context/br-clarification.ts`, `readiness/br-clarification.ts`, registries + `readiness` verb in `cli/run.ts`, with tests — `npm test --workspace packages/asdlc-coordinator` green.
2. Land the `overmind-br-clarification` skill payload + installer wiring (`init.ts` third skill) — `npm test --workspace packages/installer` green.
3. Land setup staging + e2e phase-4.2 rewiring; update shell suites — `project_setup_asdlc_tests.sh` / `project_add_feature_e2e_tests.sh` green.
4. Parity sweep (old script+rule+helper vs SKILL.md+context+gate+readiness), then delete the migrated bash, rule, helper, and the two old shell test files; update `CLAUDE.md`, README/QUICKRUN, and the migration overview (mark 4.2 done).
5. `git diff --check`; `openspec validate crp-132-migrate-br-clarification-to-skill --strict`.

Rollback: revert the change; nothing else depends on the new `readiness` verb yet, and the shared `repo/` / `class_repo_paths` modules are untouched.

## Open Questions

_None — the split (skill + `readiness` verb), the verb naming, and the parity scope are settled above._
