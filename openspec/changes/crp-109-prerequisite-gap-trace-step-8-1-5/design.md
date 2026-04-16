## Context

`crp-098` enforces step-level evidence and unresolved-work coverage in implementation plans. `crp-108` splits each surface-map and `technical_requirements.md` `current_state` entry into `transport_layer` and `user_reachable_surface` subfields so downstream logic can distinguish between callable code and operator-accessible entry points.

The gap exposed by `crp-098` and `crp-108` together: the implementation-plan helper only checks that every unresolved-gap token from `technical_requirements.md` is touched by a plan step. It never asks whether the user-reachable prerequisites that make a targeted EARS requirement reachable are already present or scheduled. A plan step can reference a protected route, admin panel, or CLI command that has no entry-point route and no slice scheduled to add one. The plan passes every current gate and is still wrong.

Live failure: "Add protected workspace route + redirect to `/admin/login` on session-invalid" passed `crp-098` because every gap token resolved; `/admin/login` had no working sign-in page in the repo and no slice was scheduled to add one.

## Goals / Non-Goals

**Goals:**
- Insert a new required Step `8.1.5` between `8.1` (slices) and `8.2` (plan) that produces `prerequisite_gaps.md`.
- Define `prerequisite_gaps.md` as a per-EARS-requirement trace of externally-invocable prerequisites (using the per-class taxonomy introduced by CRP-108: frontend navigable routes/pages/screens, backend HTTP endpoints / CLI commands / scheduled jobs / admin tools, mobile screens / deep links), each tagged `present_in_repo`, `scheduled_in_slices`, or `unmet`. Internal service-to-service dependencies are explicitly out of scope and remain covered by CRP-098 `gap/TECH_REQ-*` and `comp/*` tokens.
- Ground `present_in_repo` exclusively on the `user_reachable_surface` subfield introduced by `crp-108`; transport-layer presence alone never satisfies the check.
- Gate Step `8.2` start on zero `unmet` entries in `prerequisite_gaps.md`.
- Extend `check_implementation_plan_quality.sh` to fail when any prerequisite marked `scheduled_in_slices` in `prerequisite_gaps.md` is not covered by at least one implementation step.
- Add rule, template, golden example, generator script, and quality helper for Step `8.1.5`.
- Update the sequence diagram, progress-definition template, e2e orchestrator, scanner, and README.

**Non-Goals:**
- Do not add a new project class or project type code.
- Do not change `crp-098` evidence-token semantics (`gap/TECH_REQ-*`, `comp/*`).
- Do not redefine or re-implement the `user_reachable_surface` split; that is fully owned by `crp-108`.
- Do not enforce prerequisite reasoning on Steps other than `8.1.5` and `8.2`.

## Decisions

**1. Step 8.1.5 is mandatory and positioned between 8.1 and 8.2**
Rationale: slices are the canonical scheduling source and must exist before the prerequisite trace can evaluate what is `scheduled_in_slices`. The plan (`8.2`) must not start until the prerequisite gate is clear, so `8.1.5` sits between them as a hard dependency. Making it optional would allow the failure mode it is designed to prevent.
Alternative: fold prerequisite tracing into `8.1` or `8.2`. Rejected — merging the gate into an existing step makes the rule harder to audit and allows a single large step to silently skip prerequisite reasoning.

**2. `prerequisite_gaps.md` entry structure**
Each entry targets one EARS requirement and lists named prerequisites. Each prerequisite carries:
- `status`: `present_in_repo` | `scheduled_in_slices` | `unmet`
- `evidence`: path or token from `user_reachable_surface` (for `present_in_repo`) or a description (for `scheduled_in_slices`)
- `slice_ref`: the slice identifier from `implementation_slices.md` (required when `status: scheduled_in_slices`)

Rationale: a named, per-requirement structure makes the gate mechanical and the quality helper deterministic. Anonymous or free-text formats cannot be validated structurally.

**3. `present_in_repo` requires `user_reachable_surface` evidence; transport alone is insufficient**
Rationale: this is the direct fix for the live failure. Transport-layer presence means the code exists; user-reachable presence means the operator can reach it. Only the latter satisfies the prerequisite for a user-facing EARS requirement. The `user_reachable_surface` subfield from `crp-108` is the canonical source.

**4. `unmet` prerequisites must be promoted to `implementation_slices.md` before `8.2`**
Rationale: the only valid resolution for an `unmet` prerequisite is to schedule it. Closing the gate by deleting the entry or changing the status without adding the slice would silently corrupt the plan. The quality helper rejects any `prerequisite_gaps.md` that contains `unmet` entries.
Alternative: allow `8.2` to add steps for `unmet` prerequisites inline. Rejected — `implementation_slices.md` is the canonical scheduling source; adding prerequisites only in the plan skips slice-level visibility and breaks the `crp-098` coverage check.

**5. `check_implementation_plan_quality.sh` cross-checks `scheduled_in_slices` prerequisites**
The extended helper reads `prerequisite_gaps.md` (same feature directory) and extracts every `slice_ref` from `scheduled_in_slices` entries. It then verifies that each referenced slice maps to at least one plan step. A `present_in_repo` prerequisite is not checked — it is already satisfied by the repo.
Rationale: the plan quality gate is the last enforcement point before a plan enters implementation. Adding the cross-check there closes the loop without requiring a new script invocation in the pipeline.

## Risks / Trade-offs

- [Risk] Introducing a mandatory step raises the bar for existing feature workflows that pre-date this change.
  Mitigation: the gate only applies to new feature runs. Existing `implementation_plan.md` artifacts already produced are not retroactively invalidated by this change alone.

- [Risk] `prerequisite_gaps.md` may become stale if `implementation_slices.md` is edited after `8.1.5` runs.
  Mitigation: the quality helper for `prerequisite_gaps.md` validates that every `scheduled_in_slices` entry has a `slice_ref` that resolves in the current `implementation_slices.md`. A stale entry will cause a gate failure and force a re-run of `8.1.5`.

- [Risk] The generator (`feature_prerequisite_gaps.sh`) must parse `user_reachable_surface` output from `technical_requirements.md`; if that field format varies across project types, detection may be unreliable.
  Mitigation: `crp-108` defines a deterministic field shape and the quality helper for `technical_requirements.md` already rejects non-conforming entries. The generator can rely on that contract.

- [Risk] Writers may assign `present_in_repo` without genuine `user_reachable_surface` evidence.
  Mitigation: the quality helper (`check_prerequisite_gaps_quality.sh`) requires a non-empty `evidence` value for every `present_in_repo` entry and validates that the token matches a path or identifier present in `technical_requirements.md`.

## Migration Plan

1. Create new artifacts:
   - `overmind/rules/prerequisite_gaps_rule.md`
   - `overmind/templates/prerequisite_gaps_TEMPLATE.md`
   - `overmind/golden_examples/prerequisite_gaps_GOLDEN_EXAMPLE.md`
   - `overmind/scripts/feature_prerequisite_gaps.sh`
   - `overmind/scripts/helper/check_prerequisite_gaps_quality.sh`
2. Modify existing scripts:
   - `overmind/scripts/feature_implementation_plan.sh` — read `prerequisite_gaps.md` as context input
   - `overmind/scripts/helper/check_implementation_plan_quality.sh` — add `scheduled_in_slices` prerequisite cross-check
   - `overmind/scripts/project_mgmt/project_add_feature_e2e.sh` — insert `"8.1.5"` into `PHASE_IDS` and `PHASE_OPTIONAL` arrays; add step label, script name, and resume-alias handling
   - `overmind/scripts/project_mgmt/init_progress_scanner.sh` — recognize `prerequisite_gaps.md` as the Step `8.1.5` completion artifact
   - `overmind/scripts/project_mgmt/project_setup_first_init_machine.sh` — stage new scripts
   - `overmind/scripts/project_mgmt/project_setup_update_project.sh` — propagate new scripts on update
3. Update docs/templates:
   - `overmind/init_progress_definition_sequence_diagram.md` — add Step `8.1.5` node between `8.1` and `8.2`
   - `overmind/templates/init_progress_definition_TEMPLATE.yaml` — add `step_number: 8.1.5` block between `8.1` and `8.2`
   - `overmind/README.md` — document the new step
4. Add and update tests:
   - `tests/ai_scripts/check_implementation_plan_quality_tests.sh` — add cases for missing `scheduled_in_slices` coverage
   - `tests/ai_scripts/<new>` — full test suite for `check_prerequisite_gaps_quality.sh`
   - `tests/ai_scripts/init_progress_scanner_tests.sh` — add Step `8.1.5` detection cases

Rollback: revert `project_add_feature_e2e.sh` and `init_progress_scanner.sh` to remove `8.1.5`; revert `check_implementation_plan_quality.sh` to remove the cross-check. Existing `prerequisite_gaps.md` artifacts are inert without the gate scripts.

## Open Questions

None. Step position, artifact structure, presence-detection ground truth, gate mechanics, and plan cross-check design are all resolved above.
