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
 
## Additional gaps — project type `A` enablement

Gaps 5 and 6 address a separate workstream from Gaps 1–4. They do not come from the discarded five-commit attempt. They address the fact that step 7 (`feature_repo_surface_and_exec_context`) is the structural gate for the entire downstream planning pipeline, but only supports project types `B` and `C`. For type `A` (a brand-new project with no repository to scan), the pipeline fails by design, which blocks every later phase for that class.

Their purpose is to let type `A` produce the same surface-map artefact without inventing facts, by introducing a declarative per-class stack blueprint that substitutes for repo scan evidence.

## Gap 5 - Project type `A` has no path to produce the per-class surface map required by step 7

### 1. Gap

Step 7 (`feature_repo_surface_and_exec_context`) is the structural gate for every downstream planning phase. Steps 8, 8.1, 8.2, and 8.3 all take `project_surface_struct_resp_map_<class>.md` as a required input, so if step 7 cannot produce that artefact for a class, every later phase is blocked for that class.

Today step 7 only supports project types `B` and `C` because it relies on scanning a real repository at `class_repo_paths[<class>].path`:

- `overmind/scripts/feature_repo_surface_and_exec_context.sh` hard-fails with `fail_mcp_not_supported_for_project_a` when `project_type_code=A`.
- `overmind/rules/feature_repo_surface_and_exec_context_rule.md` states "If project type is `A`: this stage is unsupported for now; do not generate pseudo-content."

For a brand-new project (type `A`) there is no repository to scan, but the surface-map template still requires concrete values for `main_repo_paths`, `key_components`, `transport_layer`, per-layer `user_reachable_surface`, and Section 4 `evidence`. The rule also forbids inventing layers, module boundaries, or touched surfaces without evidence. Without a declarative substitute for repo evidence, the only honest behaviour is to block — which is what the pipeline does today.

The missing input is a structured description of how the project intends to build each active class: language and framework, layer folder conventions, datastore, async/messaging, observability, and the baseline operator-reachable tokens (login, health, already-planned routes) that the feature will reuse rather than create.

### 2. How to fix

Introduce a per-class project-level artefact, `project_stack_blueprint_<class>.md`, authored once during project init and reused for every feature's step 7 run. The blueprint supplies the same structural facts a repo scan would otherwise reveal, in a form downstream planning can cite as evidence.

For project type `A`, blueprint creation must be an explicit project-init substep after the user selects active project classes and before step 2 (`Create Cross-Repository Contract Definition For This Project`). Step 1 records `project_type_code`, `project_classes`, and optional per-class stack guidance sources when the user provides them at startup; new step 1.1 creates exactly one project-level blueprint for each active class. Step 2 then consumes those blueprints as read-only project context when preparing `common_contract_definition.md`.

Blueprint creation must be interactive and source-aware:

- first check whether project startup configuration declares an MCP/source of stack guidance for the active class,
- when such MCP guidance exists, use it as the proposal source and summarize the proposed stack choices for user approval,
- when no class-specific MCP guidance is configured or available, the model proposes a small default menu and asks the user to approve or override it,
- default fallback proposals are intentionally boring: backend defaults to Java/Spring Boot with Node.js as the main alternative; frontend defaults to React with Angular as the main alternative; mobile defaults to native Android Kotlin and iOS Swift with Flutter/Dart as the main alternative,
- do not write the final blueprint until the user has approved the chosen stack and baseline class conventions,
- record the proposal source and approval decision in the step 1.1 authoring flow, not in the blueprint template contract.

Blueprint scope is deliberately narrow:

- stack choices (language, framework, datastore, messaging, observability, deployment, test stack),
- per-layer folder conventions and component archetypes aligned to the surface-map template,
- a baseline inventory of already-planned `user_reachable_surface` tokens the feature can reuse.

It must not encode implementation decisions that belong in `implementation_slices.md` or `implementation_plan.md`, and it must not duplicate contract governance owned by `common_contract_definition.md`.

Sizing guidance: a roughly two-page blueprint (stack + per-layer folder conventions + archetypes + baseline tokens) is the sweet spot. Going deeper pre-commits architecture decisions that belong in `implementation_slices.md` or `implementation_plan.md` and drags the blueprint out of its "stable across features" lane.

### 3. Concrete implementation steps

1. Add new templates under `overmind/templates/`:
   - `project_stack_blueprint_be_TEMPLATE.md`
   - `project_stack_blueprint_fe_TEMPLATE.md`
   - `project_stack_blueprint_mobile_TEMPLATE.md`
2. Each template defines structure only: required headings, field names, and placeholders/comments. Concrete stack choices, project-specific values, proposal source, approval state, and behavior rules do not belong in templates.
3. Each template defines four required sections:
   - §1 Meta — `class`, `repo_name`, `service_name`, `planned_repo_path`, `group_id_or_package_root`, `last_updated`.
   - §2 Stack Choices — language/runtime, framework, build tool, datastore, ORM/migrations, async/messaging (or literal `none`), http clients, auth model, logging, metrics, tracing, health endpoint, deployment target, test stack.
   - §3 Layer Bindings — one block per standard layer in the matching surface-map template, each carrying `folder_paths`, `archetypes`, and a `user_reachable_pattern` or literal `none`.
   - §4 Baseline User-Reachable Inventory — machine-parseable operator-reachable tokens already planned at project level (login routes, health/metrics endpoints, baseline screens, scheduled jobs). Tokens must match the per-class taxonomy in `overmind/rules/feature_repo_surface_and_exec_context_rule.md`.
4. Add a quality helper `overmind/scripts/helper/check_project_stack_blueprint_quality.sh` that validates structural completeness only:
   - all §1 meta fields present,
   - at least one populated field per §2 stack category,
   - §3 layer blocks match the standard layers expected by the surface-map template for that class,
   - §4 tokens, when present, match the rule's token regex rather than prose; a literal `none` is a valid §4 value when the project has no operator-reachable surfaces planned yet.
5. Add a step 1.1 model prompt/rule/script for blueprint authoring:
   - read `init_progress_definition.yaml` to get `project_type_code` and active `project_classes`,
   - read optional per-class startup metadata such as `stack_guidance_sources[<class>]` when present,
   - no-op for project types `B` and `C`,
   - for project type `A`, process each active class separately,
   - check the startup-configured MCP/source of stack guidance for that class before proposing choices,
   - if guidance exists, present MCP-backed stack choices for user discussion and approval,
   - if guidance is absent, present the bounded default menu (`Java/Spring Boot` vs `Node.js`, `React` vs `Angular`, `native Android Kotlin + iOS Swift` vs `Flutter/Dart`) for user discussion and approval,
   - write the approved blueprint only after user approval,
   - run `check_project_stack_blueprint_quality.sh` before the step is considered complete.
6. Update step 1 project setup metadata so type `A` startup can record optional per-class `stack_guidance_sources`; absence of this metadata is valid and triggers the fallback proposal path.
7. Add step 1.1 to `overmind/templates/init_progress_definition_TEMPLATE.yaml`:
   - `phase_name: "init"`,
   - `step_name: "Define Project Stack Blueprints For Active Classes"`,
   - input documents/user input are `init_progress_definition.yaml`, `project_type_code`, and active `project_classes`,
   - a new `finished_only_if_artefacts_present` entry for `project_stack_blueprint_<class>.md` per active class at the project root,
   - a `required_if` guard so the artefact is required only when `project_type_code=A`; optional for `B` and `C`.
8. Update step 2 inputs/conditions so, for project type `A`, `common_contract_definition.md` is created after the per-class blueprints exist and treats them as read-only project context, not as API contract schema definitions.
9. Add a matching init-phase rule clarifying that type `A` projects cannot proceed to step 2 until a blueprint exists for every active class.
10. Add tests covering:
   - type `A` init blocks until the per-class blueprint exists,
   - startup can record a per-class stack guidance source and step 1.1 passes it into the blueprint authoring prompt,
   - no final blueprint is written before stack approval is recorded,
   - missing MCP guidance falls back to bounded model proposals rather than blocking,
   - the blueprint quality helper fails when required fields or layer blocks are missing,
   - step 2 for type `A` sees the per-class blueprints as available read-only inputs,
   - type `B` and `C` init remains unaffected by the new artefact.

### 4. Risks / what NOT to do

- Do not require the blueprint for project types `B` and `C`; repo scan remains their source of truth.
- Do not expand the blueprint into a prescriptive implementation plan. It describes structural conventions, not feature work.
- Do not let the blueprint duplicate `common_contract_definition.md`; contract shapes stay in the contract artefact.
- Do not allow §4 baseline tokens to include feature-specific surfaces; those belong in `feature_contract_delta.md`.
- Do not let the blueprint drift silently. Any stack change (for example, adding Kafka mid-project) must update the blueprint before the next step 7 run.
- Do not silently choose a default stack because MCP guidance is missing; defaults are proposals that require user approval.
- Do not make MCP availability mandatory. A type `A` project must still be able to proceed through explicit user-approved fallback choices.

## Gap 6 - Step 7 cannot consume a stack blueprint as substitute evidence for project type `A`

### 1. Gap

Even when the blueprint from Gap 5 exists, step 7 still refuses to run for type `A`, and its rule forbids generating "pseudo-content". Two concrete obstructions remain:

- `overmind/scripts/feature_repo_surface_and_exec_context.sh` hard-fails on `project_type_code=A` before it looks at any input.
- `overmind/rules/feature_repo_surface_and_exec_context_rule.md` treats repository evidence as the only acceptable source, so the model has no authorised way to cite blueprint sections in Section 4 `evidence:` fields or to populate `main_repo_paths` from a planned path.

Without these changes, the blueprint is inert: it exists but cannot flow into the surface-map artefact downstream planning consumes.

### 2. How to fix

Teach step 7 to accept the stack blueprint as substitute structural evidence when `project_type_code=A`:

- the script binds the per-class blueprint path into the model prompt instead of a repo scan path,
- the rule authorises blueprint section ids as legitimate `evidence:` citations for type `A` only,
- the quality helper continues to validate structural completeness only. It already accepts `project_type_code=A` in meta and checks only non-emptiness for evidence and paths, so no gate loosening is needed — only rule clarification.

For types `B` and `C`, nothing changes.

### 3. Concrete implementation steps

1. Update `overmind/scripts/feature_repo_surface_and_exec_context.sh`:
   - remove the `fail_mcp_not_supported_for_project_a` branch,
   - when `project_type_code=A`, require `project_stack_blueprint_<class>.md` to exist at the project root for every active class, and treat its absence as a hard error,
   - pass the blueprint path into `build_prompt` as an explicit context line (for example, `Stack blueprint source:`), replacing `Selected repository to scan:` when type is `A`,
   - keep all read-only snapshot and commit logic unchanged so existing type `B` and `C` behaviour is untouched.
2. Update `overmind/rules/feature_repo_surface_and_exec_context_rule.md`:
   - replace the "project type `A` is unsupported" paragraph with explicit type-`A` guidance,
   - specify that `main_repo_paths` and `analyzed_repo_paths` carry the blueprint's `planned_repo_path` marked `(planned)`,
   - specify that `key_components`, `transport_layer`, and `user_reachable_surface` in Section 3 are drawn verbatim from blueprint §3 layer bindings and §4 baseline tokens,
   - specify that Section 4 `repo_paths` are drawn from blueprint §3 `folder_paths` for layers the feature touches,
   - specify that Section 4 `evidence` must cite at least one concrete blueprint section id (for example, `project_stack_blueprint_backend.md §3.1`) plus the applicable `feature_contract_delta.md` item id; prose-only evidence remains invalid,
   - specify that Section 4 `user_reachable_surface` is the union of `feature_contract_delta.md` tokens (new) and blueprint §4 tokens (reused).
3. Update `overmind/templates/init_progress_definition_TEMPLATE.yaml` step 7 `finished_only_if_conditions_meet` so the type-`A` guidance matches the new source of truth:
   - replace the condition "For project type A, best-practice repository execution context is requested from MCP and handled separately per active repo class..." with wording that names the per-class stack blueprint as the source,
   - replace the condition "Sources used to prepare these documents follow project type rules: C from code analysis, B from code analysis or knowledge base, A from knowledge base only." with wording that states type `A` sources the per-class stack blueprint plus the standard feature inputs,
   - keep type `B` and `C` wording unchanged.
4. Update `overmind/golden_examples/project_surface_struct_resp_map_be_GOLDEN_EXAMPLE.md` and `overmind/golden_examples/project_surface_struct_resp_map_fe_GOLDEN_EXAMPLE.md` with a second, clearly-labelled type `A` example showing blueprint citations in `evidence:` and `(planned)`-tagged paths, so the style contract covers both modes.
5. Do not modify `overmind/scripts/helper/check_feature_repo_surface_and_exec_context_be_quality.sh` or `..._fe_quality.sh`. They already accept `project_type_code=A` in meta and check only non-emptiness for evidence and paths.
6. Add tests covering:
   - type `A` step 7 with a valid blueprint produces a surface map that passes the existing quality gate,
   - type `A` step 7 with a missing blueprint fails fast in the command, before any model invocation,
   - every Section 4 `evidence:` line in a type `A` surface map cites at least one blueprint section id,
   - type `B` and `C` runs remain unchanged by the new code paths.

### 4. Risks / what NOT to do

- Do not allow type `A` runs to invent component names, folder paths, or user-reachable tokens that are not present in the blueprint or in `feature_contract_delta.md`.
- Do not let blueprint citations become a loophole that lets types `B` and `C` skip the repo scan.
- Do not expand blueprint consumption into downstream steps (8, 8.1, 8.2, 8.3). They keep consuming the surface map exactly as they do today; the blueprint is only an input to step 7.
- Do not confuse `(planned)`-tagged paths with real paths in prerequisite-gap tracing; that phase must keep requiring `user_reachable_surface` tokens, not filesystem paths.
- Do not require the blueprint to enumerate every possible future component. It only needs archetypes rich enough to instantiate the standard layers.

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

### Step 5 - Implement Gap 5 (independent workstream)

Why separate:

- type `A` enablement is orthogonal to gaps 1–4 and can proceed in parallel,
- no behaviour change for existing type `B` and `C` runs.

Expected result:

- new projects can publish a declarative stack blueprint per active class at init.

### Step 6 - Implement Gap 6 (after Gap 5)

Why after Gap 5:

- step 7 consumption is the minimum additional wiring needed for the blueprint to flow into the planning pipeline, and it requires the blueprint artefact to already exist.

Expected result:

- type `A` features can generate a surface map from the blueprint, unblocking steps 8 through 8.3.

## Acceptance criteria for the rebuild direction

The rebuild direction is correct only if all of the following are true:

- if `requirements_ears.md` requires a login, entry route, workspace shell, or operator-facing screen, that surface still appears in slices and plan until covered,
- semantic review raises an operator question when a newly delivered user-reachable surface has no inbound path,
- technical requirements can express cross-repo coordination intent in typed form,
- the planner may emit contract-coordination work when evidence justifies it,
- the planner is not forced to emit contract-coordination work merely because the feature is multi-repo,
- quality helpers do not fail merely because no coordination artifact was emitted,
- optional coordination work never displaces required operator-facing delivery,
- project type `A` startup can record optional per-class stack guidance sources, but absence of MCP guidance does not block blueprint creation,
- type `A` stack blueprints are created only after user-approved stack choices are recorded,
- project type `A` can complete init only when a stack blueprint exists for each active class,
- step 7 runs successfully for type `A` using the blueprint as substitute evidence,
- every Section 4 `evidence:` line in a type `A` surface map cites at least one blueprint section id,
- type `B` and `C` runs remain untouched by the type `A` changes.

## Out of scope for this brief

- resetting the main repository branch,
- patching the discarded five commits in place,
- authoring proposal/spec/design artifacts before these process gaps are accepted,
- unrelated refactors outside this rebuild scope.

## Appendix A — Backend stack blueprint schema (Gap 5 reference)

Reference filled example for the backend blueprint shape. Templates should preserve this structure with placeholders/comments, not copy these concrete values. Section numbering matches §1–§4 defined in Gap 5 step 3. `group_id` in §1 is the package/module root used to expand `{group}` placeholders in §3 `folder_paths`.

```markdown
## 1. Meta
- class: backend
- repo_name: <planned>
- service_name: <planned>
- planned_repo_path: <fs path, tagged (planned)>
- group_id: com.acme.foo
- last_updated: YYYY-MM-DD

## 2. Stack Choices
- language: Java 21
- framework: Spring Boot 3.2 (Web, Security, Data JPA, Actuator)
- build: Gradle
- rdbms: Postgres 16
- migrations: Liquibase
- async_messaging: Kafka 3           # or: none
- http_clients: Spring RestClient    # or: Feign, WebClient
- auth: JWT (HS256 or RS256) + Spring Security filter chain
- logging: Logback JSON to stdout
- metrics: Micrometer to Prometheus at /actuator/prometheus
- tracing: OpenTelemetry SDK to OTLP
- health: /actuator/health
- deployment: Docker to k8s          # or: Fly.io, ECS
- test_stack: JUnit 5, Testcontainers (Postgres, Kafka), REST Assured

## 3. Layer Bindings

### 3.1 API
- folder_paths: src/main/java/{group}/api, src/main/java/{group}/api/dto
- archetypes: Controller, RequestDto, ResponseDto, ControllerAdvice
- user_reachable_pattern: "METHOD /api/v{n}/<resource>"

### 3.2 Service
- folder_paths: src/main/java/{group}/service
- archetypes: ApplicationService, UseCase, Orchestrator
- user_reachable_pattern: none

### 3.3 Domain
- folder_paths: src/main/java/{group}/domain
- archetypes: Entity, ValueObject, Enum, DomainPolicy, DomainEvent
- user_reachable_pattern: none

### 3.4 Persistence
- folder_paths: src/main/java/{group}/repository, src/main/resources/db/changelog
- archetypes: JpaRepository, JPA @Entity mapping, Liquibase changeset
- user_reachable_pattern: none

### 3.5 Integration
- folder_paths: src/main/java/{group}/integration
- archetypes: KafkaListener, KafkaProducer, <vendor>Client
- topics_convention: "<bounded-context>.<event-name>.v<n>"
- user_reachable_pattern: none

### 3.6 Runtime / Ops
- folder_paths: src/main/java/{group}/security, src/main/java/{group}/config, src/main/resources
- archetypes: SecurityConfig, JwtAuthenticationFilter, application.yaml, RequestLoggingFilter, MetricsConfig, Dockerfile
- user_reachable_pattern: none

### 3.7 Test
- folder_paths: src/test/java/{group}
- archetypes: UnitTest, IntegrationTest (Testcontainers), ContractTest, SecurityFilterTest
- user_reachable_pattern: none

## 4. Baseline User-Reachable Inventory
- POST /api/v1/auth/login
- GET /actuator/health
- GET /actuator/prometheus
- scheduled: reconcile-daily          # list every operator-invocable token; or: none
```

## Appendix B — Frontend stack blueprint schema (Gap 5 reference)

Reference filled example for the frontend blueprint shape. Templates should preserve this structure with placeholders/comments, not copy these concrete values. Same four-section contract as Appendix A; layer numbering tracks the frontend surface-map template (§3.1–§3.7).

```markdown
## 1. Meta
- class: frontend
- repo_name: <planned>
- service_name: <planned>
- planned_repo_path: <fs path, tagged (planned)>
- group_id_or_package_root: src
- last_updated: YYYY-MM-DD

## 2. Stack Choices
- framework: React 18 + Vite          # or: Next.js, Vue 3, SvelteKit
- router: react-router v6
- state: React Query + Zustand        # or: Redux Toolkit, Pinia
- http: fetch wrapper in src/api/client.ts
- styling: CSS modules + design tokens
- auth_client: admin JWT in sessionStorage
- env_validation: zod-based env parser at src/config/env.ts
- deployment: static bundle behind CDN
- test: Vitest + React Testing Library + Playwright

## 3. Layer Bindings

### 3.1 UI Composition
- folder_paths: src/routes, src/pages, src/layouts, src/app
- archetypes: RouterDefinition, RootLayout, PageComponent
- user_reachable_pattern: "/<route>"

### 3.2 Component
- folder_paths: src/components, src/styles
- archetypes: SharedComponent, DesignTokenModule, FeatureComponent
- user_reachable_pattern: none

### 3.3 State / Data
- folder_paths: src/hooks, src/state
- archetypes: ReactQueryHook, Zustand store, selector
- user_reachable_pattern: none

### 3.4 API Integration
- folder_paths: src/api
- archetypes: ApiClient, TypedClientFn, RequestMapper, ResponseMapper, ApiError
- user_reachable_pattern: none

### 3.5 UX Behavior
- folder_paths: src/pages, src/components
- archetypes: LoadingState, EmptyState, ErrorBoundary, RouteErrorPage, DisplayMessageMapper
- user_reachable_pattern: none

### 3.6 Platform / Runtime
- folder_paths: src/main.tsx, src/config, vite.config.ts
- archetypes: Bootstrap, EnvParser, BuildConfig
- user_reachable_pattern: none

### 3.7 Test
- folder_paths: src, test
- archetypes: UnitTest (Vitest), ComponentTest (RTL), ContractTest, E2ETest (Playwright)
- user_reachable_pattern: none

## 4. Baseline User-Reachable Inventory
- /login
- /status
- /                                    # or: none if not yet planned
```

## Appendix C — Mobile stack blueprint schema (Gap 5 reference)

Reference filled example for the mobile blueprint shape. Templates should preserve this structure with placeholders/comments, not copy these concrete values. Same four-section contract as Appendix A; layer numbering tracks the mobile-capable frontend/mobile surface-map taxonomy, including mobile-specific native/device and local/offline/sync layers.

```markdown
## 1. Meta
- class: mobile
- repo_name: <planned>
- service_name: <planned>
- planned_repo_path: <fs path, tagged (planned)>
- group_id_or_package_root: app
- last_updated: YYYY-MM-DD

## 2. Stack Choices
- platforms: Android Kotlin + iOS Swift
- android_ui: Jetpack Compose
- ios_ui: SwiftUI
- navigation: Jetpack Navigation + SwiftUI NavigationStack
- state: ViewModel + Kotlin Flow, Swift Observation
- http: Ktor client + URLSession wrapper
- auth_client: secure token storage via Android Keystore and iOS Keychain
- local_storage: Room + SwiftData
- device_integration: permissions, deep links, push notifications
- distribution: Play Console + App Store Connect
- test_stack: JUnit, XCTest, Compose UI tests, XCUITest

## 3. Layer Bindings

### 3.1 UI Composition
- folder_paths: app/src/main/java/<package>/ui, ios/App/UI
- archetypes: ComposeScreen, SwiftUIView, NavigationGraph
- user_reachable_pattern: "screen:<name>"

### 3.2 Component
- folder_paths: app/src/main/java/<package>/ui/components, ios/App/Components
- archetypes: SharedComposable, SwiftUIViewComponent, DesignTokenModule
- user_reachable_pattern: none

### 3.3 State / Data
- folder_paths: app/src/main/java/<package>/state, ios/App/State
- archetypes: ViewModel, StateFlow, ObservableModel
- user_reachable_pattern: none

### 3.4 API Integration
- folder_paths: app/src/main/java/<package>/api, ios/App/API
- archetypes: ApiClient, RequestMapper, ResponseMapper, ApiError
- user_reachable_pattern: none

### 3.5 UX Behavior
- folder_paths: app/src/main/java/<package>/ui, ios/App/UI
- archetypes: LoadingState, EmptyState, ErrorPresenter, PermissionPrompt
- user_reachable_pattern: none

### 3.6 Platform / Runtime
- folder_paths: app/src/main/java/<package>/config, ios/App/Config
- archetypes: EnvConfig, AppBootstrap, FeatureFlagProvider
- user_reachable_pattern: none

### 3.7 Native / Device Integration
- folder_paths: app/src/main/java/<package>/device, ios/App/Device
- archetypes: PermissionHandler, PushRegistration, DeepLinkHandler, BiometricAdapter
- user_reachable_pattern: "deeplink:<scheme>/<path>"

### 3.8 Local Storage / Offline / Sync
- folder_paths: app/src/main/java/<package>/storage, ios/App/Storage
- archetypes: LocalDatabase, SyncQueue, OfflineCache
- user_reachable_pattern: none

### 3.9 Test
- folder_paths: app/src/test, app/src/androidTest, ios/AppTests, ios/AppUITests
- archetypes: UnitTest, UITest, ContractTest
- user_reachable_pattern: none

## 4. Baseline User-Reachable Inventory
- screen:login
- screen:status
- deeplink:app/login
```

## Appendix D — Field-by-field mapping of blueprint into surface map (Gap 6 reference)

This table is the wiring contract the rule update in Gap 6 step 2 must encode. For type `A` runs, every surface-map field on the left has a named source on the right; nothing is invented.

| Surface-map field | Fed from |
|---|---|
| `meta.repo_name`, `service_name` | blueprint §1 |
| `meta.analyzed_repo_paths` | blueprint §1 `planned_repo_path`, tagged `(planned)` |
| `meta.project_type_code` | `init_progress_definition.yaml` (`A`) |
| `meta.project_classes` | prompt-bound target class |
| `meta.feature_id`, `feature_title` | feature folder name + `requirements_ears.md` header |
| `meta.source_inputs_used` | init yaml + `requirements_ears.md` + `feature_contract_delta.md` + blueprint path |
| `meta.last_updated` | run date (`YYYY-MM-DD`) |
| `feature_scope.feature_summary` | `requirements_ears.md` overview |
| `feature_scope.in_scope_feature_delta` | `feature_contract_delta.md` §2 + §3 |
| `feature_scope.out_of_scope_notes` | `requirements_ears.md` out-of-scope + `feature_contract_delta.md` §2 |
| `§3.x responsibility_summary` | generic per-layer wording from surface-map template (no blueprint input needed) |
| `§3.x main_repo_paths` | blueprint §3.x `folder_paths` (with `{group}` expanded from §1) |
| `§3.x key_components` | blueprint §3.x `archetypes` |
| `§3.x transport_layer` | same archetypes rendered as transport tokens |
| `§3.x user_reachable_surface` | blueprint §3.x `user_reachable_pattern` concretised against blueprint §4 tokens; `none` otherwise |
| `§4.y surface_summary` | generic per-surface wording from surface-map template |
| `§4.y applicability` | `feature_contract_delta.md` impact analysis (`applicable` or `not_applicable`) |
| `§4.y repo_paths` | blueprint §3.x `folder_paths` for layers the feature touches |
| `§4.y why_feature_touches_it` | `feature_contract_delta.md` item `change_scope` + `requirements_ears.md` acceptance criteria |
| `§4.y expected_changes` | `feature_contract_delta.md` item `change_scope` + `compatibility_impact` |
| `§4.y evidence` | citation string, e.g. `project_stack_blueprint_backend.md §3.1 + feature_contract_delta.md Delta 1` |
| `§4.y transport_layer` | blueprint §3.x `archetypes` for the touched layer |
| `§4.y user_reachable_surface` | union of `feature_contract_delta.md` new tokens and blueprint §4 reused tokens; `none` if the surface is internal |
