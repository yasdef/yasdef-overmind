# Implementation Plan Semantic Review Rule

Read this file fully before producing output.

## Purpose
- Run an optional semantic review pass after `implementation_plan.md` exists.
- Evaluate step-level cohesion and split quality in `implementation_plan.md`.
- Summarize findings to the user and ask which finding numbers should be applied.
- Update both `implementation_plan.md` and `implementation_plan_semantic_review.md` from the user decision.

## Inputs
- Mutable plan target: `<IMPLEMENTATION_PLAN_ARTIFACT>`.
- Read-only project definition source: `<PROJECT_INIT_PROGRESS_DEFINITION_ARTIFACT>`.
- Read-only requirements source: `<REQUIREMENTS_EARS_ARTIFACT>`.
- Read-only technical source: `<TECHNICAL_REQUIREMENTS_ARTIFACT>`.
- Read-only prerequisite trace source when present: `<PREREQUISITE_GAPS_ARTIFACT>`.
- Read-only repo surface maps when present for active repo classes:
  - `<PROJECT_SURFACE_STRUCT_RESP_MAP_BACKEND_ARTIFACT>`
  - `<PROJECT_SURFACE_STRUCT_RESP_MAP_FRONTEND_ARTIFACT>`
  - `<PROJECT_SURFACE_STRUCT_RESP_MAP_MOBILE_ARTIFACT>`
- Mutable review target: `<IMPLEMENTATION_PLAN_SEMANTIC_REVIEW_ARTIFACT>`.
- Structure contract: `.templates/implementation_plan_semantic_review_TEMPLATE.md`.
- Style contract: `.golden_examples/implementation_plan_semantic_review_GOLDEN_EXAMPLE.md`.

## Review Scope
- Evaluate implementation-plan steps at semantic slice boundaries.
- Focus only on findings that affect execution quality, such as:
  - one step mixing unrelated behavior that should be split,
  - one step combining separate technical gaps without a shared implementation slice,
  - semantically weak dependency or ordering choices,
  - requirement grouping that obscures distinct delivery slices,
  - newly delivered user-reachable surfaces with unclear inbound operator reachability.
  - Type A repo scaffold readiness that is unclear for a class represented in the plan.
- For each newly delivered user-reachable surface, apply this four-step access-path heuristic:
  1. identify the delivered surface in the implementation plan,
  2. inspect applicable surface maps for existing inbound affordances,
  3. inspect sibling plan steps for newly added inbound affordances,
  4. if neither exists, raise an operator reachability question via finding type `delivered_surface_consumption_unclear`.
- Keep one independent issue per finding.
- Exclude style-only, wording-only, or formatting-only comments.
- Treat `delivered_surface_consumption_unclear` as a product-fit finding:
  - missing inbound path can be a defect,
  - isolation can be intentional.
- Do not invent new navigation requirements unless justified by `requirements_ears.md` or explicit operator confirmation recorded in the review artifact.
- For `delivered_surface_consumption_unclear`, link the finding to at least one `REQ-*` or `NFR-*` id in `related_requirements` so the judgment remains anchored to required behavior.
- For Type A only, use `repo_scaffold_readiness_unclear` when a planned repo class has implementation steps but project metadata does not show a ready repo path and the plan does not explicitly account for scaffold creation, verification, or parallel ownership.

## Allowed Finding Types
Every finding must use one `finding_type` from:
- `step_scope_overlap`
- `technical_gap_mix`
- `dependency_ordering`
- `requirement_grouping`
- `delivered_surface_consumption_unclear`
- `repo_scaffold_readiness_unclear`

## Finding State Rules
Use one `state` per finding:
- `added` when the finding is first recorded before user decision.
- `applied` when the user selected this finding and its recommendation was applied to `implementation_plan.md`.
- `rejected` when the user explicitly declined this finding.
- `postponed` when the user explicitly deferred this finding.

## User Interaction Rules
- After the initial semantic pass, show a concise numbered summary of all findings.
- If there are findings, ask exactly which finding numbers to apply to `implementation_plan.md`.
- Interpret user response and update both artifacts accordingly.
- Do not finish while findings remain without a terminal state (`applied`, `rejected`, `postponed`).

## Editing Rules
- Update only `<IMPLEMENTATION_PLAN_ARTIFACT>` and `<IMPLEMENTATION_PLAN_SEMANTIC_REVIEW_ARTIFACT>`.
- Never modify `<REQUIREMENTS_EARS_ARTIFACT>` or `<TECHNICAL_REQUIREMENTS_ARTIFACT>`.
- Never add ad-hoc sections or free-form blocks to `<IMPLEMENTATION_PLAN_ARTIFACT>`.
- Apply selected findings to `<IMPLEMENTATION_PLAN_ARTIFACT>` only by:
  - adding checklist bullets to an existing `### Step ...` block,
  - splitting an existing step into valid `### Step ...` blocks,
  - adding a new valid `### Step ...` block,
  - adjusting `#### Depends on:`, `#### Evidence:`, or `#### Preserved Surface:` lines as needed.
- Keep implementation-plan edits minimal and directly tied to selected findings.
- Preserve full traceability of decisions in the review artifact.

## Minimal Plan Patch Guidance
- Prefer adding checklist bullets to an existing step when the selected finding belongs to the same repo owner, same semantic delivery slice, same dependency position, and same requirement/evidence scope.
- Prefer splitting an existing step when the current step mixes independent semantic slices, separate repo-owned work, or work that should have different dependency timing.
- Prefer adding a new valid step only when the selected finding represents independently executable work, prerequisite work, repo-scaffold/readiness work, or work that cannot be cleanly attached to an existing step without weakening the step boundary.
- Keep the patch proportional to the selected findings; do not create extra steps solely for tidier wording.

## Type A Scaffold Readiness Guidance
- Resolve selected `repo_scaffold_readiness_unclear` findings inside the normal implementation-plan structure.
- Prefer adding concrete readiness bullets to an existing repo-owned step when that step already covers setup, scaffold, or repo-readiness work for the affected class.
- Add a new repo-owned scaffold/readiness step only when scaffold/readiness is a separate prerequisite or cannot be cleanly represented in an existing step.

## Completion
- If no material findings exist, set `review_status: complete` and `- no_findings: true`.
- If findings exist, ensure each finding has terminal state and resolution notes.
- `delivered_surface_consumption_unclear` and `repo_scaffold_readiness_unclear` MUST NOT be terminal (`applied`, `rejected`, `postponed`) with empty `resolution_notes`.
- If `<IMPLEMENTATION_PLAN_ARTIFACT>` is changed, run the prompt-provided implementation-plan quality gate before finalizing.
- End with the prompt-provided success line when complete, or the failure line if completion is not feasible.
