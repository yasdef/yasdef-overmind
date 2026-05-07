## ADDED Requirements

### Requirement: Preserve user-provided links in linked artifacts registry
During the step 4.2 BR clarification dialogue, whenever the user's reply contains one or more HTTP(S) URLs, the model SHALL append a new LAR-NNN entry for each URL to `## 16. Linked Artifacts` in `feature_br_summary.md`, using the same id/title/type/locator schema used by the Jira-source extraction at step 3.

#### Scenario: User reply contains a single URL
- **WHEN** the user provides exactly one URL in a clarification reply
- **THEN** the model adds one new LAR-NNN entry to `## 16. Linked Artifacts` with the next sequential id, a derived title, an inferred type, and the URL as locator

#### Scenario: User reply contains multiple URLs
- **WHEN** the user provides two or more URLs in a single clarification reply
- **THEN** the model adds one LAR-NNN entry per URL in sequential order

#### Scenario: User reply contains no URL
- **WHEN** the user reply contains no HTTP(S) URL
- **THEN** `## 16. Linked Artifacts` is not modified by this rule

### Requirement: LAR id assignment continues existing sequence
The new LAR-NNN ids appended at step 4.2 SHALL continue the gap-free sequential numbering of any entries already present in `## 16. Linked Artifacts` from earlier steps.

#### Scenario: Section 16 already has entries from step 3
- **WHEN** `## 16. Linked Artifacts` already contains LAR-001 and LAR-002 from step 3
- **THEN** the first user-provided link at step 4.2 is assigned LAR-003

#### Scenario: Section 16 is empty
- **WHEN** `## 16. Linked Artifacts` has no entries
- **THEN** the first user-provided link is assigned LAR-001

### Requirement: Duplicate URL is a no-op
If the URL supplied by the user already exists as a `locator` value in any existing LAR entry in `## 16. Linked Artifacts`, the model SHALL skip adding a duplicate entry.

#### Scenario: URL already recorded from step 3
- **WHEN** the user pastes a URL that matches the `locator` of an existing LAR entry
- **THEN** no new LAR entry is added and the existing entry is left unchanged

### Requirement: Type vocabulary is consistent with step 3
The `type` field of user-sourced LAR entries SHALL use the same closed vocabulary defined in `task_to_br_rule.md`: `data_schema`, `diagram`, `api_spec`, `design_mock`, `document`, `image`, `pdf`, `other`. When type cannot be determined, `document` is used as the default.

#### Scenario: URL points to a Confluence page
- **WHEN** the URL is a Confluence page URL
- **THEN** the entry type is set to `document`

#### Scenario: URL points to an image file
- **WHEN** the URL ends with an image extension (e.g., `.png`, `.jpg`, `.svg`)
- **THEN** the entry type is set to `image`

#### Scenario: URL type is ambiguous
- **WHEN** the URL does not clearly indicate an artifact type
- **THEN** the entry type defaults to `document`
