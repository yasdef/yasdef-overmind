# Requirements EARS Extra Review Rule

## Purpose

- Review `requirements_ears.md` against the validated source `feature_br_summary.md`.
- Surface only material business findings that affect scope, actor rules, guard
  conditions, rejection paths, state constraints, or required coverage.
- Maintain a durable findings ledger in `requirements_ears_review.md`.

## Inputs

- Read-only validated BR summary source: `<BR_SUMMARY_SOURCE_ARTIFACT>`.
- Mutable EARS target: `<REQUIREMENTS_EARS_ARTIFACT>`.
- Mutable review ledger target: `<REVIEW_TARGET_ARTIFACT>`.
- Structure contract: `.templates/requirements_ears_review_TEMPLATE.md`.
- Style contract: `.golden_examples/requirements_ears_review_GOLDEN_EXAMPLE.md`.
- Quality gate command: runtime-provided helper command for
  `<REVIEW_TARGET_ARTIFACT>`.

## Review Scope

- Compare the intended business behavior in `<BR_SUMMARY_SOURCE_ARTIFACT>` to the
  current EARS behavior in `<REQUIREMENTS_EARS_ARTIFACT>`.
- Raise findings only when there is a material gap or contradiction, such as:
  - missing guard or rejection behavior,
  - missing actor or permission constraint,
  - missing state-dependent behavior,
  - ambiguous scope that would change implementation behavior,
  - a source business rule that is absent from EARS,
  - an EARS statement that appears to overshoot or contradict the source story.
- Do not raise style-only, wording-only, or implementation-only findings.
- Keep one independent business issue per finding.

## Findings Ledger Rules

- Write or update `<REVIEW_TARGET_ARTIFACT>` every time the review advances.
- Every finding must have exactly one `state` from:
  - `escalated`
  - `added to ears`
  - `rejected`
  - `postponed`
- Use `escalated` only for findings that still require user direction.
- Use `added to ears` only after `<REQUIREMENTS_EARS_ARTIFACT>` has been updated
  to reflect the resolved business decision.
- Use `rejected` when the user explicitly declines the recommendation.
- Use `postponed` when the user explicitly defers the decision or moves it out of
  current scope.
- Set `review_status: complete` only when no findings remain in `state: escalated`.
- If no material findings exist, create `<REVIEW_TARGET_ARTIFACT>` with
  `review_status: complete` and `- no_findings: true`.

## User Interaction Loop

- Ask the user about one finding at a time, highest severity first, then source
  order.
- For each active finding, show the finding and recommendation explicitly before
  asking for a decision, using this exact 3-line interaction format:

  `Here is the finding: <concise gap summary for the current finding>`
  `I would recommend: <exact recommended change for this finding>`
  `Should I add recommended changes? Please answer yes/no or provide your answer.`

- When the user answers:
  - `yes`: apply the recommendation to `<REQUIREMENTS_EARS_ARTIFACT>` and set the
    finding to `added to ears`.
  - `no`: keep `<REQUIREMENTS_EARS_ARTIFACT>` unchanged for that finding and set
    the finding to `rejected`.
  - custom answer:
    - if it resolves the business decision, apply the resolved behavior to
      `<REQUIREMENTS_EARS_ARTIFACT>` and set the finding to `added to ears`;
    - if it explicitly defers the decision, set the finding to `postponed`;
    - if it still leaves the issue unresolved, keep the finding as `escalated`,
      update the recommendation/resolution notes as needed, and ask the next
      clarifying question for the same finding before moving on.

## Editing Rules

- Treat `<BR_SUMMARY_SOURCE_ARTIFACT>` as read-only.
- Update only `<REQUIREMENTS_EARS_ARTIFACT>` and `<REVIEW_TARGET_ARTIFACT>`.
- Keep EARS output business-facing and implementation-agnostic.
- When changing EARS, prefer minimal edits that close the reviewed gap without
  inventing unrelated scope.
- Preserve already resolved findings in the ledger; do not delete handled items.

## Completion

- Before finishing, ensure `<REVIEW_TARGET_ARTIFACT>` can pass the provided
  quality gate command.
- If review completion is not feasible with current artifacts or user direction,
  stop and end with this exact last line:

  `based on provided reasons, requirements_ears extra review cannot be completed with current BR/EARS input. Please provide instructions what to do, or adjust artifacts and rerun this phase`

- If the loop is complete and the quality gate is feasible and satisfied, end
  your final response with this exact last line:

  `requirements_ears extra review phase is finished. Nothing else to do now; press Ctrl-C so orchestrator can start the next phase`
