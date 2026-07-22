## Context

Step 5.1 of the Overmind init/feature pipeline is the **optional** "EARS review". Today it is one bash script run by the e2e orchestrator (`project_add_feature_e2e.sh` phase 5.1 → `feature_requirements_ears_review.sh`):

- `feature_requirements_ears_review.sh` (+ `requirements_ears_review_rule.md` rule + `check_requirements_ears_review_quality.sh` helper) — a **user-interactive model step**: it resolves the read-only `feature_br_summary.md` source, the mutable `requirements_ears.md` target, and the mutable `requirements_ears_review.md` ledger target; loads the model config; builds a prompt binding the rule/template/golden-example + the quality-gate command; launches a Codex session that compares EARS against the BR summary for **material business gaps only**, asks the operator one finding at a time (a fixed 3-line finding/recommendation/decision prompt), applies accepted edits to `requirements_ears.md`, and keeps a durable findings ledger in `requirements_ears_review.md`; afterward it asserts the model produced `requirements_ears_review.md` and that `feature_br_summary.md` was not modified. The helper gate validates the **review ledger** structure (sections, meta keys, per-finding fields, severity/state enums, and the `no_findings`/`review_status`/`escalated` cross-field rules) with awk.

Unlike CRP-133's step 5 (single read-only BR input, single EARS target, no user loop), step 5.1 has **two mutable targets** (`requirements_ears.md` and `requirements_ears_review.md`), a **user-question loop** (like CRP-132's step 4.2), and a gate that validates the **review ledger**, not the EARS file. It has **no capture** (BR summary + EARS are upstream artifacts) and **no readiness/state flip** of its own.

This change is the sixth in the md+sh → skill+TS migration, after CRP-129/130/131/132/133. The constraints from `design_docs/to_skills_migration/*` apply: clean break (no dual bash+TS path), the model owns the artifact + user loop, JS/TS owns deterministic mechanics, the gate is model-invoked with the `0/1/2` contract, and skills install only to the supported `.codex`/`.claude` runner targets sharing the single `.overmind/overmind.js` CLI. The design overview Steps→Skills table names this skill `overmind-ears-review`; gate name = skill name minus the `overmind-` prefix → `ears-review`.

## Goals / Non-Goals

**Goals:**
- Migrate the optional EARS review to the `overmind-ears-review` skill backed by an `ears-review` gate + context builder in the core, with behavior parity to the old rule + helper.
- Preserve the user-interaction loop (one finding at a time, highest severity first, the exact 3-line interaction format), the two terminal final-response lines (success + "cannot be completed"), the findings-ledger state machine, and the read-only-BR / dual-target ownership boundary.
- Fold the installer/setup/e2e wiring into this same change so no CRP-130-style follow-up is needed.
- Retrofit the same deterministic read-only-BR guard onto the already-shipped step 5 phase 5 launcher (`run_requirements_ears_skill`), closing the equivalent CRP-133 gap in the same edit (see D8).
- Port both bash test suites to TS-runner + shell-suite coverage, then delete the migrated bash, rule, helper, and old tests (clean break).

**Non-Goals:**
- The cross-step TS orchestrator / state machine (`overmind run`); the e2e shell launcher stays the transitional sequencer.
- Migrating `project_add_feature_e2e.sh` / `project_setup_first_init_machine.sh` themselves to TS.
- `.github`/`.agents` runner fan-out (still deferred).
- Step 6 (`feature_contract_delta.sh`) and all later pipeline steps; the shared `class_repo_paths` / `repo/` modules.

## Decisions

### D1 — One skill + one gate + one context builder, no capture and no readiness verb
Step 5.1 has no user-captured input (the BR summary and EARS file are upstream artifacts) and no state-flip of its own, so it needs only the three standard primitives plus the model's user-question loop: the `overmind-ears-review` skill (model loop + operator interaction), the model-invoked `gate ears-review` (structural validation of the review ledger), and the deterministic `context ears-review` (path bindings + required-input resolution). No `capture` and no `readiness` verb are added.

_Alternative considered:_ add a `capture` for the review ledger seed. Rejected — the ledger is model-authored from the template, not operator-supplied input; the template lives in `assets/` and the skill owns ledger creation.

### D2 — The gate validates the review ledger (`requirements_ears_review.md`), not the EARS file
The old helper (`check_requirements_ears_review_quality.sh`) validates `requirements_ears_review.md` structure (sections, meta, finding fields, severity/state enums, and the `no_findings`/`review_status`/`escalated` cross-field rules). The TS port keeps this exactly: `validate/ears-review.ts` validates the ledger and never inspects EARS pattern structure (that is step 5's `requirements-ears` gate). Keeping the gate scoped to the ledger keeps it idempotent across the model's repair loop and avoids coupling two artifacts' validation.

_Alternative considered:_ also re-validate `requirements_ears.md` here. Rejected — step 5's gate already owns EARS structural validity; re-running it inside 5.1 would duplicate ownership and could block legitimate review edits.

### D3 — `validate/ears-review.ts` ports the awk ledger validator one-for-one
`check_requirements_ears_review_quality.sh` is a self-contained awk validator. The TS port reproduces its checks exactly before any additions: empty-target failure; `[UNFILLED]` placeholder failure; required sections (`## 1. Document Meta`, `## 2. Review Guidance`, `## 3. Findings Ledger`); required meta keys (`feature_id`, `feature_title`, `source_feature_br_summary`, `source_requirements_ears`, `review_status`, `last_updated`) present and filled; `review_status` ∈ {`in_progress`, `complete`}; per-finding 10 required fields; `severity` ∈ {`High`, `Medium`, `Low`}; `state` ∈ {`escalated`, `added to ears`, `rejected`, `postponed`} (normalized lowercase, whitespace-collapsed, quote-stripped as the awk did); the `no_findings`/`review_status` consistency rules (no findings ⇒ `no_findings: true` and `review_status: complete`; findings present ⇒ `no_findings` not `true`); `review_status: complete` with any `escalated` finding fails; `review_status: in_progress` with findings but no `escalated` finding fails. Exit codes map to the migration contract: structural failures → `1` with the same `quality gate failed: …` messages; runtime failures → `2`.

### D4 — Two mutable targets; `feature_br_summary.md` stays read-only, enforced by a deterministic post-run guard
The context builder's allowed-write list is `requirements_ears.md` and `requirements_ears_review.md`; `feature_br_summary.md` is the only read-only source and must not be mutated. The old script gave this **deterministic** protection: `ensure_feature_br_summary_unchanged` snapshotted `feature_br_summary.md` (`cp`) before the model run and `cmp -s`-asserted it unchanged after, dying if the model touched it. The context allowed-write list and the `SKILL.md` ownership rule are advisory text the model can ignore, so they are **not** a substitute for that guard. This step therefore re-adds the deterministic check in the transitional phase 5.1 e2e launcher (`run_ears_review_skill`): snapshot `feature_br_summary.md` before launching the skill session and `cmp`-assert it byte-unchanged after, failing the phase if it differs. This is allowed under the migration guide — a file-immutability assertion is deterministic mechanics, not skill-owned semantic logic — and it follows Ownership Rule 2 (JS/TS/shell owns deterministic mechanics). The allowed-write list + `SKILL.md` rule stay as defense-in-depth, not the sole protection. When sequencing later moves to the TS orchestrator, the guard moves with it. `requirements_ears.md` must exist before the review (context exits `2` if absent) since the review compares and minimally edits it.

The gate and context are not the right home for this check: by D2 the gate must not read `feature_br_summary.md` (and runs only against the ledger), and context runs *before* the model so it cannot observe post-run mutation. The post-run launcher is the faithful 1:1 port.

### D5 — User-interaction loop and ledger state machine live only in `SKILL.md`
The fixed 3-line interaction format, the one-finding-at-a-time / highest-severity-first ordering, the yes/no/custom answer-handling rules, the four terminal finding states, and the `review_status: complete only when no finding is escalated` rule all move verbatim into `SKILL.md` (inlined from the rule). The e2e launcher prompt carries none of this semantic logic.

### D6 — Two terminal final-response lines live only in `SKILL.md`
`feature_requirements_ears_review.sh` defined two exact terminal lines: the success line and the "cannot be completed with current BR/EARS input" infeasibility line. Both move verbatim into `SKILL.md` and nowhere else (not the e2e launcher prompt). The infeasibility line is the model's escape hatch when review completion cannot satisfy the gate with the available BR/EARS facts or operator decisions.

### D7 — e2e phase 5.1 mirrors the phase 4.2 / phase 5 skill-launch pattern
Phase 4.2 and phase 5 already launch skill sessions via thin launchers. Phase 5.1 follows the same shape: `run_ears_review_skill` launches the model session telling it to load `overmind-ears-review` with runtime bindings + the exact `context`/`gate ears-review` commands; the launcher prompt carries no literal final lines and no gate exit-code handling (single source of truth is `SKILL.md`). The `feature_requirements_ears_review.sh` entry is removed from the phase 5.1 `phase_scripts` list. There is no post-skill deterministic step here (no readiness flip).

### D8 — Retrofit the same guard onto the step 5 phase 5 launcher (close the CRP-133 gap)
CRP-133 migrated step 5 (BR→EARS) but did not carry `feature_br_to_ears.sh`'s `ensure_feature_br_summary_unchanged` guard into its phase 5 launcher; `run_requirements_ears_skill` now protects the read-only BR with advisory allowed-write/SKILL.md text only — the same regression this change fixes for step 5.1. Because both launchers live in the same `project_add_feature_e2e.sh` and share the read-only `feature_br_summary.md` input, this change applies the identical snapshot-before / `cmp`-assert-after guard to `run_requirements_ears_skill` in the same edit. Doing it here (rather than a separate CRP) avoids shipping two adjacent launchers with inconsistent protection and lets one e2e test fixture cover both phases.

_Alternative considered:_ leave step 5 for a dedicated follow-up CRP. Rejected — the fix is a few lines mirroring the step 5.1 guard, the gap is live in the merged code, and splitting it risks the step 5 launcher staying unprotected indefinitely. The scope stays narrow: only the read-only-BR guard is added to phase 5; nothing else about step 5's skill/gate/context changes.

## Risks / Trade-offs

- **[awk → TS enum/cross-field drift]** → mitigated by porting the section/meta/finding-field rules and the `no_findings`/`review_status`/`escalated` cross-field logic exactly (including state normalization), and pinning every edge case from `check_requirements_ears_review_quality_tests.sh` in TS tests before deleting the bash.
- **[Losing the user-interaction contract]** → the exact 3-line format and answer-handling rules are inlined into `SKILL.md` and pinned by a parity-sweep row plus an e2e test asserting the launcher prompt does not duplicate them.
- **[Losing a terminal final line]** → mitigated by a parity sweep table (old script+rule vs SKILL.md+context+gate) that pins both exact lines, and a test asserting they appear only in `SKILL.md` (not the e2e launcher).
- **[Read-only BR / dual-target boundary regression]** → the old script snapshotted `feature_br_summary.md` and `cmp`-asserted it unchanged (`ensure_feature_br_summary_unchanged`); dropping that for prompt/context text alone would turn a guaranteed deterministic failure into silent BR corruption that flows into every downstream step. Mitigated by re-adding the deterministic snapshot+`cmp` guard in the phase 5.1 e2e launcher (D4), keeping the `context` allowed-write list (`requirements_ears.md` + `requirements_ears_review.md` only) and SKILL.md rule as defense-in-depth, and pinning both with a parity-sweep row and an e2e test that fails the phase when the stubbed model mutates `feature_br_summary.md`.

## Migration Plan

1. Land the TS core: `validate/ears-review.ts`, `context/ears-review.ts`, registries in `cli/run.ts`, with tests — `npm test --workspace packages/asdlc-coordinator` green.
2. Land the `overmind-ears-review` skill payload + installer wiring (`init.ts` fifth skill) — `npm test --workspace packages/installer` green.
3. Land setup staging + e2e phase-5.1 rewiring; update shell suites — `project_setup_asdlc_tests.sh` / `project_add_feature_e2e_tests.sh` green.
4. Parity sweep (old script+rule+helper vs SKILL.md+context+gate), then delete the migrated bash, rule, helper, and the two old shell test files; update `CLAUDE.md`/`AGENTS.md`, README/QUICKRUN, and the migration overview (mark step 5.1 done).
5. `git diff --check`; `openspec validate crp-134-migrate-feature-req-ears-review --strict`.

Rollback: revert the change; nothing depends on the new `ears-review` gate/context yet, and step 5 and the downstream steps are untouched.

## Open Questions

_None — the single-skill shape (no capture, no readiness verb), the ledger-scoped gate, the dual-target allowed-write list, and the parity scope are settled above._
