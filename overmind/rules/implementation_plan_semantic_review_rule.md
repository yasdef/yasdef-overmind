# Implementation Plan Semantic Review Rule

Read this file fully before producing output.

## Purpose
- Run an optional semantic review pass after `implementation_plan.md` exists.
- Evaluate step-level cohesion and split quality in `implementation_plan.md`.
- Summarize findings to the user and ask which finding numbers should be applied.
- Update both `implementation_plan.md` and `implementation_plan_semantic_review.md` from the user decision.

## Inputs
- Mutable plan target: `<IMPLEMENTATION_PLAN_ARTIFACT>`.
- Read-only requirements source: `<REQUIREMENTS_EARS_ARTIFACT>`.
- Read-only technical source: `<TECHNICAL_REQUIREMENTS_ARTIFACT>`.
- Mutable review target: `<IMPLEMENTATION_PLAN_SEMANTIC_REVIEW_ARTIFACT>`.
- Structure contract: `.templates/implementation_plan_semantic_review_TEMPLATE.md`.
- Style contract: `.golden_examples/implementation_plan_semantic_review_GOLDEN_EXAMPLE.md`.

## Review Scope
- Evaluate implementation-plan steps at semantic slice boundaries.
- Focus only on findings that affect execution quality, such as:
  - one step mixing unrelated behavior that should be split,
  - one step combining separate technical gaps without a shared implementation slice,
  - semantically weak dependency or ordering choices,
  - requirement grouping that obscures distinct delivery slices.
- Keep one independent issue per finding.
- Exclude style-only, wording-only, or formatting-only comments.

## Allowed Finding Types
Every finding must use one `finding_type` from:
- `step_scope_overlap`
- `technical_gap_mix`
- `dependency_ordering`
- `requirement_grouping`

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
- Keep implementation-plan edits minimal and directly tied to selected findings.
- Preserve full traceability of decisions in the review artifact.

## Completion
- If no material findings exist, set `review_status: complete` and `- no_findings: true`.
- If findings exist, ensure each finding has terminal state and resolution notes.
- End with the prompt-provided success line when complete, or the failure line if completion is not feasible.
