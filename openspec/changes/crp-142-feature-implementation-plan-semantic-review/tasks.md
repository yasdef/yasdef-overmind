## 1. Gate Module (asdlc-coordinator)

- [x] 1.1 Add `packages/asdlc-coordinator/src/validate/plan-semantic-review.ts` — resolve the feature path, derive target `implementation_plan_semantic_review.md`; exit `2` when the feature-path arg is missing or the target is absent; exit `1` for an empty/whitespace-only target (parity: absent→`2`, empty/whitespace→`1`)
- [x] 1.2 Port the section anchoring (`## 1. Document Meta`, `## 2. Review Guidance`, `## 3. Findings Ledger`), the `### Finding N -`/`### Finding N :` block boundary, the `parse_kv` list-item parser, and the `trim`/`normalize`/`is_unfilled`/`normalize_state`/`normalize_bool` helpers behavior-for-behavior
- [x] 1.3 Port meta-key checks: all eight required keys (`feature_id`, `feature_title`, `source_implementation_plan`, `source_project_definition`, `source_requirements_ears`, `source_technical_requirements`, `review_status`, `last_updated`) present and not unfilled; `review_status ∈ {in_progress, complete}`
- [x] 1.4 Port findings-ledger consistency: no Finding blocks ⇒ ledger must declare `- no_findings: true` and `review_status` must be `complete`; Finding blocks present ⇒ `no_findings` must not be `true`
- [x] 1.5 Port per-finding validation: all twelve required fields present and filled; `severity ∈ {High, Medium, Low}`; `finding_type` one of the six allowed types; `state ∈ {added, applied, rejected, postponed}`; terminal `delivered_surface_consumption_unclear`/`repo_scaffold_readiness_unclear` requires non-empty `resolution_notes`; `delivered_surface_consumption_unclear` `related_requirements` must reference `(REQ|NFR)-<n>`
- [x] 1.6 Port completion consistency: `review_status == complete` with Finding blocks ⇒ every finding terminal (non-terminal remaining → fail); and the `[UNFILLED]` anywhere → fail check
- [x] 1.7 Aggregate: any failure ⇒ exit `1` with actionable `quality gate failed: ...` messages; exit `0` on clean pass; awk-equivalent runtime failure ⇒ exit `2`
- [x] 1.8 Export `validatePlanSemanticReview` from `packages/asdlc-coordinator/src/validate/index.ts`
- [x] 1.9 Register `plan-semantic-review` in `gateRegistry` in `packages/asdlc-coordinator/src/cli/run.ts`

## 2. Context Module (asdlc-coordinator)

- [x] 2.1 Add `packages/asdlc-coordinator/src/context/plan-semantic-review.ts` — resolve feature path under `projects/<id>/<feature>/`, read active project classes from `init_progress_definition.yaml` (accept `backend`/`frontend`/`mobile`/`infrastructure`; reject unsupported classes with exit `2`), derive supported repo classes (skip `infrastructure`); do **not** require at least one supported repo class (legacy 8.4 parity) — when none is derivable, emit active repo classes as `none` with no applicable surface maps
- [x] 2.2 Require `requirements_ears.md`, `technical_requirements.md`, `prerequisite_gaps.md`, `implementation_plan.md`, and `init_progress_definition.yaml` (exit `2` on any missing); require the applicable surface map (`project_surface_struct_resp_map_{backend,frontend,mobile}.md`) for each active repo class (exit `2` naming the class whose map is absent, porting `collect_applicable_surface_maps`)
- [x] 2.3 Emit one context block with workspace root, feature root, project root, active repo classes, the two mutable target paths (`implementation_plan.md`, `implementation_plan_semantic_review.md`), the read-only manifest as stable one-per-line `- read_only_input: <path>` entries (`init_progress_definition.yaml`, `requirements_ears.md`, `technical_requirements.md`, `prerequisite_gaps.md`, plus each applicable surface map) — matching the format the e2e launcher greps (`sed -n 's/^- read_only_input: //p'`) so the launcher snapshots exactly this manifest — skill-relative asset references (template + golden example), and both gate commands (`node .overmind/overmind.js gate plan-semantic-review <feature-path>` and `node .overmind/overmind.js gate implementation-plan <feature-path>`)
- [x] 2.4 Export `buildPlanSemanticReviewContext` from `packages/asdlc-coordinator/src/context/index.ts`
- [x] 2.5 Register `plan-semantic-review` in `contextRegistry` in `packages/asdlc-coordinator/src/cli/run.ts`

## 3. TS Tests — Gate (asdlc-coordinator)

- [x] 3.1 Add gate test: exit `0` with a valid `no_findings: true` ledger (`review_status: complete`, no Finding blocks)
- [x] 3.2 Add gate test: exit `0` with a valid findings-present ledger (all fields filled, terminal states, valid enums)
- [x] 3.3 Add gate tests: exit `1` for each missing required section (Document Meta, Review Guidance, Findings Ledger)
- [x] 3.4 Add gate tests: exit `1` for a missing/unfilled meta key and for an invalid `review_status`
- [x] 3.5 Add gate tests: exit `1` for findings-ledger inconsistency — no Finding blocks without `no_findings: true`, `no_findings: true` with `review_status: in_progress`, and `no_findings: true` with Finding blocks present
- [x] 3.6 Add gate tests: exit `1` for per-finding failures — missing required field, invalid `severity`, invalid `finding_type`, invalid `state`, terminal `delivered_surface_consumption_unclear`/`repo_scaffold_readiness_unclear` with empty `resolution_notes`, and `delivered_surface_consumption_unclear` without a `REQ-*`/`NFR-*` reference
- [x] 3.7 Add gate test: exit `1` for a `complete` review with a non-terminal (`added`) finding, and exit `1` when an `[UNFILLED]` placeholder is present
- [x] 3.8 Add gate tests: exit `2` when the feature-path arg is missing and when the target artifact is absent; exit `1` when the target is zero-byte or whitespace-only
- [x] 3.9 Run `npm test --workspace packages/asdlc-coordinator` and confirm all tests pass

## 4. TS Tests — Context (asdlc-coordinator)

- [x] 4.1 Add context test: exits `0` and emits workspace root, feature root, active repo classes, both mutable targets, and both gate commands for a valid two-class feature
- [x] 4.2 Add context test: read-only manifest lists `init_progress_definition.yaml`, `requirements_ears.md`, `technical_requirements.md`, `prerequisite_gaps.md`, and the applicable surface map for each active repo class
- [x] 4.3 Add context test: `infrastructure` class is silently skipped, while an unsupported project class fails resolution with exit `2` naming the class
- [x] 4.3a Add context test: an `infrastructure`-only project resolves with exit `0`, emits active repo classes as `none`, and lists no applicable surface maps (legacy 8.4 parity — zero supported repo classes allowed)
- [x] 4.4 Add context tests: exit `2` when any of `requirements_ears.md`, `technical_requirements.md`, `prerequisite_gaps.md`, `implementation_plan.md`, or `init_progress_definition.yaml` is missing
- [x] 4.5 Add context test: exit `2` when the applicable surface map for an active repo class (e.g. `project_surface_struct_resp_map_backend.md`) is absent, naming the class
- [x] 4.6 Add context test: exit `2` when the feature path does not resolve under `projects/<id>/<feature>/`
- [x] 4.7 Run `npm test --workspace packages/asdlc-coordinator` and confirm all tests pass

## 5. Skill Package

- [x] 5.1 Create `packages/installer/_data/skills/overmind-plan-semantic-review/assets/` and copy `overmind/templates/implementation_plan_semantic_review_TEMPLATE.md` and `overmind/golden_examples/implementation_plan_semantic_review_GOLDEN_EXAMPLE.md` into it
- [x] 5.2 Create `packages/installer/_data/skills/overmind-plan-semantic-review/SKILL.md` with YAML frontmatter, Required Invocation (context command, allowed write list = `implementation_plan.md` + `implementation_plan_semantic_review.md`, the two-gate discipline — **run `gate plan-semantic-review` after every write or repair of the review ledger, including the initial findings ledger written before pausing for operator input, and run `gate implementation-plan` after every write or repair of the plan** — and gate exit-code handling), the literal success line (`Implementation plan semantic review phase is finished. Nothing else to do now; press Ctrl-C so orchestrator can start the next phase`), the literal infeasibility line (`implementation plan semantic review cannot be completed with current plan/requirements/technical inputs. Please provide instructions what to do, or adjust inputs and rerun this phase`), the exact operator question (`Which finding numbers should I apply to implementation_plan.md? (examples: 1,3 | all | none | postpone 2 | reject 4)`), an `Assets` section with skill-relative template and golden example paths, and the inlined rule from `implementation_plan_semantic_review_rule.md` (purpose, inputs, review scope, allowed finding types, finding state rules, user interaction rules, editing rules, minimal-plan-patch guidance, deferred-class scaffold readiness guidance, completion)
- [x] 5.3 Define one operator question per ledger decision round and prevent the Required Invocation and User Interaction Rules sections from triggering duplicate asks

## 6. Installer

- [x] 6.1 Add `"overmind-plan-semantic-review"` to `PACKAGED_SKILLS` array in `packages/installer/src/init.ts`
- [x] 6.2 Add installer tests: fresh install copies `overmind-plan-semantic-review` to `.codex/skills/` and `.claude/skills/` with `SKILL.md` and `assets/`
- [x] 6.3 Add installer tests: install fails before writing runner targets when the packaged `overmind-plan-semantic-review` skill is missing `SKILL.md`, and (separately) when it is missing its `assets/` directory
- [x] 6.4 Run `npm test --workspace packages/installer` and confirm all tests pass
- [x] 6.5 Add packaged-skill coverage for the single-question contract and rerun the installer suite

## 7. Setup Staging (project_setup_first_init_machine.sh)

- [x] 7.1 Add `"overmind-plan-semantic-review"` to `SKILL_NAMES` array
- [x] 7.2 Remove the `feature_implementation_plan_semantic_review.sh` command constant and all staging array references, AND add `"feature_implementation_plan_semantic_review.sh"` to `OBSOLETE_STAGED_COMMAND_FILES` so update mode prunes the stale command
- [x] 7.3 Remove the `implementation_plan_semantic_review_rule.md` rule constant and staging references
- [x] 7.4 Remove the `check_implementation_plan_semantic_review_quality.sh` helper constant and staging references
- [x] 7.5 Remove the `implementation_plan_semantic_review_TEMPLATE.md` flat template staging constant and references
- [x] 7.6 Remove the `implementation_plan_semantic_review_GOLDEN_EXAMPLE.md` flat golden-example staging constant and references
- [x] 7.7 Update the quickrun docs block to reference the new skill and remove the old bash command line
- [x] 7.8 Add a setup test asserting update mode removes a stale `.commands/feature_implementation_plan_semantic_review.sh` (and that the `overmind-plan-semantic-review` runner skill folders are present), plus fresh-setup omission of the migrated command/rule/helper
- [x] 7.9 Run `bash tests/ai_scripts/project_setup_asdlc_tests.sh` and confirm all tests pass

## 8. E2e Runner (project_add_feature_e2e.sh)

- [x] 8.1 Add `PLAN_SEMANTIC_REVIEW_SKILL_FILE` constant pointing to `.codex/skills/overmind-plan-semantic-review/SKILL.md` and reuse the `implementation_plan_semantic_review` model phase
- [x] 8.2 Add `build_plan_semantic_review_prompt` function: prompt includes skill name, workspace root, feature path, `context plan-semantic-review` command, `gate plan-semantic-review` command, `gate implementation-plan` command, and the OVERMIND_CLI_FILE path; must not include literal final-response lines from SKILL.md
- [x] 8.3 Add `run_plan_semantic_review_skill` function following the established migrated-launcher pattern (as in `run_implementation_plan_skill`): invoke `node .overmind/overmind.js context plan-semantic-review <feature-path>` **once**, capture its output, and on a nonzero context exit echo it to stderr and return that code; extract the read-only inputs to snapshot by parsing exactly the context command's stable `- read_only_input: <path>` lines (do NOT independently resolve active classes or surface-map paths in the launcher — that logic is owned by `context/plan-semantic-review.ts`, and duplicating it risks divergence that leaves inputs unguarded); resolve each and `die` if a listed input is missing; snapshot each; then launch Codex; do NOT snapshot/guard `implementation_plan.md` (mutable target); do NOT run any `overmind sync`
- [x] 8.3a Apply the D7 exit-path ordering in `run_plan_semantic_review_skill` (launched-session function), matching `run_implementation_plan_skill`: (1) capture the model exit code under `set +e`; (2) always run the read-only `cmp` guards first, with a corruption `die` taking precedence over the model exit (guard runs before the rc check); (3) return any launched-model nonzero exit — **including `30`** — unchanged so `run_phase_by_index` maps it to `PHASE_EXECUTION_FAILED_RC`/`40`, without asserting output and without treating `30` as a decline; (4) assert `implementation_plan_semantic_review.md` was produced ONLY after a clean (`0`) model exit
- [x] 8.4 Replace the phase-8.4 legacy bash invocation (`feature_implementation_plan_semantic_review.sh`) with a `run_plan_semantic_review_skill` call in `run_phase_by_index`; keep the decline/skip signals owned by `run_phase_by_index` on the pre-launch confirmation-declined path only (never emitted by the skill function). Because 8.4 is the **final** phase, an ordinary decline returns `30` (no later required phase) and a closed input stream returns `20`; the `10` branch (`has_later_required_phase`) is unreachable for 8.4. Preserve the existing before/after phase-8.4 checkpoint commits and the pre-launch decline pass-through
- [x] 8.5 Ensure the e2e does NOT run either gate itself for phase 8.4 — only the model/skill owns the gate loop
- [x] 8.6 Allow explicit `--resume 8.4` to reuse a valid cached feature when required-step discovery reports no unfinished features; preserve no-resume completed-feature behavior

## 9. E2e Tests (project_add_feature_e2e_tests.sh)

- [x] 9.1 Add test: phase-8.4 prompt loads `overmind-plan-semantic-review` skill and includes the exact `context plan-semantic-review` command
- [x] 9.2 Add test: phase-8.4 prompt includes both `gate plan-semantic-review` and `gate implementation-plan` commands
- [x] 9.3 Add test: phase-8.4 prompt does not duplicate literal final-response lines from SKILL.md
- [x] 9.4 Add test: phase-8.4 e2e does not shell out to either gate command itself
- [x] 9.5 Add test: no `overmind sync` is invoked for the phase-8.4 session
- [x] 9.6 Add test: `run_plan_semantic_review_skill` fails the phase when a read-only input (`technical_requirements.md`) is mutated during the session (simulated via cmp mismatch)
- [x] 9.7 Add test: `run_plan_semantic_review_skill` fails the phase when an applicable surface map is mutated during the session
- [x] 9.8 Add test: `run_plan_semantic_review_skill` does NOT fail the phase when only `implementation_plan.md` is changed (mutable target)
- [x] 9.9 Add test: `run_plan_semantic_review_skill` fails the phase when `implementation_plan_semantic_review.md` is not produced after a clean (`0`) model exit
- [x] 9.10 Add test: a launched Codex session exiting nonzero — **including `30`** — with inputs unchanged causes `run_plan_semantic_review_skill` to return the nonzero exit so `run_phase_by_index` maps it to phase failure (`PHASE_EXECUTION_FAILED_RC`); it is NOT treated as a clean decline and no output is asserted
- [x] 9.11 Add test: a pre-launch decline for the final phase 8.4 (confirmation declined so `run_phase_by_index` returns `30`, or `20` on a closed input stream — never `10`, which is unreachable for the last phase) launches no session, runs no read-only guard, and runs no missing-output assertion, and the skip/decline signal propagates as designed
- [x] 9.12 Add test: the read-only `cmp` guard runs on every launched-session exit path — when the model mutates a read-only input AND exits nonzero, the phase fails with the read-only-corruption error, which takes precedence over the returned model exit status (corruption wins on double-failure)
- [x] 9.13 Run `bash tests/ai_scripts/project_add_feature_e2e_tests.sh` and confirm all tests pass
- [x] 9.14 Add a regression test for `--resume 8.4` with a valid completed cached feature, then rerun the full e2e suite

## 10. Parity Sweep Before Deletion (blocks Section 11)

Per the migration guide (Preflight Inventory and Preserve Instruction Quality), record a responsibility inventory and a comparison table before deleting any legacy file; any `missing` row blocks deletion until its new owner is in place.

- [x] 10.1 Record the old→new responsibility inventory: user/finding-selection interaction (SKILL.md, live model session — no capture module), dynamic context assembly (`context/plan-semantic-review.ts`), artifact generation + apply-findings loop (SKILL.md), structural review-ledger gate (`validate/plan-semantic-review.ts`), the deterministic read-only-input immutability guard (e2e launcher `cmp`), and cross-step sequencing (transitional e2e wrapper)
- [x] 10.2 Build the comparison table and confirm each row is `kept`/`changed` (never `missing`) before deleting: every `build_prompt` hard constraint and Context line, every `implementation_plan_semantic_review_rule.md` constraint (six finding types, four states, four-step reachability heuristic, in-flight sibling overlap rule, `repo_scaffold_readiness_unclear` rule, minimal-plan-patch guidance, editing/completion rules), every `check_implementation_plan_semantic_review_quality.sh` check (sections, meta keys, `review_status`, `no_findings` consistency, per-finding fields/enums, terminal-resolution-notes, `delivered_surface_consumption_unclear` REQ/NFR ref, complete/non-terminal, `[UNFILLED]`), the two literal final-response lines (success/failure, in SKILL.md only), the exact operator question string, and every scenario in `init_feature_implementation_plan_semantic_review_tests.sh` (ported to TS gate/context tests or e2e tests)
- [x] 10.3 Confirm the deterministic read-only-input immutability guard is preserved in a deterministic owner (e2e launcher `cmp`, not advisory SKILL.md text) and covered by a test (Section 9), and that no literal final-response line is duplicated in the e2e prompt — any unresolved `missing` row blocks Section 11

## 11. Delete Old Bash Artifacts

- [x] 11.1 Delete `overmind/scripts/feature_implementation_plan_semantic_review.sh`
- [x] 11.2 Delete `overmind/rules/implementation_plan_semantic_review_rule.md`
- [x] 11.3 Delete `overmind/scripts/helper/check_implementation_plan_semantic_review_quality.sh`
- [x] 11.4 Delete `tests/ai_scripts/init_feature_implementation_plan_semantic_review_tests.sh`
- [x] 11.5 Remove the deleted test script from **both** `CLAUDE.md` and `AGENTS.md` test listings, and remove any other deleted-file references (keep the un-migrated `check_implementation_plan_readiness_tests.sh` and `feature_assign_workers_to_implementation_plan_tests.sh`)

## 12. Documentation and Final Checks

- [x] 12.1 Update `README.md` step-8.4 entries: reference the `overmind-plan-semantic-review` skill and `overmind context plan-semantic-review` command; remove the old bash command references
- [x] 12.2 Update `design_docs/to_skills_migration/migration_to_skill_architecture_overview.md` step-8.4 row: mark as **done** (CRP-142)
- [x] 12.3 Update `tests/ai_scripts/project_setup_update_project_tests.sh`: remove any `feature_implementation_plan_semantic_review.sh` / rule / helper copy and assertion lines for the deleted assets
- [x] 12.4 Run `bash tests/ai_scripts/project_setup_asdlc_tests.sh` and confirm all tests pass
- [x] 12.5 Run `bash tests/ai_scripts/project_setup_update_project_tests.sh` and confirm all tests pass
- [x] 12.6 Run `git diff --check` — no whitespace errors
- [x] 12.7 Run `openspec validate crp-142-feature-implementation-plan-semantic-review --strict` and confirm the change validates
