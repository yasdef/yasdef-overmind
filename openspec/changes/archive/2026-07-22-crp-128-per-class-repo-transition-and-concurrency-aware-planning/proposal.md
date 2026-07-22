## Why

The coordinator's evolution model no longer fits how projects actually grow. `project_type_code` is a single label fixed at init, but classes materialize at different times: a type `A` project whose backend repo exists after feature 1 — while mobile is still months away — is neither `A` nor `B`/`C`, and the blueprint-fallback machinery (CRP-117) is wired as type-`A`-only even though a repo-backed class still needs blueprint evidence for every layer no feature has touched yet. Meanwhile the `B`/`C` distinction is documented but unenforceable (there was never a recorded best practice to diverge from), and feature concurrency already exists de facto — `project_add_feature_e2e.sh` happily starts a new feature while others are unfinished — but no pipeline step reasons about other in-flight features, so concurrent features can silently duplicate work, claim conflicting contract shapes, and collide on surfaces.

This CRP consolidates the June 2026 design review into one baseline: classes transition blueprint→repo individually; evidence resolves per layer through a permanent demand-driven chain; `B`/`C` become divergence policies with real semantics; and planning becomes concurrency-aware by distinguishing merged truth (upstream-synchronized default branch) from promised truth (committed feature plans). It is the requirements baseline for the planned overmind Python+skills port; implementation lands inside the port.

## What Changes

- **Per-class transition (D1):** at feature start, the e2e flow prompts the operator directly for every deferred class — enter a valid repo path to attach (reusing `project_setup_update_project.sh` logic), defaulting policy to `C` with a one-line policy explanation, or leave blank to keep the class deferred. A blueprint cannot know the operator's machine layout, so there is no blueprint-declared repo path and no auto-detection; the operator-provided path is the sole attach source. `project_type_code` is demoted to init-time bookkeeping.
- **Per-class gating (D2):** steps `4.1` (Scan repo and apply task-to-BR update), `6` (Define Feature Contract Delta), and `7` (Analyze Repos And Prepare Repo Execution Context) gate on `class_repo_paths[<class>].state` instead of `project_type_code`; a per-class `policy` field is recorded at attach time (the list-shaped multi-repo hedge is deferred to the Python port — see design D9).
- **Permanent evidence chain (D3):** the CRP-117 blueprint fallback generalizes from type-`A`-only to a permanent per-layer chain — repo scan → in-flight promises → blueprint `(planned)` → placeholder — demand-driven, one source per row, every source tagged. Blueprint citations carry the blueprint's `last_updated` date.
- **Policy `C` divergence tagging (D5):** materialized-but-divergent layers resolve from repo silently with a passive `divergent_from_blueprint` row tag.
- **Concurrency (D7):** planning is serial (assumed, not enforced — one operator plans one feature at a time), execution is concurrent; scans synchronize the attached local repo's default branch from its configured upstream via `git pull --rebase` before reading it as merged truth; any sibling feature folder holding an `implementation_plan.md` is a promise evidence tier (`(in-flight <feature-folder>)` — features are referenced by folder name; the system has no separate feature-ID scheme; no readiness predicate, no lifecycle states — implemented steps come from repo scan, the rest stay promises); step `8.2` (Prerequisite Gap Trace) gains `scheduled_in_feature <feature-folder>/<step-id>`; plan `#### Depends on:` learns cross-feature syntax.
- **Execution gating (D7):** assignment refuses steps with incomplete cross-feature dependencies (the dependency's step block exists with every box `- [x]`), writing deterministic hold markers; every assignment run re-validates, flipping a hold to an assignment once the dependency completes.
- **Overlap surfacing (D7):** serial planning makes the feature being planned see every sibling promise, so overlaps surface inline — surface-map rows from a sibling are tagged `(in-flight <feature-folder>)` and raised as step `8.4` (Implementation Plan Semantic Review) product-fit findings; contract overlaps are reported during step `6` (Define Feature Contract Delta). No dedicated commit-moment detector and no collision prompt; nothing hard-gates.
- **Contract reconciliation stopgap (D6):** one-time diff of `common_contract_definition.md` against the as-built API when a class first attaches.
- **Reconciliation scoping (D10 follow-up):** first-attach reconciliation runs once after the per-class attach loop (not mid-loop) and is scoped to surface produced by attached classes; surface owned by still-deferred (promised) classes is never challenged.
- **Worker coordination (D4):** new worker step outcome `already_satisfied` (change lands in the yasdef worker repo; tracked here for coordination).
- **Phase 2 (D5-B):** policy `B` interactive divergence review on the step `8.4` (Implementation Plan Semantic Review) pattern (bounded criteria; resolution = blueprint edit or scheduled alignment step; blueprint is the only memory) plus retroactive blueprint authoring for born-`B` projects. May split into its own CRP when cut.

## Capabilities

### New Capabilities

- `overmind-per-class-repo-transition`: The e2e flow SHALL prompt the operator, per deferred class at feature start, for a repo path to attach with a one-line policy explanation, defaulting to policy `C`; an operator-provided path SHALL be the only attach source (no blueprint-declared path, no auto-detection) and a blank response SHALL keep the class deferred; feature steps SHALL gate on per-class repo state, never on `project_type_code`.
- `overmind-permanent-evidence-resolution-chain`: Surface-map and planning evidence SHALL resolve per layer/row through repo scan → in-flight promises → blueprint → placeholder, demand-driven, one tagged source per row, for the life of the project; blueprint citations SHALL carry the blueprint's `last_updated` date.
- `overmind-policy-c-divergence-tagging`: Under policy `C`, a layer materialized in the repo but divergent from the blueprint SHALL resolve from the repo without prompting and SHALL carry a passive `divergent_from_blueprint` tag.
- `overmind-feature-promise-evidence-tier`: A sibling feature folder SHALL emit promise evidence if and only if it holds an `implementation_plan.md` (planning is serial, so any such sibling has finished planning); promise resolution SHALL be per-row — implemented steps from repo scan, the rest as promises — with no lifecycle-state or implementation-status analysis; step `8.2` (Prerequisite Gap Trace) SHALL support `scheduled_in_feature <feature-folder>/<step-id>`; repo scans SHALL synchronize the attached local repo's default branch from its configured upstream with `git pull --rebase` before reading it.
- `overmind-cross-feature-dependency-assignment-gate`: Worker assignment SHALL refuse steps whose cross-feature dependencies are not complete-and-merged (the dependency's step block exists with every box `- [x]`), SHALL write deterministic hold markers naming the blocker, and SHALL re-validate all cross-feature dependencies on every run.
- `overmind-cross-feature-overlap-surfacing`: Because planning is serial, surface-map rows resolved from a sibling promise SHALL be tagged `(in-flight <feature-folder>)` and step `8.4` (Implementation Plan Semantic Review) SHALL raise them as product-fit findings; contract overlaps with sibling deltas SHALL be reported during step `6` (Define Feature Contract Delta). There SHALL be no dedicated commit-moment collision detector and no collision prompt; nothing here SHALL hard-block.
- `overmind-first-attach-contract-reconciliation`: On a class's first attach, `common_contract_definition.md` SHALL be diffed against the as-built API for operator resolution; documented as a stopgap pending the feedback loop.
- `overmind-policy-b-divergence-review` (phase 2): Under policy `B`, structural blueprint divergences MAY surface as bounded semantic-review findings whose resolution is exactly one of: blueprint edit, or a scheduled alignment step.

### Modified Capabilities

- `overmind-type-a-step-7-blueprint-fallback-evidence` (CRP-117): generalized from type-`A`-only transitional behavior to the permanent per-class, per-layer chain.
- `overmind-prerequisite-gap-trace` (CRP-109): classification gains the cross-feature `scheduled_in_feature` category.
- `overmind-feature-implementation-plan-worker-assignment` (CRP-107): cross-feature dependency hold markers and re-validation added (the readiness predicate stays the assignment-time gate only).
- `overmind-feature-lightweight-step-orchestrator` (CRP-103/106/116): transition prompt at feature start.

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
