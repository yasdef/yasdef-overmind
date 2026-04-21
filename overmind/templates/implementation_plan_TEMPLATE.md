# Implementation Plan

Use one shared implementation plan for the whole feature.
Ground the plan in `technical_requirements.md`: current repo state, explicit gaps, impacted components, and dependency notes.
Each step must belong to exactly one repo class so backend, frontend, and mobile workers can pick their own work while still seeing one ordered delivery picture.

## Format Rules
- Use one `### Step <major>.<minor> <title> [REQ-<id>] [NFR-<id>] ...` heading per implementable slice.
- Immediately under each step add `#### Repo: <backend|frontend|mobile>`.
- Add `#### Depends on: <none|step ids>` to show cross-repo ordering when relevant.
- Add `#### Evidence: <gap/TECH_REQ-1 | gap/TECH_REQ-NFR-1, comp/component-slug, ...>` and keep evidence links at step scope (not checklist bullets).
- Add `#### Preserved Surface: <none|operator-facing surface identity>` so required missing operator-facing delivery remains explicit through planning, whether the surface is a page/route/shell, CLI/admin tool, job, or endpoint.
- Add `#### Assigned: <worker-uuid>` only after a worker is explicitly assigned.
- Keep bullets outcome-oriented, implementation-shaped, and sized for one worker.
- If one functional slice touches multiple repos, split it into multiple steps and connect them with `#### Depends on:`.

### Step 1.1 [UNFILLED] [REQ-1] [NFR-1]
#### Repo: [backend|frontend|mobile]
#### Depends on: [none|1.0]
#### Evidence: [gap/TECH_REQ-1 | gap/TECH_REQ-NFR-1, comp/component-slug]
#### Preserved Surface: [none|UNFILLED]
#### Assigned: [OPTIONAL]
- [ ] Plan and discuss the step
- [ ] [UNFILLED concrete component slice]
- [ ] [UNFILLED concrete component slice]
- [ ] [UNFILLED tests/docs/verification slice]
- [ ] Review step implementation
