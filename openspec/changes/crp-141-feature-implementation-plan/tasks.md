## 1. Gate Module — Catalog Extractors (asdlc-coordinator)

- [x] 1.1 Add `packages/asdlc-coordinator/src/validate/implementation-plan.ts` — resolve the feature path, derive target `implementation_plan.md`, sibling `requirements_ears.md`/`technical_requirements.md`/`prerequisite_gaps.md`, and parent `init_progress_definition.yaml`; exit `2` when the target path arg is missing, target is absent, any required sibling/definition is absent; exit `1` for an empty/whitespace-only target (legacy parity: absent→`2`, empty→`1`, strengthened to reject whitespace-only)
- [x] 1.2 Port `extract_meta_project_classes` — read active project classes from `init_progress_definition.yaml` (inline `[a, b]` and block-list forms), keep only `backend`/`frontend`/`mobile` for the active-classes set, `helper_fail` (exit `2`) when none found
- [x] 1.3 Port `extract_requirement_refs` — harvest `REQ-*`/`NFR-*` ids **only from `###` heading lines** (awk guard `/^###[[:space:]]+/`): `### Requirement N`, `### NFR N`, and any `(REQ|NFR)-N` tokens appearing inline *within those heading lines*; `REQ-*`/`NFR-*` tokens in requirement body text (bullets/prose) are ignored; deduped; `helper_fail` when none found
- [x] 1.4 Port `extract_technical_evidence_catalog` from `technical_requirements.md` behavior-for-behavior: section-anchored on `## 4. Requirement Coverage and Gaps` (→ `req_all`/`req_unresolved` `gap/TECH_REQ-<suffix>` tokens keyed by `gap_status: fully_implemented` / `gap_to_close: no remaining gap|none|n/a`) and `## 5. Impacted Components` (→ `comp_all`/`comp_unresolved` `comp/<slug>` tokens via the `slugify` rule, and `repo_unresolved` repos from `repo:` + unresolved `gap_to_close`), with `flush_requirement`/`flush_component` boundaries at section changes and EOF; `helper_fail` when no req/comp tokens found
- [x] 1.5 Port the two `prerequisite_gaps.md` extractors: scheduled `slice_ref`s (`status: scheduled_in_slices` with a filled, non-`none` `slice_ref`, evaluated from the complete block independent of field order per D10) and required missing operator-facing surfaces (`surface_kind: required_missing_user_reachable_surface` with `status ∈ {scheduled_in_slices, unmet}` and a filled, non-`none` `surface_identity`), each deduped
- [x] 1.6 Export `validateImplementationPlan` from `packages/asdlc-coordinator/src/validate/index.ts`
- [x] 1.7 Register `implementation-plan` in `gateRegistry` in `packages/asdlc-coordinator/src/cli/run.ts`

## 2. Gate Module — Per-Step + Whole-Plan Validation (asdlc-coordinator)

- [x] 2.1 Port per-step structural checks (`validate_previous_step` + heading handler): strictly-increasing unique `<major>.<minor>` step ids; ≥1 valid `[REQ-*]`/`[NFR-*]` heading ref (unknown ref → fail; zero refs → fail); exactly-once `#### Repo:` (∈ active classes, ∈ {backend,frontend,mobile}), `#### Depends on:`, `#### Evidence:`, `#### Preserved Surface:` (duplicate/empty each fail); ≥3 checklist bullets; first bullet `Plan and discuss the step`; a `Review step implementation` bullet; `#### Assigned:`/`#### Coordination:`/bullet-before-heading guards
- [x] 2.2 Port dependency-edge validation: `none` skipped; same-feature entries must reference an earlier known step id; cross-feature entries must match `^[A-Za-z0-9._-]+/[0-9]+(\.[0-9]+)*$` with folder ≠ `.`/`..`; empty entries and duplicate edges per step fail
- [x] 2.3 Port evidence-token validation: split on `,`; `gap/TECH_REQ-(N|NFR-N)` must be in the requirement catalog; `comp/<slug>` (`^comp/[a-z0-9]+(-[a-z0-9]+)*$`) must be in the component catalog; `slice/<ref>` (`^slice/[A-Za-z0-9][A-Za-z0-9_.-]*$`) accepted free-form; empty/duplicate/invalid-format/unknown tokens fail; a step with no valid technical evidence token fails; record covered tokens
- [x] 2.4 Port preserved-surface validation: non-`none` value must pass `has_surface_terms`; step whose heading+bullets `looks_supporting_only` fails; record preserved surfaces with their coordination flag for the END coverage check
- [x] 2.5 Port the canonical-surface matcher helpers (`canonical_surface` gsub chain, `has_surface_terms`, `looks_supporting_only`, `is_weak_content_token`, `surface_matches` specific/content token scoring) behavior-for-behavior
- [x] 2.6 Port whole-plan END coverage checks: no `[UNFILLED]`; ≥1 step; every `repo_unresolved` repo has ≥1 step; every valid requirement id covered by a heading; every `req_unresolved`/`comp_unresolved` token covered by a step evidence token; every scheduled `slice_ref` covered by a `slice/<ref>` token; every required missing surface preserved by a `surface_matches` non-coordination step (unmatched → fail; coordination-only → fail)
- [x] 2.7 Aggregate: any failure ⇒ exit `1` with actionable `quality gate failed: ...` messages; exit `0` on clean pass

## 3. Context Module (asdlc-coordinator)

- [x] 3.1 Add `packages/asdlc-coordinator/src/context/implementation-plan.ts` — resolve feature path under `projects/<id>/<feature>/`, read active project classes from `init_progress_definition.yaml` (accept `backend`/`frontend`/`mobile`/`infrastructure`; reject unsupported classes with exit `2`), derive supported repo classes (`backend`/`frontend`/`mobile`, skip `infrastructure`), require at least one supported repo class (exit `2` otherwise), and require `requirements_ears.md`, `technical_requirements.md`, `feature_contract_delta.md`, `implementation_slices.md`, `prerequisite_gaps.md`, and `init_progress_definition.yaml` (exit `2` on any missing)
- [x] 3.2 Emit one context block with workspace root, feature root, project root, active repo classes, target artifact path (`<feature-path>/implementation_plan.md`), read-only manifest (`init_progress_definition.yaml`, `requirements_ears.md`, `technical_requirements.md`, `feature_contract_delta.md`, `implementation_slices.md`, `prerequisite_gaps.md`), skill-relative asset references (template + golden example), and exact gate command `node .overmind/overmind.js gate implementation-plan <feature-path>`
- [x] 3.3 Export `buildImplementationPlanContext` from `packages/asdlc-coordinator/src/context/index.ts`
- [x] 3.4 Register `implementation-plan` in `contextRegistry` in `packages/asdlc-coordinator/src/cli/run.ts`

## 4. TS Tests — Gate (asdlc-coordinator)

- [x] 4.1 Add gate tests: exit `0` with a valid multi-step, multi-repo `implementation_plan.md` covering all requirement ids, unresolved evidence tokens, scheduled slice_refs, and required surfaces
- [x] 4.2 Add gate tests: exit `1` for step-block structure failures — out-of-order/duplicate step id, missing/unknown heading REQ/NFR ref, zero heading refs, missing/duplicate Repo (and repo outside active classes / not in {backend,frontend,mobile}), missing/duplicate Depends on/Evidence/Preserved Surface, <3 bullets, missing plan bullet, missing review bullet; include the D9 strengthening test: a step with a second non-empty `#### Evidence:` declaration exits `1`; assert legacy message parity for single empty Repo and Evidence declarations
- [x] 4.3 Add gate tests: exit `1` for dependency-edge failures — dependency on unknown/later step, invalid cross-feature dependency, empty entry, duplicate edge; and pass for a valid same-feature and a valid cross-feature dependency
- [x] 4.4 Add gate tests: exit `1` for evidence-token failures — unknown `gap/TECH_REQ-*`, unknown `comp/<slug>`, invalid token format, empty token, duplicate token, step with no valid evidence token; and pass for `slice/<ref>` and catalog-backed tokens
- [x] 4.5 Add gate tests: exit `1` for preserved-surface failures — non-operator-facing preserved surface (`test_fails_when_surface_step_is_supporting_only`), plus the four required-missing-surface fixtures (`test_fails_when_required_login_surface_is_missing_from_plan`, `..._protected_shell_...`, `..._admin_entry_route_...`, `..._lookup_surface_...`); and explicitly port every legacy **positive** matcher scenario: `test_passes_with_equivalent_surface_wording` (canonical-surface fuzzy match, e.g. required "login page" preserved as "operator sign-in screen"), `test_passes_with_equivalent_operator_tool_wording` (CLI/admin-tool surface equivalence, e.g. required "order query CLI command" preserved as "order query admin tool command"), `test_passes_with_coordination_step_beside_preserved_surface_step` (a coordination step alongside a non-coordination step preserving the same required surface passes), and `test_passes_with_no_coordination_step`
- [x] 4.6 Add gate tests: exit `1` for whole-plan coverage failures — `[UNFILLED]` present, no steps, required repo without a step, uncovered requirement id, uncovered unresolved req token, uncovered unresolved comp token, uncovered scheduled slice_ref, required surface not preserved, required surface preserved only by a coordination step (`test_fails_when_coordination_step_is_sole_surface_coverage`)
- [x] 4.7 Add gate tests: exit `1` when target artifact is zero-byte and when it is whitespace-only (strengthened from legacy zero-byte-only `-s`), and exit `2` when the target artifact is absent (split: empty/whitespace→`1`, absent→`2`)
- [x] 4.8 Add gate tests: exit `2` when target path argument is missing
- [x] 4.9 Add gate tests: exit `2` when `requirements_ears.md`, `technical_requirements.md`, `prerequisite_gaps.md`, or `init_progress_definition.yaml` is absent
- [x] 4.10 Add catalog-extractor unit tests: `extract_technical_evidence_catalog` resolved vs. unresolved requirements/components across `## 4.`/`## 5.` sections; `extract_requirement_refs` heading-only harvest — a `REQ-*`/`NFR-*` token in requirement body text (not on a `###` heading) is NOT extracted (heading-only scope), while heading and inline-in-heading refs are; the two prerequisite extractors (scheduled slice_refs, including `slice_ref` before `status`, and required missing surfaces)
- [x] 4.11 Run `npm test --workspace packages/asdlc-coordinator` and confirm all tests pass

## 5. TS Tests — Context (asdlc-coordinator)

- [x] 5.1 Add context tests: exits `0` and emits workspace root, feature root, active repo classes, target artifact path, and gate command for a valid two-class feature
- [x] 5.2 Add context tests: read-only manifest lists all six inputs (`init_progress_definition.yaml`, `requirements_ears.md`, `technical_requirements.md`, `feature_contract_delta.md`, `implementation_slices.md`, `prerequisite_gaps.md`)
- [x] 5.3 Add context tests: `infrastructure` class is silently skipped, while an unsupported project class fails resolution with exit `2` naming the class
- [x] 5.4 Add context tests: exits `2` when any of `requirements_ears.md`, `technical_requirements.md`, `feature_contract_delta.md`, `implementation_slices.md`, or `prerequisite_gaps.md` is missing
- [x] 5.5 Add context tests: exits `2` when feature path does not resolve under `projects/<id>/<feature>/`
- [x] 5.6 Run `npm test --workspace packages/asdlc-coordinator` and confirm all tests pass

## 6. Skill Package

- [x] 6.1 Create `packages/installer/_data/skills/overmind-implementation-plan/assets/` and copy `overmind/templates/implementation_plan_TEMPLATE.md` and `overmind/golden_examples/implementation_plan_GOLDEN_EXAMPLE.md` into it
- [x] 6.2 Create `packages/installer/_data/skills/overmind-implementation-plan/SKILL.md` with YAML frontmatter, Required Invocation (context command, allowed write artifact list = `implementation_plan.md` only, gate command, gate exit-code handling), the literal success line (`Repository implementation plan phase is finished. Nothing else to do now; press Ctrl-C so orchestrator can start the next phase`), the literal infeasibility line (`repository implementation plan gate cannot pass with current requirements/technical-requirements/contract/slice inputs. Please provide instructions what to do, or adjust inputs and rerun this phase`), an `Assets` section with skill-relative template and golden example paths, and the inlined rule from `implementation_plan_rule.md` (purpose, ownership boundaries, authoritative inputs/outputs, output format baseline, planning rules, coordination plan steps, final self-review, evidence rules, completion gate)

## 7. Installer

- [x] 7.1 Add `"overmind-implementation-plan"` to `PACKAGED_SKILLS` array in `packages/installer/src/init.ts`
- [x] 7.2 Add installer tests: fresh install copies `overmind-implementation-plan` to `.codex/skills/` and `.claude/skills/` with `SKILL.md` and `assets/`
- [x] 7.3 Add installer tests: install fails before writing runner targets when the packaged `overmind-implementation-plan` skill is missing `SKILL.md`, and (separately) when it is missing its `assets/` directory — both incomplete-payload cases per the runner-skill-installation spec
- [x] 7.4 Run `npm test --workspace packages/installer` and confirm all tests pass

## 8. Setup Staging (project_setup_first_init_machine.sh)

- [x] 8.1 Add `"overmind-implementation-plan"` to `SKILL_NAMES` array
- [x] 8.2 Remove `feature_implementation_plan.sh` command constant and all staging array references, AND add `"feature_implementation_plan.sh"` to `OBSOLETE_STAGED_COMMAND_FILES` so update mode prunes the stale command (`.commands` is not an exact manifest; removals rely on this list)
- [x] 8.3 Remove `implementation_plan_rule.md` rule constant and staging references
- [x] 8.4 Remove `check_implementation_plan_quality.sh` helper constant and staging references
- [x] 8.5 Remove `implementation_plan_TEMPLATE.md` flat template staging constant and references
- [x] 8.6 Remove `implementation_plan_GOLDEN_EXAMPLE.md` flat golden-example staging constant and references
- [x] 8.7 Update quickrun docs block to reference the new skill and remove old bash references
- [x] 8.8 Add a setup test asserting update mode removes a stale `.commands/feature_implementation_plan.sh` (and that the `overmind-implementation-plan` runner skill folders are present), plus fresh-setup omission of the migrated command/rule/helper
- [x] 8.9 Run `bash tests/ai_scripts/project_setup_asdlc_tests.sh` and confirm all tests pass

## 9. E2e Runner (project_add_feature_e2e.sh)

- [x] 9.1 Add `IMPLEMENTATION_PLAN_SKILL_FILE` constant pointing to `.codex/skills/overmind-implementation-plan/SKILL.md` and an `IMPLEMENTATION_PLAN_MODEL_PHASE` (`repository_implementation_plan`) constant
- [x] 9.2 Add `build_implementation_plan_prompt` function: prompt includes skill name, workspace root, feature path, `context implementation-plan` command, `gate implementation-plan` command, and OVERMIND_CLI_FILE path; must not include literal final-response lines from SKILL.md
- [x] 9.3 Add `run_implementation_plan_skill` function: snapshot `init_progress_definition.yaml`, `requirements_ears.md`, `technical_requirements.md`, `feature_contract_delta.md`, `implementation_slices.md`, and `prerequisite_gaps.md` before the session; launch Codex with the skill prompt; `cmp`-assert every snapshotted read-only input byte-unchanged after the session on every exit path (read-only-corruption error wins on double-failure); assert `implementation_plan.md` was produced; do NOT run any `overmind sync` (step 8.3 has no pre-session sync)
- [x] 9.4 Replace the phase-8.3 legacy bash invocation (`feature_implementation_plan.sh`) with a `run_implementation_plan_skill` call in `run_phase_by_index`
- [x] 9.5 Ensure the e2e does NOT run the gate itself for phase 8.3 — only the model/skill owns the gate loop

## 10. E2e Tests (project_add_feature_e2e_tests.sh)

- [x] 10.1 Add test: phase-8.3 prompt loads `overmind-implementation-plan` skill and includes exact `context implementation-plan` command
- [x] 10.2 Add test: phase-8.3 prompt includes `gate implementation-plan` command
- [x] 10.3 Add test: phase-8.3 prompt does not duplicate literal final-response lines from SKILL.md
- [x] 10.4 Add test: phase-8.3 e2e does not shell out to the gate command itself
- [x] 10.5 Add test: no `overmind sync` is invoked for the phase-8.3 session
- [x] 10.6 Add test: `run_implementation_plan_skill` fails the phase when a read-only input (`technical_requirements.md`) is mutated during the session (simulated via cmp mismatch)
- [x] 10.7 Add test: `run_implementation_plan_skill` fails the phase when `prerequisite_gaps.md` is mutated during the session
- [x] 10.8 Add test: `run_implementation_plan_skill` fails the phase when `implementation_plan.md` is not produced after a successful model exit
- [x] 10.9 Add test: read-only-corruption error takes precedence when the model both mutates a read-only input and fails to produce the output (double-failure)
- [x] 10.10 Run `bash tests/ai_scripts/project_add_feature_e2e_tests.sh` and confirm all tests pass

## 11. Step 8.4 Plan-Gate Rewire (feature_implementation_plan_semantic_review.sh)

Step 8.4 is the only remaining consumer of `check_implementation_plan_quality.sh`; it must be rewired off the helper before the helper is deleted (Section 12), otherwise step 8.4 fails its required-file check at startup. This is wiring only — step 8.4's own semantic-review gate/rule/template/golden-example/skill migration is deferred (see design D8).

- [x] 11.1 Add an `OVERMIND_CLI_FILE` (`.overmind/overmind.js`) constant to `feature_implementation_plan_semantic_review.sh` if not already present
- [x] 11.2 In `ensure_required_files`, **replace** the `IMPLEMENTATION_PLAN_QUALITY_GATE_HELPER` entry with `$OVERMIND_CLI_FILE`, and remove the `IMPLEMENTATION_PLAN_QUALITY_GATE_HELPER` constant — so step 8.4 no longer requires `.helper/check_implementation_plan_quality.sh` but still preflights the shared CLI it now references in the prompt (a missing `.overmind/overmind.js` must fail before launching the model, not hand it an unusable gate command)
- [x] 11.3 Change the model-facing "Implementation plan quality gate command" (and its helper-path/context lines) to `node .overmind/overmind.js gate implementation-plan <feature-path>`; keep it model-invoked (do not run it from the orchestrator); leave step 8.4's own `check_implementation_plan_semantic_review_quality.sh` gate untouched
- [x] 11.4 Update `tests/ai_scripts/init_feature_implementation_plan_semantic_review_tests.sh`: replace assertions that the prompt/required-files reference `.helper/check_implementation_plan_quality.sh` with assertions for the `node .overmind/overmind.js gate implementation-plan` command; confirm step 8.4 no longer requires the deleted helper
- [x] 11.5 Add a step-8.4 test: when `.overmind/overmind.js` is absent, `ensure_required_files` fails before launching the model with an actionable "Required file not found" error naming the CLI (missing-CLI preflight)
- [x] 11.6 Run `bash tests/ai_scripts/init_feature_implementation_plan_semantic_review_tests.sh` and confirm all tests pass

## 12. Delete Old Bash Artifacts

- [x] 12.1 Delete `overmind/scripts/feature_implementation_plan.sh`
- [x] 12.2 Delete `overmind/rules/implementation_plan_rule.md`
- [x] 12.3 Delete `overmind/scripts/helper/check_implementation_plan_quality.sh` (only after Section 11 rewires step 8.4 off it)
- [x] 12.4 Delete `tests/ai_scripts/init_feature_implementation_plan_tests.sh`
- [x] 12.5 Delete `tests/ai_scripts/check_implementation_plan_quality_tests.sh`
- [x] 12.6 Remove both deleted test scripts from `CLAUDE.md` test listings and remove any other deleted-file references (keep the un-migrated `check_implementation_plan_readiness_tests.sh`, `feature_assign_workers_to_implementation_plan_tests.sh`, and `init_feature_implementation_plan_semantic_review_tests.sh`)

## 13. Documentation and Final Checks

- [x] 13.1 Update `README.md` step-8.3 entry: reference `overmind-implementation-plan` skill and `overmind context implementation-plan` command; remove old bash command reference
- [x] 13.2 Update `design_docs/to_skills_migration/migration_to_skill_architecture_overview.md` step-8.3 row: mark as **done** (CRP-141)
- [x] 13.3 Update `tests/ai_scripts/project_setup_update_project_tests.sh`: remove any `feature_implementation_plan.sh` / rule / helper copy and assertion lines for the deleted assets
- [x] 13.4 Run `bash tests/ai_scripts/project_setup_asdlc_tests.sh` and confirm all tests pass
- [x] 13.5 Run `bash tests/ai_scripts/project_setup_update_project_tests.sh` and confirm all tests pass
- [x] 13.6 Run `git diff --check` — no whitespace errors
- [x] 13.7 Run `openspec validate crp-141-feature-implementation-plan --strict` and confirm the change validates
