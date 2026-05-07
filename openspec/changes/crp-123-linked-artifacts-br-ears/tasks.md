## 1. BR Summary Template and Golden Example

- [x] 1.1 Add `## 16. Linked Artifacts` section to `overmind/templates/feature_br_summary_TEMPLATE.md` after `## 15. Open Questions`, with `id`, `title`, `type`, and `locator` placeholder fields
- [x] 1.2 Add `## 16. Linked Artifacts` section to `overmind/golden_examples/feature_br_summary_GOLDEN_EXAMPLE.md` with at least two entries covering two distinct artifact types (e.g., `diagram` and `api_spec`)

## 2. BR Enrichment Rule (task_to_br)

- [x] 2.1 Add a linked-artifact extraction rule block to `overmind/rules/task_to_br_rule.md` instructing the model to inspect Jira MCP story content for linked non-text artifacts and populate `## 16. Linked Artifacts` with LAR-NNN entries
- [x] 2.2 Extend the rule to specify that section 16 is always emitted (empty list when no artifacts found) and applies only when source is `jira:<ticket>`
- [x] 2.3 Extend the rule to specify the closed type vocabulary (`data_schema`, `diagram`, `api_spec`, `design_mock`, `document`, `image`, `pdf`, `other`) and the LAR-NNN sequential ID scheme

## 3. EARS Template and Golden Example

- [x] 3.1 Add `#### Linked Artifacts` placeholder block inside the `### Requirement` template block in `overmind/templates/reqirements_ears_TEMPLATE.md`
- [x] 3.2 Add `## Linked Artifacts` registry section at the end of `overmind/templates/reqirements_ears_TEMPLATE.md` (after `## Non-Functional Requirements`) with `id`, `title`, `type`, `locator` placeholder fields
- [x] 3.3 Add a `#### Linked Artifacts` subsection to at least one `### Requirement` block in `overmind/golden_examples/reqirements_ears_GOLDEN_EXAMPLE.md` with one or more LAR IDs
- [x] 3.4 Add a populated `## Linked Artifacts` registry to `overmind/golden_examples/reqirements_ears_GOLDEN_EXAMPLE.md` with at least two entries matching those referenced in the requirement blocks

## 4. EARS Conversion Rule (br_to_ears)

- [x] 4.1 Add a linked artifact propagation rule block to `overmind/rules/br_to_ears.md` instructing the model to copy all entries from BR section 16 into the `## Linked Artifacts` registry at the end of `requirements_ears.md`
- [x] 4.2 Extend the rule to specify that the registry is omitted entirely when BR section 16 is empty
- [x] 4.3 Add a rule instructing the model to add a `#### Linked Artifacts` subsection to each `### Requirement` block listing semantically relevant LAR IDs, and to omit the subsection when no artifacts are relevant to that requirement
- [x] 4.4 Add a rule requiring that every LAR ID referenced in a `#### Linked Artifacts` subsection has a matching entry in the document-level registry

## 5. Tests

- [x] 5.1 Add test cases to `tests/ai_scripts/init_task_to_br_tests.sh` verifying that section 16 is present in `feature_br_summary.md` output (with entries when Jira artifacts exist, empty list when none)
- [x] 5.2 Add test cases to `tests/ai_scripts/init_br_to_ears_tests.sh` verifying that `requirements_ears.md` contains a `## Linked Artifacts` registry when BR section 16 is populated
- [x] 5.3 Add test cases to `tests/ai_scripts/init_br_to_ears_tests.sh` verifying that at least one `### Requirement` block contains a `#### Linked Artifacts` subsection when artifacts are present
- [x] 5.4 Add test cases to `tests/ai_scripts/init_br_to_ears_tests.sh` verifying that the `## Linked Artifacts` registry is absent when BR section 16 is empty
