## 1. Preflight Inventory

- [x] 1.1 Re-read `feature_br_to_ears.sh`, `br_to_ears.md`, and `check_requirements_ears_quality.sh`; record the old-responsibility → new-owner inventory (context/gate/skill; no capture, no readiness verb) per the step-by-step guide
- [x] 1.2 Extract every old final-response line (success + infeasibility), gate exit-code rule, `ready_to_ears` precondition, read-only-BR boundary, allowed-write list, EARS pattern set, numbering rule, and `## 16. Linked Artifacts` propagation rule into the parity checklist
- [x] 1.3 List the scenarios in `tests/ai_scripts/check_requirements_ears_quality_tests.sh` and `tests/ai_scripts/init_br_to_ears_tests.sh` (block-field, pattern, numbering, empty/no-block cases; precondition, read-only-BR, model-produced-file cases) to port

## 2. asdlc-coordinator core — validator and context

- [x] 2.1 Implement `validate/requirements-ears.ts`: port `check_requirements_ears_quality.sh` one-for-one — empty-target fail; per-block `**User Story:**` / `**Acceptance Criteria (EARS):**` / `**Verification:**`; ≥1 bullet and ≥1 valid EARS-pattern bullet per block; allowed-pattern set (incl. bare `THE … SHALL …` and `WHEN … AND WHILE …`, case-insensitive); independent sequential 1-based numbering with duplicate detection for `Requirement` and `NFR`; no-blocks fail; exit `0/1/2`; export from `validate/index.ts`
- [x] 2.2 Implement `context/requirements-ears.ts`: resolve feature path + read-only `feature_br_summary.md` (exit `2` if absent) + `requirements_ears.md` target; verify `ready_to_ears: true` in `## 1. Document Meta` (reuse the CRP-132 BR-summary meta reader) and exit `2` with a "run `readiness br-clarification` first" message when missing/not-true; emit one block with workspace root, feature root, target EARS artifact path (`requirements_ears.md`), read-only BR source, allowed-write list (`requirements_ears.md` only), exact gate command, skill-relative asset refs (rule inlined in `SKILL.md`); export from `context/index.ts`

## 3. asdlc-coordinator core — CLI wiring

- [x] 3.1 Register `requirements-ears` in `gateRegistry` and `contextRegistry` in `cli/run.ts`
- [x] 3.2 Confirm unknown-step + missing-arg usage errors behave with parity to the other verbs for `gate requirements-ears` / `context requirements-ears`

## 4. asdlc-coordinator core — tests

- [x] 4.1 `gate requirements-ears` tests: exit `0` complete artifact; exit `1` for each — empty target, missing each block field, invalid EARS bullet, no-valid-pattern criteria, non-sequential/duplicate numbering (Requirement and NFR), no blocks found; exit `2` runtime error; assert actionable failure messages — porting `check_requirements_ears_quality_tests.sh`
- [x] 4.2 `context requirements-ears` tests: assembled block content + explicit target EARS artifact path (`requirements_ears.md`) + exact gate command + read-only BR source + allowed-write list; missing `feature_br_summary.md` exits `2`; `ready_to_ears` missing/not-true exits `2` with the readiness hint; skill-relative asset paths (no `.codex`/`.claude` hardcoding); absolute feature path
- [x] 4.3 Run `npm test --workspace packages/asdlc-coordinator` green

## 5. Skill package

- [x] 5.1 Create `packages/installer/_data/skills/overmind-requirements-ears/SKILL.md` with frontmatter, purpose, required invocation, exact `context`/`gate requirements-ears` commands, allowed-write list (`requirements_ears.md` only), gate exit-code handling, and BOTH literal final-response lines (success + infeasibility) — only here
- [x] 5.2 Inline `br_to_ears.md` into `SKILL.md` (output-format baseline, source-of-truth/`[Inference]`/`Unresolved gap:` rules, atomic splitting, allowed EARS patterns, prohibited content, deterministic ordering/numbering, runtime path bindings, read-only BR boundary, `## 16. Linked Artifacts` propagation); do not keep a separate rule asset
- [x] 5.3 Copy `reqirements_ears_TEMPLATE.md` and `reqirements_ears_GOLDEN_EXAMPLE.md` into `assets/` (preserve the existing filenames); use skill-relative `assets/...` references
- [x] 5.4 Run the parity sweep table (old script+rule+helper vs SKILL.md+context+gate); resolve every `missing` row — confirm both terminal lines live only in `SKILL.md`, the `ready_to_ears` precondition moved to context, and the read-only-BR boundary is preserved

## 6. Installer + setup staging

- [x] 6.1 Add `overmind-requirements-ears` to `PACKAGED_SKILLS` in `packages/installer/src/init.ts` (install to `.codex`/`.claude`, payload validation, install metadata); keep `.overmind/overmind.js` the single CLI
- [x] 6.2 Add `overmind-requirements-ears` to skill-staging in `project_setup_first_init_machine.sh`; add preflight checks for its canonical folder/`SKILL.md`/`assets/`
- [x] 6.3 Remove staging of `feature_br_to_ears.sh` (the `INIT_BR_TO_EARS_SCRIPT` constant + command array), `br_to_ears.md` (rule array), and `check_requirements_ears_quality.sh` (helper array); keep the step 5.1 review assets staged; ensure update mode removes stale staged copies
- [x] 6.4 Run `npm test --workspace packages/installer` and `bash tests/ai_scripts/project_setup_asdlc_tests.sh` green

## 7. Feature e2e wiring

- [x] 7.1 Add `build_requirements_ears_prompt` + `run_requirements_ears_skill` (thin launcher: runtime bindings + exact `context`/`gate requirements-ears` commands only; no literal final lines, no gate handling), mirroring the phase 4.2 launcher; apply the migration-guide e2e safeguards explicitly: run Codex from the ASDLC runtime root, require/assert `MODEL_CMD=codex`, preflight-check that the installed `overmind-requirements-ears` skill and `.overmind/overmind.js` exist before launching, and capture the model exit code without leaking `set -e`
- [x] 7.2 Rewire phase 5 to run the requirements-ears skill session and remove the `feature_br_to_ears.sh` entry from the phase 5 `phase_scripts` list; add restart guidance resuming at phase 5; no deterministic post-skill step
- [x] 7.3 Update `tests/ai_scripts/project_add_feature_e2e_tests.sh`: assert phase 5 launches the skill (stub `codex`), prompt has exact commands and neither literal final line, the orchestrator does not run the gate, the launcher requires `MODEL_CMD=codex`, and phase 5 fails before launching when the installed `overmind-requirements-ears` skill or `.overmind/overmind.js` is missing; run green

## 8. Clean break + docs

- [x] 8.1 Delete `feature_br_to_ears.sh`, `br_to_ears.md`, `check_requirements_ears_quality.sh`, `tests/ai_scripts/init_br_to_ears_tests.sh`, `tests/ai_scripts/check_requirements_ears_quality_tests.sh`
- [x] 8.2 Remove all references to the deleted files from setup staging arrays, shell test listings, the `CLAUDE.md` and `AGENTS.md` test lists, `README.md`/`QUICKRUN.md`
- [x] 8.3 Mark step 5 **done** in `design_docs/to_skills_migration/migration_to_skill_architecture_overview.md` Steps→Skills table

## 9. Verification

- [x] 9.1 Run `npm test --workspace packages/asdlc-coordinator`, `npm test --workspace packages/installer`, `bash tests/ai_scripts/project_setup_asdlc_tests.sh`, `bash tests/ai_scripts/project_add_feature_e2e_tests.sh`
- [x] 9.2 `git diff --check` and `openspec validate crp-133-migrate-br-to-ears-to-skill --strict`
- [x] 9.3 Manual smoke: build, stage workspace, confirm `.codex`/`.claude` `overmind-requirements-ears/SKILL.md` + `.overmind/overmind.js`, run `context requirements-ears` (exit `2` when not ready, `0` when ready) and `gate requirements-ears` against an incomplete then complete fixture (exit `1` then `0`)
