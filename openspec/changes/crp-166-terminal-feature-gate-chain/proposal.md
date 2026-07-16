## Why

Step-local gates can still miss an earlier artifact that was edited later, produced before stronger enforcement existed, or accepted through a path without a post-session recheck. The measured UMSS feature demonstrates both sides of the failure mode: its artifact-based progress is complete while `requirements_ears.md` fails the current deterministic EARS validator, and its `implementation_plan.md` lost the template's leading `# Implementation Plan` header while the current plan validator still passes. Plan completion needs one final inexpensive chain-wide safety net whose owning validators cover both measured defects.

## What Changes

- Add an ordered terminal feature-gate chain that reuses every applicable deterministic feature validator for which the owning artifact exists.
- Add one exact leading-header regex to the existing implementation-plan validator so a plan that lost `# Implementation Plan` fails recoverably before either its step-local gate or the terminal chain can pass it.
- Add `node .overmind/overmind.js gate all <feature-path>` to run the complete applicable chain, continue after failures, print artifact-and-gate-specific results, and preserve aggregate exit `0`, `1`, or `2`.
- Run the same in-process chain from the feature flow after the last optional-review decision and before an after-review checkpoint or successful plan-complete outcome.
- Treat missing optional artifacts as not applicable, expand existing surface-map artifacts by supported class, and preserve phase applicability such as the ready-repository condition for `repo-br-scan`.
- On failure, block plan completion, retain the aggregate exit classification, and identify the earliest owning workflow step for an explicit operator-driven repair resume.
- Allow an explicit repair resume to reopen the cached feature that failed terminal validation even though artifact-presence scanning otherwise considers it complete.
- Build on CRP-165's shared in-process validator registry; do not add model calls, semantic re-review, another validator-rule change, or a new runtime asset.

## Capabilities

### New Capabilities

- `terminal-feature-gate-chain`: typed feature-gate inventory, standalone `gate all` dispatch, aggregate result semantics, and flow-end enforcement before plan completion.

### Modified Capabilities

<!-- None. openspec/specs/ contains no consolidated feature-flow or gate-chain capability. -->

## Impact

- Coordinator validation/registry layer: add the typed terminal-chain manifest and an injectable aggregate runner on top of CRP-165's shared validator dispatch.
- `packages/asdlc-coordinator/src/validate/implementation-plan.ts`: require the exact template header at the start of `implementation_plan.md` with one structural regex and a recoverable diagnostic.
- `packages/asdlc-coordinator/src/cli/run.ts`: route `gate all <feature-path>` and render stable per-gate and aggregate output without a new flag.
- `packages/asdlc-coordinator/src/orchestrator/run-feature-flow.ts` and feature selection: enforce the terminal hook and make its repair guidance resumable for the cached feature.
- `overmind/init_progress_definition_sequence_diagram.md`, `overmind/templates/init_progress_definition_TEMPLATE.yaml`, `overmind/README.md`, `README.md`, and the generated quick-run guide: document terminal completion and the operator command.
- Coordinator and installer tests: cover inventory/applicability, full aggregation, exit classification, completion/checkpoint blocking, repair resume, the live invalid-EARS and missing-plan-header regressions, and installed-runtime behavior.
- No artifact schema, skill payload, external dependency, or validator acceptance-rule change beyond the implementation-plan header check.
