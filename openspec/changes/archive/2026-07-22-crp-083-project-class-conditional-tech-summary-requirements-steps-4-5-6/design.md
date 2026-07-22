## Context

CRP-083 extends technical-baseline gating so backend/frontend tech-summary requirements are class-aware rather than unconditional. Today, Step 4 completion in `overmind/scripts/init_progress_scanner.sh` requires both `project_tech_summary_be.md` and `project_tech_summary_fe.md`, and Step 5/6 `input_required` definitions in `overmind/init_progress_definition.yaml` list both files unconditionally.

Repository-level project classes are already persisted in `meta_info.project_classes`, but current requirement evaluation does not use that metadata. This creates false negatives for backend-only and frontend/mobile-only repositories and blocks progress when `project_classes` is empty.

This change is cross-cutting because it updates:
- YAML requirement schema (`required_if` on artifact/input entries)
- scanner-side required-artifact evaluation (Step 4)
- input-required consumers for Step 5 and Step 6
- regression tests for scanner and input-required gating

## Goals / Non-Goals

**Goals:**
- Add declarative conditional requirement guards for step entries using `meta_info.project_classes`.
- Keep conditions structured and deterministic (no free-form expression parsing).
- Make Step 4 scanner completion class-aware for tech-summary artifacts.
- Make Step 5/6 input-required checks class-aware for tech-summary documents.
- Preserve existing semantics for unguarded entries and existing YAML fields.

**Non-Goals:**
- Redesign generation scripts for technical summary artifacts.
- Introduce new CLI flags or alternate entrypoints.
- Add a full generic expression language beyond required class-membership predicates.
- Change Step 7+ contracts in this CR.

## Decisions

1. Use `required_if` as a structured guard on individual requirement entries.
Rationale: guard-at-entry level keeps current schema shape intact and minimizes parser impact. It is explicit and easy to audit in YAML.
Alternative considered: top-level per-step condition maps. Rejected because it complicates mixed mandatory/conditional entries within one step.

2. Restrict first implementation to `meta_info.project_classes.any_of` semantics.
Rationale: this CR needs class-membership checks only. A narrow predicate surface is easier to validate and test.
Alternative considered: a generic DSL (for example arbitrary boolean expressions). Rejected because it increases implementation complexity and validation risk without immediate value.

3. Treat unmatched guards as non-mandatory and keep unguarded entries mandatory.
Rationale: this preserves current strict behavior as the default while enabling selective opt-in conditionality.
Alternative considered: treating missing/empty classes as validation error. Rejected because the CR explicitly requires non-blocking behavior when no matching class exists.

4. Reuse one shared guard evaluator for scanner and input-required consumers.
Rationale: Step 4 artifact checks and Step 5/6 input checks must not diverge. Shared evaluation avoids semantic drift.
Alternative considered: implement separate evaluators per script. Rejected because duplication invites inconsistent interpretation.

5. Fail fast on malformed `required_if` contracts.
Rationale: silent fallback would hide contract mistakes and produce unstable readiness decisions.
Alternative considered: ignore malformed guards and treat entries as unguarded. Rejected because it can accidentally make requirements stricter or looser than intended.

## Risks / Trade-offs

- [Risk] Extending scanner YAML parsing may regress existing checklist behavior.
  Mitigation: preserve existing keys/flow and add regression tests for default behavior plus guarded scenarios.

- [Risk] Input-required consumers are less centralized than scanner logic and may miss shared semantics.
  Mitigation: introduce or reuse a shared parser/evaluator helper and add Step 5/6-focused tests.

- [Risk] Future guard needs may exceed `any_of` quickly.
  Mitigation: design `required_if` as a structured object so additional predicates can be added later without breaking current contracts.

- [Risk] Empty `project_classes` may hide missing metadata in some workflows.
  Mitigation: keep this behavior scoped to guarded tech-summary entries only; other unguarded requirements remain strict.

## Migration Plan

1. Update `overmind/init_progress_definition.yaml` Step 4/5/6 tech-summary entries to include `required_if.meta_info.project_classes.any_of`.
2. Extend scanner definition parsing/evaluation to support optional `required_if` on `finished_only_if_artefacts_present` entries.
3. Extend input-required evaluation code paths to support the same `required_if` semantics for Steps 5 and 6.
4. Add tests for backend-only, frontend/mobile-only, fullstack, and empty `project_classes` cases.
5. Run targeted script test suites and verify no regressions in unguarded requirement behavior.

Rollback strategy: revert YAML guard fields and shared evaluator/parser changes together to restore unconditional requirements.

## Open Questions

- Which concrete script(s) currently enforce `input_required` readiness for Step 5/6 should own the shared evaluator call path in this repository state.
