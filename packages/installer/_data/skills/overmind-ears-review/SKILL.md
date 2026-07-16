---
name: overmind-ears-review
description: Use when reviewing requirements_ears.md against feature_br_summary.md (authoritative) and user_br_input.md (raw drift backstop) and maintaining requirements_ears_review.md.
---

# Overmind EARS Review

Use this skill to run the optional step 5.1 requirements EARS extra review for a feature folder. The review reads two read-only business sources: `feature_br_summary.md` is the authority for clarified business decisions, and `user_br_input.md` is the raw drift-detection backstop. It compares `requirements_ears.md` against the authoritative summary, independently sweeps both the summary and EARS for narrowing relative to the raw input, asks the operator about material business findings one at a time, applies accepted EARS edits, and maintains `requirements_ears_review.md` as the durable findings ledger.

## Required Invocation

Run these commands from the installed project root:

1. Assemble deterministic context:

```bash
node .overmind/overmind.js context ears-review <feature-path>
```

2. Read the emitted context block, read both read-only business sources it names (`feature_br_summary.md` and `user_br_input.md`), and write only:
- `<feature-path>/requirements_ears.md`
- `<feature-path>/requirements_ears_review.md`

3. Validate after every write or repair:

```bash
node .overmind/overmind.js gate ears-review <feature-path>
```

Handle gate exit codes exactly:
- `0`: gate passed; finish when no finding remains `escalated`.
- `1`: recoverable review-ledger issue; read each `missing: ...` line, repair `requirements_ears_review.md` and, only when needed to keep an accepted decision synchronized, `requirements_ears.md`; then rerun the gate.
- `2`: runtime or validation failure; stop, report the blocker, and wait for operator instructions.

The model owns the context/write/gate/repair loop. Do not ask the operator for deterministic paths, required-input checks, allowed-write lists, asset paths, or validation details that the context and gate commands provide.

If review completion is not feasible with the current BR/EARS input or operator decisions, stop finalization, briefly explain the blocker, and end with this exact line:

```text
based on provided reasons, requirements_ears extra review cannot be completed with current BR/EARS input. Please provide instructions what to do, or adjust artifacts and rerun this phase
```

When the gate passes and no finding remains `escalated`, end your final response with this exact last line:

```text
requirements_ears extra review phase is finished. Nothing else to do now; press Ctrl-C so orchestrator can start the next phase
```

## Assets

Asset paths are relative to this loaded skill directory. Do not resolve them through a hardcoded agent install path such as `.codex/skills/...` or `.claude/skills/...`; use the copy exposed by the current supported CLI.

- `assets/requirements_ears_review_TEMPLATE.md`
- `assets/requirements_ears_review_GOLDEN_EXAMPLE.md`

## Inlined Requirements EARS Extra Review Rule

### Purpose

- Review `requirements_ears.md` against the authoritative source `feature_br_summary.md`.
- Independently sweep both `feature_br_summary.md` and `requirements_ears.md` for narrowing relative to the raw `user_br_input.md`, and record every narrowing as a material finding.
- Surface only material business findings that affect scope, actor rules, guard conditions, rejection paths, state constraints, or required coverage.
- Maintain a durable findings ledger in `requirements_ears_review.md`.

### Authoritative Inputs and Outputs

- Read-only authoritative BR summary source: `feature_br_summary.md`, resolved by the context command. This is the authority for clarified business decisions.
- Read-only raw user input backstop source: `user_br_input.md`, resolved by the context command. This is an independent drift detector; it never silently overrides a clarified summary decision.
- Mutable EARS target: `requirements_ears.md`, resolved by the context command.
- Mutable review ledger target: `requirements_ears_review.md`, resolved by the context command.
- Structure contract: `assets/requirements_ears_review_TEMPLATE.md`.
- Style contract: `assets/requirements_ears_review_GOLDEN_EXAMPLE.md`.
- Quality gate command: `node .overmind/overmind.js gate ears-review <feature-path>`.
- Update only `requirements_ears.md` and `requirements_ears_review.md`.
- Never modify `feature_br_summary.md` or `user_br_input.md`.

### Source Precedence

- Treat clarified decisions recorded in `feature_br_summary.md` as authoritative. When the summary records an explicit clarified decision, that decision is the current expected behavior.
- Use `user_br_input.md` only to detect semantic drift: information lost, weakened, or narrowed between the raw request, the BR summary, and EARS.
- Never silently replace a clarified summary decision with raw wording. When the raw input conflicts with an explicit clarified summary decision, keep the summary as the current authority and record the discrepancy as a finding for operator disposition; cite the clarified decision and ask the operator to confirm or retain it.
- When a narrowing is not explained by a clarified decision, recommend restoring the broader raw obligation.

### Review Scope

- Compare the intended business behavior in `feature_br_summary.md` to the current EARS behavior in `requirements_ears.md`.
- Raise findings only when there is a material gap or contradiction, such as:
  - missing guard or rejection behavior,
  - missing actor or permission constraint,
  - missing state-dependent behavior,
  - ambiguous scope that would change implementation behavior,
  - a source business rule that is absent from EARS,
  - an EARS statement that appears to overshoot or contradict the source story.
- Do not raise style-only, wording-only, or implementation-only findings.
- Keep one independent business issue per finding.

### Mandatory Raw-Input Narrowing Sweep

- Separately from the summary-to-EARS comparison, sweep both `feature_br_summary.md` and `requirements_ears.md` against `user_br_input.md`.
- A statement in the summary or EARS is **narrowing** when it is narrower than the corresponding raw obligation, that is, it adds a condition, state, actor, or qualifier that permits behavior the raw source prohibits, or it reduces required coverage.
- Every narrowing relative to the raw input is a mandatory material finding. Surfacing the discrepancy is not optional; the source precedence only controls the recommended resolution, not whether the finding is recorded.
- Worked example: `user_br_input.md` prohibits duplicate accounts for the same user and account type without any status qualifier, while `feature_br_summary.md` or `requirements_ears.md` blocks duplicates only when the existing account is `ACTIVE`. The added `ACTIVE` qualifier permits a duplicate against a non-`ACTIVE` account, which the raw story forbids. This is narrowing and must become a finding that identifies the `ACTIVE` qualifier as an unsupported narrowing.
- Every raw-narrowing finding must cite all three locations: the raw rule in `user_br_input.md` (`source_user_br_input_reference`), the corresponding `feature_br_summary.md` location (`source_br_summary_reference`), and the affected EARS requirement (`related_requirement_targets`).
- When the summary and EARS preserve the full scope of a raw obligation without an added narrowing qualifier, do not create a raw-narrowing finding for that obligation.

### Findings Ledger Rules

- Write or update `requirements_ears_review.md` every time the review advances.
- Record both source artifacts in document metadata: `source_feature_br_summary` and `source_user_br_input`.
- Every finding must record both `source_br_summary_reference` and `source_user_br_input_reference`.
  - For a raw-narrowing finding, set `source_user_br_input_reference` to the concrete raw location that was narrowed.
  - For a finding not motivated by raw-source drift, set `source_user_br_input_reference` to the literal `none`.
- Every finding must have exactly one `state` from:
  - `escalated`
  - `added to ears`
  - `rejected`
  - `postponed`
- Use `escalated` only for findings that still require user direction.
- Use `added to ears` only after `requirements_ears.md` has been updated to reflect the resolved business decision.
- Use `rejected` when the user explicitly declines the recommendation.
- Use `postponed` when the user explicitly defers the decision or moves it out of current scope.
- Set `review_status: complete` only when no findings remain in `state: escalated`.
- If no material findings exist, create `requirements_ears_review.md` with `review_status: complete` and `- no_findings: true`.

### User Interaction Loop

- Ask the user about one finding at a time, highest severity first, then source order.
- For each active finding, show the finding and recommendation explicitly before asking for a decision, using this exact 3-line interaction format:

  `Here is the finding: <concise gap summary for the current finding>`
  `I would recommend: <exact recommended change for this finding>`
  `Should I add recommended changes? Please answer yes/no or provide your answer.`

- When the user answers:
  - `yes`: apply the recommendation to `requirements_ears.md` and set the finding to `added to ears`.
  - `no`: keep `requirements_ears.md` unchanged for that finding and set the finding to `rejected`.
  - custom answer:
    - if it resolves the business decision, apply the resolved behavior to `requirements_ears.md` and set the finding to `added to ears`;
    - if it explicitly defers the decision, set the finding to `postponed`;
    - if it still leaves the issue unresolved, keep the finding as `escalated`, update the recommendation/resolution notes as needed, and ask the next clarifying question for the same finding before moving on.

### Editing Rules

- Treat `feature_br_summary.md` and `user_br_input.md` as read-only.
- Update only `requirements_ears.md` and `requirements_ears_review.md`.
- Keep EARS output business-facing and implementation-agnostic.
- When changing EARS, prefer minimal edits that close the reviewed gap without inventing unrelated scope.
- Preserve already resolved findings in the ledger; do not delete handled items.

### Runtime Path Binding Rules

- Runtime bindings from `node .overmind/overmind.js context ears-review <feature-path>` are authoritative for each invocation.
- Use the emitted workspace root, feature path, authoritative BR summary source, raw user input backstop source, EARS artifact, review ledger artifact, asset paths, allowed-write list, and gate command exactly.
- Do not assume fixed source-repo paths or runner-specific skill install paths.
- Run the gate command after every write or repair.

### Completion Gate

- Before finalizing, run `node .overmind/overmind.js gate ears-review <feature-path>` against the current `requirements_ears_review.md`.
- Gate pass condition:
  - command exits `0`.
- Gate recoverable condition:
  - command exits `1` and returns one or more `missing: quality gate failed: ...` lines.
- Runtime failure condition:
  - command exits `2`.
- On gate exit `1`, repair the ledger according to the gate output and rerun the gate. If a ledger repair reveals that the accepted EARS edit is missing or inconsistent, update `requirements_ears.md` only as needed to keep the decision history true.
- If the gate cannot pass with the current artifacts or operator decisions, stop finalization with the infeasibility line from `Required Invocation`.
