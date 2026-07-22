## Context

Step 5 of the Overmind init/feature pipeline is "BR → EARS". Today it is one bash script run by the e2e orchestrator (`project_add_feature_e2e.sh` phase 5 → `feature_br_to_ears.sh`):

- `feature_br_to_ears.sh` (+ `br_to_ears.md` rule + `check_requirements_ears_quality.sh` helper) — a **single model step**: it enforces the `ready_to_ears: true` precondition (`ensure_ready_to_ears`, reading `## 1. Document Meta` of `feature_br_summary.md`), loads the model config, builds a prompt that binds the read-only BR source + the `requirements_ears.md` target + the rule/template/golden-example + the quality-gate command, launches a Codex session that converts the BR into atomic EARS blocks, and afterward asserts `feature_br_summary.md` was not modified. The helper gate validates the EARS structure (block fields, allowed EARS patterns, sequential numbering) with awk.

Unlike CRP-132's step 4.2 (two halves: a model loop + a deterministic readiness transition), step 5 is **purely model-owned** with one structural gate and one read-only precondition. The precondition (`ready_to_ears: true`) is now produced upstream by CRP-132's `readiness br-clarification` flip, so this step only *verifies* it — it never mutates `feature_br_summary.md` meta.

This change is the fifth in the md+sh → skill+TS migration, after CRP-129/130/131/132. The constraints from `design_docs/to_skills_migration/*` apply: clean break (no dual bash+TS path), the model owns the artifact loop, JS/TS owns deterministic mechanics, the gate is model-invoked with the `0/1/2` contract, and skills install only to the supported `.codex`/`.claude` runner targets sharing the single `.overmind/overmind.js` CLI.

## Goals / Non-Goals

**Goals:**
- Migrate the BR→EARS conversion to the `overmind-requirements-ears` skill backed by a `requirements-ears` gate + context builder in the core, with behavior parity to the old rule + helper.
- Preserve the two terminal final-response lines (success + "gate cannot pass") and the read-only-BR / single-target ownership boundary.
- Move the `ready_to_ears: true` precondition into the deterministic context builder (exit `2`), reusing the CRP-132 BR-summary meta reader.
- Fold the installer/setup/e2e wiring into this same change so no CRP-130-style follow-up is needed.
- Port both bash test suites to TS-runner + shell-suite coverage, then delete the migrated bash, rule, helper, and old tests (clean break).

**Non-Goals:**
- The cross-step TS orchestrator / state machine (`overmind run`); the e2e shell launcher stays the transitional sequencer.
- Migrating `project_add_feature_e2e.sh` / `project_setup_first_init_machine.sh` themselves to TS.
- `.github`/`.agents` runner fan-out (still deferred).
- Step 5.1 (`feature_requirements_ears_review.sh`) and all later pipeline steps; the shared `class_repo_paths` / `repo/` modules.

## Decisions

### D1 — One skill + one gate + one context builder, no capture and no readiness verb
Step 5 has no user-captured input (the BR summary is an upstream artifact) and no state-flip of its own, so it needs only the three standard primitives: the `overmind-requirements-ears` skill (model loop), the model-invoked `gate requirements-ears` (structural EARS validation), and the deterministic `context requirements-ears` (path bindings + precondition). No `capture` and no `readiness` verb are added — this is the simplest of the migrated steps so far.

_Alternative considered:_ have the model also re-verify `ready_to_ears` itself. Rejected — it is a deterministic precondition read; per the Ownership Rules, deterministic mechanics belong in TS, so the context builder owns it and blocks with exit `2` before the model edits anything.

### D2 — The `ready_to_ears` precondition lives in `context`, not in the gate
The old script enforced `ready_to_ears: true` (`ensure_ready_to_ears`) *before* launching the model, dying with a "run readiness first" message otherwise. The new home is `context/requirements-ears.ts`: it reads `## 1. Document Meta` (reusing the CRP-132 BR-summary meta reader), and exits `2` (blocked, not recoverable) with a message pointing at `readiness br-clarification` when the key is missing or not `true`. The **gate** stays a pure structural check of `requirements_ears.md` and never inspects the BR meta — keeping the gate read-only and idempotent across the model's repair loop.

_Alternative considered:_ put the precondition in the gate. Rejected — the gate may run many times in the repair loop and validates the EARS artifact; mixing in an upstream-meta precondition would couple two concerns and could block legitimate repairs.

### D3 — `validate/requirements-ears.ts` ports the awk EARS validator one-for-one
`check_requirements_ears_quality.sh` is a self-contained awk validator (no composition with other gates, unlike CRP-132's task-to-br base). The TS port reproduces its checks exactly before any additions: empty-target failure; per-block required fields (`**User Story:**`, `**Acceptance Criteria (EARS):**`, `**Verification:**`); at-least-one-bullet and at-least-one-valid-EARS-pattern bullet per block; the allowed-pattern set (including the bare `THE … SHALL …` and the `WHEN … AND WHILE …` combined form, matched case-insensitively as the awk did with `toupper`); independent sequential 1-based numbering with duplicate detection for `Requirement` and `NFR`; and the "no blocks found" failure. Exit codes map to the migration contract: structural failures → `1` with actionable `quality gate failed: …`-style messages; runtime failures → `2`.

### D4 — Reuse the CRP-132 BR-summary meta reader; no new parser
CRP-132 added a `parse/` BR-summary helper that reads `## 1. Document Meta` keys (it implemented the `ready_to_ears` read used by `readiness`). This step reuses that reader read-only for the precondition. No new parser module is introduced, and no flip/write helper is needed (step 5 never mutates meta).

### D5 — Two terminal final-response lines live only in `SKILL.md`
`feature_br_to_ears.sh` defined two exact terminal lines: the success line and the "gate cannot pass with current BR input" infeasibility line. Both move verbatim into `SKILL.md` and nowhere else (not the e2e launcher prompt). The infeasibility line is the model's escape hatch when conversion cannot satisfy the gate with the available BR facts — it stops finalization and asks the operator for instructions, mirroring the old rule's Completion Gate clause.

### D6 — e2e phase 5 mirrors the phase 4.2 skill-launch pattern
Phase 4.2 already launches a skill session via `run_br_clarification_skill` / `build_br_clarification_prompt`. Phase 5 follows the same shape: `run_requirements_ears_skill` launches the model session telling it to load `overmind-requirements-ears` with runtime bindings + the exact `context`/`gate requirements-ears` commands; the launcher prompt carries no literal final lines and no gate exit-code handling (single source of truth is `SKILL.md`). The `feature_br_to_ears.sh` entry is removed from the phase 5 `phase_scripts` list. There is no post-skill deterministic step here (no readiness flip), so phase 5 is simpler than 4.2.

## Risks / Trade-offs

- **[awk → TS pattern-match drift]** → mitigated by porting the `is_allowed_ears_pattern` rule set and block-field logic exactly (including the case-insensitive match and the bare `THE … SHALL …` allowance) and pinning every pattern/numbering edge case from `check_requirements_ears_quality_tests.sh` in TS tests before deleting the bash.
- **[Precondition moved from script to context could be skipped]** → mitigated by `context requirements-ears` exiting `2` when `ready_to_ears` is not `true`, and by an e2e/TS test asserting the block; the model cannot proceed without a successful context call that supplies the target path.
- **[Losing a terminal final line]** → mitigated by a parity sweep table (old script+rule vs SKILL.md+context+gate) that pins both exact lines, and a test asserting they appear only in `SKILL.md` (not the e2e launcher).
- **[Read-only BR boundary regression]** → the old script snapshotted `feature_br_summary.md` and asserted it unchanged; the new boundary is enforced by the `context` allowed-write list (`requirements_ears.md` only) and the SKILL.md ownership rule, with a parity-sweep row pinning it.

## Migration Plan

1. Land the TS core: `validate/requirements-ears.ts`, `context/requirements-ears.ts` (reusing the BR-summary meta reader for the precondition), registries in `cli/run.ts`, with tests — `npm test --workspace packages/asdlc-coordinator` green.
2. Land the `overmind-requirements-ears` skill payload + installer wiring (`init.ts` fourth skill) — `npm test --workspace packages/installer` green.
3. Land setup staging + e2e phase-5 rewiring; update shell suites — `project_setup_asdlc_tests.sh` / `project_add_feature_e2e_tests.sh` green.
4. Parity sweep (old script+rule+helper vs SKILL.md+context+gate), then delete the migrated bash, rule, helper, and the two old shell test files; update `CLAUDE.md`/`AGENTS.md`, README/QUICKRUN, and the migration overview (mark step 5 done).
5. `git diff --check`; `openspec validate crp-133-migrate-br-to-ears-to-skill --strict`.

Rollback: revert the change; nothing depends on the new `requirements-ears` gate/context yet, and step 5.1 and the shared modules are untouched.

## Open Questions

_None — the single-skill shape (no capture, no readiness verb), the precondition-in-context decision, and the parity scope are settled above._
