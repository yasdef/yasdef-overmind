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

## Project Type Branching
- If project type is `B` or `C`: produce the surface map from repository evidence plus feature inputs.
- If project type is `A`: the prompt provides an approved stack blueprint as planned structural evidence and optionally a ready repository path when the class repo is scannable. Apply the following rules per section:
  - **§3 layer blocks**: enumerate only layers materialized in the repo or anticipated in the blueprint §3 section. Omit layers absent from both sources entirely — do not create a §3 entry with placeholder values.
  - **§4 `repo_paths`**: real repo path → blueprint §3.x `folder_paths` tagged `(planned)` → `<to be defined during implementation>`.
  - **§4 `transport_layer`**: repo-observed archetype → blueprint §3.x archetype → `<to be defined during implementation>`.
  - **§4 `evidence`**: real repo path → blueprint section id (e.g. `project_stack_blueprint_backend.md §3.1`) → delta item id alone; always combined with `feature_contract_delta.md <item id>`. Prose-only evidence is invalid.
  - **§4 `user_reachable_surface`**: union of `feature_contract_delta.md` tokens, repo-scanned tokens, and blueprint §4 tokens that apply. Use `none` when no applicable entry exists. Do not use `<to be defined during implementation>` here.
  - One source per field within a §4 block. Do not mix repo and blueprint evidence within the same field.

## Output Format Baseline
- Use the prompt-provided template as the structure contract.
- Use the prompt-provided golden example as the style contract.
- Preserve heading order and key names from the template.
- Keep section `3` general to the repository or codebase layer responsibilities.
- Keep section `4` focused only on surfaces touched with the current feature.

## Evidence Rules
- Use only repository-proven evidence plus declared feature input artifacts.
- For project type `A`: blueprint-derived paths and archetypes are planned structural evidence only. Tag blueprint-derived values as `(planned)`. Do not present them as already existing repository code.
- Blueprint evidence (`project_stack_blueprint_<class>.md`) is consumed by Step `7` only for project type `A`. Do not bind or reference stack blueprints for project types `B` or `C`.
- Do not invent layers, module boundaries, or touched surfaces without evidence from repo or blueprint.
- Keep feature scope narrow to this feature delta.
- Explain each layer or touched surface in concise plain language.
- Do not duplicate details that belong in other artifacts.

## Runtime Path Binding Rules
- Treat runtime path bindings in prompt context as authoritative for this invocation.
- Resolve outputs under runtime feature root.
- Do not hardcode `overmind/product/...` when runtime override is supplied.

## Transport vs User-Reachable Split

Every Section 3 layer block and every Section 4 surface block in the output surface map SHALL record two explicit subfields:
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
