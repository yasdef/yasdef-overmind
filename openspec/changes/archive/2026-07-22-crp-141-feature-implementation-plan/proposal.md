## Why

CRP-140 completed migration of step 8.2 (prerequisite gaps), leaving **step 8.3 — "Implementation plan"** → `overmind-implementation-plan` as the next row in the migration table (`design_docs/to_skills_migration/migration_to_skill_architecture_overview.md` Steps→Skills). It is still implemented as bash: `feature_implementation_plan.sh` (model orchestrator) + `implementation_plan_rule.md` (rule) + `check_implementation_plan_quality.sh` (gate helper). This change migrates that step to the agent-skill + TypeScript-core pattern proven by CRP-129→140.

Step 8.3 produces one **shared** `implementation_plan.md` artifact per feature: a single ordered, cross-repo executable plan where every `### Step` has exactly one `#### Repo:` owner, explicit `#### Depends on:` ordering, `#### Evidence:` traceability tokens grounded in `technical_requirements.md`, and `#### Preserved Surface:` retention of required operator-facing surfaces from `prerequisite_gaps.md`. It consumes the outputs of steps 8.1 (`implementation_slices.md`) and 8.2 (`prerequisite_gaps.md`) plus `requirements_ears.md`, `technical_requirements.md`, and `feature_contract_delta.md`. Like steps 8/8.1/8.2, it runs once and covers all active repo classes in a single pass; it does not loop per class.

Unlike step 8.2 (CRP-140), step 8.3 has **no pre-session repo sync** (`feature_implementation_plan.sh` never syncs repos) and **no capture module** (all upstream inputs are in place before it runs). It therefore mirrors CRP-139's structure — a **context** module + **validate** module + skill — with no `sync/` module and no `capture/` module.

The gate (`check_implementation_plan_quality.sh`) is the largest in the pipeline. It derives four catalogs from the read-only inputs before validating the plan:
1. **Active repo classes** from `init_progress_definition.yaml` (`backend`/`frontend`/`mobile`; `infrastructure` skipped).
2. **Valid requirement ids** (`REQ-*`/`NFR-*`) from `requirements_ears.md`.
3. **Technical evidence catalog** from `technical_requirements.md` — all + unresolved `gap/TECH_REQ-*` requirement tokens (section `## 4. Requirement Coverage and Gaps`), all + unresolved `comp/<slug>` component tokens and their repos (section `## 5. Impacted Components`), keyed by `gap_status`/`gap_to_close`.
4. **Scheduled slice_refs** and **required missing operator-facing surfaces** from `prerequisite_gaps.md`.

It then validates each `### Step` block: strictly-increasing unique step ids; at least one valid `REQ-*`/`NFR-*` heading ref; exactly-once `#### Repo:` (∈ active classes, ∈ {backend,frontend,mobile}), `#### Depends on:`, `#### Evidence:`, `#### Preserved Surface:`; ≥3 checklist bullets with first `Plan and discuss the step` and a `Review step implementation` bullet; dependency edges (same-feature refs point to earlier known steps, cross-feature refs match `<feature-folder>/<step-id>`, no duplicate/empty edges); evidence tokens (`gap/TECH_REQ-*`, `comp/<slug>` must exist in the catalog; `slice/<ref>` is free-form; no duplicates/empty; ≥1 valid token); optional `#### Coordination: true`; and preserved-surface operator-facing/supporting-only checks. Finally it runs whole-plan coverage checks: no `[UNFILLED]`; ≥1 step; every repo with unresolved impacted components has ≥1 step; every valid requirement id covered by a heading; every unresolved requirement/component evidence token covered; every scheduled `slice_ref` covered by a `slice/<ref>` token; every required missing operator-facing surface preserved by a non-coordination step (with a canonical-surface fuzzy matcher). All of this ports one-for-one to `validate/implementation-plan.ts`.

## What Changes

- New skill `packages/installer/_data/skills/overmind-implementation-plan/SKILL.md` with `implementation_plan_rule.md` inlined; `assets/` with the template and golden example
- New context module `packages/asdlc-coordinator/src/context/implementation-plan.ts` — resolves feature path + project root, reads active project classes from `init_progress_definition.yaml` (accepts `backend`/`frontend`/`mobile`/`infrastructure`; requires at least one supported repo class), and emits the deterministic context block with the read-only input manifest (`init_progress_definition.yaml`, `requirements_ears.md`, `technical_requirements.md`, `feature_contract_delta.md`, `implementation_slices.md`, `prerequisite_gaps.md`), target artifact path (`implementation_plan.md`), active repo classes, skill-relative asset references, and exact gate command
- New gate module `packages/asdlc-coordinator/src/validate/implementation-plan.ts` — ports every check from `check_implementation_plan_quality.sh` one-for-one: the four catalog extractors (active classes, requirement refs, technical evidence catalog with req/comp all+unresolved and unresolved repos, prerequisite scheduled slice_refs + required missing surfaces), all per-`### Step` structural/semantic checks (step-id ordering/uniqueness, heading REQ/NFR refs, exactly-once Repo/Depends on/Evidence/Preserved Surface, bullet count + plan/review bullets, dependency-edge validation, evidence-token validation, preserved-surface operator-facing + supporting-only checks, coordination marker), and the whole-plan END coverage checks (no `[UNFILLED]`, ≥1 step, required-repo coverage, requirement-id coverage, unresolved req/comp token coverage, scheduled slice_ref coverage, required-surface preservation via the canonical-surface matcher); exits `0` on pass, `1` with actionable messages on content failures, `2` on runtime failures (missing target/sibling/definition artifacts)
- No sync module: step 8.3 performs no pre-session repo sync (unlike step 8.2)
- No capture module: step 8.3 has no human-input artifact; all inputs are already present when the step runs
- Register `implementation-plan` in `contextRegistry` and `gateRegistry` in `packages/asdlc-coordinator/src/cli/run.ts`
- Export from `packages/asdlc-coordinator/src/context/index.ts` and `validate/index.ts`
- Add TS tests in `packages/asdlc-coordinator` covering context output correctness (path resolution, read-only manifest, active classes, gate command) and all gate scenarios (exit `0`, every exit `1` content failure incl. each catalog-derived coverage failure, exit `2` runtime failures)
- Add `overmind-implementation-plan` to `PACKAGED_SKILLS` in `packages/installer/src/init.ts`
- Update `overmind/scripts/project_mgmt/project_add_feature_e2e.sh`: replace the legacy phase-8.3 bash invocation with a `run_implementation_plan_skill` function (same Codex skill pattern as phases 8/8.1/8.2, no sync); snapshot read-only inputs before session and `cmp`-assert each unchanged after, assert `implementation_plan.md` was produced
- Rewire step 8.4 (`overmind/scripts/feature_implementation_plan_semantic_review.sh`, still bash) off the deleted `check_implementation_plan_quality.sh` helper: drop the `IMPLEMENTATION_PLAN_QUALITY_GATE_HELPER` required-file dependency, add an `OVERMIND_CLI_FILE` (`.overmind/overmind.js`) binding, and change the model-facing "Implementation plan quality gate command" to `node .overmind/overmind.js gate implementation-plan <feature-path>` (wiring only — step 8.4's own gate/rule/skill migration is deferred). Without this, deleting the helper breaks step 8.4 at startup
- Update `overmind/scripts/project_mgmt/project_setup_first_init_machine.sh`: add `overmind-implementation-plan` to `SKILL_NAMES`, remove legacy script/rule/helper and flat template/golden-example staging references for the old bash
- Update `tests/ai_scripts/project_add_feature_e2e_tests.sh` to cover the skill invocation for phase 8.3
- Delete `overmind/scripts/feature_implementation_plan.sh`
- Delete `overmind/rules/implementation_plan_rule.md`
- Delete `overmind/scripts/helper/check_implementation_plan_quality.sh`
- Delete `tests/ai_scripts/init_feature_implementation_plan_tests.sh`
- Delete `tests/ai_scripts/check_implementation_plan_quality_tests.sh`
- Remove all deleted file references from setup staging arrays, test listings (`CLAUDE.md`), docs, and README
- Mark step 8.3 done in `design_docs/to_skills_migration/migration_to_skill_architecture_overview.md`

## Capabilities

### New Capabilities

- `implementation-plan`: Skill and TS context + gate primitives for step 8.3 (shared feature implementation plan). Covers the model-invokable `overmind context implementation-plan` and `overmind gate implementation-plan` commands, the inlined rule, all gate checks ported from the bash helper (four catalog extractors, per-step structural/semantic validation, and whole-plan coverage checks), and all TS tests proving context output and gate exit codes. No sync or capture command (step 8.3 has neither).

### Modified Capabilities

- `runner-skill-installation`: Extended to additionally install/stage `overmind-implementation-plan` across supported runners (Codex + Claude), plus clean-break removal of the migrated step-8.3 bash command, rule, helper, and both test suites from ASDLC setup staging.

## Impact

- **New:** `packages/asdlc-coordinator/src/context/implementation-plan.ts`, `packages/asdlc-coordinator/src/validate/implementation-plan.ts`, `packages/installer/_data/skills/overmind-implementation-plan/` (SKILL.md + two assets), and matching TS tests
- **Modified:** `packages/asdlc-coordinator/src/cli/run.ts` (register in context + gate registries), `context/index.ts`, `validate/index.ts`, `packages/installer/src/init.ts`, `overmind/scripts/project_mgmt/project_setup_first_init_machine.sh`, `overmind/scripts/project_mgmt/project_add_feature_e2e.sh`, `overmind/scripts/feature_implementation_plan_semantic_review.sh` (step-8.4 plan-gate reference rewired to the CLI), `tests/ai_scripts/project_add_feature_e2e_tests.sh`, `CLAUDE.md`, docs, README
- **Deleted:** `overmind/scripts/feature_implementation_plan.sh`, `overmind/rules/implementation_plan_rule.md`, `overmind/scripts/helper/check_implementation_plan_quality.sh`, `tests/ai_scripts/init_feature_implementation_plan_tests.sh`, `tests/ai_scripts/check_implementation_plan_quality_tests.sh`
- **Retained:** shared libs (`class_repo_paths.sh`, `sync_repo_to_default_branch.sh`, `list_committed_sibling_features.sh`), surface quality helpers, and all downstream un-migrated step assets (step 8.4's own semantic-review gate/rule/template/golden-example/skill, worker assignment/readiness). Step 8.4's bash orchestrator stays but has its plan-gate reference rewired to the CLI (see above)
- **No new runtime dependency**; still requires built bundled CLI from `npm run build`
- **Out of scope:** the cross-step TS orchestrator; migrating setup/e2e shell to TS; migrating step 8.4's own semantic-review gate/rule/skill (only its cross-step plan-gate reference is rewired); worker assignment/readiness (`feature_assing_workers.sh`, `check_implementation_plan_readiness`)
