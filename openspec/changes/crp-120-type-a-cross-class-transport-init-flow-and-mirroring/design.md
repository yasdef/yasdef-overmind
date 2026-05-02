## Context

CRP-119 defines the §5 "Cross-Class Transport/Contract Approach" artifact contract on the backend stack blueprint: schema, placeholder sentinel, two valid shapes, quality-helper rules, and a Step `1.1` finished-only-if condition. CRP-120 wires that contract into the live init/feature pipeline.

Three distinct integrations land here:

- Step `1.1` derivation flow: how §5 values get proposed and approved (or written as the placeholder).
- Step `2` mirror: how `common_contract_definition.md` reflects each backend's §5 verbatim, including per-backend ownership for multi-backend projects.
- Step `6` mirror: how `feature_contract_delta.md` carries the current §5 forward and how a feature may record concrete values directly when it defines or refines them.

Because §5 itself is a no-op when there is no in-project cross-class peer for the backend (no active backend, or exactly one active backend with no other active class), every change in this CRP is gated on the same trigger.

## Goals / Non-Goals

**Goals:**

- Wire MCP-backed and stack-inference §5 derivation into the existing Step `1.1` blueprint authoring flow.
- Require explicit user approval before writing concrete §5 values; allow placeholder writes without approval.
- Mirror §5 verbatim into `common_contract_definition.md` at Step `2`, with per-backend ownership when multiple backends are active.
- Mirror §5 into `feature_contract_delta.md` at Step `6`, with the feature able to record concrete values directly when it defines or refines them.
- Apply the same in-project-cross-class-peer trigger across all three integrations so a lone-backend project sees no §5 work anywhere.
- Keep type `B` and type `C` flows untouched.

**Non-Goals:**

- Change CRP-119's §5 artifact contract or quality-helper rules.
- Add a Step `6` enforcement check, terminal-state machine, or required block for §5.
- Force consumer classes (FE/Mobile) to record §5; backend remains the sole holder.
- Touch Step `7` surface-map evidence or any planning-pipeline phase beyond Step `6`.
- Introduce per-endpoint contract content into §5; protocol and schema format only.
- Make MCP availability mandatory.

## Decisions

### Decision 1: Single trigger guard, applied at every integration point

§5 applies only when the project has at least one in-project cross-class peer for the backend (another active backend, an active frontend, or an active mobile class). The Step `1.1` derivation, Step `2` mirror, and Step `6` mirror all check the same predicate and no-op together when it is false.

Alternatives considered: per-step independent triggers (rejected — three places to drift); a separate "§5 enabled" flag in init metadata (rejected — derivable from active classes already known to the pipeline).

### Decision 2: Derivation order is MCP → stack inference → placeholder, reusing the existing harness

The Step `1.1` blueprint authoring flow already implements MCP-query + bounded-fallback + user-approval for §2 stack choices, §3 layer bindings, and §4 baseline tokens. The §5 derivation reuses that harness rather than introducing parallel logic.

For each active backend blueprint with §5 in scope:

1. Query the existing MCP harness against the `stack_knowledge_base` source declared in `.setup/external_sources.yaml` for a transport/schema proposal. (Reuses existing infrastructure.)
2. Otherwise, run §5-specific inference from the approved §2 stack choices (e.g., Spring Boot → REST + OpenAPI 3.1; gRPC service framework → gRPC + protobuf). (New for §5 — earlier sections fall back to a bounded family menu, not §2-derived inference.)
3. If neither yields a confident proposal, or the user declines, write the placeholder pair with `user_approved: false`. (New for §5 — earlier sections have no placeholdered escape hatch.)

A "confident proposal" is one the flow is willing to surface to the user for approval. The flow never auto-fills concrete values without approval; it either obtains approval through the existing approval flow or falls through to the placeholder.

What's net-new on top of the existing harness: (a) the §5-specific stack-inference fallback, (b) the placeholder write path with `user_approved: false`, (c) user-decline → placeholder fall-through (instead of looping or blocking).

### Decision 3: Approval is required for concrete writes, not for placeholder writes

Writing the placeholder pair is a no-decision outcome and must not require user approval — that would block init unnecessarily. Writing concrete values must require explicit approval, recorded in the authoring flow log (not in the §5 fields themselves beyond `user_approved: true`).

### Decision 4: Step `2` mirror is verbatim, with per-backend ownership

`common_contract_definition.md` mirrors each active backend blueprint's §5 verbatim. When multiple backends are active, the file labels which backend owns which contract approach (e.g., one section per backend keyed by `service_name` or `repo_name` from blueprint §1). Mismatched §5 values across backends are visible but not enforced — making divergence reviewable without forcing project-wide convergence.

Placeholder carry-through does not block Step `2`. A type `A` project can complete Step `2` with §5 in any combination of populated and placeholdered states across its backends.

### Decision 5: Step `6` mirror lives in `feature_contract_delta.md`, no enforcement

The `feature_contract_delta.md` template gains two simple per-backend fields, `transport_protocol` and `schema_format`, each accepting a concrete value or the placeholder. By default the feature mirrors the current `common_contract_definition.md` values per backend. When the feature defines or refines those values, it records the concrete values directly in delta.

There is no Step `6` enforcement check, no resolution state machine, no required block. The fields either carry concrete values or carry the placeholder; nothing else.

### Decision 6: Concrete values written at Step `6` do not back-propagate to blueprint or contract definition

When a feature records concrete §5 values in delta, those values stay in the feature's delta. They do not automatically rewrite the blueprint's §5 or `common_contract_definition.md`. Project-level convergence (when and how to update the blueprint after a feature defines values) is out of scope for this CRP — keeping the delta as the single feature-scoped surface keeps the mirror simple.

Alternatives considered: auto-back-propagate concrete values to the blueprint (rejected — silent project-wide writes; the user should explicitly re-approve §5 in the blueprint via a future flow if they want to flip the project default); enforce that the blueprint must be updated before a feature can record concrete values (rejected — defeats the "feature defines it" path the gap explicitly allows).

### Decision 7: Placeholder string and field ordering match CRP-119

The placeholder is the literal `<to be defined during first feature implementation plan>` defined by CRP-119. Field ordering in delta mirrors blueprint §5 to keep the two surfaces visually aligned.

## Risks / Trade-offs

- **Risk: derivation flow auto-approves silently** → Mitigation: separate the "confident proposal" check from the "user approves" step in the flow code; only write `user_approved: true` after explicit approval.
- **Risk: multi-backend §5 drift surprises reviewers** → Mitigation: Step `2` mirror records per-backend ownership; downstream consumers and reviewers see each backend's §5 separately and can act on the divergence.
- **Risk: feature delta values diverge from project default** → Accepted. The delta is the feature-scoped truth for that feature; project default convergence is a separate concern.
- **Risk: trigger predicate evaluated inconsistently across steps** → Mitigation: factor it into one helper (e.g., a single shell function) used by Step `1.1`, Step `2` conditions, and Step `6` conditions.
- **Risk: `common_contract_definition_TEMPLATE.md` changes affect type `B`/`C`** → Mitigation: §5-mirror section is conditional on type `A` + peer-trigger; type `B`/`C` template behavior remains unchanged.

## Migration Plan

No runtime migration. Type `A` projects created after this change run the §5 derivation flow during Step `1.1` (when §5 applies) and carry the mirror through Step `2` and Step `6`. Type `A` projects in progress that already passed Step `1.1` need to re-run the §5 portion of Step `1.1` once before Step `2` can proceed, because their backend blueprints will not yet carry §5; the CRP-119 quality helper will surface this on the next run.

Type `B` and type `C` projects are unaffected.

## Open Questions

- Stack-inference confidence thresholds for common backend frameworks are intentionally left to the implementation; the flow should default to "ask the user when in doubt, then fall through to the placeholder when the user declines or no inference applies." A future refinement may add an explicit confidence map, but it is not needed for correctness.
