# Process Gaps in the Overmind Planning Pipeline

This note records two structural gaps observed in the Overmind feature-planning pipeline (Steps `7` → `8` → `8.1` → `8.2`) and the proposals that close them.

## Observed failure mode

While reviewing the live feature `admin_workspace_alt-1776081025` (project `umss_spg-1775826843000`), the generated `implementation_plan.md` produced **Step 1.5 "Frontend protected workspace route and lookup entry"** as the first frontend step. That step:

- assumed an `/admin/login` route existed for invalid-session redirects, and
- assumed an admin operator had a way to obtain a JWT.

Neither was true in the frontend repo. What existed was only a transport-layer module (`src/api/auth.ts` exposing `loginAdmin / getAdminToken / clearAdminSession`) — API client helpers with **no** route, page, or sign-in UI. Yet the surface map (Step `7`), the technical requirements (Step `8`), and the implementation plan (Step `8.2`) all reported "the admin login flow exists" as ground truth, and the existing `crp-097` / `crp-098` quality gates passed because every requirement and every gap token resolved.

The plan was structurally sound by the existing rules and still wrong by construction.

## Root cause

Two compounding gaps:

### Gap A — "exists" is conflated

Step `7` (`project_surface_struct_resp_map_*.md`) and Step `8` (`technical_requirements.md` `current_state`) record a single free-text line per concern that silently mixes two very different forms of "exists":

- **Transport layer**: API clients, hooks, services, repositories, helpers — internal callable code.
- **User-reachable surface**: routes, pages, screens, CLI commands, scheduled jobs — entry points an operator can invoke without writing code.

When the surface-map writer notes `loginAdmin / getAdminToken / clearAdminSession` as evidence and the tech-req writer paraphrases it as "frontend login flow," everything downstream treats that as user-reachable presence. It isn't.

### Gap B — no prerequisite-journey check

Even with `crp-098`'s unresolved-work coverage gate, the implementation-plan helper only verifies that every `gap/TECH_REQ-<n>` and `comp/<component-slug>` token from `technical_requirements.md` is touched by a plan step. It does **not** walk the user-visible journey behind each EARS requirement and verify that every entry point on that journey is either in the repo or scheduled in the plan.

For `FR-1.5-003` ("redirect to `/admin/login` when JWT is invalid") the journey trace would surface:

1. Operator must reach `/admin/login` — does the route exist user-reachable? **No** → unmet prerequisite.
2. Operator must obtain a valid JWT — does a sign-in form exist user-reachable? **No** → unmet prerequisite.
3. JWT must land in `sessionStorage` — `loginAdmin` does this — OK.

The current pipeline never performs this trace, so the unmet prerequisites stay invisible.

## Way to fix

Two openspec proposals close the gap structurally. They compose: `crp-108` produces a trustworthy ground truth; `crp-109` enforces the prerequisite chain on top of it.

### crp-108 — surface-map and tech-req transport vs user-reachable split

Path: `openspec/changes/crp-108-surface-map-and-tech-req-transport-vs-user-reachable-split/`

- Splits every Section 3 layer block and Section 4 surface block in the surface-map templates into two explicit subfields: `transport_layer` and `user_reachable_surface`.
- Splits each requirement's `current_state` in `technical_requirements.md` the same way.
- Defines what counts as user-reachable per project class (frontend, backend, mobile).
- Quality helpers fail when the split is missing, blank, or collapsed back into a single conflated line.
- Why this is the right place to fix it: the conflation enters the pipeline at Step `7`. Splitting downstream alone would let the boundary regress.

### crp-109 — prerequisite gap trace at Step `8.1.5`

Path: `openspec/changes/crp-109-prerequisite-gap-trace-step-8-1-5/`

- Adds a new required Step `8.1.5` between slices and plan: "Prerequisite Gap Trace."
- Produces `prerequisite_gaps.md` listing, per EARS requirement, the operator-visible journey and each prerequisite marked `present_in_repo` (proven via `user_reachable_surface` from `crp-108`), `scheduled_in_slices`, or `unmet`.
- Blocks Step `8.2` from starting while any `unmet` prerequisite remains. Unmet prerequisites must be promoted into `implementation_slices.md`.
- Extends `check_implementation_plan_quality.sh` to fail when prerequisites marked `scheduled_in_slices` are not covered by at least one plan step.
- Why this is the right place to fix it: the prerequisite chain is a property of the plan as a whole, not of any single requirement, so the gate must run after slices exist and before ordering begins.

## How the two proposals work together

```
Step 7  (surface map)             ──► crp-108 forces transport vs user-reachable split
Step 8  (technical requirements)  ──► crp-108 forces same split on current_state
Step 8.1 (slices)                 ──► unchanged
Step 8.1.5 (NEW)                  ──► crp-109 produces prerequisite_gaps.md, blocks on unmet
Step 8.2 (plan)                   ──► crp-109 helper fails plan if scheduled prerequisites uncovered
```

`crp-108` alone would surface the missing user-reachable surface in the artifacts but would not stop a plan from skipping it. `crp-109` alone would have nothing trustworthy to detect presence against. Together they convert "the planner forgot the sign-in page" from a silent failure into a hard gate.

## Out of scope

- No change to EARS conversion (Step `5`), contract delta (Step `6`), or worker assignment.
- No change to `crp-097` step-level FR traceability or `crp-098` unresolved-work coverage semantics.
- No new bullet-level traceability — both proposals stay at step / requirement scope.
