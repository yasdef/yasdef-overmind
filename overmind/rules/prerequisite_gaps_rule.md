# Prerequisite Gaps Rule

Read this file fully before generating output.

## Purpose
- Derive a deterministic list of externally-invocable prerequisites per EARS requirement and record whether each is already present in the repository or scheduled in `implementation_slices.md`.
- Gate Step 8.3 on zero `unmet` entries: every missing prerequisite must be promoted into `implementation_slices.md` before the plan can start.
- Keep required missing operator-facing surfaces explicitly identifiable for downstream preservation checks, and keep them distinguishable from transport-only/internal execution gaps.
- Produce deterministic output for `<TARGET_PREREQUISITE_GAPS_ARTIFACT>`.

## Ownership Boundaries
Owns:
- per-EARS-requirement trace of externally-invocable prerequisites
- status classification per prerequisite: `present_in_repo`, `scheduled_in_slices`, or `unmet`
- evidence linking each prerequisite to a `user_reachable_surface` entry or a slice identifier
- stable `surface_identity` naming for required missing operator-facing surfaces (`user_reachable_surface`)
- explicit `surface_kind` classification used by downstream slice/plan preservation checks

Must not own:
- internal service-to-service dependency tracking (belongs to CRP-098 `gap/TECH_REQ-*` and `comp/*` tokens)
- implementation step ordering or slice decomposition
- transport-layer coverage claims (transport alone never satisfies a user-reachable prerequisite)

## Authoritative Inputs and Outputs
- Read final feature behavior from `<REQUIREMENTS_EARS_ARTIFACT>`.
- Read `user_reachable_surface` subfields from `<TECHNICAL_REQUIREMENTS_ARTIFACT>` as the ground truth for `present_in_repo` decisions.
- Read slice identifiers from `<IMPLEMENTATION_SLICES_ARTIFACT>` as the ground truth for `scheduled_in_slices` decisions.
- Update only `<TARGET_PREREQUISITE_GAPS_ARTIFACT>`.
- Do not modify input artifacts.

## Class Taxonomy for Externally-Invocable Prerequisites
Only prerequisites in these per-class categories belong in `prerequisite_gaps.md`. Internal service-to-service dependencies are explicitly excluded.

- **frontend**: navigable routes, pages, screens (e.g., `/checkout/summary`, `/admin/login`)
- **backend**: operator-reachable HTTP endpoints, CLI commands, scheduled jobs, admin tools (e.g., `POST /api/v1/orders`, `reconciliation-job`)
- **mobile**: screens, deep links (e.g., `checkout://risk-screen`, `CheckoutConfirmationScreen`)

## Field Definitions

### `status`
Allowed values: `present_in_repo`, `scheduled_in_slices`, `unmet`
- `present_in_repo`: a matching `user_reachable_surface` entry exists in `technical_requirements.md`. Transport-layer presence alone does not satisfy this; the user-reachable surface must be confirmed.
- `scheduled_in_slices`: no matching `user_reachable_surface` exists, but the prerequisite is covered by a slice in `implementation_slices.md`. The `slice_ref` field must be populated.
- `unmet`: the prerequisite is neither present in the repo nor scheduled in slices. Any `unmet` entry must be resolved by adding a slice to `implementation_slices.md` before Step 8.3.

### `surface_kind`
Allowed values: `required_missing_user_reachable_surface`, `present_user_reachable_surface`, `transport_or_internal_execution_gap`
- `required_missing_user_reachable_surface`: use when the prerequisite is required by EARS behavior and the operator-facing surface is currently missing (`unmet` or `scheduled_in_slices`).
- `present_user_reachable_surface`: use when the operator-facing prerequisite is already present in repository state (`present_in_repo`).
- `transport_or_internal_execution_gap`: never use for an emitted prerequisite entry; transport/internal concerns must stay outside prerequisite entries and be represented as `prerequisites: none` for that requirement block.

### `surface_identity`
- Stable operator-facing surface identity (for example `Operator login page`, `Admin workspace shell`, `Admin entry route`, `Operator account lookup page`, `Operator sync CLI command`, `Reconciliation admin tool`, `Account export endpoint`).
- Required when `surface_kind: required_missing_user_reachable_surface`.
- Must remain unchanged when the entry transitions from `status: unmet` to `status: scheduled_in_slices`.
- Must be `none` when `surface_kind` is not `required_missing_user_reachable_surface`.

### `evidence`
- For `present_in_repo`: the exact `user_reachable_surface` token (e.g., `POST /api/v1/orders`, `/checkout/summary`) that confirms the prerequisite. Must not be left blank.
- For `scheduled_in_slices`: the slice description or a brief rationale describing why this slice covers the prerequisite. Must not be left blank.
- For `unmet`: leave blank or omit; no evidence exists by definition.

### `slice_ref`
- Required when `status: scheduled_in_slices`. Must be blank or omitted when `status` is not `scheduled_in_slices`.
- The value SHALL match the slice identifier used in `implementation_slices.md` exactly.
- The value SHALL be referenceable in plan steps as the evidence token `slice/<slice_ref>`, matching the regex `slice/[A-Za-z0-9][A-Za-z0-9_.-]*`.
- Use the exact slice identifier (e.g., `slice-1`, `slice-2`) as it appears in `implementation_slices.md`.

## Derivation Rules
- For each EARS requirement, read its WHEN/THEN/IF conditions and extract any externally-invocable entry points referenced (URL paths, CLI commands, job identifiers, routes, screens).
- Only emit prerequisites that match the class taxonomy above.
- Do not emit internal service calls, domain model interactions, or repository/persistence operations.
- For each extracted prerequisite:
  1. Check `user_reachable_surface` entries in `technical_requirements.md` for a match. If found, status is `present_in_repo`.
  2. If not present in repo, check `implementation_slices.md` for a slice that covers this entry point. If found, status is `scheduled_in_slices`.
  3. If neither, status is `unmet`.
- Set `surface_kind` and `surface_identity` deterministically:
  - required missing operator-facing prerequisite: `surface_kind: required_missing_user_reachable_surface`, stable non-empty `surface_identity`
  - already present operator-facing prerequisite: `surface_kind: present_user_reachable_surface`, `surface_identity: none`
  - never emit transport/internal-only concerns as prerequisite entries

## Gate Condition
- `prerequisite_gaps.md` is valid only when zero `unmet` entries remain.
- Any `unmet` entry must be resolved by adding a new or updated slice to `implementation_slices.md` and re-running this step with `scheduled_in_slices` status and a populated `slice_ref`.
- Deleting an `unmet` entry without adding a corresponding slice is not a valid resolution.

## Output Format Baseline
- Use `overmind/templates/prerequisite_gaps_TEMPLATE.md` as structure contract.
- Use `overmind/golden_examples/prerequisite_gaps_GOLDEN_EXAMPLE.md` as style contract.
- Preserve heading order and key names.
- Include one `### Requirement:` block per EARS `REQ-*` / `NFR-*` in scope.
- Include one `#### Prerequisite:` block per externally-invocable entry point derived from that requirement.
- If a requirement has no externally-invocable prerequisites, include the block with `prerequisites: none`.

## Completion Gate
- Before finalizing, run the prompt-provided quality gate command.
- If the gate fails, revise the output and rerun the gate command.
- If gate compliance is not feasible with current inputs and constraints, stop and use the prompt-provided failure line exactly.
- If the gate passes, end with the prompt-provided success line exactly.
