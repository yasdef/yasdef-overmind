---
name: overmind-implementation-slices
description: Use when creating the shared implementation slice planning artifact for Overmind Step 8.1.
---

# Overmind Implementation Slices

Use this skill to create one shared `implementation_slices.md` containing thin executable slices across all active repo classes.

## Required Invocation

1. From the ASDLC workspace root, run:

```text
node .overmind/overmind.js context implementation-slices <feature-path>
```

2. Treat the emitted runtime paths and read-only manifest as authoritative. Read every bound input and both skill assets.
3. Draft the bound target using the template structure and golden-example quality target.
4. Write only the bound `implementation_slices.md`; do not modify any input or create unrelated files.
5. After every write or repair, run:

```text
node .overmind/overmind.js gate implementation-slices <feature-path>
```

6. Handle the gate result exactly:
   - `0`: validation passed; finish with the success line below.
   - `1`: recoverable content issue; read every reported problem, repair only `implementation_slices.md`, and rerun the gate.
   - `2`: validation cannot run; stop, report the blocker, and wait for operator instructions.

If gate compliance is infeasible with the current inputs, end with exactly:

implementation slice planning gate cannot pass with current requirements/technical/contract/surface-map inputs. Please provide instructions what to do, or adjust inputs and rerun this phase

When the gate passes, end with exactly:

Implementation slice planning phase is finished. Nothing else to do now; press Ctrl-C so orchestrator can start the next phase

## Assets

- Template: `assets/implementation_slices_TEMPLATE.md`
- Golden example: `assets/implementation_slices_GOLDEN_EXAMPLE.md`

## Purpose

- Generate implementation-driven executable slices before final ordered implementation-plan generation.
- Answer one question only: what thin, executable slices should exist for this feature before Step 8.2 turns them into a fully ordered, fully traceable implementation plan?
- Preserve required missing operator-facing surface delivery from upstream evidence so supporting-only slices cannot replace required surface outcomes.
- Produce deterministic output at the context-bound target artifact.

## Ownership Boundaries

This step owns thin executable slice discovery across active repo classes, recovery of execution shape flattened during technical-requirements consolidation, first usable increment framing, local prerequisite capture, scaffold-aware frontend/mobile decomposition, handoff notes for ordered planning, and explicit preservation of required missing operator-facing surfaces as feature-delivery slices.

Full global ordering, full REQ/NFR-to-step coverage enforcement, worker assignment/discovery, and architecture redesign unrelated to current feature inputs belong outside this step.

## Authoritative Inputs and Output

- Read project/class scope from the bound `init_progress_definition.yaml`.
- Read behavioral scope from the bound `requirements_ears.md`.
- Read current implementation state and technical evidence from the bound `technical_requirements.md`.
- Read contract prerequisites from the bound `feature_contract_delta.md`.
- Re-read applicable surface-map artifacts to recover repo execution context flattened in technical requirements.
- When the context binds an existing `prerequisite_gaps.md`, treat it as read-only evidence for required missing operator-facing surfaces.
- Update only the context-bound `implementation_slices.md`.
- Treat `project_type_code` as historical metadata only; do not branch slice generation on it.

## Output Format Baseline

- Follow `assets/implementation_slices_TEMPLATE.md` for exact sections and slice block structure.
- Use `assets/implementation_slices_GOLDEN_EXAMPLE.md` as a non-normative quality example.
- Keep each slice owned by one repo: `backend`, `frontend`, or `mobile`.
- Use `status: existing` or `status: planned`.
- Describe executable slices rather than final ordered implementation steps.
- Requirement refs in slice headings are optional hints, not a completeness contract.
- Keep `ordering_scope: local_prerequisites_only` and `traceability_scope: slice_level_only`.
- Keep checklist bullets execution-shaped and concrete.
- Do not add lifecycle boilerplate bullets such as `Plan and discuss the slice` or `Review slice readiness`.

## Planning Rules

- Start from `technical_requirements.md` to identify concrete gaps and impacted components, but do not let its grouping dictate slice boundaries.
- Re-open applicable surface maps to recover execution structure, especially for thin or scaffold-heavy frontend/mobile repos.
- Use `feature_contract_delta.md` for contract, payload, schema, rollout, or compatibility prerequisites that affect whether a slice can begin.
- Use `requirements_ears.md` to align slices with behavioral scope without forcing full REQ/NFR coverage in this phase.
- For every required missing operator-facing surface identified by upstream evidence, include at least one explicit feature-delivery slice that delivers that surface itself.
- Supporting auth/API/contract/state/coordination slices may be added, but never satisfy required operator-facing surface delivery by themselves.
- Do not add a dedicated surface-restatement field or duplicate tracking mechanism on the slice; Step 8.2 records the delivering slice as `slice_ref` on the prerequisite entry, and the gate resolves coverage from that link.
- Prefer the smallest meaningful slice that produces a first usable/admin-visible increment or cleanly unblocks another real slice.
- Pull first usable increments forward instead of burying them behind broad bucket work.
- For thin frontend/mobile repos, decompose by shell, composition, state, API adapter, UX behavior, or focused tests rather than one broad client bucket.
- Allow backend, frontend, and mobile slices to proceed independently unless a real contract or state dependency blocks independence.
- Capture only local prerequisites needed to begin safely; do not force full cross-repo ordering.
- Do not require every REQ, NFR, or evidence token in slice headings; Step 8.2 restores full ordering and traceability.
- Word a surface-delivering slice so its heading, objective, first increment, and bullets name the delivered page/screen/shell/route, CLI/admin tool/job/endpoint, or equivalent, rather than only its supporting scaffolding. This is quality guidance for a clearer slice, not a gate condition: the gate decides coverage from the resolved `slice_ref` link alone, not from this wording.
- Mark assumptions as `[Inference]`.

## Coordination Slices

- A `kind: coordination` slice is optional and may be emitted only when shared contract semantics are materially ambiguous, repos would otherwise implement incompatible interpretations, a concrete shared artifact must be frozen before safe parallel delivery, or a `cross_repo_contract_lock` signal in `technical_requirements.md` makes the drift risk explicit.
- Absence of coordination slices is valid; do not emit them reflexively based on scope alone.
- A coordination slice must include a non-empty `signal_ref` identifying its upstream planning signal.
- A coordination slice cannot be the sole coverage for a required missing operator-facing surface.
- Multi-repo scope, `delta_needed: true`, shared `comp/*` evidence, or the mere presence of planning signals is insufficient by itself.

## Final Self-Review

Before finishing, verify that at least one slice exists; each slice has repo ownership and evidence; local prerequisites are minimal; slices are thinner than final plan steps; required operator-facing surfaces have explicit delivery slices; supporting scaffolding is not substituted for surface delivery; frontend/mobile work is not flattened into broad buckets; the output remains slice-planning focused; and no full-ordering/full-traceability overreach was introduced.

## Runtime Path Binding and Completion

- Runtime context paths are authoritative for each invocation.
- Resolve output under the bound feature root; do not hardcode source-repository or runner-specific skill paths.
- Run the bound gate after every write or repair.
- Do not finish after exit `1`; repair and rerun until exit `0` or a genuine exit `2` blocker.
