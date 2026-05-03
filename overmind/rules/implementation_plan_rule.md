# Repository Implementation Plan Rule

Read this file fully before generating output.

## Purpose
- Convert implementation-slice planning output, feature requirements, feature-scoped technical requirements, and contract delta into one shared ordered implementation plan.
- Answer one question only:
  `What is the concrete executable implementation sequence for this feature, expressed as one shared plan with one repo owner per step and grounded in the current repo state?`
- Preserve required missing operator-facing surface delivery from upstream evidence so supporting-only work cannot replace required surface outcomes.
- Produce deterministic output for `<TARGET_IMPLEMENTATION_PLAN_ARTIFACT>`.

## Ownership Boundaries
Owns:
- executable implementation sequence across active repo classes
- per-step repo ownership using `#### Repo:`
- prerequisite or alignment steps required before downstream implementation
- explicit cross-step dependency ordering using `#### Depends on:`
- traceability from steps to `REQ-*` / `NFR-*` ids
- concrete step slicing from impacted components and explicit gaps
- inclusion of already-implemented slices when they materially explain current delivery state
- explicit retention of required missing operator-facing surface delivery through final plan ordering

Must not own:
- worker assignment or worker discovery rules
- redefinition of stable cross-project contracts already captured elsewhere
- restating full repository structure beyond what is needed for planning
- architecture redesign unrelated to the current feature inputs

## Authoritative Inputs And Outputs
- Read project/class scope from `<PROJECT_INIT_PROGRESS_DEFINITION_ARTIFACT>`.
- Read behavioral scope from `<REQUIREMENTS_EARS_ARTIFACT>`.
- Read executable slice discovery from `<IMPLEMENTATION_SLICES_ARTIFACT>`.
- Read current implementation state, impacted components, repo ownership, and explicit gaps from `<TECHNICAL_REQUIREMENTS_ARTIFACT>`.
- Read shared-contract prerequisites and cross-track compatibility constraints from `<FEATURE_CONTRACT_DELTA_ARTIFACT>`.
- Update only `<TARGET_IMPLEMENTATION_PLAN_ARTIFACT>`.
- Do not modify input artifacts.
- Do not create or modify unrelated files.

## Project Type Branching
- If project type is `A`, `B`, or `C`: produce the plan from implementation slices, requirements, technical requirements, and contract delta.

## Output Format Baseline
- Use the prompt-provided template as the structure contract.
- Use the prompt-provided golden example as the style contract.
- Preserve step block structure exactly:
  - `### Step <major>.<minor> <title> [REQ-*] [NFR-*] ...`
  - `#### Repo: <backend|frontend|mobile>`
  - `#### Depends on: <none|step ids>`
  - `#### Evidence: <gap/TECH_REQ-id, comp/component-slug, ...>`
  - `#### Preserved Surface: <none|operator-facing surface identity>`
  - optional `#### Assigned: <worker-uuid>`
  - ordered checklist bullets
- Omit `#### Assigned:` by default. Worker assignment is a separate later action.
- Each step must belong to exactly one repo owner.
- Step heading requirement links are the canonical functional-requirement traceability contract for this stage.
- Keep unresolved-work coverage and technical justification at step scope (`### Step ...` + `#### Evidence:`), never on checklist bullets.
- Checkboxes may use `[x]` for already-implemented bullets and `[ ]` for remaining work.

## Planning Rules
### Phase Boundary
- Start from `<IMPLEMENTATION_SLICES_ARTIFACT>` first and treat it as the primary source for executable decomposition discovered in Step 8.1.
- This phase adds what Step 8.1 intentionally did not add: full cross-repo ordering, explicit dependency edges, and full traceability restoration.
- Respect local prerequisite intent from implementation slices, then optimize global execution order here.
- Use `<TECHNICAL_REQUIREMENTS_ARTIFACT>` as the canonical source for repo ownership, unresolved coverage obligations, and valid evidence tokens, but do not let its component/gap grouping collapse thin slices back into the flattened Step 7 shape.
- Do not plan directly from surface-map artifacts in this phase; `<TECHNICAL_REQUIREMENTS_ARTIFACT>` is the consolidated evidence source now.

### Ordering And Transformations
- Use `<FEATURE_CONTRACT_DELTA_ARTIFACT>` to identify shared-contract, compatibility, rollout, or cross-track prerequisite work that must land before dependent repo-specific implementation steps.
- Put shared contracts or common prerequisite work before dependent repo-specific work.
- Allow backend, frontend, and mobile steps to proceed in parallel unless a real contract, payload, schema, state, or prerequisite dependency blocks parallel execution.
- Every `#### Depends on:` edge must reflect a real dependency reason, not convenience ordering.
- Preserve useful thin slice boundaries from `<IMPLEMENTATION_SLICES_ARTIFACT>` by default.
- When a slice preserves a required missing operator-facing surface, keep that surface explicit in at least one plan step after any reorder/split/merge transformation.
- Supporting API/auth/contract/state/coordination work may surround preserved surfaces, but it never fulfills preserved-surface delivery by itself.
- Reorder slices, split overloaded slices, or add prerequisite steps when needed for executable ordering or safe delivery.
- Merge only when slices are truly coupled and the final plan records the merge rationale.
- Never merge solely to reduce step count, simplify requirement grouping, or make traceability look tidier.
- Do not collapse scaffold-heavy frontend/mobile work back into one broad bucket unless a hard dependency truly makes that unavoidable.
- Preserve coverage semantically (page/screen/shell/route, CLI/admin tool/job/endpoint, or equivalent wording), not by brittle route-name literals, framework labels, or one surface vocabulary.

### Traceability And Evidence
- Use `<REQUIREMENTS_EARS_ARTIFACT>` as the authoritative source of behavior and requirement ids.
- Reuse the existing `REQ-*` / `NFR-*` ids directly; do not invent a plan-only id namespace.
- Every step title line must reference one-or-more valid `REQ-*` or `NFR-*` ids.
- Every `REQ-*` / `NFR-*` id in `<REQUIREMENTS_EARS_ARTIFACT>` must be represented by at least one step heading.
- Every step must include one `#### Evidence:` line with one-or-more comma-separated tokens using only:
  - `gap/TECH_REQ-<n>` for entries from `### Requirement: REQ-<n>` blocks in `<TECHNICAL_REQUIREMENTS_ARTIFACT>`
  - `gap/TECH_REQ-NFR-<n>` for entries from `### Requirement: NFR-<n>` blocks in `<TECHNICAL_REQUIREMENTS_ARTIFACT>`
  - `comp/<component-slug>` for entries from `### Component:` blocks in `<TECHNICAL_REQUIREMENTS_ARTIFACT>`
- Ensure unresolved requirement-gap and impacted-component entries (remaining gap only) from `<TECHNICAL_REQUIREMENTS_ARTIFACT>` are represented by at least one step `#### Evidence:` token.
- Already completed technical entries (`fully_implemented` or `no remaining gap`) are optional context and are not part of mandatory unresolved-work coverage.

### Step Quality
- Derive step contents from concrete impacted components and `gap_to_close` evidence, not from generic repository topology summaries.
- If one functional slice spans multiple repos, split it into multiple repo-owned steps and connect them with `#### Depends on:`.
- Include already-implemented slices only when they materially explain current repo state or are needed so later incomplete work has clear prerequisites and traceability.
- Keep bullets implementation-shaped and component-specific, for example create or update controller, service, DTO, mapper, client, state, migration, security, or test work.
- Do not create generic paraphrase bullets such as `align backend` or `implement feature`.
- Keep step bullets outcome-oriented and specific.
- Prefer roughly balanced slices when feasible; target about 1-3 days of human coding per step, but do not force artificial fragmentation.
- Include prerequisite or refactoring steps when current inputs show they are needed to start safe implementation.
- Do not restate stable contract governance already captured in `common_contract_definition.md`.

## Coordination Plan Steps

- A plan step derived from a coordination slice may be marked `#### Coordination: true`. This marker is optional; omitting it means the step is a normal feature-delivery step.
- A coordination slice is only lifted into a plan step when at least one downstream implementation step cannot safely begin without the coordination artifact being resolved. The coordination step is not required merely because a coordination slice exists; absence of a coordination plan step is a valid plan outcome.
- A plan step marked `#### Coordination: true` must not be the sole coverage for a required missing operator-facing surface identified in `prerequisite_gaps.md`. If a required surface is tracked, at least one non-coordination plan step with `#### Preserved Surface:` referencing that surface must also exist.
- Every `#### Depends on:` edge from a downstream implementation step to a coordination plan step must reflect a real per-step dependency reason. The same coordination dependency edge must not be applied blanket to every consumer-repo step; each dependency must be justified by that specific step's need for the coordination artifact.

## Final Self-Review
Before finishing, review the full generated plan once more and correct it if needed so that:
- prerequisite steps appear before dependent implementation work
- no dependency points to a later step
- cross-repo sequencing is coherent
- repo ownership is explicit on every step
- technical-requirements evidence is reflected in the actual step list
- no implementation step is missing `#### Evidence:`
- required missing operator-facing surfaces from upstream evidence still appear as explicit delivery work in at least one step each
- supporting-only steps are not the only coverage for required missing operator-facing surfaces

## Evidence Rules
- Prefer facts from the input artifacts.
- Keep inferences minimal; when needed, mark them with `[Inference]`.
- Do not invent repository changes that are not supported by requirements, contract delta, or technical requirements.
- Keep statements concise and implementation-oriented.

## Runtime Path Binding Rules
- Treat runtime bindings in prompt context as authoritative for this invocation.
- Resolve outputs under the runtime feature root.
- Do not hardcode `overmind/product/...` paths when runtime override is supplied.

## Completion Gate
- Before finalizing, run the prompt-provided quality gate command.
- If the gate fails, revise the output and rerun the gate command.
- If gate compliance is not feasible with current inputs and constraints, stop and use the prompt-provided failure line exactly.
- If the gate passes, end with the prompt-provided success line exactly.
