## ADDED Requirements

### Requirement: Section 16 present in BR template
`feature_br_summary_TEMPLATE.md` SHALL include a `## 16. Linked Artifacts` section after `## 15. Open Questions`. The section SHALL contain a list where each entry has four fields: `id` (LAR-NNN format), `title` (free text), `type` (one of: `data_schema`, `diagram`, `api_spec`, `design_mock`, `document`, `image`, `pdf`, `other`), and `locator` (URL or path string).

#### Scenario: Template has section 16
- **WHEN** `feature_br_summary_TEMPLATE.md` is read
- **THEN** the file SHALL contain a `## 16. Linked Artifacts` heading followed by a list scaffold with `id`, `title`, `type`, and `locator` placeholder fields

#### Scenario: Template section 16 appears after section 15
- **WHEN** `feature_br_summary_TEMPLATE.md` section order is inspected
- **THEN** `## 16. Linked Artifacts` SHALL appear after `## 15. Open Questions` and SHALL be the final section in the document

### Requirement: Model populates section 16 from Jira linked items
When the BR source is `jira:<ticket>`, the model SHALL inspect the fetched Jira story content for linked non-text artifacts (attachments, linked Confluence pages, schema links, image references) and populate `## 16. Linked Artifacts` with one entry per discovered artifact using the LAR-NNN ID scheme.

#### Scenario: Jira story has linked artifacts
- **WHEN** the source is `jira:<ticket>` AND the fetched story contains linked non-text artifacts
- **THEN** `## 16. Linked Artifacts` SHALL contain one entry per artifact with `id` (LAR-001, LAR-002, …), `title`, `type`, and `locator` populated from the story data

#### Scenario: Jira story has no linked artifacts
- **WHEN** the source is `jira:<ticket>` AND the fetched story contains no linked artifacts
- **THEN** `## 16. Linked Artifacts` SHALL be present with an empty list (not omitted from the document)

#### Scenario: Non-Jira source path
- **WHEN** the source is a local file path (not `jira:<ticket>`)
- **THEN** `## 16. Linked Artifacts` SHALL be present with an empty list

### Requirement: LAR IDs are document-local and sequential
Each artifact entry in `## 16. Linked Artifacts` SHALL be assigned an ID in the format `LAR-NNN` where NNN is a zero-padded three-digit integer starting at `001` and incrementing by one per artifact in document order.

#### Scenario: Multiple artifacts assigned sequential IDs
- **WHEN** a Jira story produces three linked artifacts
- **THEN** the entries SHALL be assigned `LAR-001`, `LAR-002`, `LAR-003` in the order they appear in the story

#### Scenario: Re-run with unchanged input preserves IDs
- **WHEN** the BR enrichment step is run again with the same Jira ticket and the linked artifacts are unchanged
- **THEN** each artifact SHALL retain the same LAR-NNN ID as in the previous run

### Requirement: Artifact type uses closed vocabulary
The `type` field of each entry in `## 16. Linked Artifacts` SHALL be one of: `data_schema`, `diagram`, `api_spec`, `design_mock`, `document`, `image`, `pdf`, `other`. The model SHALL select the closest matching type; if no type fits, it SHALL use `other`.

#### Scenario: Known artifact type assigned correctly
- **WHEN** a linked artifact is identified as an API specification document
- **THEN** its `type` field SHALL be `api_spec`

#### Scenario: Unknown artifact type falls back to other
- **WHEN** a linked artifact does not match any defined type
- **THEN** its `type` field SHALL be `other`

### Requirement: Golden example includes section 16
`feature_br_summary_GOLDEN_EXAMPLE.md` SHALL include a `## 16. Linked Artifacts` section with at least two entries covering at least two distinct artifact types.

#### Scenario: Golden example section 16 has two entries
- **WHEN** `feature_br_summary_GOLDEN_EXAMPLE.md` is read
- **THEN** `## 16. Linked Artifacts` SHALL contain at least two entries with distinct `type` values and valid `LAR-NNN` IDs
