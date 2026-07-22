---
name: overmind-technical-requirements
description: Use when creating the shared feature-scoped technical requirements artifact for Overmind Step 8.
---

# Overmind Technical Requirements

Use this skill to create one shared `technical_requirements.md` for all active surface-map classes in a feature.

## Required Invocation

1. From the ASDLC workspace root, run:

```text
node .overmind/overmind.js context technical-requirements <feature-path>
```

2. Treat the emitted runtime paths and read-only manifest as authoritative. Read every bound input and the skill assets.
3. Draft the bound target using the template structure and golden-example quality target.
4. Write only the bound `technical_requirements.md`; do not modify any input or create unrelated files.
5. After every write or repair, run:

```text
node .overmind/overmind.js gate technical-requirements <feature-path>
```

6. Handle the gate result exactly:
   - `0`: validation passed; finish with the success line below.
   - `1`: recoverable content issue; read every reported problem, repair only `technical_requirements.md`, and rerun the gate.
   - `2`: validation cannot run; stop, report the blocker, and wait for operator instructions.

If gate compliance is infeasible with the current inputs, end with exactly:

feature technical requirements gate cannot pass with current requirements/common-contract/surface-map inputs. Please provide instructions what to do, or adjust inputs and rerun this phase

When the gate passes, end with exactly:

Feature technical requirements phase is finished. Nothing else to do now; press Ctrl-C so orchestrator can start the next phase

## Assets

- Template: `assets/technical_requirements_TEMPLATE.md`
- Golden example: `assets/technical_requirements_GOLDEN_EXAMPLE.md`

## Purpose

- Consolidate feature-scoped technical requirements from requirements, the shared-contract baseline, applicable repo surface maps, and targeted code evidence into one shared artifact.
- Answer: what is currently implemented, what gaps remain, and which concrete components are impacted across active repo classes?
- Produce deterministic output at the context-bound target artifact.

## Ownership Boundaries

This step owns feature-scoped current-state and gap analysis, per-repo evidence summaries, requirement coverage, concrete impacted components with repo ownership, and planning signals needed before implementation planning.

Implementation-step slicing and worker assignment belong to later steps. Feature contract delta authoring belongs to `feature_contract_delta.md`. Keep unrelated repository inventory and stable shared-contract governance outside this artifact.

## Authoritative Inputs and Output

- Read project and class scope from the bound `init_progress_definition.yaml`.
- Read final feature behavior and valid `REQ-*` / `NFR-*` IDs from the bound `requirements_ears.md`.
- Read stable shared contracts and existing cross-repo drift from the bound `common_contract_definition.md`.
- Use applicable surface maps as the feature-scoped index for direct evidence inspection.
- Use the smallest direct repository file set needed to confirm current behavior or gaps.
- Update only the context-bound `technical_requirements.md`.

## Evidence Rules

- Prefer direct repository evidence when available.
- Treat surface maps as context and ownership guidance, not automatic proof that implementation exists.
- Planned, derived, blueprint, or non-code evidence may support conservative gap analysis but must not be described as implemented code.
- Inspect only relevant controllers/handlers, DTOs/schemas/client contracts, services/domain/persistence, security/config/migrations, and nearby tests.
- Do not perform a full-repository inventory.
- Keep inferences minimal and mark them `[Inference]`.
- Do not invent implementation details or gaps.

## Output Contract

- Follow `assets/technical_requirements_TEMPLATE.md` for exact heading order and key names.
- Use `assets/technical_requirements_GOLDEN_EXAMPLE.md` as a non-normative quality example.
- Keep one shared artifact for the entire feature.
- In `technical_requirements_TEMPLATE.md ## 3. Repository Evidence`, include one or more `### Repository:` blocks covering every active surface-map class.
- In `technical_requirements_TEMPLATE.md ## 4. Requirement Coverage and Gaps`, include one `### Requirement:` block for every valid requirement ID.
- In `technical_requirements_TEMPLATE.md ## 5. Impacted Components`, include concrete `### Component:` blocks with explicit `repo` ownership.
- In `technical_requirements_TEMPLATE.md ## 6. Cross-Repo Constraints and Planning Signals`, use typed `### Planning Signal:` blocks or exactly `- planning_signals: none`.
- `gap_status`: `fully_implemented`, `partially_implemented`, `not_implemented`, or `unclear`.
- `repo_impact`: an active `backend`, `frontend`, or `mobile` class, or `multiple`.
- `component_kind`: `controller`, `service`, `dto`, `mapper`, `domain`, `persistence`, `migration`, `security`, `config`, `test`, `ui`, `state`, `api_client`, or `other`.

## Requirement Current-State Contract

Every requirement block must use both:

- `transport_layer`: callable transport-layer code currently present; use `none` when absent.
- `user_reachable_surface`: operator-invocable routes, pages, screens, commands, jobs, or public endpoints currently present; use `none` when absent.

Do not use a conflated `current_state` line. Keep `gap_to_close` specific and implementation-oriented.

## Planning Signal Contract

Section 6 uses exactly one shape: one or more typed planning-signal blocks, or the exact empty marker. Do not use `constraint_*` or `prep_*` entries.

The only supported `signal_type` is `cross_repo_contract_lock`. Each signal includes `signal_id`, `signal_type`, `owner_repo`, `consumer_repos`, `required_artifact`, `must_precede`, `output_requirements`, and `source_evidence`. Owner and consumers must be active project classes. Source evidence may reference only local `REQ-*`, `NFR-*`, or `comp/<component-slug>` tokens. Signals are advisory coordination metadata, not hidden implementation steps.

## Runtime Binding and Completion

- Runtime context paths are authoritative for each invocation.
- Resolve output under the bound feature root; do not hardcode source-repository paths or runner-specific skill paths.
- Review the complete artifact for coverage and consistency before the final gate run.
- Do not finish after an exit `1`; repair and rerun until exit `0` or a genuine exit `2` blocker.
