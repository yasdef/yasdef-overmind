## Why

CRP-138 completed migration of step 8 (technical requirements), closing the 4.1–8 range. The next step in the agreed migration table (`design_docs/to_skills_migration/migration_to_skill_architecture_overview.md` Steps→Skills) is **step 8.1 — "Implementation slices"** → `overmind-implementation-slices` — still implemented as bash: `feature_implementation_slices.sh` (model orchestrator) + `implementation_slices_rule.md` (rule) + `check_implementation_slices_quality.sh` (gate helper). This change migrates that step to the agent-skill + TypeScript-core pattern proven by CRP-129→138.

Step 8.1 produces one **shared** `implementation_slices.md` artifact per feature: thin, executable slices discovered before step 8.2 (prerequisite gaps) and step 8.3 (ordered implementation plan) restore full ordering and traceability. Like step 8, it runs once and covers all active repo classes in a single pass; it does not loop per class. It reads four sibling artifacts (`requirements_ears.md`, `technical_requirements.md`, `feature_contract_delta.md`, and the per-class surface maps) as read-only inputs. Its gate is a substantial awk validator that checks four document sections, twelve section-1 meta keys, per-slice field/evidence/checklist rules, coordination-slice `signal_ref` gating, operator-facing-surface preservation, forbidden lifecycle boilerplate, and — when `prerequisite_gaps.md` is present — semantic coverage of every required missing operator-facing surface. This validator ports one-for-one to `validate/implementation-slices.ts`.

## What Changes

- New skill `packages/installer/_data/skills/overmind-implementation-slices/SKILL.md` with `implementation_slices_rule.md` inlined; `assets/` with the template and golden example
- New context module `packages/asdlc-coordinator/src/context/implementation-slices.ts` — resolves feature path + project root, reads active project classes from `init_progress_definition.yaml`, resolves each surface-map class's applicable surface map file, emits the deterministic context block with the read-only input manifest (`init_progress_definition.yaml`, `requirements_ears.md`, `technical_requirements.md`, `feature_contract_delta.md`, all applicable surface maps), target artifact path, active repo classes, asset references, and exact gate command
- New gate module `packages/asdlc-coordinator/src/validate/implementation-slices.ts` — ports every check from `check_implementation_slices_quality.sh`: four required sections (`## 1. Document Meta`, `## 2. Slice Planning Guardrails`, `## 3. Slice Candidates`, `## 4. Handoff To Ordered Plan`), twelve section-1 meta keys, `ordering_scope: local_prerequisites_only` and `traceability_scope: slice_level_only` literal checks, at least one Slice block with at least one `planned` slice, per-slice seven required fields (`repo`, `status`, `objective`, `first_increment`, `prerequisites`, `preserved_operator_surface`, `evidence`), repo ∈ active classes ∩ {backend,frontend,mobile}, `status` ∈ {existing,planned}, evidence-token grammar (`gap/TECH_REQ-N` / `gap/TECH_REQ-NFR-N` / `comp/<slug>`), `kind: coordination` requires non-empty `signal_ref`, at least two concrete checklist bullets per slice, operator-facing-surface term/supporting-only enforcement on non-`none` `preserved_operator_surface`, forbidden lifecycle boilerplate bullets, structured `[UNFILLED]` placeholder-value rejection, three section-4 handoff keys, and — when `prerequisite_gaps.md` exists — semantic `surface_matches` coverage of every required missing operator-facing surface; exits `0` on pass, `1` with actionable messages on content failures, `2` on runtime failures (missing sibling artifacts / project definition)
- No capture module: step 8.1 has no human-input artifact; all inputs are already present when the step runs
- Register `implementation-slices` in `contextRegistry` and `gateRegistry` in `packages/asdlc-coordinator/src/cli/run.ts`
- Export from `packages/asdlc-coordinator/src/context/index.ts` and `validate/index.ts`
- Add TS tests in `packages/asdlc-coordinator` covering context output correctness (path resolution, read-only manifest, active classes, gate command) and all gate scenarios (exit `0`, every exit `1` content failure, exit `2` runtime failures)
- Add `overmind-implementation-slices` to `PACKAGED_SKILLS` in `packages/installer/src/init.ts`
- Update `overmind/scripts/project_mgmt/project_add_feature_e2e.sh`: replace the legacy phase-8.1 bash invocation with a `run_implementation_slices_skill` function (same Codex skill pattern as phase 8); snapshot read-only inputs before session and `cmp`-assert each unchanged after, assert `implementation_slices.md` was produced
- Update `overmind/scripts/project_mgmt/project_setup_first_init_machine.sh`: add `overmind-implementation-slices` to `SKILL_NAMES`, remove legacy script/rule/helper and flat template/golden-example staging references for the old bash
- Update `tests/ai_scripts/project_add_feature_e2e_tests.sh` to cover the skill invocation for phase 8.1
- Delete `overmind/scripts/feature_implementation_slices.sh`
- Delete `overmind/rules/implementation_slices_rule.md`
- Delete `overmind/scripts/helper/check_implementation_slices_quality.sh`
- Delete `tests/ai_scripts/init_feature_implementation_slices_tests.sh`
- Delete `tests/ai_scripts/check_implementation_slices_quality_tests.sh`
- Remove all deleted file references from setup staging arrays, test listings (`CLAUDE.md`), docs, and README
- Mark step 8.1 done in `design_docs/to_skills_migration/migration_to_skill_architecture_overview.md`

## Capabilities

### New Capabilities

- `implementation-slices`: Skill and TS context + gate primitives for step 8.1 (shared feature implementation slices). Covers the model-invokable `overmind context implementation-slices` and `overmind gate implementation-slices` commands, the inlined rule, all four-section gate checks ported from the bash helper (including coordination-slice gating and required operator-facing-surface preservation), and all TS tests proving context output and gate exit codes.

### Modified Capabilities

- `runner-skill-installation`: Extended to additionally install/stage `overmind-implementation-slices` across supported runners (Codex + Claude), plus clean-break removal of the migrated step-8.1 bash command, rule, helper, and both test suites from ASDLC setup staging.

## Impact

- **New:** `packages/asdlc-coordinator/src/context/implementation-slices.ts`, `packages/asdlc-coordinator/src/validate/implementation-slices.ts`, `packages/installer/_data/skills/overmind-implementation-slices/` (SKILL.md + two assets), and matching TS tests
- **Modified:** `packages/asdlc-coordinator/src/cli/run.ts` (register in context + gate registries), `context/index.ts`, `validate/index.ts`, `packages/installer/src/init.ts`, `overmind/scripts/project_mgmt/project_setup_first_init_machine.sh`, `overmind/scripts/project_mgmt/project_add_feature_e2e.sh`, `tests/ai_scripts/project_add_feature_e2e_tests.sh`, `CLAUDE.md`, docs, README
- **Deleted:** `overmind/scripts/feature_implementation_slices.sh`, `overmind/rules/implementation_slices_rule.md`, `overmind/scripts/helper/check_implementation_slices_quality.sh`, `tests/ai_scripts/init_feature_implementation_slices_tests.sh`, `tests/ai_scripts/check_implementation_slices_quality_tests.sh`
- **Retained:** shared libs, surface quality helpers, and all downstream un-migrated step assets (steps 8.2–8.4)
- **No new runtime dependency**; still requires built bundled CLI from `npm run build`
- **Out of scope:** the cross-step TS orchestrator; migrating setup/e2e shell to TS; steps 8.2 (prerequisite gaps), 8.3 (implementation plan), 8.4 (semantic review)
