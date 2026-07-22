## 1. Gate Module (asdlc-coordinator)

- [x] 1.1 Add `packages/asdlc-coordinator/src/validate/technical-requirements.ts` — port all checks from `check_feature_technical_requirements_quality.sh` one-for-one: seven required sections, nine section-1 scalar keys, three section-2 scalar keys, surface-map class `### Repository:` blocks (one per `backend`/`frontend`/`mobile` active class; `infrastructure` skipped), per-requirement `### Requirement:` blocks keyed against `REQ-*/NFR-*` from `requirements_ears.md` with `transport_layer`/`user_reachable_surface` split, `### Component:` blocks (one per repo with `applicability: applicable` surface entries, determined by re-reading applicable surface maps), section-6 planning-signal or empty-marker shape, section-7 at least one `risk_N` entry; `[UNFILLED]` rejection; exit `0` on pass, `1` on content failures, `2` on runtime failures (including missing surface map files)
- [x] 1.2 Export `validateTechnicalRequirements` from `packages/asdlc-coordinator/src/validate/index.ts`
- [x] 1.3 Register `technical-requirements` in `gateRegistry` in `packages/asdlc-coordinator/src/cli/run.ts`

## 2. Context Module (asdlc-coordinator)

- [x] 2.1 Add `packages/asdlc-coordinator/src/context/technical-requirements.ts` — resolve feature path under `projects/<id>/<feature>/`, read and validate active project classes (`backend`, `frontend`, `mobile`, `infrastructure` only), skip `infrastructure`, reject unsupported classes with exit `2`, resolve each surface-map class's file, exit `2` on any missing required input, and emit one context block with workspace root, feature root, project root, target artifact path, read-only input manifest (init_progress_definition, requirements_ears, common_contract_definition, all applicable surface maps), active surface-map classes + their paths, skill-relative asset references (template + golden example), and exact gate command `node .overmind/overmind.js gate technical-requirements <feature-path>`
- [x] 2.2 Export `buildTechnicalRequirementsContext` from `packages/asdlc-coordinator/src/context/index.ts`
- [x] 2.3 Register `technical-requirements` in `contextRegistry` in `packages/asdlc-coordinator/src/cli/run.ts`

## 3. TS Tests — Gate (asdlc-coordinator)

- [x] 3.1 Add gate tests: exit `0` with valid seven-section artifact (all required sections, keys, blocks)
- [x] 3.2 Add gate tests: exit `1` for each missing section (7 cases)
- [x] 3.3 Add gate tests: exit `1` for each missing section-1 scalar key (9 cases)
- [x] 3.4 Add gate tests: exit `1` for each missing section-2 scalar key (3 cases)
- [x] 3.5 Add gate tests: exit `1` when an active class has no `### Repository:` block in section 3
- [x] 3.6 Add gate tests: exit `1` for each missing repository block field (`class`, `evidence_scope`, `primary_paths`, `key_findings`, `constraints`, `open_gaps`)
- [x] 3.7 Add gate tests: exit `1` when a `REQ-*`/`NFR-*` from `requirements_ears.md` has no block in section 4
- [x] 3.8 Add gate tests: exit `1` when a section-4 block uses conflated `current_state:` instead of the transport/surface split
- [x] 3.9 Add gate tests: exit `1` for each missing `transport_layer` or `user_reachable_surface` subfield
- [x] 3.10 Add gate tests: exit `1` for invalid `gap_status` or `repo_impact` values
- [x] 3.11 Add gate tests: exit `1` when a repo with applicable surface has no component block in section 5
- [x] 3.12 Add gate tests: exit `1` for invalid `component_kind` or `requirement_refs` referencing unknown ID
- [x] 3.13 Add gate tests: exit `1` for legacy section-6 format (`constraint_*`/`prep_*`), missing empty marker or signal block, mixed empty marker + signal block, invalid `signal_type`, out-of-scope `owner_repo`/`consumer_repos`
- [x] 3.14 Add gate tests: exit `1` when section 7 has no `risk_N` entries
- [x] 3.15 Add gate tests: exit `1` when artifact contains `[UNFILLED]`
- [x] 3.16 Add gate tests: exit `1` for duplicate planning signal IDs in section 6 (two blocks with the same `signal_id`)
- [x] 3.17 Add gate tests: exit `1` when `source_evidence` references an unresolved `comp/<slug>` token (component slug not present in section 5)
- [x] 3.18 Add gate tests: exit `1` when target artifact is empty (zero bytes)
- [x] 3.19 Add gate tests: exit `2` when target artifact path argument is missing
- [x] 3.20 Add gate tests: exit `2` when `init_progress_definition.yaml` is absent
- [x] 3.21 Add gate tests: exit `2` when `requirements_ears.md` is absent
- [x] 3.22 Add gate tests: exit `2` when a surface-map class's surface map file is absent (needed to reconstruct `required_repo_csv`)
- [x] 3.23 Run `npm test --workspace packages/asdlc-coordinator` and confirm all tests pass

## 4. TS Tests — Context (asdlc-coordinator)

- [x] 4.1 Add context tests: exits `0` and emits workspace root, feature root, target artifact path, and gate command for a valid two-class feature
- [x] 4.2 Add context tests: read-only manifest lists all five expected entries (init_progress_definition, requirements_ears, common_contract_definition, backend surface map, frontend surface map) for a backend+frontend project
- [x] 4.3 Add context tests: `infrastructure` class is silently skipped, while an unsupported project class is rejected with exit `2` and an actionable error naming the class
- [x] 4.4 Add context tests: exits `2` when `requirements_ears.md` is missing
- [x] 4.5 Add context tests: exits `2` when `common_contract_definition.md` is missing
- [x] 4.6 Add context tests: exits `2` when a surface-map class's surface map file is missing
- [x] 4.7 Add context tests: exits `2` when feature path does not resolve under `projects/<id>/<feature>/`
- [x] 4.8 Run `npm test --workspace packages/asdlc-coordinator` and confirm all tests pass

## 5. Skill Package

- [x] 5.1 Create `packages/installer/_data/skills/overmind-technical-requirements/assets/` and copy `overmind/templates/technical_requirements_TEMPLATE.md` and `overmind/golden_examples/technical_requirements_GOLDEN_EXAMPLE.md` into it
- [x] 5.2 Create `packages/installer/_data/skills/overmind-technical-requirements/SKILL.md` with YAML frontmatter, Required Invocation (context command, allowed write artifact list, gate command, gate exit-code handling), final response success line (`Feature technical requirements phase is finished. Nothing else to do now; press Ctrl-C so orchestrator can start the next phase`), infeasibility line, `Assets` section with skill-relative template and golden example paths, and inlined rule from `technical_requirements_rule.md`

## 6. Installer

- [x] 6.1 Add `"overmind-technical-requirements"` to `PACKAGED_SKILLS` array in `packages/installer/src/init.ts`
- [x] 6.2 Add installer tests: fresh install copies `overmind-technical-requirements` to `.codex/skills/` and `.claude/skills/` with `SKILL.md` and `assets/`
- [x] 6.3 Add installer tests: install fails before writing runner targets when `SKILL.md` is missing from packaged skill
- [x] 6.4 Run `npm test --workspace packages/installer` and confirm all tests pass

## 7. Setup Staging (project_setup_first_init_machine.sh)

- [x] 7.1 Add `"overmind-technical-requirements"` to `SKILL_NAMES` array
- [x] 7.2 Remove `feature_technical_requirements.sh` command constant and all staging array references
- [x] 7.3 Remove `technical_requirements_rule.md` rule constant and staging references
- [x] 7.4 Remove `check_feature_technical_requirements_quality.sh` helper constant and staging references
- [x] 7.5 Remove `technical_requirements_TEMPLATE.md` flat template staging constant and references
- [x] 7.6 Remove `technical_requirements_GOLDEN_EXAMPLE.md` flat golden-example staging constant and references
- [x] 7.7 Update quickrun docs block to reference the new skill and remove old bash references
- [x] 7.8 Run `bash tests/ai_scripts/project_setup_asdlc_tests.sh` and confirm all tests pass

## 8. E2e Runner (project_add_feature_e2e.sh)

- [x] 8.1 Add `TECHNICAL_REQUIREMENTS_SKILL_FILE` constant pointing to `.codex/skills/overmind-technical-requirements/SKILL.md`
- [x] 8.2 Add `build_technical_requirements_prompt` function: prompt includes skill name, workspace root, feature path, `context technical-requirements` command, `gate technical-requirements` command, and OVERMIND_CLI_FILE path; must not include literal final-response lines from SKILL.md
- [x] 8.3 Add `run_technical_requirements_skill` function: snapshot `init_progress_definition.yaml`, `requirements_ears.md`, `common_contract_definition.md`, and all applicable surface maps before session; launch Codex with the skill prompt; `cmp`-assert all read-only inputs are byte-unchanged after session on every exit path; assert `technical_requirements.md` was produced
- [x] 8.4 Replace phase-8 legacy bash invocation with `run_technical_requirements_skill` call
- [x] 8.5 Ensure the e2e does NOT run the gate itself for phase 8 — only the model/skill owns the gate loop

## 9. E2e Tests (project_add_feature_e2e_tests.sh)

- [x] 9.1 Add test: phase-8 prompt loads `overmind-technical-requirements` skill and includes exact `context technical-requirements` command
- [x] 9.2 Add test: phase-8 prompt includes `gate technical-requirements` command
- [x] 9.3 Add test: phase-8 prompt does not duplicate literal final-response lines from SKILL.md
- [x] 9.4 Add test: phase-8 e2e does not shell out to the gate command itself
- [x] 9.5 Add test: `run_technical_requirements_skill` fails the phase when a read-only input (`requirements_ears.md`) is mutated during the session (simulated via cmp mismatch)
- [x] 9.6 Add test: `run_technical_requirements_skill` fails the phase when `technical_requirements.md` is not produced after a successful model exit
- [x] 9.7 Add test: read-only-corruption error takes precedence when the model both mutates a read-only input and fails to produce the output (double-failure)
- [x] 9.8 Run `bash tests/ai_scripts/project_add_feature_e2e_tests.sh` and confirm all tests pass

## 10. Delete Old Bash Artifacts

- [x] 10.1 Delete `overmind/scripts/feature_technical_requirements.sh`
- [x] 10.2 Delete `overmind/rules/technical_requirements_rule.md`
- [x] 10.3 Delete `overmind/scripts/helper/check_feature_technical_requirements_quality.sh`
- [x] 10.4 Delete `tests/ai_scripts/init_feature_technical_requirements_tests.sh`
- [x] 10.5 Delete `tests/ai_scripts/check_feature_technical_requirements_quality_tests.sh`
- [x] 10.6 Remove all five deleted files from `CLAUDE.md` test listings
- [x] 10.7 Update `process_gaps.md ## Gap 2 - Technical requirements cannot express cross-repo coordination intent in a typed but lightweight way` to reference the packaged skill, skill-local assets, TypeScript gate, and TypeScript tests after deleting the legacy bash assets

## 11. Documentation and Final Checks

- [x] 11.1 Update `README.md` step-8 entry: reference `overmind-technical-requirements` skill and `overmind context technical-requirements` command; remove old bash command reference
- [x] 11.2 Update `design_docs/to_skills_migration/migration_to_skill_architecture_overview.md` step-8 row: mark as **done** (CRP-138)
- [x] 11.3 Update `tests/ai_scripts/project_setup_update_project_tests.sh`: remove `feature_technical_requirements.sh` copy and assertion lines (lines that stage or check for the deleted script)
- [x] 11.4 Run `bash tests/ai_scripts/project_setup_asdlc_tests.sh` and confirm all tests pass
- [x] 11.5 Run `bash tests/ai_scripts/project_setup_update_project_tests.sh` and confirm all tests pass
- [x] 11.6 Run `git diff --check` — no whitespace errors
