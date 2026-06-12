## Why

The coordinator's evolution model no longer fits how projects actually grow. `project_type_code` is a single label fixed at init, but classes materialize at different times: a type `A` project whose backend repo exists after feature 1 — while mobile is still months away — is neither `A` nor `B`/`C`, and the blueprint-fallback machinery (CRP-117) is wired as type-`A`-only even though a repo-backed class still needs blueprint evidence for every layer no feature has touched yet. Meanwhile the `B`/`C` distinction is documented but unenforceable (there was never a recorded best practice to diverge from), and feature concurrency already exists de facto — `project_add_feature_e2e.sh` happily starts a new feature while others are unfinished — but no pipeline step reasons about other in-flight features, so concurrent features can silently duplicate work, claim conflicting contract shapes, and collide on surfaces.

This CRP consolidates the June 2026 design review into one baseline: classes transition blueprint→repo individually; evidence resolves per layer through a permanent demand-driven chain; `B`/`C` become divergence policies with real semantics; and planning becomes concurrency-aware by distinguishing merged truth (default branch) from promised truth (committed feature plans). It is the requirements baseline for the planned overmind Python+skills port; implementation lands inside the port.

## What Changes

- **Per-class transition (D1):** at feature start, the e2e flow detects deferred classes whose blueprint `planned_repo_path` is now scannable and prompts the operator to attach (reusing `project_setup_update_project.sh` logic), defaulting policy to `C` with a one-line policy explanation. `project_type_code` is demoted to init-time bookkeeping.
- **Per-class gating (D2):** steps `4.1`, `6`, and `7` gate on `class_repo_paths[<class>].state` instead of `project_type_code`; a per-class `policy` field is recorded at attach time (the list-shaped multi-repo hedge is deferred to the Python port — see design D9).
- **Permanent evidence chain (D3):** the CRP-117 blueprint fallback generalizes from type-`A`-only to a permanent per-layer chain — repo scan → in-flight promises → blueprint `(planned)` → placeholder — demand-driven, one source per row, every source tagged. Blueprint citations carry the blueprint's `last_updated` date.
- **Policy `C` divergence tagging (D5):** materialized-but-divergent layers resolve from repo silently with a passive `divergent_from_blueprint` row tag.
- **Concurrency (D7):** scans pin to the default branch (merged truth); committed plans become a promise evidence tier (`(in-flight <feature-folder>)` — features are referenced by folder name; the system has no separate feature-ID scheme); promise eligibility = the `feature_assing_workers.sh` readiness predicate (planning fully finished, all-or-nothing); feature lifecycle states `planning`/`committed`/`implementing`/`complete`/`abandoned`; step `8.2` gains `scheduled_in_feature <feature-folder>/<step-id>`; plan `#### Depends on:` learns cross-feature syntax.
- **Execution gating (D7):** assignment refuses steps with incomplete cross-feature dependencies, writing deterministic hold markers; every assignment run re-validates (catches abandoned-feature citations).
- **Collision detection (D7):** runs at the plan-commit moment against existing promises + merged truth; surface overlaps become step `8.4` findings, contract conflicts become an immediate e2e prompt. Never hard gates.
- **Contract reconciliation stopgap (D6):** one-time diff of `common_contract_definition.md` against the as-built API when a class first attaches.
- **Worker coordination (D4):** new worker step outcome `already_satisfied` (change lands in the yasdef worker repo; tracked here for coordination).
- **Phase 2 (D5-B):** policy `B` interactive divergence review on the step `8.4` pattern (bounded criteria; resolution = blueprint edit or scheduled alignment step; blueprint is the only memory) plus retroactive blueprint authoring for born-`B` projects. May split into its own CRP when cut.

## Capabilities

### New Capabilities

- `overmind-per-class-repo-transition`: The e2e flow SHALL detect, per deferred class at feature start, a scannable repository at the blueprint's `planned_repo_path` and SHALL offer an operator-confirmed attach with a one-line policy explanation, defaulting to policy `C`; feature steps SHALL gate on per-class repo state, never on `project_type_code`.
- `overmind-permanent-evidence-resolution-chain`: Surface-map and planning evidence SHALL resolve per layer/row through repo scan → in-flight promises → blueprint → placeholder, demand-driven, one tagged source per row, for the life of the project; blueprint citations SHALL carry the blueprint's `last_updated` date.
- `overmind-policy-c-divergence-tagging`: Under policy `C`, a layer materialized in the repo but divergent from the blueprint SHALL resolve from the repo without prompting and SHALL carry a passive `divergent_from_blueprint` tag.
- `overmind-feature-promise-evidence-tier`: A feature SHALL emit promise evidence if and only if its `implementation_plan.md` passes the assignment readiness predicate; mid-planning features SHALL emit nothing while reading committed siblings' promises; step `8.2` SHALL support `scheduled_in_feature <feature-folder>/<step-id>`; repo scans SHALL read the default branch only.
- `overmind-cross-feature-dependency-assignment-gate`: Worker assignment SHALL refuse steps whose cross-feature dependencies are not complete-and-merged, SHALL write deterministic hold markers naming the blocker, and SHALL re-validate all cross-feature dependencies on every run.
- `overmind-plan-commit-collision-check`: When a plan first passes the readiness predicate, it SHALL be checked against all existing promises and merged truth; surface overlaps SHALL surface as step `8.4` findings and contract conflicts as an immediate e2e prompt; neither SHALL hard-block.
- `overmind-first-attach-contract-reconciliation`: On a class's first attach, `common_contract_definition.md` SHALL be diffed against the as-built API for operator resolution; documented as a stopgap pending the feedback loop.
- `overmind-policy-b-divergence-review` (phase 2): Under policy `B`, structural blueprint divergences MAY surface as bounded semantic-review findings whose resolution is exactly one of: blueprint edit, or a scheduled alignment step.

### Modified Capabilities

- `overmind-type-a-step-7-blueprint-fallback-evidence` (CRP-117): generalized from type-`A`-only transitional behavior to the permanent per-class, per-layer chain.
- `overmind-prerequisite-gap-trace` (CRP-109): classification gains the cross-feature `scheduled_in_feature` category.
- `overmind-feature-implementation-plan-worker-assignment` (CRP-107): readiness predicate reused as promise eligibility; hold markers and re-validation added.
- `overmind-feature-lightweight-step-orchestrator` (CRP-103/106/116): transition detection at feature start; collision prompts at plan commit.

Per-capability spec deltas are intentionally not authored upfront; author them per tasks.md section as each section lands.

## Impact

- Implementation executes against the current shell/md stack by operator decision (see design D9); the Python port later inherits this behavior as its baseline. Assets affected:
  - `overmind/scripts/project_mgmt/project_add_feature_e2e.sh`, `project_setup_update_project.sh`, `init_progress_scanner.sh`
  - `overmind/scripts/feature_scan_repo_for_br.sh`, `feature_contract_delta.sh`, `feature_repo_surface_and_exec_context.sh`, `feature_prerequisite_gaps.sh`, `feature_implementation_plan.sh`, `feature_implementation_plan_semantic_review.sh`, `feature_assing_workers.sh`, `init_common_contract_definition.sh`
  - `overmind/rules/feature_repo_surface_and_exec_context_rule.md`, `prerequisite_gaps_rule.md`, `implementation_plan_rule.md`, `implementation_plan_semantic_review_rule.md`, `project_stack_blueprint_rule.md`
  - `overmind/templates/init_progress_definition_TEMPLATE.yaml`, `implementation_plan_TEMPLATE.md`, `prerequisite_gaps_TEMPLATE.md`, surface-map templates
- Cross-repo: yasdef worker (`already_satisfied` step outcome) — coordinate, do not implement here.
- Depends on concepts from `crp-115`/`crp-117` (blueprints, fallback evidence), `crp-109` (prerequisite trace), `crp-107` (assignment).
- Explicitly deferred (recorded in design.md Non-Goals): multi-repo/multi-worker per class; the feedback loop; B-as-type-vs-flag decision.
