## Context

`crp-099` introduced optional Step `8.1` for implementation-plan semantic review and wired that number into bootstrap metadata, sequence docs, staging docs, and tests. The pipeline is now being split into three planning substeps where:

- Step `8.1` will become implementation-driven slice planning,
- Step `8.2` will become ordering plus traceability assembly,
- the existing semantic-review phase must move to Step `8.3`.

This change is intentionally numbering-focused. It does not redesign semantic-review behavior, finding taxonomy, or review-application mechanics.

## Goals / Non-Goals

**Goals:**
- Rename semantic review from optional Step `8.1` to optional Step `8.3` everywhere in overmind workflow artifacts.
- Keep semantic review optional and non-blocking in scanner behavior.
- Preserve staged command/runtime contracts for semantic review while updating phase positioning language.
- Update tests so they assert Step `8.3` semantics and remove stale Step `8.1` expectations for semantic review.

**Non-Goals:**
- Do not add the new Step `8.1` slice-planning phase in this change.
- Do not refactor current shared-plan generation into Step `8.2` in this change.
- Do not alter semantic-review artifact structure or helper semantics beyond numbering references.

## Decisions

1. Keep command and artifact names stable for now
Rationale: only the pipeline step index changes in this CRP; command and artifact identifiers already deployed in tests and docs should stay stable to minimize migration noise.
Alternative considered: rename command/artifact names to include `8.3`. Rejected because it creates unnecessary churn and compatibility risk before step-splitting changes land.

2. Treat progress-definition numbering as the source of truth
Rationale: scanner behavior and orchestration sequence derive from init-progress definition assets; updating those first keeps all downstream contracts coherent.
Alternative considered: update docs/scripts first and defer progress-definition changes. Rejected because it creates temporary mismatch in phase reporting.

3. Preserve optional-step semantics unchanged
Rationale: semantic review remains advisory and optional; only its step index moves.
Alternative considered: make Step `8.3` blocking or required. Rejected because it changes behavior scope beyond renumbering.

## Risks / Trade-offs

- [Risk] Partial renumbering can leave contradictory references (`8.1` vs `8.3`) across docs/tests/scripts.
  Mitigation: update all canonical phase-definition surfaces together and run scanner/setup/semantic-review tests in the same change.

- [Risk] Teams may misread this renumbering as implementation of new Step `8.1` and Step `8.2`.
  Mitigation: keep docs explicit that this CRP is a semantic-review step relocation only.

- [Risk] Existing automation may parse literal step numbers from sequence docs or checklist output.
  Mitigation: include targeted regression checks for scanner rendering and staged setup outputs after renumbering.

## Migration Plan

1. Update workflow definitions and diagrams to mark semantic review as optional Step `8.3`.
2. Update setup/bootstrap staging docs and references that currently point to semantic review as `8.1`.
3. Update scanner-related expectations so optional semantic review is keyed to `8.3`.
4. Update and run tests covering:
   - setup staging,
   - progress scanner optional-step handling,
   - semantic-review command documentation/phase messaging if step-numbered.

Rollback: restore previous step numbering references (`8.1`) in modified files and re-run scanner/setup tests.

## Open Questions

- None for this renumbering change. Follow-up CRPs will define the new Step `8.1` and revised Step `8.2` behavior.
