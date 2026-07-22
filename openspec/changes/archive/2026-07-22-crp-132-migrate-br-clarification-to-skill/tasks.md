## 1. Preflight Inventory

- [x] 1.1 Re-read `feature_user_br_clarification.sh`, `user_br_clarification_rule.md`, `check_user_br_clarification_quality.sh`, and `feature_br_check_ears_readiness.sh`; record the old-responsibility → new-owner inventory (capture/context/gate/readiness/skill) per the step-by-step guide
- [x] 1.2 Extract every old final-response line, gate exit-code rule, skip condition, ledger marker format, link-preservation rule, and `ready_to_ears` precondition into the parity checklist
- [x] 1.3 List the scenarios in `tests/ai_scripts/init_user_br_clarification_tests.sh` and `tests/ai_scripts/init_br_check_ears_readiness_tests.sh` (incl. `TEST_USER_HELPER_FAIL` / `TEST_REPO_HELPER_FAIL`, ready vs no-ready-class, absolute feature path) to port

## 2. asdlc-coordinator core — parsers and validators

- [x] 2.1 Add a `parse/` BR-summary helper: read/flip `## 1. Document Meta` keys (`ready_to_ears` read + `false→true` flip with precondition) and detect non-rised `- rised_item_N:` entries in `## 3. Unresolved Items Ledger (Rised)`, porting the awk semantics (quote-stripping, quoted-example lines ignored, missing-flag-means-unresolved)
- [x] 2.2 Implement `validate/br-clarification.ts`: run `validateTaskToBr` as base; on pass, fail `1` with actionable `missing:` line when any tracked ledger entry is unresolved; exit `0` when none/empty; exit `2` on runtime error; export from `validate/index.ts`
- [x] 2.3 Implement `context/br-clarification.ts`: resolve feature path + `feature_br_summary.md` (exit `2` if absent) + `missing_br_data.md` (exit `2` if absent); emit one block with workspace root, feature root, allowed-write list, exact gate command, skill-relative asset refs (rule is inlined in `SKILL.md`, not a separate referenced file); export from `context/index.ts`
- [x] 2.4 Implement `readiness/br-clarification.ts` (replacing `readinessStub`): call the shared validator functions in-process (`validateBrClarification`, `validateRepoBrScan`) — never the `overmind gate` CLI verb; evaluate `validateBrClarification` (task-to-br base + unresolved-ledger check, so skipped/unanswered items block readiness — documented superset of the old bare `task-to-br` check); resolve `init_progress_definition.yaml`; reuse `repo/collect-ready-paths`; conditionally evaluate `validateRepoBrScan`; flip `ready_to_ears` with precondition; export from `readiness/index.ts`

## 3. asdlc-coordinator core — CLI wiring

- [x] 3.1 Register `br-clarification` in `gateRegistry` and `contextRegistry` in `cli/run.ts`
- [x] 3.2 Add a `readinessRegistry` (`br-clarification` → readiness handler) and a `readiness` verb branch in the CLI dispatch; update the usage string to `capture|context|gate|sync|readiness`
- [x] 3.3 Handle unknown readiness step + missing-arg usage errors with parity to the other verbs

## 4. asdlc-coordinator core — tests

- [x] 4.1 Parser tests: non-rised detection edge cases (quoted examples ignored, missing flag, `non-rised`/`not-rised`, `rised=true`) and `ready_to_ears` read/flip + precondition
- [x] 4.2 `gate br-clarification` tests: exit `0` all-rised / empty ledger, exit `1` each unresolved variant with `missing:` line, base task-to-br failure surfaced verbatim, exit `2` runtime error
- [x] 4.3 `context br-clarification` tests: assembled block content + gate command, missing `missing_br_data.md` exits `2`, skill-relative asset paths (no `.codex`/`.claude` hardcoding)
- [x] 4.4 `readiness br-clarification` tests: pass with no ready class (skip notice + flip), pass with ready class (both validators), `br-clarification` validator fail blocks (incl. a `skip for now` / `rised=false` item blocking the flip), repo-br-scan validator fail blocks, `ready_to_ears` precondition failure (absent / not-false), absolute feature path, and assert the handler reuses validator functions without spawning the `overmind gate` CLI — porting the two bash suites' scenarios
- [x] 4.5 Run `npm test --workspace packages/asdlc-coordinator` green

## 5. Skill package

- [x] 5.1 Create `packages/installer/_data/skills/overmind-br-clarification/SKILL.md` with frontmatter, purpose, required invocation, exact context/gate commands, allowed-write list, gate exit-code handling, and the literal final-response line (only here)
- [x] 5.1a In `SKILL.md`, specify the sequential one-at-a-time clarification protocol: show the full list of unresolved questions + brief process note, ask one question per turn waiting for each reply, support `skip for now` as a defer-within-the-loop (item stays `rised=false`, move to next), and the terminal behavior — keep working the loop (re-offer deferred questions in new rounds), never declare completion / emit the final line / advance to the next phase while any item is `rised=false`; complete only on gate exit `0` (all `rised=true`)
- [x] 5.2 Inline `user_br_clarification_rule.md` into `SKILL.md` (business-only questions, `rised` ledger semantics, pointer-only `## 6. Latest User Answers` entries, deterministic ledger markers, `## 16. Linked Artifacts` preservation, runtime path bindings); do not keep a separate rule asset
- [x] 5.3 Copy `feature_br_summary_TEMPLATE.md` and `feature_br_summary_GOLDEN_EXAMPLE.md` into `assets/`; use skill-relative `assets/...` references
- [x] 5.4 Run the parity sweep table (old script+rule+helper vs SKILL.md+context+gate+readiness); resolve every `missing` row before proceeding

## 6. Installer + setup staging

- [x] 6.1 Extend the packaged-skill set in `packages/installer/src/init.ts` to include `overmind-br-clarification` (install to `.codex`/`.claude`, payload validation, install metadata); keep `.overmind/overmind.js` the single CLI
- [x] 6.2 Extend skill-staging in `project_setup_first_init_machine.sh` to stage `overmind-br-clarification`; add preflight checks for its canonical folder/`SKILL.md`/`assets/`
- [x] 6.3 Remove staging of `feature_user_br_clarification.sh`, `feature_br_check_ears_readiness.sh`, `user_br_clarification_rule.md`, and `check_user_br_clarification_quality.sh`; ensure update mode removes stale staged copies
- [x] 6.4 Run `npm test --workspace packages/installer` and `bash tests/ai_scripts/project_setup_asdlc_tests.sh` green

## 7. Feature e2e wiring

- [x] 7.1 Add `build_br_clarification_prompt` + `run_br_clarification_skill` (thin launcher: runtime bindings + exact context/gate commands only; no literal final line, no gate handling)
- [x] 7.2 Rewire phase 4.2 to run the clarification skill session, then `node .overmind/overmind.js readiness br-clarification <feature-path>` deterministically; remove the two deleted bash scripts from `phase_scripts` 4.2 and add restart guidance resuming at 4.2
- [x] 7.3 Update `tests/ai_scripts/project_add_feature_e2e_tests.sh`: assert phase 4.2 launches the skill, prompt has exact commands and no literal final line, model owns the gate, readiness runs deterministically after the skill; run green

## 8. Clean break + docs

- [x] 8.1 Delete `feature_user_br_clarification.sh`, `feature_br_check_ears_readiness.sh`, `user_br_clarification_rule.md`, `check_user_br_clarification_quality.sh`, `tests/ai_scripts/init_user_br_clarification_tests.sh`, `tests/ai_scripts/init_br_check_ears_readiness_tests.sh`
- [x] 8.2 Remove all references to the deleted files from setup staging arrays, shell test listings, the `CLAUDE.md` and `AGENTS.md` test lists, `README.md`/`QUICKRUN.md`
- [x] 8.3 Mark step 4.2 **done** in `design_docs/to_skills_migration/migration_to_skill_architecture_overview.md` Steps→Skills table (note `overmind readiness` verb addition)

## 9. Verification

- [x] 9.1 Run `npm test --workspace packages/asdlc-coordinator`, `npm test --workspace packages/installer`, `bash tests/ai_scripts/project_setup_asdlc_tests.sh`, `bash tests/ai_scripts/project_add_feature_e2e_tests.sh`
- [x] 9.2 `git diff --check` and `openspec validate crp-132-migrate-br-clarification-to-skill --strict`
- [x] 9.3 Manual smoke: build, stage workspace, confirm `.codex`/`.claude` `overmind-br-clarification/SKILL.md` + `.overmind/overmind.js`, run `gate br-clarification` (exit `1` then `0`) and `readiness br-clarification` against fixtures
