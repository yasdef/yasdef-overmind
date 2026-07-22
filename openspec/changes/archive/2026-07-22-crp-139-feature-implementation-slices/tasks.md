## 1. Gate Module (asdlc-coordinator)

- [x] 1.1 Add `packages/asdlc-coordinator/src/validate/implementation-slices.ts` — port all checks from `check_implementation_slices_quality.sh`: four required sections (`## 1. Document Meta`, `## 2. Slice Planning Guardrails`, `## 3. Slice Candidates`, `## 4. Handoff To Ordered Plan`), twelve section-1 meta keys, `ordering_scope: local_prerequisites_only` and `traceability_scope: slice_level_only` literals, ≥1 slice block with ≥1 `planned` slice, per-slice seven required fields (`repo`, `status`, `objective`, `first_increment`, `prerequisites`, `preserved_operator_surface`, `evidence`), `repo` ∈ active classes ∩ {backend,frontend,mobile}, `status` ∈ {existing,planned}, evidence-token grammar (`gap/TECH_REQ-N` / `gap/TECH_REQ-NFR-N` / `comp/<slug>`) with ≥1 valid token, `kind: coordination` ⇒ non-empty `signal_ref`, ≥2 concrete checklist bullets per slice, forbidden lifecycle boilerplate bullets (`Plan and discuss the slice`, `Review slice readiness`), non-`none` `preserved_operator_surface` operator-facing/supporting-only enforcement, three section-4 handoff keys, structured `[UNFILLED]` placeholder-value rejection; exit `0`/`1`/`2`
- [x] 1.2 Port the semantic helpers behavior-for-behavior: `canonical_surface` synonym folding, `has_surface_terms`, `looks_supporting_only`, `is_weak_content_token`, and weighted-token `surface_matches`
- [x] 1.3 Port the optional `prerequisite_gaps.md` cross-check: when the file exists, extract required missing operator-facing surfaces (`#### Prerequisite:` blocks with `status` ∈ {scheduled_in_slices, unmet}, `surface_kind: required_missing_user_reachable_surface`, filled `surface_identity`) and require each to be `surface_matches`-covered by some slice's non-`none` `preserved_operator_surface`; when absent, skip the cross-check without failing
- [x] 1.4 Derive active classes from `init_progress_definition.yaml` (parent project dir) and require siblings `requirements_ears.md`, `technical_requirements.md`, `feature_contract_delta.md` (feature dir); exit `2` on any missing precondition (including an absent target artifact) or when no supported class is derivable; exit `1` for an empty/whitespace-only target artifact (legacy parity: absent→`2`, empty→`1`)
- [x] 1.5 Export `validateImplementationSlices` from `packages/asdlc-coordinator/src/validate/index.ts`
- [x] 1.6 Register `implementation-slices` in `gateRegistry` in `packages/asdlc-coordinator/src/cli/run.ts`

## 2. Context Module (asdlc-coordinator)

- [x] 2.1 Add `packages/asdlc-coordinator/src/context/implementation-slices.ts` — resolve feature path under `projects/<id>/<feature>/`, read and validate active project classes (`backend`, `frontend`, `mobile`, `infrastructure` only), skip `infrastructure` for surface-map resolution, reject unsupported classes with exit `2`, require at least one supported surface-map class, resolve each surface-map class's file, exit `2` on any missing required input, and emit one context block with workspace root, feature root, project root, active repo classes, target artifact path, read-only input manifest (`init_progress_definition.yaml`, `requirements_ears.md`, `technical_requirements.md`, `feature_contract_delta.md`, all applicable surface maps, and — only when it already exists in the feature directory — `prerequisite_gaps.md`), skill-relative asset references (template + golden example), and exact gate command `node .overmind/overmind.js gate implementation-slices <feature-path>`; `prerequisite_gaps.md` absence must not cause an error
- [x] 2.2 Export `buildImplementationSlicesContext` from `packages/asdlc-coordinator/src/context/index.ts`
- [x] 2.3 Register `implementation-slices` in `contextRegistry` in `packages/asdlc-coordinator/src/cli/run.ts`

## 3. TS Tests — Gate (asdlc-coordinator)

- [x] 3.1 Add gate tests: exit `0` with a valid four-section artifact (all sections, keys, ≥1 planned slice, valid fields/evidence/bullets)
- [x] 3.2 Add gate tests: exit `1` for each missing section (4 cases)
- [x] 3.3 Add gate tests: exit `1` for each missing/unfilled section-1 meta key (12 cases)
- [x] 3.4 Add gate tests: exit `1` for wrong `ordering_scope` and wrong `traceability_scope` literals
- [x] 3.5 Add gate tests: exit `1` when section 3 has no slice block, and exit `1` when no slice is `planned`
- [x] 3.6 Add gate tests: exit `1` for each missing/unfilled slice field (`repo`, `status`, `objective`, `first_increment`, `prerequisites`, `preserved_operator_surface`, `evidence`)
- [x] 3.7 Add gate tests: exit `1` for `repo` outside active classes and for invalid `status`
- [x] 3.8 Add gate tests: exit `1` for invalid evidence token, empty token entry, and slice with no valid evidence token
- [x] 3.9 Add gate tests: exit `1` when a slice has fewer than two checklist bullets (count-based, matching the legacy `- [ ] ` counting; no content-concreteness inspection beyond `[UNFILLED]`)
- [x] 3.10 Add gate tests: exit `1` for forbidden lifecycle boilerplate bullets (`Plan and discuss the slice`, `Review slice readiness`)
- [x] 3.11 Add gate tests: exit `1` when `kind: coordination` slice has missing/empty `signal_ref`; exit `0` when coordination slice has a `signal_ref`; exit `0` when no coordination slice is present
- [x] 3.12 Add gate tests: exit `1` when non-`none` `preserved_operator_surface` is not operator-facing, and exit `1` when a slice marks a preserved surface but describes supporting-only scaffolding
- [x] 3.13 Add gate tests: `prerequisite_gaps.md` present with a required missing surface covered by a slice ⇒ exit `0`; uncovered ⇒ exit `1`; `prerequisite_gaps.md` absent ⇒ cross-check skipped (exit `0`)
- [x] 3.14 Add gate tests: exit `1` for each missing/unfilled section-4 handoff key (`ordering_intent`, `unresolved_ordering_questions`, `unresolved_traceability_questions`)
- [x] 3.15 Add gate tests: structured `[UNFILLED]` placeholder values exit `1`, while substantive prose that references `[UNFILLED]` remains valid
- [x] 3.16 Add gate tests: exit `1` when target artifact is empty (whitespace only), and exit `2` when the target artifact is absent (parity split: empty→`1`, absent→`2`)
- [x] 3.17 Add gate tests: exit `2` when target path argument is missing
- [x] 3.18 Add gate tests: exit `2` when a required sibling (`requirements_ears.md`, `technical_requirements.md`, `feature_contract_delta.md`) is absent
- [x] 3.19 Add gate tests: exit `2` when `init_progress_definition.yaml` is absent or yields no supported class
- [x] 3.20 Run `npm test --workspace packages/asdlc-coordinator` and confirm all tests pass

## 4. TS Tests — Context (asdlc-coordinator)

- [x] 4.1 Add context tests: exits `0` and emits workspace root, feature root, active classes, target artifact path, and gate command for a valid two-class feature
- [x] 4.2 Add context tests: read-only manifest lists all expected entries (`init_progress_definition.yaml`, `requirements_ears.md`, `technical_requirements.md`, `feature_contract_delta.md`, backend + frontend surface maps) for a backend+frontend project
- [x] 4.3 Add context tests: `infrastructure` class is silently skipped, while an unsupported project class fails resolution with exit `2` naming the class
- [x] 4.4 Add context tests: exits `2` when `requirements_ears.md`, `technical_requirements.md`, or `feature_contract_delta.md` is missing
- [x] 4.5 Add context tests: exits `2` when a surface-map class's surface map file is missing
- [x] 4.6 Add context tests: exits `2` when feature path does not resolve under `projects/<id>/<feature>/`
- [x] 4.7 Add context tests: read-only manifest includes `prerequisite_gaps.md` when it exists, and omits it (without error) when it is absent
- [x] 4.8 Run `npm test --workspace packages/asdlc-coordinator` and confirm all tests pass

## 5. Skill Package

- [x] 5.1 Create `packages/installer/_data/skills/overmind-implementation-slices/assets/` and copy `overmind/templates/implementation_slices_TEMPLATE.md` and `overmind/golden_examples/implementation_slices_GOLDEN_EXAMPLE.md` into it
- [x] 5.2 Create `packages/installer/_data/skills/overmind-implementation-slices/SKILL.md` with YAML frontmatter, Required Invocation (context command, allowed write artifact list = `implementation_slices.md` only, gate command, gate exit-code handling), the literal success line (`Implementation slice planning phase is finished. Nothing else to do now; press Ctrl-C so orchestrator can start the next phase`), the literal infeasibility line (`implementation slice planning gate cannot pass with current requirements/technical/contract/surface-map inputs. Please provide instructions what to do, or adjust inputs and rerun this phase`), an `Assets` section with skill-relative template and golden example paths, and the inlined rule from `implementation_slices_rule.md` (all ownership boundaries, planning rules, coordination-slice rules, final self-review, runtime path binding, completion gate)

## 6. Installer

- [x] 6.1 Add `"overmind-implementation-slices"` to `PACKAGED_SKILLS` array in `packages/installer/src/init.ts`
- [x] 6.2 Add installer tests: fresh install copies `overmind-implementation-slices` to `.codex/skills/` and `.claude/skills/` with `SKILL.md` and `assets/`
- [x] 6.3 Add installer tests: install fails before writing runner targets when `SKILL.md` is missing from packaged skill
- [x] 6.4 Run `npm test --workspace packages/installer` and confirm all tests pass

## 7. Setup Staging (project_setup_first_init_machine.sh)

- [x] 7.1 Add `"overmind-implementation-slices"` to `SKILL_NAMES` array
- [x] 7.2 Remove `feature_implementation_slices.sh` command constant and all staging array references
- [x] 7.3 Remove `implementation_slices_rule.md` rule constant and staging references
- [x] 7.4 Remove `check_implementation_slices_quality.sh` helper constant and staging references
- [x] 7.5 Remove `implementation_slices_TEMPLATE.md` flat template staging constant and references
- [x] 7.6 Remove `implementation_slices_GOLDEN_EXAMPLE.md` flat golden-example staging constant and references
- [x] 7.7 Update quickrun docs block to reference the new skill and remove old bash references
- [x] 7.8 Run `bash tests/ai_scripts/project_setup_asdlc_tests.sh` and confirm all tests pass

## 8. E2e Runner (project_add_feature_e2e.sh)

- [x] 8.1 Add `IMPLEMENTATION_SLICES_SKILL_FILE` constant pointing to `.codex/skills/overmind-implementation-slices/SKILL.md` and an `IMPLEMENTATION_SLICES_MODEL_PHASE` (`repository_implementation_slices`) constant
- [x] 8.2 Add `build_implementation_slices_prompt` function: prompt includes skill name, workspace root, feature path, `context implementation-slices` command, `gate implementation-slices` command, and OVERMIND_CLI_FILE path; must not include literal final-response lines from SKILL.md
- [x] 8.3 Add `run_implementation_slices_skill` function: snapshot `init_progress_definition.yaml`, `requirements_ears.md`, `technical_requirements.md`, `feature_contract_delta.md`, all applicable surface maps, and — only when it exists before the session — `prerequisite_gaps.md`, before session; launch Codex with the skill prompt; `cmp`-assert every snapshotted read-only input byte-unchanged after session on every exit path (read-only-corruption error wins on double-failure); assert `implementation_slices.md` was produced; do not fail when `prerequisite_gaps.md` was absent
- [x] 8.4 Replace the phase-8.1 legacy bash invocation (`feature_implementation_slices.sh`) with a `run_implementation_slices_skill` call in `run_phase_by_index`
- [x] 8.5 Ensure the e2e does NOT run the gate itself for phase 8.1 — only the model/skill owns the gate loop

## 9. E2e Tests (project_add_feature_e2e_tests.sh)

- [x] 9.1 Add test: phase-8.1 prompt loads `overmind-implementation-slices` skill and includes exact `context implementation-slices` command
- [x] 9.2 Add test: phase-8.1 prompt includes `gate implementation-slices` command
- [x] 9.3 Add test: phase-8.1 prompt does not duplicate literal final-response lines from SKILL.md
- [x] 9.4 Add test: phase-8.1 e2e does not shell out to the gate command itself
- [x] 9.5 Add test: `run_implementation_slices_skill` fails the phase when a read-only input (`technical_requirements.md`) is mutated during the session (simulated via cmp mismatch)
- [x] 9.6 Add test: `run_implementation_slices_skill` fails the phase when `implementation_slices.md` is not produced after a successful model exit
- [x] 9.7 Add test: read-only-corruption error takes precedence when the model both mutates a read-only input and fails to produce the output (double-failure)
- [x] 9.8 Add test: when `prerequisite_gaps.md` exists before the session, mutating it fails the phase; when it is absent, no `prerequisite_gaps.md` guard is applied and the phase is not failed for its absence
- [x] 9.9 Run `bash tests/ai_scripts/project_add_feature_e2e_tests.sh` and confirm all tests pass

## 10. Delete Old Bash Artifacts

- [x] 10.1 Delete `overmind/scripts/feature_implementation_slices.sh`
- [x] 10.2 Delete `overmind/rules/implementation_slices_rule.md`
- [x] 10.3 Delete `overmind/scripts/helper/check_implementation_slices_quality.sh`
- [x] 10.4 Delete `tests/ai_scripts/init_feature_implementation_slices_tests.sh`
- [x] 10.5 Delete `tests/ai_scripts/check_implementation_slices_quality_tests.sh`
- [x] 10.6 Remove both deleted test scripts from `CLAUDE.md` test listings and remove any other deleted-file references

## 11. Documentation and Final Checks

- [x] 11.1 Update `README.md` step-8.1 entry: reference `overmind-implementation-slices` skill and `overmind context implementation-slices` command; remove old bash command reference
- [x] 11.2 Update `design_docs/to_skills_migration/migration_to_skill_architecture_overview.md` step-8.1 row: mark as **done** (CRP-139)
- [x] 11.3 Update `tests/ai_scripts/project_setup_update_project_tests.sh`: remove any `feature_implementation_slices.sh` / rule / helper copy and assertion lines for the deleted assets
- [x] 11.4 Run `bash tests/ai_scripts/project_setup_asdlc_tests.sh` and confirm all tests pass
- [x] 11.5 Run `bash tests/ai_scripts/project_setup_update_project_tests.sh` and confirm all tests pass
- [x] 11.6 Run `git diff --check` — no whitespace errors
- [x] 11.7 Run `openspec validate crp-139-feature-implementation-slices --strict` and confirm the change validates
