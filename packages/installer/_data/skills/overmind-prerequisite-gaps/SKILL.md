---
name: overmind-prerequisite-gaps
description: Produce and validate the shared feature prerequisite gap trace for Overmind step 8.2.
---

# Prerequisite Gaps

Derive a deterministic list of externally invocable prerequisites per EARS requirement and record whether each is present, scheduled in current slices, or promised by a sibling plan. Step 8.3 is gated on zero `unmet` entries.

## Required Invocation

From the ASDLC workspace root, first run:

```bash
node .overmind/overmind.js context prerequisite-gaps <feature-path>
```

Treat the emitted paths and read-only manifest as authoritative. Read every bound input. Draft the target using the bound template and golden example. Write only `prerequisite_gaps.md`; do not modify any read-only input.

After every write or repair, run:

```bash
node .overmind/overmind.js gate prerequisite-gaps <feature-path>
```

Handle the gate result exactly:

- Exit `0`: finish and end with `Prerequisite gap trace phase is finished. Nothing else to do now; press Ctrl-C so orchestrator can start the next phase`
- Exit `1`: read every reported issue, repair only `prerequisite_gaps.md`, and rerun the gate.
- Exit `2`: stop and report the runtime blocker to the operator.

If gate compliance is infeasible with the current inputs, stop and end with `prerequisite gap trace gate cannot pass with current requirements/technical-requirements/slices inputs. Please provide instructions what to do, or adjust inputs and rerun this phase`

## Assets

- Structure contract: `assets/prerequisite_gaps_TEMPLATE.md`
- Style reference: `assets/prerequisite_gaps_GOLDEN_EXAMPLE.md`

## Ownership Boundaries

Own the per-EARS prerequisite trace, status, evidence, stable missing-surface identity, and surface-kind classification. Internal service dependencies belong to technical requirement gap/component tokens. Slice decomposition and implementation ordering remain owned by their respective artifacts.

## Authoritative Inputs

- Read final behavior from `requirements_ears.md`.
- Use `user_reachable_surface` values in `technical_requirements.md` as ground truth for `present_in_repo`.
- Use slice identifiers in `implementation_slices.md` as ground truth for `scheduled_in_slices`.
- Use context-bound sibling `implementation_plan.md` files as ground truth for `scheduled_in_feature <feature-folder>/<step-id>`.

## Class Taxonomy

Emit only externally invocable surfaces:

- frontend: navigable routes, pages, and screens
- backend: operator-reachable HTTP endpoints, CLI commands, scheduled jobs, and admin tools
- mobile: screens and deep links

Keep transport-only and internal execution gaps out of prerequisite entries.

## Field Rules

Declare each unique externally invocable surface exactly once under `## 2. Prerequisite Catalog`. The `#### Prerequisite:` heading text is its catalog name and must be unique. Keep the catalog entry's five fields together; when multiple requirements need the same surface, reuse its exact catalog name instead of restating the entry.

`status` is one of `present_in_repo`, `scheduled_in_slices`, `scheduled_in_feature <feature-folder>/<step-id>`, or `unmet`. Present entries require exact surface evidence. Current-slice entries require evidence and the exact slice identifier. Sibling-feature entries require evidence citing the plan step and `slice_ref: none`. Resolve every `unmet` by updating the authoritative slice input outside this session and rerunning the step; deleting an unmet entry is not resolution.

`surface_kind` is `present_user_reachable_surface` for present surfaces or `required_missing_user_reachable_surface` for missing/scheduled operator-facing surfaces. Never emit `transport_or_internal_execution_gap` as an entry.

`surface_identity` is a stable operator-facing name such as a route, page, screen, shell, workspace, command, job, endpoint, tool, or deep link. It is required for `required_missing_user_reachable_surface`, remains stable when an unmet entry becomes scheduled, and is `none` for present surfaces.

`evidence` is the exact `user_reachable_surface` token for present entries, slice coverage rationale for current-slice entries, or sibling plan and step evidence for sibling-feature entries. `slice_ref` is required only for `scheduled_in_slices` and matches `[A-Za-z0-9][A-Za-z0-9_.-]*`.

## Derivation And Output

For every in-scope `REQ-*` and `NFR-*`, extract externally invocable entry points from WHEN/THEN/IF behavior. Check technical-requirement surfaces first, then current slices, then sibling plans; otherwise classify as unmet. Do not infer repository presence from transport-layer evidence alone.

Preserve the template heading order and keys. Under `## 3. Requirement Coverage`, emit one `### Requirement:` block with `requirement_summary` and `prerequisites:` for every in-scope requirement. Set `prerequisites:` to `none` when the requirement has no externally invocable prerequisite; otherwise use a `; `-separated list of exact catalog names. Every reference must resolve to a catalog heading, every catalog entry must be referenced by at least one requirement, and requirement blocks must not restate catalog fields.
