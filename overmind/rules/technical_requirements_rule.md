# Feature Technical Requirements Rule

Read this file fully before generating output.

## Purpose
- Consolidate feature-scoped technical requirements from requirements, shared-contract baseline, applicable repo surface maps, and targeted code evidence into one shared artifact.
- Answer one question only:
  `What is currently implemented, what gaps remain, and which concrete components are impacted for this feature across the active repo classes?`
- Produce deterministic output for `<TARGET_TECHNICAL_REQUIREMENTS_ARTIFACT>`.

## Ownership Boundaries
Owns:
- feature-scoped current-state and gap analysis grounded in repository evidence
- per-repo evidence summaries for active repo classes
- requirement-by-requirement implementation coverage and gap status
- concrete impacted-component inventory with explicit repo ownership
- cross-repo constraints and planning signals needed before implementation planning

Must not own:
- full repository inventories unrelated to the feature
- redefinition of stable shared contracts already captured in `common_contract_definition.md`
- implementation-step slicing or worker assignment
- feature-level contract delta authoring (belongs to `feature_contract_delta.md`)

## Authoritative Inputs and Outputs
- Read project/class scope from `<PROJECT_INIT_PROGRESS_DEFINITION_ARTIFACT>`.
- Read final feature behavior from `<REQUIREMENTS_EARS_ARTIFACT>`.
- Read shared-contract baseline and existing cross-repo drift from `<COMMON_CONTRACT_DEFINITION_ARTIFACT>`.
- Read applicable repo surface maps as the feature-scoped index of where direct code evidence should be inspected.
- Use direct repository evidence only for the smallest file set needed to confirm current behavior or gaps.
- Update only `<TARGET_TECHNICAL_REQUIREMENTS_ARTIFACT>`.
- Do not modify input artifacts.
- Do not create or modify unrelated files.

## Project Type Branching
- If project type is `B` or `C`: inspect targeted repository evidence using the applicable surface maps as the starting index.
- If project type is `A`: this stage is unsupported for now; do not generate pseudo-content.

## Evidence Rules
- Treat `<COMMON_CONTRACT_DEFINITION_ARTIFACT>` as the stable cross-project baseline for current shared contracts.
- Treat `<REQUIREMENTS_EARS_ARTIFACT>` as the authoritative source of valid `REQ-*` / `NFR-*` ids and desired final behavior.
- Treat surface maps as file-selection and ownership guidance, not as the final truth of current implementation state.
- Inspect code only under paths called out by the applicable surface maps and the smallest adjacent set of files needed to confirm behavior:
  - controllers / handlers
  - DTOs / schemas / client contracts
  - services / domain / persistence
  - security / config / migrations
  - tests near the touched feature area
- Do not perform a full-repo inventory.
- Prefer repository-proven claims.
- Keep inferences minimal; when needed, mark them with `[Inference]`.
- Do not invent implementation details or gaps without repository or artifact support.

## Output Format Baseline
- Use `overmind/templates/technical_requirements_TEMPLATE.md` as structure contract.
- Use `overmind/golden_examples/technical_requirements_GOLDEN_EXAMPLE.md` as style contract.
- Preserve heading order and key names.
- Keep one shared `technical_requirements.md` artifact for the whole feature.
- In `## 3. Repository Evidence`, include one-or-more `### Repository:` blocks and cover all active repo classes.
- In `## 4. Requirement Coverage and Gaps`, include one `### Requirement:` block for every `REQ-*` / `NFR-*` in `<REQUIREMENTS_EARS_ARTIFACT>`.
- In `## 5. Impacted Components`, include one-or-more `### Component:` blocks with explicit `repo:` ownership.
- In `## 6. Cross-Repo Constraints and Planning Signals`, use either typed `### Planning Signal:` blocks or the exact empty marker `- planning_signals: none`.
- `gap_status` must use only: `fully_implemented`, `partially_implemented`, `not_implemented`, `unclear`.
- `repo_impact` must use only: `backend`, `frontend`, `mobile`, `multiple`.
- `component_kind` must use only: `controller`, `service`, `dto`, `mapper`, `domain`, `persistence`, `migration`, `security`, `config`, `test`, `ui`, `state`, `api_client`, `other`.

## Technical-Requirements Rules
- Use repository evidence to distinguish:
  - already implemented behavior
  - partially implemented behavior
  - missing behavior
  - unclear areas requiring follow-up
- Keep `current_state` factual and concise.
- Keep `gap_to_close` implementation-oriented and specific.
- Record cross-repo dependencies or ordering implications in `dependency_notes` and section 6, but do not convert them into implementation steps here.
- Keep this artifact feature-scoped; do not restate stable, unrelated project architecture.

## Section-Specific Contracts

### Section 4: Current-State Split
- Each `### Requirement:` block MUST record current state using:
  - `transport_layer`
  - `user_reachable_surface`
- `transport_layer` is callable transport-layer code currently present for the requirement (API clients, services, hooks, repositories, helpers). Use `none` when absent.
- `user_reachable_surface` is operator-invocable surface currently present for the requirement (routes, pages, screens, CLI commands, scheduled jobs, public HTTP endpoints). Use `none` when absent.
- A single conflated `current_state:` prose line that mixes transport and reachability is invalid.
- The split applies to all requirement blocks (`REQ-*` and `NFR-*`).
- Do not omit one side of the split; when absent, use the literal value `none`.

### Section 6: Planning Signals
- Section 6 is optional and MUST use exactly one of these shapes:
  - one-or-more typed `### Planning Signal:` blocks
  - the exact empty marker line: `- planning_signals: none`
- Do not use legacy `constraint_*` or `prep_*` entries.
- Supported `signal_type` in this stage is only: `cross_repo_contract_lock`.
- Each `### Planning Signal:` block MUST include:
  - `signal_id`
  - `signal_type`
  - `owner_repo`
  - `consumer_repos`
  - `required_artifact`
  - `must_precede`
  - `output_requirements`
  - `source_evidence`
- `owner_repo` and every `consumer_repos` entry MUST be valid active project classes for the current feature.
- `source_evidence` MUST reference local section-4 or section-5 evidence tokens only:
  - `REQ-*`
  - `NFR-*`
  - `comp/<component-slug>` (slugified `### Component:` heading)
- Planning signals are advisory metadata only. They are not mandatory triggers and must not become hidden implementation steps.
- `must_precede` and `output_requirements` are declarative coordination notes, not executable plan instructions.

## Runtime Path Binding Rules
- Treat runtime bindings in prompt context as authoritative for this invocation.
- Resolve outputs under the runtime feature root.
- Do not hardcode `overmind/product/...` paths when runtime override is supplied.

## Completion Gate
- Before finalizing, run the prompt-provided quality gate command.
- If the gate fails, revise the output and rerun the gate command.
- If gate compliance is not feasible with current inputs and constraints, stop and use the prompt-provided failure line exactly.
- If the gate passes, end with the prompt-provided success line exactly.
