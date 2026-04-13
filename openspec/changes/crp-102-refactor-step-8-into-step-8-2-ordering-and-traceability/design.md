## Context

Step `8` currently mixes two concerns in one phase: discovering executable slices and producing the final shared implementation plan with deterministic ordering and full traceability. After introducing a dedicated Step `8.1` for slice planning, the existing implementation-plan phase must be refocused to consume those slices and produce an optimized final plan as Step `8.2`.

The change affects coordinator-owned planning assets, progress-step definitions, planning prompts/rules/templates, and the plan-quality helper that validates the final `implementation_plan.md`. The design must preserve existing deterministic workflow guarantees while preventing regressions that collapse execution-driven slices back into coarse component buckets.

## Goals / Non-Goals

**Goals:**
- Refactor the implementation-plan phase into Step `8.2` focused on ordered-plan assembly and traceability restoration.
- Require Step `8.2` to consume Step `8.1` slice output plus existing planning inputs (`requirements_ears.md`, `technical_requirements.md`, `feature_contract_delta.md`).
- Preserve Step `8.1` slices by default while allowing constrained transformations (reorder, split, justified prerequisite insertion, and guarded merge).
- Keep deterministic and auditable `implementation_plan.md` generation with explicit dependency edges and parallelism where valid.
- Update quality checks and bootstrap contracts so Step `8.2` is validated as a post-slice ordering and traceability phase.

**Non-Goals:**
- Redesigning Step `8.1` slice-discovery heuristics.
- Changing downstream implementation execution semantics outside planning artifacts and their quality gates.
- Introducing new optional phase behavior unrelated to Step `8.2` ordering and traceability.

## Decisions

### Decision: Make Step `8.2` explicitly input-driven from Step `8.1`
Step `8.2` will require `implementation_slices.md` as a first-class input and treat it as the canonical starting structure for final plan assembly.

Rationale: This enforces phase separation and prevents Step `8.2` from silently redoing initial slicing from consolidated requirements.

Alternatives considered:
- Continue deriving slices primarily from `technical_requirements.md`: rejected because it repeats the pre-`8.1` coupling that produced traceability-shaped rather than execution-shaped plans.

### Decision: Preserve slices by default and gate transformations
Step `8.2` will preserve Step `8.1` slices unless one of the allowed transformation conditions is met. Allowed transformations are: dependency-driven reorder, overloaded-slice split, prerequisite-slice insertion, or guarded merge with explicit rationale in `implementation_plan.md`.

Rationale: This keeps execution intent stable while still allowing ordering optimization and prerequisite correction.

Alternatives considered:
- Free-form rewrite of slice boundaries in Step `8.2`: rejected because it blurs phase ownership and reduces traceability to Step `8.1` output.

### Decision: Encode dependency and parallelism rules in Step `8.2` contract
The phase contract will require shared prerequisites first and backend/frontend parallelization when hard dependency edges do not block concurrency. Dependency edges must be explicit and justified by concrete contract/state/schema/prerequisite constraints.

Rationale: This yields predictable execution order while preventing unnecessary serialization.

Alternatives considered:
- Allow implicit dependency inference without explicit rationale: rejected due to non-deterministic ordering decisions and weaker auditability.

### Decision: Keep full traceability restoration in Step `8.2`
`REQ-*`/`NFR-*` coverage, technical-evidence coverage, and final repository ownership mapping remain Step `8.2` responsibilities and are validated after ordered-plan assembly.

Rationale: Step `8.1` stays execution-focused; Step `8.2` remains the single point that restores complete final-plan traceability guarantees.

Alternatives considered:
- Push full traceability checks back into Step `8.1`: rejected because it overloads slice discovery and undermines the two-phase separation.

## Risks / Trade-offs

- [Risk] Existing planning scripts may assume Step `8` has direct slice-discovery authority. -> Mitigation: Update prompts/rules/templates together and add regression coverage for `implementation_slices.md` as required Step `8.2` input.
- [Risk] Over-restrictive merge guardrails may leave too many small steps. -> Mitigation: Permit guarded merges with explicit eligibility and rationale capture in the final plan artifact.
- [Risk] Dependency-edge strictness can increase authoring overhead. -> Mitigation: Keep the justification schema concise and aligned with current quality helper checks.
- [Risk] Step-number transition (`8` to `8.2`) may desynchronize progress definitions and bootstrap setup scripts. -> Mitigation: Update progress-definition template, setup staging scripts, and scanner tests in the same implementation slice.

## Migration Plan

1. Update phase assets for ordered-plan assembly contract (`feature_implementation_plan.sh`, `implementation_plan_rule.md`, template, golden example, and quality helper).
2. Update bootstrap/setup staging scripts and progress-definition assets so Step `8.2` is represented after required Step `8.1`.
3. Update documentation references (`overmind/README.md`, sequence diagram) to describe Step `8.2` ownership and inputs.
4. Add/update script tests for planning command behavior, quality gate behavior, and staged command wiring.
5. Rollback strategy: revert Step `8.2` asset and progress-definition changes together to restore prior single-step Step `8` behavior if regressions are discovered.

## Open Questions

- Should Step `8.2` hard-fail when `implementation_slices.md` is missing, or allow a temporary compatibility fallback with explicit warning?
- Should merge-rationale recording use a dedicated field in `implementation_plan.md` or an extension of existing step-justification bullets?
