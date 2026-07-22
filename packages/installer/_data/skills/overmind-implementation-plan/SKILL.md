---
name: overmind-implementation-plan
description: Use when creating the shared ordered repository implementation plan for Overmind Step 8.3.
---

# Overmind Implementation Plan

Use this skill to convert implementation slices and feature evidence into one ordered, cross-repo `implementation_plan.md`.

## Required Invocation

1. From the ASDLC workspace root, run:

```text
node .overmind/overmind.js context implementation-plan <feature-path>
```

2. Treat the emitted paths, active repo classes, and read-only manifest as authoritative. Read every bound input and both assets.
3. Draft the bound target using the template structure and golden-example quality target.
4. Write only the bound `implementation_plan.md`.
5. After every write or repair, run:

```text
node .overmind/overmind.js gate implementation-plan <feature-path>
```

6. Handle the gate result exactly:
   - `0`: validation passed; finish with the success line below.
   - `1`: recoverable content issue; repair only `implementation_plan.md` from every reported problem and rerun the gate.
   - `2`: validation cannot run; stop, report the blocker, and wait for operator instructions.

If gate compliance is infeasible with the current inputs, end with exactly:

repository implementation plan gate cannot pass with current requirements/technical-requirements/contract/slice inputs. Please provide instructions what to do, or adjust inputs and rerun this phase

When the gate passes, end with exactly:

Repository implementation plan phase is finished. Nothing else to do now; press Ctrl-C so orchestrator can start the next phase

## Assets

- Template: `assets/implementation_plan_TEMPLATE.md`
- Golden example: `assets/implementation_plan_GOLDEN_EXAMPLE.md`

## Purpose

- Convert implementation-slice planning, feature requirements, feature-scoped technical requirements, and contract delta into one shared ordered implementation plan.
- Produce a concrete executable sequence with one repo owner per step, grounded in current repo state.
- Preserve required missing operator-facing surface delivery so supporting-only work cannot replace required outcomes.

## Ownership Boundaries

This step owns executable sequencing across active repo classes, per-step `#### Repo:` ownership, prerequisite/alignment steps, `#### Depends on:` ordering, REQ/NFR traceability, concrete step slicing from impacted components and gaps, material already-implemented slices, and preserved-surface delivery through final ordering.

## Authoritative Inputs and Output

- Read project/class scope from the bound `init_progress_definition.yaml`.
- Read behavior and requirement ids from the bound `requirements_ears.md`.
- Read executable decomposition from the bound `implementation_slices.md` first.
- Read current state, impacted components, repo ownership, gaps, and valid evidence tokens from the bound `technical_requirements.md`.
- Read shared-contract prerequisites and compatibility constraints from the bound `feature_contract_delta.md`.
- Read required missing operator-facing surfaces from the bound `prerequisite_gaps.md`.
- Update only the bound `implementation_plan.md` and keep every input byte-unchanged.
- Treat `project_type_code` as historical metadata only.

## Output Format Baseline

- Follow `assets/implementation_plan_TEMPLATE.md` for structure and use `assets/implementation_plan_GOLDEN_EXAMPLE.md` as a non-normative quality example.
- Preserve each step block:
  - `### Step <major>.<minor> <title> [REQ-*] [NFR-*] ...`
  - `#### Repo: <backend|frontend|mobile>`
  - `#### Depends on: <none|same-feature step ids|cross-feature refs>`
  - `#### Evidence: <gap/TECH_REQ-id, comp/component-slug, slice/slice-ref, ...>`
  - `#### Preserved Surface: <none|operator-facing surface identity>`
  - optional `#### Coordination: true`
  - optional `#### Assigned: <worker-uuid>`
  - ordered checklist bullets
- Omit `#### Assigned:` by default; worker assignment is a later action.
- Each step has exactly one repo owner and one occurrence of each required field.
- Put traceability and evidence at step scope, never on checklist bullets.
- Use `[x]` for already implemented bullets and `[ ]` for remaining work.
- Include at least three checklist bullets; the first is `Plan and discuss the step`, and include `Review step implementation`.

## Planning Rules

### Phase Boundary

- Start from `implementation_slices.md`; this phase adds full cross-repo ordering, explicit dependency edges, and complete traceability.
- Respect local prerequisite intent, then optimize global execution order.
- Use `technical_requirements.md` for ownership, unresolved coverage obligations, and valid evidence without collapsing thin slices into broad component buckets.
- Do not plan directly from surface-map artifacts; technical requirements are the consolidated evidence source.

### Ordering and Transformations

- Put contract, compatibility, rollout, or common prerequisite work before dependent repo-specific work.
- Allow repo steps to proceed in parallel unless a real contract, payload, schema, state, or prerequisite dependency blocks them.
- Every dependency edge must represent a real reason.
- Cross-feature dependencies use exactly `<feature-folder>/<step-id>`; same-feature ids reference earlier steps.
- Preserve useful thin slice boundaries and every required missing operator-facing surface through reordering, splitting, or merging.
- Supporting API/auth/contract/state/coordination work does not fulfill preserved-surface delivery.
- Split overloaded or multi-repo slices; merge only truly coupled slices and record the rationale.
- Do not merge to reduce step count, simplify requirement grouping, or tidy traceability.
- Preserve thin frontend/mobile decomposition unless a hard dependency prevents it.
- Match surface meaning semantically across page/screen/shell/route, CLI/admin tool/job/endpoint, and equivalent wording.

### Traceability and Evidence

- Reuse source `REQ-*`/`NFR-*` ids; do not invent a plan-only namespace.
- Every step heading references at least one valid requirement id, and every source id appears in at least one heading.
- Every step has at least one comma-separated evidence token:
  - `gap/TECH_REQ-<n>` for `REQ-<n>` technical-requirement blocks
  - `gap/TECH_REQ-NFR-<n>` for `NFR-<n>` blocks
  - `comp/<component-slug>` for impacted components
  - `slice/<slice-ref>` for scheduled prerequisite slices
- Cover every unresolved requirement/component token and every scheduled prerequisite slice ref.
- Resolved technical entries are optional context.

### Step Quality

- Derive steps from impacted components and `gap_to_close`, not generic topology.
- Split cross-repo slices and connect them with real dependencies.
- Include completed work only when it explains current state or prerequisites.
- Keep bullets component-specific, outcome-oriented, and implementation-shaped.
- Avoid generic paraphrases such as `align backend` or `implement feature`.
- Prefer roughly balanced 1–3 day steps without artificial fragmentation.
- Add prerequisite/refactoring steps only when evidence shows they are needed.
- Mark necessary inference with `[Inference]`; do not invent unsupported repository changes.

## Coordination Plan Steps

- Lift a coordination slice only when a downstream step cannot safely start without its artifact.
- `#### Coordination: true` is optional; absence means normal feature delivery.
- A coordination step cannot be the sole coverage for a required missing operator-facing surface.
- Apply coordination dependency edges only to steps that genuinely need the artifact, never as a blanket edge.

## Final Self-Review

Verify prerequisite order, no forward dependencies, coherent cross-repo sequencing, explicit ownership, complete REQ/NFR and unresolved-evidence coverage, a required `#### Evidence:` on every step, explicit non-coordination delivery for every required missing surface, and no supporting-only substitute for those surfaces.

## Runtime Path Binding and Completion

- Runtime context bindings are authoritative; resolve output under the bound feature root.
- Do not hardcode source-repository, `.codex`, or `.claude` paths.
- Run the bound gate after every write or repair.
- Do not finish after exit `1`; repair and rerun until exit `0` or a genuine exit `2` blocker.
