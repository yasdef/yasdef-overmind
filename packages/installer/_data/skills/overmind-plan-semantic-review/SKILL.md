---
name: overmind-plan-semantic-review
description: Review implementation-plan semantic cohesion, record findings, collect operator decisions, and apply selected minimal plan patches.
---

# Implementation Plan Semantic Review

Run the optional Step 8.4 semantic review after `implementation_plan.md` exists. Evaluate execution-quality boundaries, record numbered findings, ask the operator which findings to apply, and update the review ledger and plan consistently.

## Required Invocation

1. Run `node .overmind/overmind.js context plan-semantic-review <feature-path>` from the ASDLC workspace root and use its emitted paths as authoritative.
2. Read every emitted read-only input and both assets fully.
3. Write only:
   - `<feature-path>/implementation_plan.md`
   - `<feature-path>/implementation_plan_semantic_review.md`
4. Create or update the review ledger with numbered findings in `added` state, or `no_findings: true` when none exist.
5. Run `node .overmind/overmind.js gate plan-semantic-review <feature-path>` after every write or repair of the review ledger, including the initial findings ledger written before pausing for operator input.
6. If findings exist and no operator decision has been received for the current ledger version, summarize them concisely and ask exactly once for this decision round: `Which finding numbers should I apply to implementation_plan.md? (examples: 1,3 | all | none | postpone 2 | reject 4)`. Wait for the answer without repeating the question. Ask again only when the answer is incomplete or ambiguous, or gate-driven repair materially changes the findings.
7. Apply the operator decision to both artifacts. Run `node .overmind/overmind.js gate implementation-plan <feature-path>` after every write or repair of the plan. Run the review gate again after every resulting review-ledger write or repair.
8. Handle each gate exit code exactly:
   - `0`: continue or finish only when the workflow is complete.
   - `1`: read the gate output, repair only the corresponding mutable artifact, and rerun that gate.
   - `2`: stop, report that validation cannot complete, and wait for operator instructions.
9. On completion, end with this exact line:
   `Implementation plan semantic review phase is finished. Nothing else to do now; press Ctrl-C so orchestrator can start the next phase`
10. If completion is infeasible with current inputs or direction, end with this exact line:
   `implementation plan semantic review cannot be completed with current plan/requirements/technical inputs. Please provide instructions what to do, or adjust inputs and rerun this phase`

## Assets

- Structure: `assets/implementation_plan_semantic_review_TEMPLATE.md`
- Quality example: `assets/implementation_plan_semantic_review_GOLDEN_EXAMPLE.md`

## Purpose

- Evaluate step-level cohesion and split quality in `implementation_plan.md`.
- Summarize findings and ask which finding numbers should be applied.
- Update both mutable artifacts from the operator decision.

## Inputs

- Treat every `read_only_input` emitted by context as immutable.
- Treat both `mutable_target` paths emitted by context as the only write surface.
- Use the context-emitted active repo classes, asset bindings, review gate command, and implementation-plan gate command.

## Review Scope

- Evaluate implementation-plan steps at semantic slice boundaries.
- Raise only execution-quality findings: unrelated behavior mixed in one step; separate technical gaps without a shared slice; weak dependencies or ordering; grouping that obscures delivery slices; unclear inbound reachability for newly delivered user-reachable surfaces; in-flight sibling overlap; unclear deferred-class repo scaffold readiness.
- Treat every surface-map row tagged `(in-flight <feature-folder>)` as an in-flight sibling promise overlap that must be raised. Use `step_scope_overlap`, cite the tagged row in `related_evidence`, and name the sibling feature folder in the summary or rationale. It is not a hard block and may be applied, rejected, or postponed with resolution notes.
- For each newly delivered user-reachable surface: identify it in the plan; inspect applicable surface maps for inbound affordances; inspect sibling plan steps for newly added inbound affordances; if neither exists, raise `delivered_surface_consumption_unclear`.
- Keep one independent issue per finding. Exclude style-only, wording-only, and formatting-only comments.
- Treat unclear surface consumption as a product-fit question: a missing inbound path can be a defect, while isolation can be intentional.
- Do not invent navigation requirements unless justified by `requirements_ears.md` or explicit operator confirmation recorded in the ledger.
- Link every `delivered_surface_consumption_unclear` finding to at least one `REQ-*` or `NFR-*` in `related_requirements`.
- Use `repo_scaffold_readiness_unclear` when a planned repo class has steps but project metadata lacks a ready repo path and the plan does not account for scaffold creation, verification, or parallel ownership.

## Allowed Finding Types

- `step_scope_overlap`
- `technical_gap_mix`
- `dependency_ordering`
- `requirement_grouping`
- `delivered_surface_consumption_unclear`
- `repo_scaffold_readiness_unclear`

## Finding State Rules

- `added`: first recorded before operator decision.
- `applied`: selected and applied to the plan.
- `rejected`: explicitly declined.
- `postponed`: explicitly deferred.

## User Interaction Rules

- Perform the numbered summary and operator question only through Required Invocation step 6; this section does not trigger a second ask action.
- Interpret the answer and update both artifacts.
- Do not finish while any finding remains non-terminal.

## Editing Rules

- Never add ad-hoc sections or free-form blocks to `implementation_plan.md`.
- Apply selected findings only by adding checklist bullets to an existing step, splitting a step into valid steps, adding a new valid step, or adjusting `#### Depends on:`, `#### Evidence:`, or `#### Preserved Surface:`.
- Keep edits minimal and directly tied to selected findings. Preserve full decision traceability in the ledger.

## Minimal Plan Patch Guidance

- Add bullets when the finding shares repo owner, delivery slice, dependency position, and requirement/evidence scope with an existing step.
- Split a step when it mixes independent slices, separate repo-owned work, or different dependency timing.
- Add a new step only for independently executable work, prerequisite work, scaffold/readiness work, or work that cannot be attached cleanly.
- Keep the patch proportional; do not create steps solely for tidier wording.

## Deferred-Class Scaffold Readiness Guidance

- Resolve selected scaffold-readiness findings within the normal plan structure.
- Prefer concrete readiness bullets in an existing repo-owned setup/readiness step.
- Add a repo-owned scaffold/readiness step only when it is a separate prerequisite or cannot be represented cleanly in an existing step.

## Completion

- With no material findings, set `review_status: complete` and `no_findings: true`.
- With findings, ensure every finding has a terminal state and resolution notes.
- Terminal `delivered_surface_consumption_unclear` and `repo_scaffold_readiness_unclear` findings require non-empty `resolution_notes`.
- Finish only after the applicable gate has passed after every artifact write or repair.
