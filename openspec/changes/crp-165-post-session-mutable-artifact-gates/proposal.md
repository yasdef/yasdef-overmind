## Why

Review sessions can edit both a normative artifact and their findings ledger, but the coordinator currently accepts a successful agent exit after checking only read-only guards and required-output existence; actual gate execution is left to in-session instructions. The measured EARS-review run demonstrates why that is insufficient: `requirements_ears_review.md` completed, while the shipped `requirements_ears.md` now fails its own gate on Requirements 12 and 13 because invalid `WHEN … THEN` bullets survived the session.

## What Changes

- Define each review's mutable artifact-to-gate set once as a typed contract consumed by both context generation and the session action that enforces it.
- Configure step `5.1` EARS review to run both the `requirements-ears` gate for `requirements_ears.md` and the `ears-review` gate for `requirements_ears_review.md`.
- Configure step `8.4` plan semantic review to run both the `implementation-plan` gate for `implementation_plan.md` and the `plan-semantic-review` gate for `implementation_plan_semantic_review.md`.
- Run every declared post-session gate, aggregate artifact-specific diagnostics, preserve gate exit `1` versus `2`, and fail the session action before checkpointing when any mutable artifact does not pass.
- Keep model-owned in-session gate/repair loops as the first line of feedback; coordinator re-gating is an independent deterministic completion backstop.
- Build on CRP-163's explicit two-artifact EARS-review write surface without adding another mutable artifact, validator, command, or CLI flag.

## Capabilities

### New Capabilities

- `post-session-mutable-artifact-gating`: catalog-declared, coordinator-enforced revalidation of every mutable artifact for multi-artifact review sessions before action success and checkpointing.

### Modified Capabilities

<!-- None. openspec/specs/ contains no consolidated session-executor capability. -->

## Impact

- Coordinator review-session contract and context builders: define the two mutable artifact-to-gate sets once and render each review's allowed-write surface from that typed data.
- `packages/asdlc-coordinator/src/sequencing/step-catalog.ts`: attach those shared mappings to steps `5.1` and `8.4` while preserving their current read-only guards and required outputs.
- `packages/asdlc-coordinator/src/runner/execute-step.ts`: invoke and aggregate post-session gates at the successful-session boundary.
- Coordinator gate registration: expose one typed validator registry to both CLI gate dispatch and executor dependency injection instead of duplicating validator mappings.
- `overmind/init_progress_definition_sequence_diagram.md` and `overmind/templates/init_progress_definition_TEMPLATE.yaml`: record the strengthened completion conditions for EARS review and plan semantic review.
- Coordinator, orchestrator, and installer/runtime tests: cover full-gate execution, aggregation, exit classification, checkpoint blocking, CRP-163 compatibility, and the reproduced invalid-EARS regression.
- No artifact schema or validator-rule change; existing standalone `overmind gate ...` commands remain unchanged.
