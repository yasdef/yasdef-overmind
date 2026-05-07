## ADDED Requirements

### Requirement: EARS template includes linked artifacts registry section
`reqirements_ears_TEMPLATE.md` SHALL include a `## Linked Artifacts` section at the end of the document (after `## Non-Functional Requirements`) and a `#### Linked Artifacts` placeholder block inside the `### Requirement` block template. Each registry entry SHALL have the same four fields as BR section 16: `id`, `title`, `type`, `locator`.

#### Scenario: EARS template has Linked Artifacts registry
- **WHEN** `reqirements_ears_TEMPLATE.md` is read
- **THEN** it SHALL contain a `## Linked Artifacts` section appearing after `## Non-Functional Requirements`

#### Scenario: EARS template Requirement block has Linked Artifacts subsection
- **WHEN** the `### Requirement` block scaffold in `reqirements_ears_TEMPLATE.md` is read
- **THEN** it SHALL contain a `#### Linked Artifacts` placeholder subsection

### Requirement: EARS conversion copies BR section 16 into document registry
When converting BR to EARS, the model SHALL copy all entries from `## 16. Linked Artifacts` in `feature_br_summary.md` into a `## Linked Artifacts` registry at the end of `requirements_ears.md`, preserving `id`, `title`, `type`, and `locator` values unchanged.

#### Scenario: BR has linked artifacts — registry present in EARS
- **WHEN** `feature_br_summary.md` contains one or more entries in `## 16. Linked Artifacts`
- **THEN** `requirements_ears.md` SHALL contain a `## Linked Artifacts` section with the same entries

#### Scenario: BR section 16 is empty — registry omitted from EARS
- **WHEN** `feature_br_summary.md` has an empty `## 16. Linked Artifacts` section
- **THEN** `requirements_ears.md` SHALL NOT contain a `## Linked Artifacts` section

### Requirement: Each Requirement block lists relevant artifact IDs
For each `### Requirement` block in `requirements_ears.md`, the model SHALL add a `#### Linked Artifacts` subsection listing the LAR IDs of artifacts from the registry that are semantically relevant to that requirement.

#### Scenario: Requirement has relevant artifacts
- **WHEN** a `### Requirement` block covers behavior related to one or more linked artifacts
- **THEN** the block SHALL contain a `#### Linked Artifacts` subsection listing the relevant LAR IDs (e.g., `LAR-001, LAR-003`)

#### Scenario: Requirement has no relevant artifacts
- **WHEN** a `### Requirement` block covers behavior unrelated to any linked artifact
- **THEN** the block SHALL NOT contain a `#### Linked Artifacts` subsection

#### Scenario: No linked artifacts in BR — no subsections in EARS
- **WHEN** BR section 16 is empty
- **THEN** no `### Requirement` block in `requirements_ears.md` SHALL contain a `#### Linked Artifacts` subsection

### Requirement: LAR IDs in per-requirement subsections reference registry entries
Every LAR ID listed in a `#### Linked Artifacts` subsection SHALL correspond to an entry in the `## Linked Artifacts` registry of the same `requirements_ears.md` document.

#### Scenario: Referenced LAR ID exists in registry
- **WHEN** `#### Linked Artifacts: LAR-002` appears in a Requirement block
- **THEN** `LAR-002` SHALL appear as an entry in the `## Linked Artifacts` registry of the same document

#### Scenario: No dangling LAR references
- **WHEN** all `#### Linked Artifacts` subsections in `requirements_ears.md` are collected
- **THEN** each LAR ID listed SHALL have a matching entry in the `## Linked Artifacts` registry

### Requirement: EARS br_to_ears rule instructs linked artifact propagation
`br_to_ears.md` SHALL include a rule block that instructs the model to (a) build the `## Linked Artifacts` registry from BR section 16, and (b) associate each registry entry to one or more `### Requirement` blocks using semantic judgment.

#### Scenario: Rule file contains linked artifact section
- **WHEN** `overmind/rules/br_to_ears.md` is read
- **THEN** it SHALL contain a section describing linked artifact propagation behavior for both the registry and the per-requirement subsection

### Requirement: EARS golden example demonstrates linked artifact traceability
`reqirements_ears_GOLDEN_EXAMPLE.md` SHALL include at least one `### Requirement` block with a `#### Linked Artifacts` subsection and a populated `## Linked Artifacts` registry.

#### Scenario: Golden example has Linked Artifacts registry
- **WHEN** `reqirements_ears_GOLDEN_EXAMPLE.md` is read
- **THEN** it SHALL contain a `## Linked Artifacts` section with at least two entries

#### Scenario: Golden example Requirement block references artifacts
- **WHEN** the `### Requirement` blocks in `reqirements_ears_GOLDEN_EXAMPLE.md` are inspected
- **THEN** at least one block SHALL contain a `#### Linked Artifacts` subsection with one or more LAR IDs
