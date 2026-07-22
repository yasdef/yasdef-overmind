## Why

When a Jira story is fetched via MCP (introduced in CRP-122), it can carry non-text linked artifacts — images, schemas, PDFs, Confluence pages — that are silently dropped today because `feature_br_summary.md` has no place to record them. These artifacts often contain critical design and domain context that must be traceable through the EARS requirements layer for reviewers and implementers.

## What Changes

- `overmind/templates/feature_br_summary_TEMPLATE.md`: new `## 16. Linked Artifacts` section appended after `## 15. Open Questions`; each artifact entry captures `id` (LAR-NNN), `title`, `type`, and `locator`.
- `overmind/rules/task_to_br_rule.md`: new rule block instructing the model to populate `## 16. Linked Artifacts` by inspecting Jira linked items and Confluence page links present in the fetched story; applies only when source is `jira:<ticket>`; section is left empty (not omitted) when no linked artifacts are found.
- `overmind/golden_examples/feature_br_summary_GOLDEN_EXAMPLE.md`: add `## 16. Linked Artifacts` example entries covering at least two artifact types.
- `overmind/rules/br_to_ears.md`: new rule block instructing the EARS conversion to (a) emit a `## Linked Artifacts` registry at the end of `requirements_ears.md` using the same LAR-NNN entries from the BR source, and (b) add `#### Linked Artifacts` subsections inside each `### Requirement` block listing the LAR IDs the model judges most relevant to that requirement.
- `overmind/templates/reqirements_ears_TEMPLATE.md`: add `## Linked Artifacts` registry section at end of template; add `#### Linked Artifacts` placeholder inside the `### Requirement` block template.
- `overmind/golden_examples/reqirements_ears_GOLDEN_EXAMPLE.md`: add at least one `### Requirement` with `#### Linked Artifacts` entries and a populated `## Linked Artifacts` registry.
- Tests: new test cases covering (a) `## 16. Linked Artifacts` presence and structure in `feature_br_summary.md` output, and (b) `#### Linked Artifacts` subsections and end-of-doc registry in `requirements_ears.md` output.

## Capabilities

### New Capabilities
- `br-linked-artifacts-section`: Captures linked artifact metadata (id, title, type, locator) from Jira/Confluence sources into a dedicated `## 16. Linked Artifacts` section in `feature_br_summary.md`.
- `ears-linked-artifact-traceability`: Propagates linked artifacts from the BR summary into `requirements_ears.md` — a per-requirement `#### Linked Artifacts` subsection and a document-level registry — connecting each artifact to the requirements it informs.

### Modified Capabilities

## Impact

- `overmind/templates/feature_br_summary_TEMPLATE.md` — add `## 16. Linked Artifacts` section.
- `overmind/golden_examples/feature_br_summary_GOLDEN_EXAMPLE.md` — add section 16 example.
- `overmind/rules/task_to_br_rule.md` — new linked-artifact extraction rule for Jira MCP source path.
- `overmind/templates/reqirements_ears_TEMPLATE.md` — add `## Linked Artifacts` registry and `#### Linked Artifacts` block in requirement template.
- `overmind/golden_examples/reqirements_ears_GOLDEN_EXAMPLE.md` — add linked artifact examples.
- `overmind/rules/br_to_ears.md` — new rule block for linked artifact propagation and per-requirement association.
- `tests/ai_scripts/init_task_to_br_tests.sh` — new test cases for section 16 population.
- `tests/ai_scripts/init_br_to_ears_tests.sh` — new test cases for EARS linked artifact output.

## References

- Jira: CRP-123
- Depends on: CRP-122 (Jira MCP source path in `feature_task_to_br.sh`)
