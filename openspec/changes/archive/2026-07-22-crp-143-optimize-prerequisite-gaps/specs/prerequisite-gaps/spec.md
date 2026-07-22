## ADDED Requirements

### Requirement: Prerequisite artifact declares each surface once in a catalog with requirement references

`prerequisite_gaps.md` SHALL be structured as a `## 1. Document Meta` section, a `## 2. Prerequisite Catalog` section, and a `## 3. Requirement Coverage` section. The catalog SHALL contain one `#### Prerequisite:` block per unique externally-invocable surface, each carrying `status`, `surface_kind`, `surface_identity`, `evidence`, and `slice_ref`, and each surface SHALL be declared exactly once regardless of how many requirements need it. Each `### Requirement:` block in Requirement Coverage SHALL carry a `requirement_summary` and a `prerequisites:` line that is either `none` or a `; `-separated list of catalog prerequisite names, and SHALL NOT restate catalog fields.

#### Scenario: Surface shared by multiple requirements is declared once
- **WHEN** two requirements both need the same prerequisite surface
- **THEN** the catalog contains exactly one `#### Prerequisite:` block for that surface
- **AND** each of the two `### Requirement:` blocks references it by name in its `prerequisites:` line

#### Scenario: Requirement with no prerequisites
- **WHEN** a requirement has no externally-invocable prerequisite
- **THEN** its `### Requirement:` block records `prerequisites: none` and carries no field restatement

#### Scenario: Requirement references resolve to catalog entries
- **WHEN** a requirement lists prerequisite names in its `prerequisites:` line
- **THEN** every listed name matches a `#### Prerequisite:` heading in the catalog

### Requirement: Gate validates catalog integrity

The gate SHALL fail with exit `1` when a prerequisite name appears as more than one `#### Prerequisite:` heading in the catalog, and SHALL name the duplicated entry in the failure message. The gate SHALL also fail with exit `1` and name the prerequisite when a `#### Prerequisite:` heading appears outside `## 2. Prerequisite Catalog`, so every prerequisite consumed by downstream gates is covered by catalog validation.

#### Scenario: Duplicate catalog entry fails
- **WHEN** the catalog declares two `#### Prerequisite:` blocks with the same heading name
- **THEN** the gate exits `1` and names the duplicated prerequisite

#### Scenario: Each surface declared once passes catalog integrity
- **WHEN** every catalog prerequisite heading is unique
- **THEN** the catalog-integrity check contributes no failure

#### Scenario: Prerequisite block outside the catalog fails
- **WHEN** a `#### Prerequisite:` heading appears under Requirement Coverage or any section other than `## 2. Prerequisite Catalog`
- **THEN** the gate exits `1` and names the misplaced prerequisite

### Requirement: Gate resolves requirement references against the catalog

The gate SHALL fail with exit `1` when a `### Requirement:` `prerequisites:` entry names a prerequisite that is absent from the catalog (dangling reference), and SHALL fail with exit `1` when a catalog entry is referenced by no requirement (orphan entry). Each failure message SHALL name the offending reference or catalog entry.

#### Scenario: Dangling reference fails
- **WHEN** a requirement's `prerequisites:` line names a prerequisite that is not declared in the catalog
- **THEN** the gate exits `1` and names the unresolved reference

#### Scenario: Orphan catalog entry fails
- **WHEN** a catalog `#### Prerequisite:` block is referenced by no `### Requirement:` block
- **THEN** the gate exits `1` and names the orphan catalog entry

#### Scenario: Fully cross-referenced artifact passes reference resolution
- **WHEN** every requirement reference resolves to a catalog entry and every catalog entry is referenced at least once
- **THEN** the reference-resolution check contributes no failure

### Requirement: Gate per-block checks and EARS-literal cross-check operate over the catalog

The gate SHALL apply the existing per-block validation (`surface_kind`, `status`, `surface_identity`, `evidence`, `slice_ref`, and `slice_ref` format) to each catalog `#### Prerequisite:` block, and SHALL run the EARS-literal cross-check over catalog `evidence`/`slice_ref` values together with `user_reachable_surface` values from `technical_requirements.md`. A deduplicated catalog that retains all evidence SHALL satisfy the cross-check exactly as the pre-optimization artifact did. The exit-code contract (`0` pass, `1` content failure, `2` runtime failure) SHALL be unchanged.

#### Scenario: Unmet catalog entry still fails
- **WHEN** a catalog block has `status: unmet`
- **THEN** the gate exits `1` naming the unmet prerequisite

#### Scenario: Literal covered by a single catalog entry passes
- **WHEN** an EARS literal appears in exactly one catalog entry's evidence (declared once, not restated)
- **THEN** the cross-check treats the literal as covered

#### Scenario: Uncovered literal still fails
- **WHEN** an EARS literal appears in no catalog entry and no `user_reachable_surface`
- **THEN** the gate exits `1` naming the uncovered literal

### Requirement: Migrated downstream gates consume the catalog format unchanged

The step 8.1 implementation-slices gate and the step 8.3 implementation-plan gate SHALL extract required-missing `surface_identity` values and scheduled `slice_ref` values from the catalog `#### Prerequisite:` blocks without any change to their parsing logic, and the extracted sets SHALL equal those produced from the pre-optimization nested artifact carrying the same surfaces.

#### Scenario: Implementation-plan gate reads scheduled slice_refs from the catalog
- **WHEN** the implementation-plan gate reads a new-format `prerequisite_gaps.md` whose catalog has `scheduled_in_slices` entries
- **THEN** it extracts each scheduled `slice_ref` and requires a matching `slice/<ref>` evidence token in the plan

#### Scenario: Implementation-slices gate reads required-missing surfaces from the catalog
- **WHEN** the implementation-slices gate reads a new-format `prerequisite_gaps.md` whose catalog has `required_missing_user_reachable_surface` entries with `scheduled_in_slices`/`unmet` status
- **THEN** it extracts each `surface_identity` as a required preserved surface
