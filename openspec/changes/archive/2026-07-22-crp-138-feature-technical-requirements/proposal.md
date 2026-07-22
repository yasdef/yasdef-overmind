## Why

CRP-137 completed migration of step 7.1 (MCP placeholder enrichment), closing the 4.1–7.1 range. The next step in the agreed migration table (`design_docs/to_skills_migration/migration_to_skill_architecture_overview.md` Steps→Skills) is **step 8 — "Technical requirements"** → `overmind-technical-requirements` — still implemented as bash: `feature_technical_requirements.sh` (model orchestrator) + `technical_requirements_rule.md` (rule) + `check_feature_technical_requirements_quality.sh` (gate helper). This change migrates that step to the agent-skill + TypeScript-core pattern proven by CRP-129→137.

Step 8 produces one **shared** `technical_requirements.md` artifact per feature, consolidating evidence from `requirements_ears.md`, `common_contract_definition.md`, and the per-class surface maps. Unlike step 7 (which loops per class), step 8 runs once and covers all active repo classes in a single pass. The gate is a substantial awk validator that checks all seven document sections, per-class repository-evidence blocks, per-requirement coverage blocks with transport/surface split, impacted-component blocks, and planning-signal or empty-marker in section 6. This validator ports one-for-one to `validate/technical-requirements.ts`.

## What Changes

- New skill `packages/installer/_data/skills/overmind-technical-requirements/SKILL.md` with `technical_requirements_rule.md` inlined; `assets/` with the template and golden example
- New context module `packages/asdlc-coordinator/src/context/technical-requirements.ts` — resolves feature path + project root, reads active project classes from `init_progress_definition.yaml`, resolves each class's applicable surface map file, emits the deterministic context block with read-only input manifest, target artifact path, and exact gate command
- New gate module `packages/asdlc-coordinator/src/validate/technical-requirements.ts` — ports every check from `check_feature_technical_requirements_quality.sh` one-for-one: all seven required sections, section-1 nine scalar keys, section-2 three scalar keys, section-3 per-class repo blocks (one per active class), section-4 per-requirement blocks with `transport_layer`/`user_reachable_surface` split (keyed against `REQ-*`/`NFR-*` from `requirements_ears.md`), section-5 component blocks (one per repo with applicable surface entries), section-6 planning-signal or `- planning_signals: none` shape, section-7 at least one `risk_N` entry; exits `0` on pass, `1` with actionable messages on content failures, `2` on runtime failures
- No capture module: step 8 has no human-input artifact; all inputs are already present when the step runs
- Register `technical-requirements` in `contextRegistry` and `gateRegistry` in `packages/asdlc-coordinator/src/cli/run.ts`
- Export from `packages/asdlc-coordinator/src/context/index.ts` and `validate/index.ts`
- Add TS tests in `packages/asdlc-coordinator` covering context output correctness (path resolution, read-only manifest, gate command) and all gate scenarios (exit `0`, every exit `1` content failure, exit `2` runtime failures)
- Add `overmind-technical-requirements` to `PACKAGED_SKILLS` in `packages/installer/src/init.ts`
- Update `overmind/scripts/project_mgmt/project_add_feature_e2e.sh`: replace legacy bash invocation at phase 8 with a `run_technical_requirements_skill` function (same Codex skill pattern as other phases); pre-session `overmind sync` if applicable, snapshot read-only inputs before session and `cmp`-assert each unchanged after, assert `technical_requirements.md` was produced
- Update `overmind/scripts/project_mgmt/project_setup_first_init_machine.sh`: add `overmind-technical-requirements` to `SKILL_NAMES`, remove legacy script/rule staging references for the old bash
- Update `tests/ai_scripts/project_add_feature_e2e_tests.sh` to cover the skill invocation for phase 8
- Delete `overmind/scripts/feature_technical_requirements.sh`
- Delete `overmind/rules/technical_requirements_rule.md`
- Delete `tests/ai_scripts/init_feature_technical_requirements_tests.sh`
- Delete `tests/ai_scripts/check_feature_technical_requirements_quality_tests.sh`
- Remove all deleted file references from setup staging arrays, test listings (`CLAUDE.md`), docs, and README
- Mark step 8 done in `design_docs/to_skills_migration/migration_to_skill_architecture_overview.md`

## Capabilities

### New Capabilities

- `technical-requirements`: Skill and TS context + gate primitives for step 8 (shared feature technical requirements). Covers the model-invokable `overmind context technical-requirements` and `overmind gate technical-requirements` commands, the inlined rule, all seven-section gate checks ported from the bash helper, and all TS tests proving context output and gate exit codes.

### Modified Capabilities

- `runner-skill-installation`: Extended to additionally install/stage `overmind-technical-requirements` across supported runners (Codex + Claude), plus clean-break removal of the migrated step-8 bash command, rule, and both test suites from ASDLC setup staging.

## Impact

- **New:** `packages/asdlc-coordinator/src/context/technical-requirements.ts`, `packages/asdlc-coordinator/src/validate/technical-requirements.ts`, `packages/installer/_data/skills/overmind-technical-requirements/` (SKILL.md + two assets), and matching TS tests
- **Modified:** `packages/asdlc-coordinator/src/cli/run.ts` (register in context + gate registries), `context/index.ts`, `validate/index.ts`, `packages/installer/src/init.ts`, `overmind/scripts/project_mgmt/project_setup_first_init_machine.sh`, `overmind/scripts/project_mgmt/project_add_feature_e2e.sh`, `tests/ai_scripts/project_add_feature_e2e_tests.sh`, `CLAUDE.md`, docs, README
- **Deleted:** `overmind/scripts/feature_technical_requirements.sh`, `overmind/rules/technical_requirements_rule.md`, `tests/ai_scripts/init_feature_technical_requirements_tests.sh`, `tests/ai_scripts/check_feature_technical_requirements_quality_tests.sh`
- **Retained:** all surface-map quality helpers (still used by the shell helper gate invocations for step 7.1 if needed by step 8.1+ un-migrated steps), shared libs, un-migrated steps 8.1–8.4
- **No new runtime dependency**; still requires built bundled CLI from `npm run build`
- **Out of scope:** the cross-step TS orchestrator; migrating setup/e2e shell to TS; steps 8.1 (implementation slices), 8.2 (prerequisite gaps), 8.3 (implementation plan), 8.4 (semantic review)
