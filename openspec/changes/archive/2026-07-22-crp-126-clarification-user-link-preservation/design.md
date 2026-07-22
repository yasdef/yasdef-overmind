## Context

`user_br_clarification_rule.md` governs the entire step 4.2 dialogue. It instructs the model to write business answers to `feature_br_summary.md` and track ledger state in `missing_br_data.md`. The rule currently says nothing about links, so when a user pastes a URL the model may read it for content but never records the link itself.

`## 16. Linked Artifacts` in `feature_br_summary.md` already holds a LAR-NNN registry populated at step 3 from Jira-sourced artifacts. The schema (id, title, type, locator) and type vocabulary are stable. Appending new entries at step 4.2 is a natural extension of that registry.

## Goals / Non-Goals

**Goals:**
- Treat a relevant user-provided URL as business input for the current clarification question in the same way as a direct text answer.
- When the user provides a URL that actually answers or materially clarifies the current clarification question, add a corresponding LAR-NNN entry to `## 16. Linked Artifacts` in `feature_br_summary.md`.
- Assign the next available sequential id (continuing from any existing LAR entries).
- Derive title and type from context (page title, file extension, URL structure); fall back to `document` type when ambiguous.
- If a relevant link contains more information than the current question needs, record only the question-relevant business content while still preserving the link.
- Update the section 16 template hint comment to reflect the new source.

**Non-Goals:**
- Changing how the model fetches or applies link content (existing behavior unchanged).
- Changing the gate helper, scanner, or any other downstream rule.
- Preserving irrelevant links that do not answer the current clarification question.

## Decisions

### Split link behavior between general clarification flow and preservation mechanics

The rule file is the single authoritative source for step 4.2 model behavior. The decision criteria for whether a link counts as usable business input belong in the general clarification flow and hard constraints, because they affect how the model interprets any user answer. The dedicated `## User-Provided Link Preservation` section should then focus only on how qualifying links are recorded in the BR artifact.

Alternatives considered:
- **New rule file** — unnecessary indirection for a small addendum.
- **Updating the prompt in `feature_user_br_clarification.sh`** — the rule file is already injected via the prompt; adding it there would be redundant and harder to maintain.

### Preserve only links that answer the current clarification need

A user-provided link is preserved only when the model actually uses that link as business input for the current unresolved question. This keeps section 16 aligned with source material that materially contributed to the BR and avoids filling the registry with unrelated references.

### Reuse the same LAR-NNN scheme

The id, title, type, locator fields and the closed type vocabulary from `task_to_br_rule.md` are reused verbatim. No new schema is introduced; downstream consumers (br_to_ears.md) already handle all LAR entries uniformly.

### Deduplication: URL collision is a no-op

If the user supplies a URL that matches an existing `locator` in section 16, the model skips adding a duplicate entry. This avoids inflated registries when a Jira-linked Confluence page is also pasted directly by the user.

## Risks / Trade-offs

- [Title inference may be imprecise] → The model infers title from page metadata or URL path; an imprecise title is still traceable via the `locator` field.
- [Model may miss a URL embedded in prose] → The rule requires scanning every user reply for HTTP(S) URLs; this is well within standard model capability.
- [Relevant vs irrelevant link judgment may be imperfect] → The rule grounds the decision in the currently discussed unresolved business question and explicitly forbids copying unrelated content.
