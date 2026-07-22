# EARS-Review (Step 5.1) Migration Parity Checklist

## Old Responsibility Inventory

| Old responsibility | Old location | New owner | Status |
|---|---|---|---|
| Resolve feature path, read-only `feature_br_summary.md`, `requirements_ears.md`, and `requirements_ears_review.md` ledger | `feature_requirements_ears_review.sh` | `context/ears-review.ts` | kept |
| Require `feature_br_summary.md` and `requirements_ears.md` to exist before launch | `feature_requirements_ears_review.sh` `ensure_required_files` | `context/ears-review.ts` (exit `2` if absent) | kept |
| Bind workspace root, feature root, read-only source, two mutable targets, asset refs, and gate command | `feature_requirements_ears_review.sh` prompt | `context/ears-review.ts` + thin e2e launcher | kept |
| Compare EARS vs BR for material business findings only; exclude style/wording/implementation findings | `requirements_ears_review_rule.md` + model prompt | `overmind-ears-review/SKILL.md` | kept |
| One-finding-at-a-time, highest-severity-first user loop with the exact 3-line interaction format | `requirements_ears_review_rule.md` + model prompt | `overmind-ears-review/SKILL.md` | kept |
| yes/no/custom answer handling and finding-state transitions | `requirements_ears_review_rule.md` | `overmind-ears-review/SKILL.md` | kept |
| Maintain durable findings ledger; preserve resolved findings; `review_status: complete` only when none escalated; `no_findings: true` path | `requirements_ears_review_rule.md` | `overmind-ears-review/SKILL.md` | kept |
| Validate ledger sections, meta, finding fields, severity/state enums, and cross-field rules | `check_requirements_ears_review_quality.sh` | `validate/ears-review.ts` | kept |
| Assert model produced `requirements_ears_review.md` | `feature_requirements_ears_review.sh` | phase 5.1 e2e launcher post-run check | kept |
| Deterministic post-run guard: snapshot `feature_br_summary.md` before run, `cmp`-assert unchanged after (`ensure_feature_br_summary_unchanged`) | `feature_requirements_ears_review.sh` | phase 5.1 e2e launcher (`run_ears_review_skill`) snapshot+`cmp`; `context` allowed-write list + `SKILL.md` rule as defense-in-depth | kept |
| Stage runnable bash command, rule, and helper | `project_setup_first_init_machine.sh` | removed; package runner skill instead | changed |

No `capture` verb is added because the BR summary and EARS file are upstream artifacts. No `readiness` verb is added because this step has no state flip of its own.

## Required Parity Rows

| Old instruction/check | New location | Status |
|---|---|---|
| Success final line: `requirements_ears extra review phase is finished. Nothing else to do now; press Ctrl-C so orchestrator can start the next phase` | `SKILL.md` only | kept |
| Infeasibility final line: `based on provided reasons, requirements_ears extra review cannot be completed with current BR/EARS input. Please provide instructions what to do, or adjust artifacts and rerun this phase` | `SKILL.md` only | kept |
| Gate exit `0` means complete | `SKILL.md` | kept |
| Gate exit `1` means repair the ledger (and EARS if needed) and rerun the gate | `SKILL.md` | kept |
| Gate exit `2` means stop and report blocker | `SKILL.md` | kept |
| Read-only BR boundary for `feature_br_summary.md` | phase 5.1 e2e launcher snapshot+`cmp` guard (deterministic) + `context/ears-review.ts` allowed-write list + `SKILL.md` (defense-in-depth) | kept |
| Allowed write list is `requirements_ears.md` and `requirements_ears_review.md` only | `context/ears-review.ts` + `SKILL.md` | kept |
| Required input files (`feature_br_summary.md`, `requirements_ears.md`) must exist | `context/ears-review.ts` (exit `2`) | kept |
| Exact 3-line interaction format (`Here is the finding:` / `I would recommend:` / `Should I add recommended changes? Please answer yes/no or provide your answer.`) | `SKILL.md` | kept |
| Material-findings-only scope (exclude style/wording/implementation) | `SKILL.md` | kept |
| Finding states `escalated` / `added to ears` / `rejected` / `postponed`; one state per finding | `validate/ears-review.ts` + `SKILL.md` | kept |
| `review_status` ∈ {`in_progress`, `complete`}; `complete` only when none escalated; `no_findings: true` ⇒ `complete` | `validate/ears-review.ts` + `SKILL.md` | kept |
| Ledger sections `## 1. Document Meta` / `## 2. Review Guidance` / `## 3. Findings Ledger` and meta keys | `validate/ears-review.ts` | kept |
| Per-finding 10 required fields; `severity` ∈ {High, Medium, Low} | `validate/ears-review.ts` + `SKILL.md` | kept |
| `[UNFILLED]` placeholder rejection | `validate/ears-review.ts` | kept |
| Review template and golden example asset refs use skill-relative `assets/...` paths | `context/ears-review.ts` + `SKILL.md` | kept |
| e2e wrapper prompt supplies runtime bindings and exact commands only | `project_add_feature_e2e.sh` | kept |

## Test Scenarios To Port

### From `tests/ai_scripts/check_requirements_ears_review_quality_tests.sh`

- Valid complete ledger exits `0`: port.
- Missing target path argument exits `2`: port.
- Missing target artifact exits `2`: port.
- Empty target exits `1`: port.
- Remaining `[UNFILLED]` placeholder exits `1`: port.
- Missing required section / meta key exits `1`: port.
- Missing finding field / invalid severity / invalid state exits `1`: port.
- `no_findings`/`review_status` consistency failures exit `1`: port.
- `review_status: complete` with an escalated finding, and `in_progress` with no escalated finding, exit `1`: port.

### From `tests/ai_scripts/init_feature_requirements_ears_review_tests.sh`

- Missing feature path usage is handled by the new e2e/CLI paths: port.
- Non-staged copied command test is deleted with the migrated command: change.
- Required context inputs (`feature_br_summary.md`, `requirements_ears.md`) missing report actionable exit `2`: port to context tests.
- Model phase config checks are replaced by `MODEL_CMD=codex` launcher checks: port.
- Orchestrator does not run the gate directly; the skill owns the gate loop: port.
- Phase 5.1 launches Codex with runtime root bindings, exact context/gate commands, and no literal final lines or 3-line format: port.
- Absolute feature paths remain accepted by context/launcher path handling: port.
- Read-only `feature_br_summary.md` boundary and dual-target allowed-write list survive in `SKILL.md` instructions: kept.
- Deterministic guard: phase 5.1 fails when the stubbed model mutates `feature_br_summary.md` (ports the old `ensure_feature_br_summary_unchanged` assertion): port.

## Adjacent Fix — Step 5 (requirements-ears) Read-Only BR Guard Retrofit

CRP-133 dropped `feature_br_to_ears.sh`'s `ensure_feature_br_summary_unchanged` guard when migrating step 5; `run_requirements_ears_skill` now protects the read-only BR with advisory text only. This change retrofits the same snapshot+`cmp` guard onto the phase 5 launcher (design D8). Not a step 5.1 parity item — tracked here for traceability.

- Phase 5 launcher (`run_requirements_ears_skill`) snapshots `feature_br_summary.md` and `cmp`-asserts unchanged after the session: add (retrofit).
- e2e test: phase 5 fails when the stubbed model mutates `feature_br_summary.md`, passes when untouched: add.
