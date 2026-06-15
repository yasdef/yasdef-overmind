# Repo Surface And Execution Context Rule

Read this file fully before generating output.

## Purpose
- Convert feature requirements plus feature contract delta into a repository surface map for the target track.
- Describe two things only:
  - key parts of the target repository and their general responsibilities
  - repository surfaces touched by the current feature for the target track
- Produce deterministic output for `<TARGET_PROJECT_SURFACE_MAP_ARTIFACT>`.

## Track Binding
- This rule is shared across multiple tracks.
- Treat the prompt-provided track bindings as authoritative for:
  - target track name
  - applicable project classes
  - repository paths to scan
  - target template and golden example
  - `project_classes` value to write in artifact meta
  - quality gate command and completion wording
- Do not infer another track when the prompt already binds one.

## Ownership Boundaries
Owns:
- repository-level structure summary for the bound track
- feature-scoped surface mapping for the bound track

Must not own:
- another track execution context
- business requirements decomposition
- contract governance redesign
- broad risk analysis outside repository structure and touched surfaces

## Authoritative Inputs And Outputs
- Read project type and class applicability from prompt context.
- Read these input artifacts:
  - `<PROJECT_INIT_PROGRESS_DEFINITION_ARTIFACT>`
  - `<REQUIREMENTS_EARS_ARTIFACT>`
  - `<FEATURE_CONTRACT_DELTA_ARTIFACT>`
- Use only repository paths listed in prompt context as scan scope.
- Update only `<TARGET_PROJECT_SURFACE_MAP_ARTIFACT>`.

## Evidence Resolution Chain
- Resolve each row in `Key Parts of Repo and Their Responsibilities` and each row in `Backend Surfaces Touched With Current Feature` or `Frontend / Mobile Surfaces Touched With Current Feature` per class and per row using the permanent chain: repo scan → in-flight feature promises → blueprint (`(planned)` tag) → literal `<to be defined during implementation>`.
- The chain runs only for surfaces this feature's requirements touch; "absent" means this feature's need is not satisfied, never an inventory claim about the repo.
- Repo scan evidence is available only when the prompt binds a ready repository path for the target class. Repo scan rows cite the concrete repository path.
- In-flight feature promise evidence is available only when committed sibling plans are bound by the prompt.
- Rows resolved from a sibling plan must carry the tag `(in-flight <feature-folder>)` and evidence must cite `<feature-folder>/implementation_plan.md step <step-id>`.
- Blueprint evidence is available when approved `project_stack_blueprint_<class>.md` exists for the target class. Blueprint-derived values are planned structural evidence only, must be tagged `(planned)`, and must not be presented as repository-proven code evidence.
- Blueprint evidence citations must append the blueprint's `Meta` block `last_updated` value, exactly: `project_stack_blueprint_<class>.md §<n> (last_updated: <YYYY-MM-DD>)`.
- A blueprint is never retired; it remains fallback evidence for unmaterialized layers for the life of the project.
- For policy `C`, when a layer under `project_surface_struct_resp_map_<class>.md ## 3. Key Parts of Repo and Their Responsibilities` is materialized in the repo but diverges from `project_stack_blueprint_<class>.md ## 3. Layer Bindings`, resolve the layer from repo evidence and add at most one passive bullet field in that layer block, exactly: `- divergent_from_blueprint: §<n>`, where `§<n>` is the subsection number under `project_stack_blueprint_<class>.md ## 3. Layer Bindings` that the materialized repo layer diverges from. This field is optional, never required, never prompts, and never blocks.
- One source per row; do not mix repo, promise, blueprint, and placeholder sources in the same row. Every non-repo source must be tagged.
- Keep each row's transport and structural evidence single-tiered through the permanent chain. For `user_reachable_surface`, use an explicit union that always includes applicable concrete tokens from `feature_contract_delta.md` plus concrete tokens from the row's selected repo, in-flight promise, or blueprint tier. Use `none` only when no applicable entry exists. Do not use `<to be defined during implementation>` for this field.
- For every applicable row in `Backend Surfaces Touched With Current Feature` or `Frontend / Mobile Surfaces Touched With Current Feature`, `evidence` must combine the selected chain-tier citation with `feature_contract_delta.md <item id>` for the feature touch. Prose-only evidence is invalid.

## Output Format Baseline
- Use the prompt-provided template as the structure contract.
- Use the prompt-provided golden example as the style contract.
- Preserve heading order and key names from the template.
- Keep `Key Parts of Repo and Their Responsibilities` general to the repository or codebase layer responsibilities.
- Keep `Backend Surfaces Touched With Current Feature` and `Frontend / Mobile Surfaces Touched With Current Feature` focused only on surfaces touched with the current feature.

## Evidence Rules
- Use only repository-proven evidence, declared feature input artifacts, and prompt-bound non-repo evidence from the permanent chain.
- Do not invent layers, module boundaries, or touched surfaces without evidence from repo, prompt-bound sibling plans, or blueprint.
- Keep feature scope narrow to this feature delta.
- Explain each layer or touched surface in concise plain language.
- Do not duplicate details that belong in other artifacts.

## Runtime Path Binding Rules
- Treat runtime path bindings in prompt context as authoritative for this invocation.
- Resolve outputs under runtime feature root.
- Do not hardcode `overmind/product/...` when runtime override is supplied.

## Transport vs User-Reachable Split

Every row in `Key Parts of Repo and Their Responsibilities` and every row in `Backend Surfaces Touched With Current Feature` or `Frontend / Mobile Surfaces Touched With Current Feature` SHALL record two explicit subfields:
- `transport_layer`: internal callable code present in the repository (API clients, services, hooks, repositories, helpers) that other code can invoke. Use `none` when no transport-layer code exists for this block.
- `user_reachable_surface`: operator-invocable entry points that an operator or end user can invoke without writing code. Use `none` when no user-reachable surface exists.

A single conflated line that mixes both forms SHALL NOT be used. The quality helper will reject a block missing either subfield.

### User-Reachable Taxonomy per Project Class
The following defines what counts as user-reachable for each project class:
- **frontend**: a mounted route, page, or top-level screen an operator can navigate to (e.g., `/admin/login`, `/checkout/summary`).
- **mobile**: a registered screen or deep link an operator can land on (e.g., `checkout://risk-screen`).
- **backend**: an operator-reachable HTTP endpoint, CLI command, scheduled job, or admin tool. Internal-only services, repositories, and helpers do NOT qualify.

### Token Requirements for user_reachable_surface
Each `user_reachable_surface` entry SHALL be a concrete navigable token — a route path, full HTTP method+path, CLI command name, or job identifier — rather than prose. This field is the ground-truth contract consumed by downstream prerequisite-gap tooling and must be machine-parseable.

Valid examples: `/admin/login`, `POST /api/v2/orders`, `bin/reconcile`, `reconcile-accounts-daily`.
Invalid: `the admin login page` (prose description, not parseable).

### Forbid Restating Transport Coverage as User-Reachable Presence
Transport-layer presence (callable code exists) does NOT imply user-reachable presence. Do NOT list an internal service, repository, or helper in `user_reachable_surface`. A backend service method or a frontend API client is transport-layer code; it is NOT a user-reachable surface entry.

### none Marker
Use the literal value `none` when a subfield has no applicable value. A blank or omitted subfield is invalid.

## Completion Gate
- Before finalizing, run the prompt-provided quality gate command.
- If the gate fails, revise the output and rerun the gate command.
- If gate compliance is not feasible with current evidence and constraints, stop and use the prompt-provided failure line exactly.
- If the gate passes, end with the prompt-provided success line exactly.
