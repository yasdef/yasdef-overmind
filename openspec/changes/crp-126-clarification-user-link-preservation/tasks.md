## 1. Extend the clarification rule with link-preservation behavior

- [ ] 1.1 Add a `## User-Provided Link Preservation` section to `overmind/rules/user_br_clarification_rule.md` that instructs the model to scan every user reply for HTTP(S) URLs and append a LAR-NNN entry to `## 16. Linked Artifacts` in `feature_br_summary.md` for each new URL found, continuing the existing sequential id scheme, skipping duplicates, and using the closed type vocabulary (defaulting to `document` when type is ambiguous).

## 2. Update the BR summary template hint

- [ ] 2.1 Update the hint comment on `## 16. Linked Artifacts` in `overmind/templates/feature_br_summary_TEMPLATE.md` to reflect that the section is populated from both Jira-sourced artifacts (step 3) and user-provided links during BR clarification (step 4.2).
