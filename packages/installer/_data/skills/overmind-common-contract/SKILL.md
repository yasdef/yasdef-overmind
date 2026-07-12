---
name: overmind-common-contract
description: Generate the initial common_contract_definition.md artifact for project init step 2.
---

# Overmind Common Contract

Use this skill only for init step 2 initial common-contract generation.

## Required Invocation

1. Run `node .overmind/overmind.js context common-contract <project>`.
2. Read the full context output before writing.
3. Use only the project path, target artifact, read-only inputs, evidence blocks, deterministic values, and gate command from that context.
4. Ask the operator only for missing human decisions. Do not ask for deterministic values already provided by the context command.

## Runtime Bindings

- `project_root`, `progress_definition`, `target_common_contract`, `gate_command`, `cross_class_peer_trigger`, type A blueprint context, and type B/C ready repository evidence come from the context command.
- Treat runtime bindings in context as authoritative for this invocation.
- Use skill-relative assets from this skill's `assets/` directory.
- Do not hardcode source-repository `overmind/...` paths.

## Allowed Write Surface

- Write exactly one artifact: the `target_common_contract` path from context.
- Preserve `init_progress_definition.yaml`, type A stack blueprints, attached repositories, and every unrelated project artifact.
- Do not create repository inventory artifacts, feature deltas, implementation plans, helper outputs, or workflow markers.

## Assets

- Template: `assets/common_contract_definition_TEMPLATE.md`
- Golden example: `assets/common_contract_definition_GOLDEN_EXAMPLE.md`

## Purpose

- Answer one question only: what project-level shared contracts, current alignment states, and baseline coordination implications should all active project tracks know before feature-specific deltas and implementation planning?
- Reconcile shared/cross-project contract definitions from approved type A stack blueprints or ready type B/C repositories into one baseline artifact.
- Keep the artifact contract-centric, concise, and useful for downstream feature contract deltas and implementation planning.

## Ownership Boundaries

Own:

- cross-repository/common contract baseline definitions
- reconciliation decisions for overlaps or mismatches between repository contracts
- source-of-truth assignment for shared contracts
- contract-local alignment status: `aligned`, `drifted`, `single_source`, or `inferred`
- contract-local planning implications required before feature-level implementation planning
- cross-repository contract risks and uncertainties

Do not own:

- full repository structure inventory or deep architecture mapping
- feature-specific contract deltas
- feature slicing or implementation task breakdown
- contributor or agent workflow instructions
- type A stack-family blueprints as contract schemas

## Authoritative Evidence

- For project type A, use `project_stack_blueprint_<class>.md` files only as read-only high-level project context.
- For project type A, do not treat stack blueprints as API contract schemas, shared request/response definitions, repository scan evidence, or surface-map evidence.
- For project type B/C, use only the ready repository evidence listed in context as source evidence.
- Prefer repository-proven claims from API specs, DTO/schema definitions, events, integration adapters, tests, and docs near contract boundaries.
- Do not invent contract surfaces, statuses, ownership, compatibility rules, or planning implications without evidence.
- If evidence is incomplete, keep uncertainty explicit in `## 5. Known Risks / Uncertainties`.

## Output Format Rules

- Use `assets/common_contract_definition_TEMPLATE.md` as the output structure contract.
- Use `assets/common_contract_definition_GOLDEN_EXAMPLE.md` as the style target.
- Preserve heading order and key names.
- In `## 1. Document Meta`, set:
  - `project_id` from context
  - `project_path` from context
  - `source_repo_count` from context
  - `source_repositories` from context as a concise class/name list
- Keep `## 2. Source Repository Evidence` in one-or-more `### Repository:` blocks.
- Keep `## 3. Common Contract Baseline` in one-or-more `### Contract:` blocks.
- Keep `## 4. Reconciliation Decisions` in one-or-more numbered `decision_N` lines.
- Keep `## 5. Known Risks / Uncertainties` in one-or-more numbered `uncertainty_N` lines.
- Keep `## 6. Common Planning Signals` in one-or-more numbered `prep_N` lines.
- For every contract block, include all template keys. `contract_status` and `planning_implication` are mandatory.
- Use canonical value sets from the template for `contract_kind`, `interaction_mode`, `contract_status`, and `trust_boundary`.
- Keep `canonical_shape` compact and structured, for example `request: {..}; response: {..}` or `topic + payload schema`; do not turn it into narrative prose.
- If repository evidence disagrees for a shared contract, set `contract_status: drifted`.
- If only one repository currently provides direct evidence for a shared contract, set `contract_status: single_source`.
- If a contract is inferred from type A blueprint context rather than repository proof, set `contract_status: inferred` and record uncertainty.
- Global sections 4 and 5 remain required, but contract-local status and planning implication in section 3 are primary.

## Cross-Class Transport/Contract Approach Mirror

- Use the context-provided `cross_class_peer_trigger`.
- If `cross_class_peer_trigger: inactive`, omit `## 7. Cross-Class Transport/Contract Approach Mirror` entirely.
- If `cross_class_peer_trigger: active`, add `## 7. Cross-Class Transport/Contract Approach Mirror`.
- Write one `### Backend: <identity>` block per active backend blueprint.
- Mirror `transport_protocol` and `schema_format` from each backend blueprint's `## 5. Cross-Class Transport/Contract Approach` verbatim.
- Carry concrete values verbatim and carry the literal `<to be defined during first feature implementation plan>` placeholder verbatim.
- Do not collapse, normalize, or reject mismatched values across backends.
- Label each backend block with `service_name` or `repo_name` from blueprint Meta, even when only one active backend exists.
- Placeholder carry-through never blocks step 2. The mirror is informational and is not gated on concrete values.

## Gate Loop

1. Draft or repair only `common_contract_definition.md` at the `target_common_contract` path from context.
2. Run the exact `gate_command` from context after every write or repair.
3. If the gate exits `0`, stop and report completion.
4. If the gate exits `1`, read the gate output, repair only the reported missing or invalid content, and rerun the same gate command.
5. If the gate exits `2`, stop, include the gate error, and report that validation cannot complete with the current runtime inputs.
6. If gate compliance is not feasible with current evidence and constraints, stop with the infeasibility line below.

## Final Response

If the gate cannot pass, end with exactly:

`common contract definition gate cannot pass with current repository evidence. Please provide instructions what to do, or adjust requirements and rerun this phase`

If the gate passes, end with exactly:

`Common contract definition phase is finished. Nothing else to do now; press Ctrl-C so Overmind can finalize project initialization`
