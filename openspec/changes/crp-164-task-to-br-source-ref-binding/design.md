## Context

The old task-to-BR run produced `feature_br_summary.md` with both traceability hops in `## 1. Document Meta -> source_refs`: the workspace-relative `user_br_input.md` capture record and the original local story file recorded by that capture. The migrated packaged golden example shows only a Jira identifier, the installed skill has no explicit source-binding rule, and `validateTaskToBr` does not read `source_refs`. The measured migrated artifact consequently retained the original story file but dropped `user_br_input.md`, with no gate failure.

Commit `41cdce3` introduced CRP-162 (`crp-162-session-context-precall-scope`). That change addresses the preceding lifecycle defect: the TypeScript executor pre-called task-to-BR context before the skill could capture `user_br_input.md`. CRP-162 does not mention `source_refs` in its proposal, design, specification, or tasks, and its implementation preserves the skill-owned capture→context→gate loop. CRP-164 therefore remains a separate, compatible restoration applied inside that loop after capture exists.

The current capture schema accepts exactly one original source and always persists a durable capture record. For a local source, `epic_story_source_file` is a workspace-relative file path inside the feature; for Jira, it is `jira:<ticket>`. The current gate already reads `user_br_input.md` to validate captured story content and classifies a missing capture record as recoverable exit `1`; source-reference derivation must preserve that behavior. The packaged task-to-BR `SKILL.md` is the operational rule source installed into both `.codex/skills/` and `.claude/skills/`; the template already defines the `source_refs` field, while the golden example illustrates its expected value.

## Goals / Non-Goals

**Goals:**

- Restore complete source binding in `feature_br_summary.md`: the durable capture record and its underlying local or Jira source.
- Derive one canonical required-reference set in deterministic TypeScript and expose it to both context generation and gate validation.
- Make missing source bindings a recoverable, actionable task-to-BR gate failure.
- Preserve additional valid source references and keep installed Codex and Claude skill payloads aligned.
- Integrate with CRP-162's capture-first sequencing without changing orchestration or CLI shape.

**Non-Goals:**

- Semantic validation that a cited source supports every FR or BR.
- Acceptance-criterion-to-FR coverage mapping or atomic FR enforcement.
- Changes to capture source selection, Jira fetching, BR clarification, EARS review, or downstream artifact schemas.
- New commands, CLI flags, artifact fields, or a second source-of-truth rule file.

## Decisions

### D1: Derive one canonical required-reference set from captured input

A shared deterministic function derives the required references in this order:

1. `displayPath(<feature>/user_br_input.md, workspaceRoot)` — the durable captured-input artifact.
2. The trimmed `user_br_input.md` `epic_story_source_file` value — either the workspace-relative local story path or the exact `jira:<ticket>` locator.

The function removes duplicate values while retaining first-seen order. It does not discover sources from prose or infer paths from the BR summary. Context and validation use the same derivation so their expected values cannot drift.

Alternative considered: let the model reconstruct references from the context's existing `captured_user_input_artifact` and `epic_story_source_file` lines. Rejected because that is the current implicit contract that allowed one reference to disappear. Alternative considered: validate only the `user_br_input.md` basename. Rejected because workspace-relative paths are portable and unambiguous across features.

### D2: Emit the canonical set in context and make the installed skill own the write

`buildTaskToBrContext` emits a dedicated required-source binding containing the canonical references as a semicolon-delimited value. The installed task-to-BR skill requires `feature_br_summary.md` `## 1. Document Meta -> source_refs` to contain every emitted reference. When the field already contains additional valid references, the skill merges the required values rather than replacing the field wholesale. Canonical output places the capture record first and the underlying story source second.

This keeps responsibilities aligned with the migrated architecture: TypeScript resolves runtime facts, the model writes the artifact, `SKILL.md` owns operational behavior, the template defines only the existing field shape, and the golden example demonstrates the quality target.

Alternative considered: have context or the gate rewrite `feature_br_summary.md` directly. Rejected because deterministic helpers validate and report; the skill owns artifact generation and repair.

### D3: Validate source references as exact list members, not substrings

The task-to-BR gate parses `source_refs` only from `feature_br_summary.md` `## 1. Document Meta`. Multiple references use semicolon delimiters; surrounding whitespace is ignored. Each canonical required reference must equal one parsed element. This prevents a shorter path or ticket text from passing because it happens to be a substring of an unrelated reference. Ordering is recommended by the skill and golden example but is not gate-enforced, and extra non-placeholder elements are allowed.

The gate preserves the capture record's existing recoverable lifecycle: when `<feature-path>/user_br_input.md` is missing, it returns exit `1` with a diagnostic naming that file so the operator or skill can rerun task-to-BR capture. Once the file exists, the gate also returns exit `1` when `source_refs` is missing/unfilled, when `epic_story_source_file` is missing/unfilled so the required set cannot be completed, or when a required reference is absent. Diagnostics name the exact missing field or reference. A missing target `feature_br_summary.md` and validator runtime failures remain exit `2`; a missing `missing_br_data.md` remains recoverable exit `1`.

Alternative considered: require `source_refs` to equal exactly the two derived values. Rejected because task-to-BR may legitimately retain additional source evidence and the restoration only requires that captured sources cannot be dropped.

### D4: Update only the packaged skill source and verify installer propagation

The canonical runtime payload is `packages/installer/_data/skills/overmind-task-to-br/`. The change updates its `SKILL.md` and golden example; the existing template field needs no behavioral text. The golden example replaces the current bare `JIRA-AUTH-241` value with the canonical two-hop value `projects/auth-platform/self-service-password-reset/user_br_input.md; jira:JIRA-AUTH-241`. Installer tests verify fresh and update installations copy the new contract into both supported runner directories. Deleted shell-step rule/helper copies are not revived.

### D5: Treat older summaries as repairable, not silently grandfathered

An existing summary lacking the capture-record reference fails the updated task-to-BR gate with exit `1`. Rerunning the task-to-BR skill repairs `source_refs` from the existing capture record without recapturing or changing the original source. This makes historical loss visible and keeps a future whole-chain gate from treating absent traceability as valid legacy state.

## Risks / Trade-offs

- [Existing migrated summaries begin failing task-to-BR validation] → Use recoverable exit `1` with the exact canonical reference to add; no source recapture or semantic regeneration is required.
- [Context and gate could disagree about path spelling] → Centralize derivation and use the existing `displayPath` workspace-relative convention for the capture artifact while preserving the capture-recorded original locator exactly.
- [A source locator could contain a semicolon] → Capture currently produces workspace paths and `jira:<ticket>` values, for which semicolon is not a supported locator character; keep the serialization contract narrow and deterministic.
- [The model may reorder or retain extra references] → Gate set membership rather than presentation order; ordering remains a golden-example convention.
- [Installer copies can become stale after source changes] → Exercise both fresh install and update install against `.codex/skills/overmind-task-to-br` and `.claude/skills/overmind-task-to-br`.
- [The upcoming ledger terminal-consistency change also edits `packages/asdlc-coordinator/src/validate/task-to-br.ts`] → Land CRP-164 first; have the ledger change build on CRP-164's shared parsing utilities. If the changes proceed in parallel, merge both validator checks rather than replacing either validation path.

## Migration Plan

1. Land CRP-164 before the planned ledger terminal-consistency change so that later validator work can reuse its shared parsing utilities.
2. Add the shared reference derivation, emit it from task-to-BR context, and consume it in the task-to-BR validator.
3. Update the packaged skill rule, golden example, concise runtime documentation, and focused coordinator/installer tests.
4. Run the coordinator, installer, repository, and verification test suites.
5. Existing workspaces receive the new skill payload and CLI validator through the normal installer update; rerun task-to-BR for any feature whose gate reports a missing source reference.

Rollback removes the additional context binding, skill rule, golden-example references, and validator checks. No artifact schema migration is required because `source_refs` already exists.

## Open Questions

- None blocking.
