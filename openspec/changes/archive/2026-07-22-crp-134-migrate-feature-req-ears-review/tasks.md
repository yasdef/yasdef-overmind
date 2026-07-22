## 1. Preflight Inventory

- [x] 1.1 Re-read `feature_requirements_ears_review.sh`, `requirements_ears_review_rule.md`, and `check_requirements_ears_review_quality.sh`; record the old-responsibility → new-owner inventory (context/gate/skill; no capture, no readiness verb) per the step-by-step guide
- [x] 1.2 Extract every old final-response line (success + infeasibility), gate exit-code rule, required-input check, read-only-BR boundary, dual-target allowed-write list, 3-line interaction format, finding-state set, `no_findings`/`review_status` cross-field rules, and ledger section/meta/finding-field set into the parity checklist
- [x] 1.3 List the scenarios in `tests/ai_scripts/check_requirements_ears_review_quality_tests.sh` and `tests/ai_scripts/init_feature_requirements_ears_review_tests.sh` (section/meta/finding-field, severity/state, no_findings/review_status, empty/unfilled cases; required-input, read-only-BR, model-produced-file cases) to port

## 2. asdlc-coordinator core — validator and context

- [x] 2.1 Implement `validate/ears-review.ts`: port `check_requirements_ears_review_quality.sh` one-for-one — empty-target fail; `[UNFILLED]` fail; required sections (`## 1. Document Meta`, `## 2. Review Guidance`, `## 3. Findings Ledger`); required filled meta keys (`feature_id`, `feature_title`, `source_feature_br_summary`, `source_requirements_ears`, `review_status`, `last_updated`); `review_status` ∈ {`in_progress`, `complete`}; per-finding 10 fields; `severity` ∈ {High, Medium, Low}; `state` ∈ {escalated, added to ears, rejected, postponed} (normalized); `no_findings`/`review_status` consistency; `complete` rejected with escalated; `in_progress` rejected with findings but none escalated; exit `0/1/2`; export from `validate/index.ts`
- [x] 2.2 Implement `context/ears-review.ts`: resolve feature path + read-only `feature_br_summary.md` (exit `2` if absent) + `requirements_ears.md` source/target (exit `2` if absent) + `requirements_ears_review.md` ledger target; emit one block with workspace root, feature root, read-only BR source, allowed-write list (`requirements_ears.md` + `requirements_ears_review.md`), exact gate command, skill-relative asset refs (rule inlined in `SKILL.md`); export from `context/index.ts`

## 3. asdlc-coordinator core — CLI wiring

- [x] 3.1 Register `ears-review` in `gateRegistry` and `contextRegistry` in `cli/run.ts`
- [x] 3.2 Confirm unknown-step + missing-arg usage errors behave with parity to the other verbs for `gate ears-review` / `context ears-review`

## 4. asdlc-coordinator core — tests

- [x] 4.1 `gate ears-review` tests: exit `0` complete ledger; exit `1` for each — empty target, `[UNFILLED]`, missing each section/meta key, missing finding field, invalid severity, invalid state, no_findings/review_status inconsistency, `complete`+escalated, `in_progress`+no-escalated; exit `2` runtime error and missing target; assert actionable failure messages — porting `check_requirements_ears_review_quality_tests.sh`
- [x] 4.2 `context ears-review` tests: assembled block content + read-only BR source + allowed-write list (`requirements_ears.md` + `requirements_ears_review.md`) + exact gate command; missing `feature_br_summary.md` exits `2`; missing `requirements_ears.md` exits `2`; skill-relative asset paths (no `.codex`/`.claude` hardcoding); absolute feature path
- [x] 4.3 Run `npm test --workspace packages/asdlc-coordinator` green

## 5. Skill package

- [x] 5.1 Create `packages/installer/_data/skills/overmind-ears-review/SKILL.md` with frontmatter, purpose, required invocation, exact `context`/`gate ears-review` commands, allowed-write list (`requirements_ears.md` + `requirements_ears_review.md`), gate exit-code handling, and BOTH literal final-response lines (success + infeasibility) — only here
- [x] 5.2 Inline `requirements_ears_review_rule.md` into `SKILL.md` (material-findings-only scope, the exact 3-line interaction format, yes/no/custom answer handling, finding-state set, ledger rules, `review_status`/`no_findings` completion rules, read-only-BR boundary, dual-target allowed-write list, runtime path bindings); do not keep a separate rule asset
- [x] 5.3 Copy `requirements_ears_review_TEMPLATE.md` and `requirements_ears_review_GOLDEN_EXAMPLE.md` into `assets/` (preserve the existing filenames); use skill-relative `assets/...` references
- [x] 5.4 Run the parity sweep table (old script+rule+helper vs SKILL.md+context+gate); resolve every `missing` row — confirm both terminal lines live only in `SKILL.md`, the 3-line interaction format and finding-state machine are preserved, and the read-only-BR / dual-target boundary is preserved

## 6. Installer + setup staging

- [x] 6.1 Add `overmind-ears-review` to `PACKAGED_SKILLS` in `packages/installer/src/init.ts` (install to `.codex`/`.claude`, payload validation, install metadata); keep `.overmind/overmind.js` the single CLI
- [x] 6.2 Add `overmind-ears-review` to skill-staging in `project_setup_first_init_machine.sh`; add preflight checks for its canonical folder/`SKILL.md`/`assets/`
- [x] 6.3 Remove staging of `feature_requirements_ears_review.sh` (command array), `requirements_ears_review_rule.md` (rule array), and `check_requirements_ears_review_quality.sh` (helper array); keep the downstream un-migrated step assets staged; ensure update mode removes stale staged copies
- [x] 6.4 Run `npm test --workspace packages/installer` and `bash tests/ai_scripts/project_setup_asdlc_tests.sh` green

## 7. Feature e2e wiring

- [x] 7.1 Add `build_ears_review_prompt` + `run_ears_review_skill` (thin launcher: runtime bindings + exact `context`/`gate ears-review` commands only; no literal final lines, no 3-line format, no gate handling), mirroring the phase 4.2 / phase 5 launchers; apply the migration-guide e2e safeguards explicitly: run Codex from the ASDLC runtime root, require/assert `MODEL_CMD=codex`, preflight-check that the installed `overmind-ears-review` skill and `.overmind/overmind.js` exist before launching, and capture the model exit code without leaking `set -e`
- [x] 7.2 Re-add the deterministic read-only-BR guard in `run_ears_review_skill` (porting `ensure_feature_br_summary_unchanged`): snapshot `feature_br_summary.md` (`cp`/`mktemp`) before launching the skill session and `cmp -s`-assert it byte-unchanged after, failing the phase with an actionable error if it differs; also assert the model produced `requirements_ears_review.md`
- [x] 7.3 Rewire phase 5.1 to run the ears-review skill session and remove the `feature_requirements_ears_review.sh` entry from the phase 5.1 `phase_scripts` list; add restart guidance resuming at phase 5.1; no deterministic post-skill artifact step beyond the read-only-BR guard
- [x] 7.4 Update `tests/ai_scripts/project_add_feature_e2e_tests.sh`: assert phase 5.1 launches the skill (stub `codex`), prompt has exact commands and neither literal final line nor the 3-line format, the orchestrator does not run the gate, the launcher requires `MODEL_CMD=codex`, phase 5.1 fails before launching when the installed `overmind-ears-review` skill or `.overmind/overmind.js` is missing, and phase 5.1 fails after the run when the stubbed model mutates `feature_br_summary.md` (read-only-BR guard); run green
- [x] 7.5 Retrofit the read-only-BR guard onto the step 5 phase 5 launcher (`run_requirements_ears_skill`, CRP-133 gap per design D8): snapshot `feature_br_summary.md` before the `overmind-requirements-ears` session and `cmp`-assert it byte-unchanged after, failing the phase with an actionable error if it differs; limit the edit to this guard, leaving step 5's skill/gate/context behavior unchanged
- [x] 7.6 Extend `tests/ai_scripts/project_add_feature_e2e_tests.sh`: assert phase 5 fails after the run when the stubbed model mutates `feature_br_summary.md`, and still passes when the BR is untouched; run green

## 8. Clean break + docs

- [x] 8.1 Delete `feature_requirements_ears_review.sh`, `requirements_ears_review_rule.md`, `check_requirements_ears_review_quality.sh`, `tests/ai_scripts/init_feature_requirements_ears_review_tests.sh`, `tests/ai_scripts/check_requirements_ears_review_quality_tests.sh`
- [x] 8.2 Remove all references to the deleted files from setup staging arrays, shell test listings, the `CLAUDE.md` and `AGENTS.md` test lists, `README.md`/`QUICKRUN.md`
- [x] 8.3 Mark step 5.1 **done** in `design_docs/to_skills_migration/migration_to_skill_architecture_overview.md` Steps→Skills table

## 9. Verification

- [x] 9.1 Run `npm test --workspace packages/asdlc-coordinator`, `npm test --workspace packages/installer`, `bash tests/ai_scripts/project_setup_asdlc_tests.sh`, `bash tests/ai_scripts/project_add_feature_e2e_tests.sh`
- [x] 9.2 `git diff --check` and `openspec validate crp-134-migrate-feature-req-ears-review --strict`
- [x] 9.3 Manual smoke: build, stage workspace, confirm `.codex`/`.claude` `overmind-ears-review/SKILL.md` + `.overmind/overmind.js`, run `context ears-review` (exit `2` when BR/EARS missing, `0` when present) and `gate ears-review` against an incomplete then complete ledger fixture (exit `1` then `0`)
