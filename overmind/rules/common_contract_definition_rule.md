# Common Contract Definition Rule

Read this file fully before generating output.

## Purpose
- Reconcile shared/cross-project contract definitions from configured repositories into one baseline artifact.
- Answer one question only: `What project-level shared contracts, current alignment states, and baseline coordination implications should all active project tracks know before feature-specific deltas and implementation planning?`
- Produce deterministic output for `<TARGET_COMMON_CONTRACT_DEFINITION_ARTIFACT>`.

## Ownership Boundaries
Owns:
- cross-repository/common contract baseline definitions
- reconciliation decisions for overlaps or mismatches between repository contracts
- source-of-truth assignment for shared contracts
- contract-local alignment status (`aligned`, `drifted`, `single_source`, `inferred`)
- contract-local planning implications required before feature-level implementation planning
- cross-repository contract risks and uncertainties

Must not own:
- full repository structure inventory or deep architecture mapping
- feature-specific contract deltas (belongs to `feature_contract_delta.md`)
- feature slicing or implementation task breakdown
- contributor/agent workflow instructions

## Authoritative Inputs and Outputs
- Authoritative repository set comes from project metadata in `<PROJECT_INIT_DEFINITION_FILE>`, key `meta_info.class_repo_paths`, filtered to usable repository paths by the init script.
- Use available repository evidence as primary source (API specs, DTO/schema definitions, events, integration adapters, tests, and docs near contract boundaries).
- For project type `A`, approved stack-family blueprints may be provided as read-only high-level project context only.
- Output target is `<TARGET_COMMON_CONTRACT_DEFINITION_ARTIFACT>`.
- Do not create or modify unrelated files.

## Output Format Baseline
- Use `overmind/templates/common_contract_definition_TEMPLATE.md` as structure contract.
- Use `overmind/golden_examples/common_contract_definition_GOLDEN_EXAMPLE.md` as style contract.
- Preserve heading order and key names.
- In `## 1. Document Meta`, set:
  - `project_id` from prompt context,
  - `project_path` from prompt context,
  - `source_repo_count` equal to the number of repositories analyzed,
  - `source_repositories` as a concise class/name list.
- Keep section `## 2. Source Repository Evidence` in one-or-more `### Repository:` blocks.
- Keep section `## 3. Common Contract Baseline` in one-or-more `### Contract:` blocks.
- Keep section `## 4. Reconciliation Decisions` in one-or-more numbered `decision_N` lines.
- Keep section `## 5. Known Risks / Uncertainties` in one-or-more numbered `uncertainty_N` lines.
- Keep section `## 6. Common Planning Signals` in one-or-more numbered `prep_N` lines.
- For every contract block, include all template keys; `contract_status` and `planning_implication` are mandatory.
- Use canonical value sets from the template for `contract_kind`, `interaction_mode`, `contract_status`, and `trust_boundary`.
- `canonical_shape` must stay compact and structured (for example: `request: {..}; response: {..}` or `topic + payload schema`) and must not be narrative prose.
- If repository evidence disagrees for a shared contract, set `contract_status: drifted`.
- If only one repository currently provides direct evidence for a shared contract, set `contract_status: single_source`.
- Global sections 4 and 5 remain required, but contract-local status and planning implication in section 3 are primary.

## Evidence Rules
- Prefer repository-proven claims.
- For project type `A`, use stack-family blueprint context only to understand broad technology family; do not copy it as contract schema content.
- Do not invent contract surfaces, statuses, ownership, or compatibility rules without repository evidence.
- If evidence is incomplete, keep uncertainty explicit in section 5.
- Keep prose concise and contract-centric.

## Type A Stack Blueprint Context
- For project type `A`, one approved `project_stack_blueprint_<class>.md` per active class is available as input — produced and quality-gated by Step `1.1`.
- Treat `project_stack_blueprint_<class>.md` files as read-only.
- Do not modify stack blueprint files.
- Do not treat stack-family blueprints as API contract schemas, shared request/response definitions, repository scan evidence, or Step `7` surface-map evidence.
- Stable shared contract definitions remain owned by `common_contract_definition.md`.

## Runtime Path Binding Rules
- Treat runtime bindings in prompt context as authoritative for this invocation.
- Write only to `<TARGET_COMMON_CONTRACT_DEFINITION_ARTIFACT>`.
- Do not hardcode repository-level `overmind/product` paths for this artifact.

## Completion Gate
- Before finalizing, run:
  - `<COMMON_CONTRACT_DEFINITION_GATE_HELPER_COMMAND>`
- Gate pass condition:
  - command exits `0`.
- Gate fail condition:
  - command exits non-zero with one or more quality errors.
- On gate failure:
  - revise output using the helper-reported quality errors and rerun the gate command until it exits `0`.
  - if gate cannot pass with current evidence and constraints, stop and end with this exact line:
    `common contract definition gate cannot pass with current repository evidence. Please provide instructions what to do, or adjust requirements and rerun this phase`
- If gate passes, end final response with this exact last line:
  `Common contract definition phase is finished. Nothing else to do now; press Ctrl-C so orchestrator can start the next phase`
