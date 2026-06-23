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

1. Keep `delivered_surface_consumption_unclear` and the four-step delivered-surface heuristic in `packages/installer/_data/skills/overmind-plan-semantic-review/SKILL.md`.
2. Require the semantic review prompt to receive these read-only inputs when applicable:
   - `prerequisite_gaps.md`
   - backend/frontend/mobile surface-map artifacts for active repo classes
3. Keep the semantic-review template and golden example under the skill's `assets/` directory, including both valid outcomes:
   - `applied` when an inbound affordance must be added,
   - `rejected` when the surface is intentionally isolated.
4. Bind required inputs through `node .overmind/overmind.js context plan-semantic-review <feature-path>`.
5. Add tests proving:
   - a new route with no inbound edge produces the finding,
   - a route with a sibling inbound-affordance step does not,
   - terminal state is rejected when `resolution_notes` is empty for this finding type.

### 4. Risks / what NOT to do

- Do not move this into the `implementation-plan` gate as a hard-fail rule.
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

1. Update `packages/installer/_data/skills/overmind-technical-requirements/SKILL.md ## Planning Signal Contract` so section 6 supports zero-or-more typed `planning_signal` blocks.
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
4. Update `packages/installer/_data/skills/overmind-technical-requirements/assets/technical_requirements_TEMPLATE.md` and `packages/installer/_data/skills/overmind-technical-requirements/assets/technical_requirements_GOLDEN_EXAMPLE.md` to show:
   - one valid populated signal block,
   - one valid empty-path case when no signal is needed.
5. Update `packages/asdlc-coordinator/src/validate/technical-requirements.ts` to validate only structural correctness:
   - unique ids,
   - required fields present,
   - evidence tokens resolve,
   - repo names are valid for the active project classes.
6. Keep section 6 explicitly optional. When no signal is needed, require only a simple empty marker line.
7. Add coverage in `packages/asdlc-coordinator/test/technical-requirements-validator.test.ts` for:
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
2. Update `packages/installer/_data/skills/overmind-implementation-slices/SKILL.md` so each required missing operator-facing surface is preserved by at least one feature-delivery slice.
3. Update the inlined `overmind-implementation-plan` skill rule so the same required missing surface is preserved by at least one implementation-plan step until delivered.
4. Update `packages/asdlc-coordinator/src/validate/implementation-slices.ts` to verify that unresolved required operator-facing surfaces from upstream artifacts remain represented in slice output.
5. Update the TypeScript `implementation-plan` gate to verify the same preservation at plan level.
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

1. Update `packages/installer/_data/skills/overmind-implementation-slices/SKILL.md` so slice generation may emit an optional coordination slice kind for justified contract-lock work.
2. Keep coordination slices separate from ordinary feature-delivery slices in the artifact structure so they remain visible but do not replace feature delivery.
3. Define clear emission criteria in the rule:
   - real ambiguity,
   - real shared-artifact need,
   - real multi-repo drift risk,
   - direct supporting evidence from section 6 and upstream artifacts.
4. Update `overmind/templates/implementation_slices_TEMPLATE.md` and the golden example to show both valid paths:
   - with a coordination slice,
   - without one.
5. Update the inlined `overmind-implementation-plan` skill rule so the plan may lift a justified coordination slice into a plan step only when downstream work is actually blocked by that artifact.
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

## Gap 6 - Step 7 cannot consume a stack blueprint as fallback evidence for unmaterialized layers in project type `A`

### 1. Gap

- `overmind/scripts/feature_repo_surface_and_exec_context.sh` hard-fails on `project_type_code=A` before reading any input.
- `overmind/rules/feature_repo_surface_and_exec_context_rule.md` rejects all non-repo evidence; blueprint citations and placeholder rows for surfaces unknown to both sources have no legal home.
- Effect: type `A` is blocked entirely; type `A` F2+ cannot mix repo and blueprint; touched surfaces unknown to both sources cannot be carried forward.

### 2. How to fix

Per-row resolution at step 7: real repo evidence → blueprint `(planned)` path → literal `<to be defined during implementation>` placeholder. Repo scan runs whenever the planned path is scannable. Blueprint binds as fallback when `project_type_code=A`. Quality helper unchanged.

### 3. Concrete implementation steps

1. `overmind/scripts/feature_repo_surface_and_exec_context.sh`:
   - remove the `fail_mcp_not_supported_for_project_a` branch,
   - run repo scan whenever `class_repo_paths[<class>].path` is scannable, regardless of `project_type_code`,
   - for `project_type_code=A`: require `project_stack_blueprint_<class>.md` at project root (hard error if missing); bind it as `Stack blueprint source:` in `build_prompt`,
   - both context lines may co-exist; precedence is per-row,
   - read-only snapshot and commit logic unchanged.

2. `overmind/rules/feature_repo_surface_and_exec_context_rule.md`:
   - replace the "project type `A` is unsupported" paragraph with the per-row resolution chain from §2,
   - `meta.analyzed_repo_paths`: real paths when scannable; otherwise blueprint §1 `planned_repo_path` tagged `(planned)`,
   - §3: enumerate only layers materialized in repo or anticipated by blueprint §3; omit layers absent from both; never invent a §3 entry for a touched surface,
   - §4 `repo_paths`: real path → blueprint §3.x `folder_paths` (`(planned)` tagged) → placeholder,
   - §4 `evidence`: real repo path → blueprint section id (e.g., `project_stack_blueprint_backend.md §3.1`) → delta item id alone; always plus `feature_contract_delta.md <item id>`. Prose-only invalid,
   - §4 `transport_layer`: repo-observed archetype → blueprint §3.x archetype → placeholder,
   - §4 `user_reachable_surface`: union of `feature_contract_delta.md` tokens, repo-scanned reused tokens, and blueprint §4 reused tokens (whichever apply).

3. `overmind/templates/init_progress_definition_TEMPLATE.yaml` step 7 `finished_only_if_conditions_meet`:
   - replace "For project type A, best-practice repository execution context is requested from MCP..." with: type `A` binds the per-class stack blueprint as fallback evidence; repo scan remains primary when code is materialized,
   - replace "Sources used to prepare these documents follow project type rules..." with: type `A` resolves evidence per row (repo when scannable, blueprint for unmaterialized layers, placeholder when neither describes the surface) plus the standard feature inputs,
   - type `B`/`C` wording unchanged.

4. `overmind/golden_examples/project_surface_struct_resp_map_be_GOLDEN_EXAMPLE.md` and `..._fe_GOLDEN_EXAMPLE.md` — add three type-`A` examples:
   - F1: every row from blueprint, paths `(planned)`, evidence cites blueprint section ids,
   - F2+ partial-repo: mix of real-path and `(planned)`-path rows with matching evidence,
   - placeholder: at least one §4 row with `<to be defined during implementation>` in `repo_paths` and `transport_layer`, delta-only evidence.

5. Quality helpers unchanged: `overmind/scripts/helper/check_feature_repo_surface_and_exec_context_be_quality.sh` and `..._fe_quality.sh` already enforce only structural non-emptiness; the literal placeholder satisfies it.

6. Tests:
   - F1 (no scannable repo): blueprint-only surface map passes quality gate,
   - F2+ partial repo: mixed-evidence surface map passes; each row's evidence matches its source,
   - missing `project_stack_blueprint_<class>.md` with `project_type_code=A`: script fails before model invocation,
   - touched surface unknown to both sources: §4 row with placeholder fields + delta-only evidence, no synthesized §3 entry, passes quality gate,
   - type `B` and `C` runs unchanged.

### 4. Risks / what NOT to do

- Do not bypass repo scan once the planned path is scannable; repo wins for materialized layers.
- Do not mix repo and blueprint evidence within a single row; one source per row.
- Do not invent §3 entries; §3 stays bound to evidence-backed layers, §4 carries unknown surfaces with placeholders.
- Do not let blueprint citations become a loophole for types `B`/`C` to skip repo scan.
- Do not expand blueprint consumption into steps 8 / 8.1 / 8.2 / 8.3 — input only to step 7.
- Do not confuse `(planned)` paths or placeholders with real paths in step 8.2 prerequisite tracing; that phase keeps tracing tokens, not filesystem paths.

## Gap 7 - Surface rows with `<to be defined during implementation>` could be enriched from MCP knowledgebase when one is available

**Placeholder — details to be defined during implementation.**

When step 7 produces a surface-map row that falls through to the literal `<to be defined during implementation>` placeholder (no repo evidence, no blueprint coverage), the pipeline currently leaves that row technically incomplete. If an MCP knowledgebase is configured and reachable for the active project, it may already hold enough context about the intended surface (stack archetype, folder conventions, transport shape) to resolve the placeholder at generation time rather than deferring it to the worker design phase. The idea is to attempt an MCP-backed lookup for each placeholder row before writing it as `<to be defined during implementation>`, fill what the knowledgebase can confirm, and fall back to the placeholder only when the MCP query returns nothing useful.

## Gap 8 - Cross-class transport/contract approach is not anchored at project init for type `A`

### 1. Gap

For project type `A` projects with multiple active classes, the pipeline never explicitly captures how those classes communicate (REST + OpenAPI, GraphQL, gRPC, Thrift, tRPC, etc.).

- Step 1.1 (`Define Project Stack Blueprints For Active Classes`) captures per-class stack, folder conventions, and archetypes, but not the cross-class transport/contract approach.
- Step 2 (`Create Cross-Repository Contract Definition For This Project`) for type `A` reads blueprints as read-only context only, so when blueprints carry no contract-shape intent, `common_contract_definition.md` is structurally thin for greenfield type `A`.
- Step 6 (`Define Feature Contract Delta`) deltas against that thin baseline, which weakens the delta.
- Step 7 still demands `transport_layer` per surface row, so the missing decision surfaces late as `<to be defined during implementation>` placeholders instead of as a planned project-level decision.

The cross-class transport/contract approach is a stable project-level decision, not a feature-scoped one — it belongs at init time and should be either stated up front or carried as a visible placeholder until a feature defines it.

### 2. How to fix

Extend step 1.1 to attempt deriving the cross-class transport/contract approach from blueprint stack choices and (when configured) MCP guidance, write it into the backend blueprint when derivable, and write a placeholder when not. Mirror the same values (or placeholder) into `common_contract_definition.md` at step 2. At step 6, `feature_contract_delta.md` may record the chosen values when the feature defines them or simply mirror the current state; no resolution state machine, no required block, no enforcement check.

Ownership rule: the **backend** class blueprint is the sole holder of the cross-class transport/contract approach section. Frontend and mobile blueprints do not carry this section. When a project has multiple active backend classes (e.g., two backend services sharing a Thrift contract), every active backend blueprint carries the section independently. The rule is a no-op for projects with no active backend class.

The placeholder is the literal sentinel `<to be defined during first feature implementation plan>`, distinct from the step 7 sentinel `<to be defined during implementation>` so the two obligations remain separately trackable.

### 3. Concrete implementation steps

1. Extend `overmind/templates/project_stack_blueprint_be_TEMPLATE.md` with a new required section `§5 Cross-Class Transport/Contract Approach` carrying these fields:
   - `transport_protocol` — e.g., `REST`, `gRPC`, `GraphQL`, `Thrift`, `tRPC`, or the literal placeholder,
   - `schema_format` — e.g., `OpenAPI 3.1`, `protobuf`, `GraphQL SDL`, `Thrift IDL`, or the literal placeholder,
   - `user_approved` — boolean.
2. Do not modify `project_stack_blueprint_fe_TEMPLATE.md` or `project_stack_blueprint_mobile_TEMPLATE.md`. Presence of §5 in either is invalid.
3. Update `overmind/rules/project_stack_blueprint_rule.md` and `overmind/scripts/init_project_stack_blueprints.sh` so that, for every active backend blueprint:
   - first attempt MCP-backed derivation when `stack_guidance_sources[backend]` is configured and reachable,
   - otherwise attempt inference from the approved §2 stack choices,
   - when either source yields a confident proposal, present it for user approval and write `transport_protocol` + `schema_format` with `user_approved: true`,
   - when neither source yields a confident proposal, write the literal placeholder for both fields with `user_approved: false`; placeholder writes do not require approval,
   - never auto-fill concrete §5 values without explicit user approval.
4. Extend `overmind/scripts/helper/check_project_stack_blueprint_quality.sh` to validate §5 structurally:
   - section present in every backend blueprint, absent from frontend and mobile blueprints,
   - all §5 fields present and non-empty,
   - `transport_protocol` and `schema_format` are either both concrete values or both the literal placeholder; mixed states are invalid,
   - `user_approved: true` is invalid when either field is the literal placeholder.
5. Add a step 1.1 condition to `overmind/templates/init_progress_definition_TEMPLATE.yaml`: for project type `A`, every active backend blueprint has a §5 section that is either fully populated and `user_approved: true`, or fully placeholdered.
6. Add step 2 conditions in the same template, type `A` only:
   - `common_contract_definition.md` reflects each active backend blueprint's §5 verbatim (concrete values or placeholder),
   - placeholder carry-through does not block step 2,
   - `common_contract_definition.md` records which backend owns which contract approach when multiple backends are active.
7. Add step 6 conditions in the same template, type `A` only: `feature_contract_delta.md` mirrors the current `transport_protocol` and `schema_format` per backend from `common_contract_definition.md` (concrete values or placeholder). When the feature defines or refines those values, `feature_contract_delta.md` records the concrete values directly; the placeholder otherwise carries forward.
8. Extend `overmind/templates/feature_contract_delta_TEMPLATE.md` with two simple per-backend fields, `transport_protocol` and `schema_format`, each accepting a concrete value or the literal placeholder.
9. Include a §5 example in `overmind/templates/project_stack_blueprint_be_TEMPLATE.md` showing both the populated and placeholdered shapes as inline reference comments.
10. Add tests covering:
   - type `A` BE+FE, MCP confident proposal: backend §5 populated with `user_approved: true`, frontend has no §5, step 1.1 quality passes,
   - type `A` BE+FE, no MCP, stack inference confident: same outcome via stack inference,
   - type `A` BE+FE, no MCP, no confident inference: backend §5 placeholdered with `user_approved: false`, step 1.1 + step 2 pass, `feature_contract_delta.md` mirrors the placeholder,
   - type `A` feature defines values: `feature_contract_delta.md` records concrete `transport_protocol` and `schema_format` directly; subsequent features may continue to mirror the placeholder from `common_contract_definition.md` or record their own concrete values,
   - type `A` multi-backend: every active backend blueprint independently carries §5,
   - type `A` no active backend: no §5 anywhere,
   - type `B` and type `C`: unchanged, no §5 expected.

### 4. Risks / what NOT to do

- Do not add §5 to frontend or mobile blueprints. Backend is the sole holder; consumers do not duplicate.
- Do not block step 1.1, step 2, or step 6 when the placeholder is in use; the placeholder is a visible carry-forward, not a hard gate.
- Do not introduce a `cross_class_contract_resolution` block, terminal-state machine, or step 6 enforcement check. The fields in `feature_contract_delta.md` either carry concrete values or carry the placeholder; nothing else.
- Do not auto-fill concrete §5 values from MCP or stack inference without explicit user approval. Placeholder writes do not require approval.
- Do not reuse the step 7 `<to be defined during implementation>` sentinel for §5. The two obligations must remain separately trackable.
- Do not let §5 grow into per-endpoint contract content. It carries protocol and schema format only; per-endpoint contract shape stays in `common_contract_definition.md` and `feature_contract_delta.md`.
- Do not treat absence of MCP guidance as a reason to omit §5 entirely. The placeholder path is the fallback, not omission.

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

### Step 7 - Implement Gap 8 (after Gap 5)

Why after Gap 5:

- the cross-class transport/contract approach lives as §5 of the backend blueprint, so the blueprint artefact and its quality helper must exist first,
- independent of Gap 6; can land before, after, or in parallel with Gap 6.

Expected result:

- type `A` projects anchor the cross-class transport/contract approach at init when derivable, and otherwise carry a tracked placeholder that step 6 enforces on each feature until resolved.

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
- step 7 runs successfully for type `A` F1 (no scannable repo) using the blueprint as fallback evidence for every row,
- step 7 runs successfully for type `A` F2+ with a partially-materialized repo, drawing materialized rows from repo and unmaterialized ones from blueprint,
- a touched surface whose shape matches no `user_reachable_pattern` in either source still produces a valid §4 row with placeholder `repo_paths` and `transport_layer` and delta-only evidence,
- §3 only enumerates layers described by repo scan or blueprint; layers absent from both are not invented,
- type `B` and `C` runs remain untouched by the type `A` changes,
- for type `A`, every active backend blueprint carries a §5 cross-class transport/contract approach section that is either fully populated and user-approved or fully placeholdered, and frontend/mobile blueprints never carry §5,
- for type `A`, `common_contract_definition.md` and `feature_contract_delta.md` mirror the current §5 values per backend (concrete values or the literal placeholder); no resolution state machine, no required block, no enforcement check exists at step 6.

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

## Appendix D — Field-by-field mapping into surface map (Gap 6 reference)

This table is the wiring contract the rule update in Gap 6 step 2 must encode. Each surface-map field has a resolution chain: take the strongest source available and fall through to the next when absent. For type `A` the chain extends into the blueprint; for types `B` and `C` it stops at the repo. When no source describes a touched surface, the row carries the literal placeholder `<to be defined during implementation>` and delta-only evidence — the surface stays in scope, technical depth is deferred to the worker design phase.

| Surface-map field | Resolution chain |
|---|---|
| `meta.repo_name`, `service_name` | repo scan when scannable → blueprint §1 |
| `meta.analyzed_repo_paths` | real scanned paths when scannable → blueprint §1 `planned_repo_path` tagged `(planned)` |
| `meta.project_type_code` | `init_progress_definition.yaml` |
| `meta.project_classes` | prompt-bound target class |
| `meta.feature_id`, `feature_title` | feature folder name + `requirements_ears.md` header |
| `meta.source_inputs_used` | init yaml + `requirements_ears.md` + `feature_contract_delta.md` + repo path (when scanned) + blueprint path (type `A`) |
| `meta.last_updated` | run date (`YYYY-MM-DD`) |
| `feature_scope.feature_summary` | `requirements_ears.md` overview |
| `feature_scope.in_scope_feature_delta` | `feature_contract_delta.md` §2 + §3 |
| `feature_scope.out_of_scope_notes` | `requirements_ears.md` out-of-scope + `feature_contract_delta.md` §2 |
| `§3.x responsibility_summary` | generic per-layer wording from surface-map template |
| `§3.x main_repo_paths` | repo scan → blueprint §3.x `folder_paths` (with `{group}` expanded from §1) — layer omitted from §3 when neither source describes it |
| `§3.x key_components` | repo scan → blueprint §3.x `archetypes` — omitted when absent from both |
| `§3.x transport_layer` | repo scan → blueprint §3.x archetypes rendered as transport tokens — omitted when absent from both |
| `§3.x user_reachable_surface` | repo scan → blueprint §3.x `user_reachable_pattern` concretised against blueprint §4 tokens; `none` when neither describes it |
| `§4.y surface_summary` | generic per-surface wording from surface-map template |
| `§4.y applicability` | `feature_contract_delta.md` impact analysis |
| `§4.y repo_paths` | real scanned paths → blueprint §3.x `folder_paths` (with `(planned)` tag) → literal `<to be defined during implementation>` |
| `§4.y why_feature_touches_it` | `feature_contract_delta.md` item `change_scope` + `requirements_ears.md` acceptance criteria |
| `§4.y expected_changes` | `feature_contract_delta.md` item `change_scope` + `compatibility_impact` |
| `§4.y evidence` | strongest available source + `feature_contract_delta.md <item id>`: real repo path → blueprint section id (e.g., `project_stack_blueprint_backend.md §3.1`) → delta-only when neither source describes the surface |
| `§4.y transport_layer` | repo-observed archetype → blueprint §3.x archetype → literal `<to be defined during implementation>` |
| `§4.y user_reachable_surface` | union of `feature_contract_delta.md` new tokens + repo-scanned reused tokens + blueprint §4 reused tokens (whichever apply); `none` if internal |
