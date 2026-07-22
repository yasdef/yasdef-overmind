## Why

During the step 4.2 BR clarification dialogue, users frequently paste Confluence or other URLs in their replies. The model fetches and uses the content, but the link itself is silently discarded — it never lands in `## 16. Linked Artifacts`. This means downstream steps (EARS, technical requirements) lose traceability to the source material the user explicitly pointed to.

## What Changes

- Extend `user_br_clarification_rule.md` so the general clarification flow treats a user-provided link as the same kind of business input as a direct text answer, but only when the link actually answers or materially clarifies the current business question.
- Preserve only those user-provided URLs that are actually used as business input in the clarification round by appending a new LAR-NNN entry to `## 16. Linked Artifacts` in `feature_br_summary.md`, using the same id/title/type/locator schema already defined for Jira-sourced artifacts.
- When a relevant link contains more information than needed, record only the question-relevant business content in the BR while still preserving the link for traceability.
- Update the hint comment in `feature_br_summary_TEMPLATE.md` section 16 to reflect that the section is also populated from user-provided links at step 4.2.
- All other link-handling behavior (fetching, reading, applying content) is unchanged.

## Capabilities

### New Capabilities

- `clarification-user-link-preservation`: Model preserves URLs supplied by the user during BR clarification in `## 16. Linked Artifacts` of `feature_br_summary.md`.

### Modified Capabilities

## Impact

- `overmind/rules/user_br_clarification_rule.md`: new link-preservation rule section added.
- `overmind/templates/feature_br_summary_TEMPLATE.md`: updated hint comment on `## 16. Linked Artifacts`.
- No changes to scripts, gate helpers, or any other rules file.
