## Context

`user_br_clarification_rule.md` governs the entire step 4.2 dialogue. It instructs the model to write business answers to `feature_br_summary.md` and track ledger state in `missing_br_data.md`. The rule currently says nothing about links, so when a user pastes a URL the model reads it for content but never records the link itself.

`## 16. Linked Artifacts` in `feature_br_summary.md` already holds a LAR-NNN registry populated at step 3 from Jira-sourced artifacts. The schema (id, title, type, locator) and type vocabulary are stable. Appending new entries at step 4.2 is a natural extension of that registry.

## Goals / Non-Goals

**Goals:**
- When the user provides a URL in any clarification reply, add a corresponding LAR-NNN entry to `## 16. Linked Artifacts` in `feature_br_summary.md`.
- Assign the next available sequential id (continuing from any existing LAR entries).
- Derive title and type from context (page title, file extension, URL structure); fall back to `document` type when ambiguous.
- Update the section 16 template hint comment to reflect the new source.

**Non-Goals:**
- Changing how the model fetches or applies link content (existing behavior unchanged).
- Changing the gate helper, scanner, or any other downstream rule.
- Deduplication of links already in section 16 from step 3 (if the same URL appears, add it only once — treat a URL collision as a no-op).

## Decisions

### Add link-preservation as a new subsection in the clarification rule

The rule file is the single authoritative source for step 4.2 model behavior. Adding a dedicated `## User-Provided Link Preservation` section to `user_br_clarification_rule.md` keeps the new behavior co-located with the existing loop rules and avoids needing a separate file.

Alternatives considered:
- **New rule file** — unnecessary indirection for a small addendum.
- **Updating the prompt in `feature_user_br_clarification.sh`** — the rule file is already injected via the prompt; adding it there would be redundant and harder to maintain.

### Reuse the same LAR-NNN scheme

The id, title, type, locator fields and the closed type vocabulary from `task_to_br_rule.md` are reused verbatim. No new schema is introduced; downstream consumers (br_to_ears.md) already handle all LAR entries uniformly.

### Deduplication: URL collision is a no-op

If the user supplies a URL that matches an existing `locator` in section 16, the model skips adding a duplicate entry. This avoids inflated registries when a Jira-linked Confluence page is also pasted directly by the user.

## Risks / Trade-offs

- [Title inference may be imprecise] → The model infers title from page metadata or URL path; an imprecise title is still traceable via the `locator` field.
- [Model may miss a URL embedded in prose] → The rule requires scanning every user reply for HTTP(S) URLs; this is well within standard model capability.
