---
name: overmind-ears-review
description: Use when reviewing requirements_ears.md for raw capture fidelity against user_br_input.md and translation fidelity against the authoritative feature_br_summary.md, and maintaining requirements_ears_review.md.
---

# Overmind EARS Review

Use this skill to run the optional step 5.1 requirements EARS extra review for a feature folder. The review reads three read-only business sources: `user_br_input.md` is the raw captured story, `feature_br_summary.md` is the authority for clarified business decisions, and `missing_br_data.md` is the clarification ledger that evidences explicit operator decisions. It runs two ordered semantic comparisons — raw capture fidelity first, then clarified-BR translation fidelity — asks the operator about material business findings one at a time, applies accepted EARS edits, and maintains `requirements_ears_review.md` as the durable findings ledger.

## Required Invocation

Run these commands from the installed project root:

1. Assemble deterministic context:

```bash
node .overmind/overmind.js context ears-review <feature-path>
```

2. Read the emitted context block, including its inlined raw captured story and inlined clarification evidence, read the read-only business sources it names (`user_br_input.md`, `feature_br_summary.md`, and `missing_br_data.md`), and write only:
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

- Run two ordered semantic comparisons in this session:
  1. **Raw capture fidelity:** compare the raw `user_br_input.md` story with both `feature_br_summary.md` and `requirements_ears.md`.
  2. **Clarified-BR translation fidelity:** compare the authoritative `feature_br_summary.md` with `requirements_ears.md`.
- Surface only material business findings that affect scope, actor rules, guard conditions, rejection paths, state constraints, or required coverage.
- Maintain a durable findings ledger in `requirements_ears_review.md`.

### Authoritative Inputs and Outputs

- Read-only raw capture source: `user_br_input.md`, resolved by the context command and inlined as the captured story. This is the independent capture-fidelity source; it never silently overrides a clarified summary decision.
- Read-only authoritative BR summary source: `feature_br_summary.md`, resolved by the context command. This is the authority for clarified business decisions and the source for translation fidelity.
- Read-only clarification ledger: `missing_br_data.md`, resolved by the context command and inlined as clarification evidence. This is the evidence that a raw/summary difference was an explicit operator decision.
- Mutable EARS target: `requirements_ears.md`, resolved by the context command.
- Mutable review ledger target: `requirements_ears_review.md`, resolved by the context command.
- Structure contract: `assets/requirements_ears_review_TEMPLATE.md`.
- Style contract: `assets/requirements_ears_review_GOLDEN_EXAMPLE.md`.
- Quality gate command: `node .overmind/overmind.js gate ears-review <feature-path>`.
- Update only `requirements_ears.md` and `requirements_ears_review.md`.
- Never modify `user_br_input.md`, `feature_br_summary.md`, or `missing_br_data.md`.

### Source Precedence

- A difference between raw input and the summary counts as an **explicit clarified decision** only when both parts of the evidence pair are present: an answered `rised=true` item in `missing_br_data.md` whose `source=` locator names an affected `feature_br_summary.md` field, and the resolved answer recorded in that mapped summary field.
- An `Answer:` fragment, a `confirmed_assumptions` entry, or any other summary text without the paired answered ledger item is not clarification evidence.
- An explicit clarified decision is the current expected behavior. Never silently replace it with raw wording. Still record the raw discrepancy as a finding, cite both locations, and ask the operator to confirm or retain the clarified decision.
- Any other material raw/summary difference is raw-source drift, not an intentional decision. Treat it as a finding rather than assuming it was deliberate.
- When drift is not explained by an explicit clarified decision, recommend restoring the raw obligation.

### Pass 1 - Raw Capture Fidelity

- Compare the raw captured story in `user_br_input.md` with both `feature_br_summary.md` and `requirements_ears.md` before any summary-to-EARS comparison.
- Raise a material finding for every drift in this taxonomy:
  - **lost obligation:** a required raw behavior, coverage item, or rejection path is absent downstream;
  - **removed guard:** a raw precondition, permission, or eligibility condition no longer constrains the behavior;
  - **added guard:** a condition the raw story does not impose now blocks required behavior;
  - **unsupported broadening:** downstream behavior applies to more cases, actors, or states than the raw story allows;
  - **unsupported narrowing:** an added condition, state, actor, or qualifier permits behavior the raw story prohibits, or reduces required coverage;
  - **actor or state change:** the acting role, target role, or governing state differs from the raw story;
  - **contradiction:** downstream behavior conflicts with an explicit raw statement;
  - **invented behavior:** a material downstream outcome has no raw basis and no explicit clarified-decision evidence.
- Worked example - removed guard causing unsupported broadening: `user_br_input.md` limits account resolution to a registered user who holds an `OFFCHAIN_POINTS` account, while `feature_br_summary.md` and `requirements_ears.md` resolve the account without that precondition. The removed account precondition broadens the behavior beyond the raw story and must become a finding.
- Worked example - unsupported narrowing: `user_br_input.md` prohibits duplicate accounts for the same user and account type without any status qualifier, while `feature_br_summary.md` or `requirements_ears.md` blocks duplicates only when the existing account is `ACTIVE`. The added `ACTIVE` qualifier permits a duplicate against a non-`ACTIVE` account, which the raw story forbids. This must become a finding that identifies the `ACTIVE` qualifier as an unsupported narrowing.
- When the summary and EARS preserve a raw obligation at full scope, do not create a raw-drift finding for that obligation.
- Do not report a finding based only on mandated EARS grammar. An EARS criterion that names the single system in the template's system-name slot while describing behavior surfaced in another interface is conformant, not an actor mismatch.

### Pass 2 - Clarified-BR Translation Fidelity

- Compare the intended business behavior in `feature_br_summary.md` to the current EARS behavior in `requirements_ears.md`.
- Raise findings only when there is a material gap or contradiction, such as:
  - missing guard or rejection behavior,
  - missing actor or permission constraint,
  - missing state-dependent behavior,
  - ambiguous scope that would change implementation behavior,
  - a summary business rule that is absent from EARS,
  - an EARS statement that overshoots or contradicts the summary.
- Do not raise style-only, wording-only, or implementation-only findings.
- Keep one independent business issue per finding. When the same drift is visible from raw to summary and from summary to EARS, record one finding that carries the raw, summary, and EARS evidence together instead of duplicating it across passes.

### Findings Ledger Rules

- Write or update `requirements_ears_review.md` every time the review advances.
- Record both source artifacts in document metadata: `source_feature_br_summary` and `source_user_br_input`.
- Every finding must record both `source_br_summary_reference` and `source_user_br_input_reference`.
  - Set `source_br_summary_reference` to a concrete `feature_br_summary.md` locator when corresponding BR content exists, and to the literal `none` when the raw obligation is entirely absent from the BR.
  - For a raw-drift finding from Pass 1, set `source_user_br_input_reference` to the concrete raw location that drifted and name the affected EARS requirement in `related_requirement_targets`.
  - Set `source_user_br_input_reference` to the literal `none` only for a finding that arises solely from translating an explicit clarified decision into EARS, after Pass 1 confirmed the finding is unrelated to raw drift. `none` is not a shortcut for skipping the raw comparison.
- Every finding must have exactly one `state` from:
  - `escalated`
  - `added to ears`
  - `rejected`
  - `postponed`
- Use `escalated` only for findings that still require user direction.
- Use `added to ears` when `requirements_ears.md` reflects the accepted business decision, either because the review applied an edit or because EARS already matched the confirmed decision and no edit was required. Record which case applies in `resolution_notes`.
- Use `rejected` when the user explicitly declines the recommendation.
- Use `postponed` when the user explicitly defers the decision or moves it out of current scope.
- Set `review_status: complete` only when no findings remain in `state: escalated`.
- Record `- no_findings: true` only after both Pass 1 and Pass 2 completed without a material discrepancy. Mutual agreement between `feature_br_summary.md` and `requirements_ears.md` is not sufficient when both drifted from the raw story.
- When both passes are clean, create `requirements_ears_review.md` with `review_status: complete` and `- no_findings: true`.

### User Interaction Loop

- Ask the user about one finding at a time, highest severity first, then source order.
- For each active finding, show the finding and recommendation explicitly before asking for a decision, using this exact 3-line interaction format:

  `Here is the finding: <concise gap summary for the current finding>`
  `I would recommend: <exact recommended change for this finding>`
  `Should I add recommended changes? Please answer yes/no or provide your answer.`

- When the user answers:
  - `yes`: apply the recommendation to `requirements_ears.md` and set the finding to `added to ears`. When the accepted recommendation is to confirm or retain a clarified decision that `requirements_ears.md` already states, leave EARS unchanged, set the finding to `added to ears`, and record in `resolution_notes` that no edit was required.
  - `no`: keep `requirements_ears.md` unchanged for that finding and set the finding to `rejected`.
  - custom answer:
    - if it resolves the business decision, apply the resolved behavior to `requirements_ears.md` and set the finding to `added to ears`; if `requirements_ears.md` already states the resolved behavior, leave it unchanged, set the finding to `added to ears`, and record in `resolution_notes` that no edit was required;
    - if it explicitly defers the decision, set the finding to `postponed`;
    - if it still leaves the issue unresolved, keep the finding as `escalated`, update the recommendation/resolution notes as needed, and ask the next clarifying question for the same finding before moving on.

### Editing Rules

- Treat `user_br_input.md`, `feature_br_summary.md`, and `missing_br_data.md` as read-only.
- Update only `requirements_ears.md` and `requirements_ears_review.md`.
- Keep EARS output business-facing and implementation-agnostic.
- When changing EARS, prefer minimal edits that close the reviewed gap without inventing unrelated scope.
- Preserve already resolved findings in the ledger; do not delete handled items.

### Runtime Path Binding Rules

- Runtime bindings from `node .overmind/overmind.js context ears-review <feature-path>` are authoritative for each invocation.
- Use the emitted workspace root, feature path, raw user input source, authoritative BR summary source, clarification ledger source, EARS artifact, review ledger artifact, asset paths, allowed-write list, and gate command exactly.
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
