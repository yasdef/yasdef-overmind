# Process Gaps in the Overmind Planning Pipeline

This document is the greenfield rebuild brief for the next clean planning-pipeline improvements.

It intentionally does not describe the discarded five-commit attempt as a patch history or postmortem. Instead, it extracts only the ideas worth keeping and rewrites them as clean implementation gaps.

Baseline assumptions for this rebuild:

- the baseline is commit `4125918`,
- transport-vs-user-reachable separation already exists,
- prerequisite gap tracing already exists,
- `requirements_ears.md` remains the canonical source of required system behavior and required operator-facing outcomes.

## Global guardrails for the rebuild

These guardrails apply to every gap below:

- Start from `requirements_ears.md` and protect the required user/operator outcome first.
- Use `technical_requirements.md`, surface maps, and `feature_contract_delta.md` as evidence inputs, not as excuses to displace required feature delivery.
- Keep hard quality gates for structural facts only.
- Keep product-fit questions in semantic review unless they can be checked mechanically.
- Prefer optional coordination over mandatory management scaffolding.
- Do not reintroduce blanket dependency wiring across repos.

## Lessons translated into clean rebuild gaps

The worthwhile lessons from the discarded attempt collapse into four greenfield improvements:

1. semantic review should question whether newly delivered user-reachable surfaces are actually reachable by an operator,
2. technical requirements should be able to express cross-repo coordination intent in a typed, reviewable form,
3. required operator-facing surfaces from `requirements_ears.md` must not disappear behind API/contract/security scaffolding during slice and plan generation,
4. the planner should be able to emit coordination work when it is truly justified, but must not be forced to do so for every multi-repo feature.

Each gap below is written in the same format:

1. Gap
2. How to fix
3. Concrete implementation steps
4. Risks / what NOT to do

## Gap 1 - Semantic review does not question whether a newly delivered surface is actually reachable by an operator

### 1. Gap

The current pipeline can produce a plan that adds a new `user_reachable_surface` and still miss the practical product question:

- how does the operator get to it?

That is a different problem from prerequisite-gap tracing.

Prerequisite tracing answers:

- is a required surface missing,
- is a missing surface at least scheduled somewhere.

It does not answer:

- after a new route, page, admin console, screen, CLI command, or public endpoint is delivered, does any reachable surface point to it,
- if not, is that isolation intentional or accidental.

This matters directly to `requirements_ears.md`. If a feature requires that an operator can use a workspace, login entry, screen, or console flow, a plan that only creates the target surface but leaves no inbound path is behaviorally incomplete even if the route technically exists.

### 2. How to fix

Add a semantic-review finding type dedicated to access-path clarity for newly delivered user-reachable surfaces.

This must stay in semantic review rather than a hard structural quality gate, because the right answer is product-fit judgment:

- sometimes a missing inbound path is a defect,
- sometimes the surface is intentionally isolated by design.

The review should perform a required four-step check for every newly delivered user-reachable surface:

1. identify the delivered surface,
2. inspect the applicable surface map for existing inbound affordances,
3. inspect sibling plan steps for newly added inbound affordances,
4. if neither exists, raise an operator question instead of silently assuming the plan is fine.

### 3. Concrete implementation steps

1. Update `overmind/rules/implementation_plan_semantic_review_rule.md` to add a new finding type: `delivered_surface_consumption_unclear`.
2. Add the explicit four-step delivered-surface heuristic to that rule.
3. Require the semantic review prompt to receive these read-only inputs when applicable:
   - `prerequisite_gaps.md`
   - backend/frontend/mobile surface-map artifacts for active repo classes
4. Update `overmind/templates/implementation_plan_semantic_review_TEMPLATE.md` so this finding type is allowed and documented as a product-fit finding.
5. Update the semantic review golden example to include both valid outcomes:
   - `applied` when an inbound affordance must be added,
   - `rejected` when the surface is intentionally isolated.
6. Update `overmind/scripts/feature_implementation_plan_semantic_review.sh` so the required inputs are actually bound into the review context.
7. Add tests proving:
   - a new route with no inbound edge produces the finding,
   - a route with a sibling inbound-affordance step does not,
   - terminal state is rejected when `resolution_notes` is empty for this finding type.

### 4. Risks / what NOT to do

- Do not move this into `check_implementation_plan_quality.sh` as a hard-fail rule.
- Do not assume every isolated surface is wrong.
- Do not let the reviewer invent fake navigation requirements that are not justified by `requirements_ears.md` or operator confirmation.
- Do not allow `delivered_surface_consumption_unclear` to reach a terminal state without non-empty `resolution_notes`.
- Do not confuse "surface exists" with "operator can reach and use it."

## Gap 2 - Technical requirements cannot express cross-repo coordination intent in a typed but lightweight way

### 1. Gap

The baseline pipeline can detect cross-repo contract pressure, but it has no compact typed way to carry that intent forward.

Today the system can know things like:

- a backend-owned artifact is shared by multiple repos,
- response-shape drift is possible,
- a contract needs to be reviewed before several repos implement against it,
- or a shared artifact would reduce coordination risk.

But without a typed representation in `technical_requirements.md`, later phases either:

- ignore the coordination need,
- or reconstruct it loosely from prose.

That makes coordination inconsistent and hard to review.

### 2. How to fix

Add typed `planning_signal` blocks to section 6 of `technical_requirements.md`.

These signals should be advisory metadata, not execution steps and not mandatory triggers.

Their purpose is limited and explicit:

- make cross-repo coordination intent visible,
- preserve that intent in a structured form for downstream consumers,
- make the reasoning reviewable without forcing downstream artifacts to overreact.

The signal should say "coordination may be needed here". It must not mean "a coordination slice and plan step are now mandatory".

### 3. Concrete implementation steps

1. Update `overmind/rules/technical_requirements_rule.md` so section 6 supports zero-or-more typed `planning_signal` blocks.
2. Start with one supported signal type:
   - `cross_repo_contract_lock`
3. Define a strict block schema in section 6 with fields such as:
   - `signal_id`
   - `signal_type`
   - `owner_repo`
   - `consumer_repos`
   - `required_artifact`
   - `must_precede`
   - `output_requirements`
   - `source_evidence`
4. Update `overmind/templates/technical_requirements_TEMPLATE.md` and the golden example to show:
   - one valid populated signal block,
   - one valid empty-path case when no signal is needed.
5. Update `overmind/scripts/helper/check_feature_technical_requirements_quality.sh` to validate only structural correctness:
   - unique ids,
   - required fields present,
   - evidence tokens resolve,
   - repo names are valid for the active project classes.
6. Keep section 6 explicitly optional. When no signal is needed, require only a simple empty marker line.
7. Add tests for:
   - valid signal block,
   - empty-path case,
   - invalid evidence token,
   - duplicate signal id,
   - invalid repo ownership.

### 4. Risks / what NOT to do

- Do not hard-require a signal solely because the feature is multi-repo.
- Do not hard-require a signal solely because `feature_contract_delta.md` says `delta_needed: true`.
- Do not let the quality helper fail simply because section 6 is empty.
- Do not turn section 6 back into loose `prep_*` prose once typed blocks exist.
- Do not let typed signals become hidden plan steps at the technical-requirements phase.

## Gap 3 - Required operator-facing surfaces from `requirements_ears.md` can still disappear during slice and plan generation

### 1. Gap

Even after prerequisite-gap tracing, the pipeline can still lose the actual required delivery surface during later transformations.

The failure pattern is:

- `requirements_ears.md` and technical analysis correctly show that an operator-facing surface is required,
- prerequisite analysis correctly shows that the surface is missing,
- but slices or plan steps later drift toward API, state, security, contract, or coordination work,
- and the required login, entry route, workspace shell, page, or screen stops being explicitly scheduled.

This is the most important regression to block in the rebuild because it breaks direct alignment to required behavior.

### 2. How to fix

Add a preservation rule across slice generation and implementation-plan generation.

The preservation rule should say:

- when `requirements_ears.md` requires a user/operator-facing surface,
- and prerequisite analysis shows that surface is missing,
- later planning phases must preserve that missing surface as explicit delivery work until it is covered.

Coordination work, API work, and state work may be added around it, but they must not replace it.

### 3. Concrete implementation steps

1. Make sure prerequisite-gap output clearly distinguishes required missing `user_reachable_surface` items from transport-only or internal execution gaps.
2. Update `overmind/rules/implementation_slices_rule.md` so each required missing operator-facing surface is preserved by at least one feature-delivery slice.
3. Update `overmind/rules/implementation_plan_rule.md` so the same required missing surface is preserved by at least one implementation-plan step until delivered.
4. Update `overmind/scripts/helper/check_implementation_slices_quality.sh` to verify that unresolved required operator-facing surfaces from upstream artifacts remain represented in slice output.
5. Update `overmind/scripts/helper/check_implementation_plan_quality.sh` to verify the same preservation at plan level.
6. Add end-to-end tests around cases like:
   - missing login surface,
   - missing protected shell,
   - missing admin entry route,
   - missing operator-facing lookup page.
7. Ensure the preservation logic works off upstream evidence and requirement meaning, not off a hardcoded route-name list.

### 4. Risks / what NOT to do

- Do not fabricate user-facing work when `requirements_ears.md` does not require a user-facing surface.
- Do not allow coordination, contract, API, or auth scaffolding to count as satisfying a missing operator-facing surface.
- Do not force navigation-affordance work from this rule alone. Preserving a required surface and deciding how operators reach it are related but different problems.
- Do not implement this as a brittle string-match against one route or one UI framework.
- Do not let a "contract first" transformation hide the actual required operator outcome.

## Gap 4 - The planner needs an optional coordination mechanism for real cross-repo contract locking, not a mandatory unblocker regime

### 1. Gap

Once typed coordination signals exist, the planner still needs a way to represent real coordination work when a shared contract artifact genuinely must be clarified before some downstream implementation can proceed safely.

Without that mechanism, section 6 becomes informative but toothless.

But the opposite extreme is worse:

- every planning signal becomes a required slice,
- every such slice becomes a required plan step,
- every consumer repo is wired behind it,
- and operator-facing feature work is delayed by management scaffolding.

So the real gap is not "missing unblockers".
The real gap is:

- how to allow coordination work when justified,
- without forcing coordination work into every multi-repo feature.

### 2. How to fix

Introduce optional coordination slices and optional coordination plan steps.

They should only be emitted when the evidence shows genuine need, for example:

- the shared contract semantics are materially ambiguous,
- several repos would otherwise implement incompatible interpretations,
- a concrete shared artifact needs to be frozen before safe parallel delivery,
- or the technical requirements make the drift risk explicit.

The absence of a coordination slice must remain valid when repo-local delivery can proceed safely.

### 3. Concrete implementation steps

1. Update `overmind/rules/implementation_slices_rule.md` so slice generation may emit an optional coordination slice kind for justified contract-lock work.
2. Keep coordination slices separate from ordinary feature-delivery slices in the artifact structure so they remain visible but do not replace feature delivery.
3. Define clear emission criteria in the rule:
   - real ambiguity,
   - real shared-artifact need,
   - real multi-repo drift risk,
   - direct supporting evidence from section 6 and upstream artifacts.
4. Update `overmind/templates/implementation_slices_TEMPLATE.md` and the golden example to show both valid paths:
   - with a coordination slice,
   - without one.
5. Update `overmind/rules/implementation_plan_rule.md` so the plan may lift a justified coordination slice into a plan step only when downstream work is actually blocked by that artifact.
6. Update the slice and plan quality helpers to validate coordination artifacts only when they are present. Their absence must remain valid.
7. Add tests proving both scenarios:
   - a feature where coordination work is emitted and correctly wired,
   - a feature where no coordination work is emitted and quality still passes.

### 4. Risks / what NOT to do

- Do not require exactly one coordination slice for every `planning_signal`.
- Do not require every coordination slice to become a plan step.
- Do not force a coordination step to be the earliest step for its repo.
- Do not blanket-add dependency edges to all consumer-repo steps.
- Do not infer hard gating purely from shared `comp/*` evidence overlap.
- Do not let optional coordination work crowd out the preserved operator-facing delivery required by Gap 3.
- Do not treat `delta_needed: true` as proof that a coordination artifact must exist.

## Recommended implementation order

### Step 1 - Implement Gap 1 first

Why first:

- self-contained,
- low coupling,
- immediate product-fit value.

Expected result:

- semantic review can catch newly delivered but practically unreachable surfaces.

### Step 2 - Implement Gap 3 second

Why second:

- it protects direct alignment to `requirements_ears.md` before any new coordination machinery is added.

Expected result:

- required operator-facing surfaces can no longer disappear behind infrastructure or contract work.

### Step 3 - Implement Gap 2 third

Why third:

- once required delivery preservation is protected, typed coordination metadata can be added safely.

Expected result:

- technical requirements can carry structured coordination intent without over-forcing downstream artifacts.

### Step 4 - Implement Gap 4 last

Why last:

- optional coordination should sit on top of preserved feature completeness and typed advisory metadata.

Expected result:

- the planner can emit coordination work when it is genuinely justified while simpler features remain lean.

## Acceptance criteria for the rebuild direction

The rebuild direction is correct only if all of the following are true:

- if `requirements_ears.md` requires a login, entry route, workspace shell, or operator-facing screen, that surface still appears in slices and plan until covered,
- semantic review raises an operator question when a newly delivered user-reachable surface has no inbound path,
- technical requirements can express cross-repo coordination intent in typed form,
- the planner may emit contract-coordination work when evidence justifies it,
- the planner is not forced to emit contract-coordination work merely because the feature is multi-repo,
- quality helpers do not fail merely because no coordination artifact was emitted,
- optional coordination work never displaces required operator-facing delivery.

## Out of scope for this brief

- resetting the main repository branch,
- patching the discarded five commits in place,
- authoring proposal/spec/design artifacts before these process gaps are accepted,
- unrelated refactors outside this rebuild scope.
