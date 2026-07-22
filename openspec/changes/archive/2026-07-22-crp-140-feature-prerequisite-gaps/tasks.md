## 1. Gate Module (asdlc-coordinator)

- [x] 1.1 Add `packages/asdlc-coordinator/src/validate/prerequisite-gaps.ts` — resolve the feature path, derive target `prerequisite_gaps.md`, `requirements_ears.md`, and `technical_requirements.md` from the feature dir; exit `2` when the target path arg is missing, target is absent, or `requirements_ears.md`/`technical_requirements.md` is absent; exit `1` for an empty/whitespace-only target (legacy parity: absent→`2`, empty→`1`)
- [x] 1.2 Port `validate_prerequisite_gaps` per-`#### Prerequisite:` checks one-for-one: `surface_kind` present and ∈ {`required_missing_user_reachable_surface`, `present_user_reachable_surface`, `transport_or_internal_execution_gap`} with `transport_or_internal_execution_gap` rejected as an entry; `status` present and ∈ {`present_in_repo`, `scheduled_in_slices`, `scheduled_in_feature <feature-folder>/<step-id>`, `unmet`}; `unmet` fails; `present_in_repo` requires `evidence`; `scheduled_in_slices` requires `evidence` + non-`none` `slice_ref`; `scheduled_in_feature` requires `evidence` + `slice_ref: none`; `required_missing_user_reachable_surface` requires status ∈ {unmet, scheduled_in_slices, scheduled_in_feature} and a filled, non-`none`, operator-facing `surface_identity`; `present_user_reachable_surface` requires `status: present_in_repo` + `surface_identity: none`
- [x] 1.3 Port the `looks_like_surface_identity` operator-facing detector behavior-for-behavior (route/page/screen/shell/login/signin/workspace/entry/portal/console/ui/view/lookup/search/dashboard/form/command/cli/job/endpoint/tool/http-verb/deep-link semantics)
- [x] 1.4 Port `run_literal_cross_check`: extract EARS literals from `requirements_ears.md` via the three passes (HTTP-verb paths, backtick-wrapped `/paths`, bare `/path` tokens > 2 chars) with dedupe; require each literal to appear in some prerequisite entry (`evidence`/`slice_ref`) or a `user_reachable_surface` value in `technical_requirements.md`; an uncovered literal exits `1` naming the literal
- [x] 1.5 Port `validate_slice_refs_in_slices`: for `status: scheduled_in_slices` prerequisites with a filled `slice_ref`, require `slice_ref` to match `[A-Za-z0-9][A-Za-z0-9_.-]*`; do not apply the format check to other statuses
- [x] 1.6 Aggregate all three passes: any pass failure ⇒ exit `1` with actionable `missing: ...` messages; exit `0` on clean pass
- [x] 1.7 Export `validatePrerequisiteGaps` from `packages/asdlc-coordinator/src/validate/index.ts`
- [x] 1.8 Register `prerequisite-gaps` in `gateRegistry` in `packages/asdlc-coordinator/src/cli/run.ts`

## 2. Context Module (asdlc-coordinator)

- [x] 2.1 Add `packages/asdlc-coordinator/src/context/prerequisite-gaps.ts` — resolve feature path under `projects/<id>/<feature>/`, read active project classes from `init_progress_definition.yaml` (accept `backend`/`frontend`/`mobile`/`infrastructure`; reject unsupported classes with exit `2`), derive supported repo classes (`backend`/`frontend`/`mobile`, skip `infrastructure`), require at least one supported repo class (exit `2` otherwise), and require `requirements_ears.md`, `technical_requirements.md`, `implementation_slices.md` and `init_progress_definition.yaml` (exit `2` on any missing)
- [x] 2.2 Discover committed sibling in-flight plans via `listCommittedSiblingFeatures(featureDir)` and include each sibling `implementation_plan.md` in the read-only manifest; absence of any sibling plan must not cause an error
- [x] 2.3 Emit one context block with workspace root, feature root, project root, active repo classes, target artifact path (`<feature-path>/prerequisite_gaps.md`), read-only manifest (`init_progress_definition.yaml`, `requirements_ears.md`, `technical_requirements.md`, `implementation_slices.md`, each sibling `implementation_plan.md`), skill-relative asset references (template + golden example), and exact gate command `node .overmind/overmind.js gate prerequisite-gaps <feature-path>`
- [x] 2.4 Export `buildPrerequisiteGapsContext` from `packages/asdlc-coordinator/src/context/index.ts`
- [x] 2.5 Register `prerequisite-gaps` in `contextRegistry` in `packages/asdlc-coordinator/src/cli/run.ts`

## 3. Sync Module (asdlc-coordinator)

- [x] 3.1 Add an optional `supportedClasses?: string[]` parameter to `collectReadyRepoPaths` in `packages/asdlc-coordinator/src/repo/collect-ready-paths.ts` that filters entries by class (case-insensitive) **before** the ready/path-existence validation — matching the legacy `class_repo_paths_collect_ready_paths` CSV filter. Default undefined = no filter, preserving existing `sync/contract-delta.ts` and `context/surface-map.ts` callers
- [x] 3.2 Add `packages/asdlc-coordinator/src/sync/prerequisite-gaps.ts` — resolve feature path and project `init_progress_definition.yaml`, call `collectReadyRepoPaths(definitionPath, ["backend", "frontend", "mobile"])` so unsupported classes (e.g. `infrastructure`) are never synced and a ready unsupported-class repo (including one with a nonexistent path) is not an error, `syncRepoToDefaultBranch` each; exit `0` on clean sync, exit `2` with blocked messages on wrong-branch/dirty supported repos or missing project definition
- [x] 3.3 Export `syncPrerequisiteGapsStep` from `packages/asdlc-coordinator/src/sync/index.ts`
- [x] 3.4 Register `prerequisite-gaps` in `syncRegistry` in `packages/asdlc-coordinator/src/cli/run.ts`

## 4. TS Tests — Gate (asdlc-coordinator)

- [x] 4.1 Add gate tests: exit `0` with a valid `prerequisite_gaps.md` covering multiple statuses (`present_in_repo`, `scheduled_in_slices`, `scheduled_in_feature`) with all EARS literals covered
- [x] 4.2 Add gate tests: exit `1` for missing/invalid `surface_kind` and for a `transport_or_internal_execution_gap` entry
- [x] 4.3 Add gate tests: exit `1` for missing/invalid `status`, for an `unmet` prerequisite, and for each status-specific evidence/slice_ref violation (`present_in_repo` missing evidence, `scheduled_in_slices` missing evidence, `scheduled_in_slices` missing/`none` slice_ref, `scheduled_in_feature` missing evidence, `scheduled_in_feature` with non-`none` slice_ref)
- [x] 4.4 Add gate tests: exit `1` for `required_missing_user_reachable_surface` with wrong status, missing/`none` `surface_identity`, and non-operator-facing `surface_identity`; exit `1` for `present_user_reachable_surface` with wrong status or non-`none` `surface_identity`
- [x] 4.5 Add gate tests: literal covered by a prerequisite entry ⇒ no error; literal covered only by a `user_reachable_surface` ⇒ no error; uncovered literal ⇒ exit `1` naming the literal
- [x] 4.6 Add gate tests: `scheduled_in_slices` with valid `slice_ref` ⇒ no error; malformed `slice_ref` ⇒ exit `1`; non-`scheduled_in_slices` prerequisites are not format-checked
- [x] 4.7 Add gate tests: exit `1` when target artifact is zero-byte and when it is whitespace-only (strengthened from legacy zero-byte-only `-s`), and exit `2` when the target artifact is absent (split: empty/whitespace→`1`, absent→`2`)
- [x] 4.8 Add gate tests: exit `2` when target path argument is missing
- [x] 4.9 Add gate tests: exit `2` when `requirements_ears.md` or `technical_requirements.md` is absent
- [x] 4.10 Run `npm test --workspace packages/asdlc-coordinator` and confirm all tests pass

## 5. TS Tests — Context (asdlc-coordinator)

- [x] 5.1 Add context tests: exits `0` and emits workspace root, feature root, active repo classes, target artifact path, and gate command for a valid two-class feature
- [x] 5.2 Add context tests: read-only manifest lists `init_progress_definition.yaml`, `requirements_ears.md`, `technical_requirements.md`, `implementation_slices.md`, and each sibling `implementation_plan.md`
- [x] 5.3 Add context tests: sibling plans included when a committed sibling has `implementation_plan.md`, and omitted (without error) when no sibling plan exists
- [x] 5.4 Add context tests: `infrastructure` class is silently skipped, while an unsupported project class fails resolution with exit `2` naming the class
- [x] 5.5 Add context tests: exits `2` when `requirements_ears.md`, `technical_requirements.md`, or `implementation_slices.md` is missing
- [x] 5.6 Add context tests: exits `2` when feature path does not resolve under `projects/<id>/<feature>/`
- [x] 5.7 Run `npm test --workspace packages/asdlc-coordinator` and confirm all tests pass

## 6. TS Tests — Sync (asdlc-coordinator)

- [x] 6.1 Add sync tests: ready backend+frontend repos on default branch with clean trees ⇒ exit `0` and both synced
- [x] 6.2 Add sync tests: a ready `infrastructure` repo alongside a ready backend repo ⇒ only backend is synced, `infrastructure` is neither synced nor errored, exit `0`; and a ready `infrastructure` repo whose path does not exist ⇒ not synced, not errored
- [x] 6.3 Add sync tests: a blocked supported repo (wrong branch/dirty tree) ⇒ exit `2` with a message naming the blocked repo
- [x] 6.4 Add sync tests: missing `init_progress_definition.yaml` ⇒ exit `2`
- [x] 6.5 Add a `collectReadyRepoPaths` unit test proving the `supportedClasses` filter excludes unsupported classes before path validation, and that the no-filter default still returns all ready classes (contract-delta/surface-map parity)
- [x] 6.6 Run `npm test --workspace packages/asdlc-coordinator` and confirm all tests pass

## 7. Skill Package

- [x] 7.1 Create `packages/installer/_data/skills/overmind-prerequisite-gaps/assets/` and copy `overmind/templates/prerequisite_gaps_TEMPLATE.md` and `overmind/golden_examples/prerequisite_gaps_GOLDEN_EXAMPLE.md` into it
- [x] 7.2 Create `packages/installer/_data/skills/overmind-prerequisite-gaps/SKILL.md` with YAML frontmatter, Required Invocation (context command, allowed write artifact list = `prerequisite_gaps.md` only, gate command, gate exit-code handling), the literal success line (`Prerequisite gap trace phase is finished. Nothing else to do now; press Ctrl-C so orchestrator can start the next phase`), the literal infeasibility line (`prerequisite gap trace gate cannot pass with current requirements/technical-requirements/slices inputs. Please provide instructions what to do, or adjust inputs and rerun this phase`), an `Assets` section with skill-relative template and golden example paths, and the inlined rule from `prerequisite_gaps_rule.md` (purpose, ownership boundaries, class taxonomy, field definitions for status/surface_kind/surface_identity/evidence/slice_ref, derivation rules, gate condition, output format baseline, completion gate)

## 8. Installer

- [x] 8.1 Add `"overmind-prerequisite-gaps"` to `PACKAGED_SKILLS` array in `packages/installer/src/init.ts`
- [x] 8.2 Add installer tests: fresh install copies `overmind-prerequisite-gaps` to `.codex/skills/` and `.claude/skills/` with `SKILL.md` and `assets/`
- [x] 8.3 Add installer tests: install fails before writing runner targets when the packaged `overmind-prerequisite-gaps` skill is missing `SKILL.md`, and (separately) when it is missing its `assets/` directory — both incomplete-payload cases per the runner-skill-installation spec
- [x] 8.4 Run `npm test --workspace packages/installer` and confirm all tests pass

## 9. Setup Staging (project_setup_first_init_machine.sh)

- [x] 9.1 Add `"overmind-prerequisite-gaps"` to `SKILL_NAMES` array
- [x] 9.2 Remove `feature_prerequisite_gaps.sh` command constant and all staging array references, AND add `"feature_prerequisite_gaps.sh"` to `OBSOLETE_STAGED_COMMAND_FILES` so update mode prunes the stale command (`.commands` is not an exact manifest; removals rely on this list)
- [x] 9.3 Remove `prerequisite_gaps_rule.md` rule constant and staging references
- [x] 9.4 Remove `check_prerequisite_gaps_quality.sh` helper constant and staging references
- [x] 9.5 Remove `prerequisite_gaps_TEMPLATE.md` flat template staging constant and references
- [x] 9.6 Remove `prerequisite_gaps_GOLDEN_EXAMPLE.md` flat golden-example staging constant and references
- [x] 9.7 Update quickrun docs block to reference the new skill and remove old bash references
- [x] 9.8 Add a setup test asserting update mode removes a stale `.commands/feature_prerequisite_gaps.sh` (and that the `overmind-prerequisite-gaps` runner skill folders are present), plus fresh-setup omission of the migrated command/rule/helper
- [x] 9.9 Run `bash tests/ai_scripts/project_setup_asdlc_tests.sh` and confirm all tests pass

## 10. E2e Runner (project_add_feature_e2e.sh)

- [x] 10.1 Add `PREREQUISITE_GAPS_SKILL_FILE` constant pointing to `.codex/skills/overmind-prerequisite-gaps/SKILL.md` and a `PREREQUISITE_GAPS_MODEL_PHASE` (`prerequisite_gap_trace`) constant
- [x] 10.2 Add `build_prerequisite_gaps_prompt` function: prompt includes skill name, workspace root, feature path, `context prerequisite-gaps` command, `gate prerequisite-gaps` command, and OVERMIND_CLI_FILE path; must not include literal final-response lines from SKILL.md
- [x] 10.3 Add `run_prerequisite_gaps_skill` function: run `overmind sync prerequisite-gaps` before the session; snapshot `init_progress_definition.yaml`, `requirements_ears.md`, `technical_requirements.md`, `implementation_slices.md`, and each sibling `implementation_plan.md` present before the session; launch Codex with the skill prompt; `cmp`-assert every snapshotted read-only input byte-unchanged after the session on every exit path (read-only-corruption error wins on double-failure); assert `prerequisite_gaps.md` was produced
- [x] 10.4 Replace the phase-8.2 legacy bash invocation (`feature_prerequisite_gaps.sh`) with a `run_prerequisite_gaps_skill` call in `run_phase_by_index`
- [x] 10.5 Ensure the e2e does NOT run the gate itself for phase 8.2 — only the model/skill owns the gate loop

## 11. E2e Tests (project_add_feature_e2e_tests.sh)

- [x] 11.1 Add test: phase-8.2 prompt loads `overmind-prerequisite-gaps` skill and includes exact `context prerequisite-gaps` command
- [x] 11.2 Add test: phase-8.2 prompt includes `gate prerequisite-gaps` command
- [x] 11.3 Add test: phase-8.2 prompt does not duplicate literal final-response lines from SKILL.md
- [x] 11.4 Add test: phase-8.2 e2e does not shell out to the gate command itself
- [x] 11.5 Add test: `overmind sync prerequisite-gaps` is invoked before the phase-8.2 session
- [x] 11.6 Add test: `run_prerequisite_gaps_skill` fails the phase when a read-only input (`implementation_slices.md`) is mutated during the session (simulated via cmp mismatch)
- [x] 11.7 Add test: `run_prerequisite_gaps_skill` fails the phase when `prerequisite_gaps.md` is not produced after a successful model exit
- [x] 11.8 Add test: read-only-corruption error takes precedence when the model both mutates a read-only input and fails to produce the output (double-failure)
- [x] 11.9 Add test: when a sibling `implementation_plan.md` exists before the session, mutating it fails the phase; when no sibling plan exists, no sibling guard is applied and the phase is not failed for its absence
- [x] 11.10 Run `bash tests/ai_scripts/project_add_feature_e2e_tests.sh` and confirm all tests pass

## 12. Delete Old Bash Artifacts

- [x] 12.1 Delete `overmind/scripts/feature_prerequisite_gaps.sh`
- [x] 12.2 Delete `overmind/rules/prerequisite_gaps_rule.md`
- [x] 12.3 Delete `overmind/scripts/helper/check_prerequisite_gaps_quality.sh`
- [x] 12.4 Delete `tests/ai_scripts/init_feature_prerequisite_gaps_tests.sh`
- [x] 12.5 Delete `tests/ai_scripts/check_prerequisite_gaps_quality_tests.sh`
- [x] 12.6 Remove both deleted test scripts from `CLAUDE.md` test listings and remove any other deleted-file references

## 13. Documentation and Final Checks

- [x] 13.1 Update `README.md` step-8.2 entry: reference `overmind-prerequisite-gaps` skill and `overmind context prerequisite-gaps` command; remove old bash command reference
- [x] 13.2 Update `design_docs/to_skills_migration/migration_to_skill_architecture_overview.md` step-8.2 row: mark as **done** (CRP-140)
- [x] 13.3 Update `tests/ai_scripts/project_setup_update_project_tests.sh`: remove any `feature_prerequisite_gaps.sh` / rule / helper copy and assertion lines for the deleted assets
- [x] 13.4 Run `bash tests/ai_scripts/project_setup_asdlc_tests.sh` and confirm all tests pass
- [x] 13.5 Run `bash tests/ai_scripts/project_setup_update_project_tests.sh` and confirm all tests pass
- [x] 13.6 Run `git diff --check` — no whitespace errors
- [x] 13.7 Run `openspec validate crp-140-feature-prerequisite-gaps --strict` and confirm the change validates
