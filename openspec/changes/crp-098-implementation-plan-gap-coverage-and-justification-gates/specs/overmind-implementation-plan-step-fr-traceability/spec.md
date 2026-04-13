## MODIFIED Requirements

### Requirement: Implementation steps SHALL carry canonical step-level FR links
Shared implementation plans SHALL place one-or-more functional-requirement links on every `### Step ...` heading using the authoritative `REQ-*` / `NFR-*` ids from `requirements_ears.md`. Additional step-scoped technical-evidence metadata used for unresolved-work coverage or justification SHALL coexist with those heading refs and SHALL NOT move FR links down to checklist bullets.

#### Scenario: Step heading includes requirement coverage links
- **WHEN** `implementation_plan.md` contains an implementation step
- **THEN** that step heading SHALL include at least one `REQ-*` or `NFR-*` id
- **AND** each referenced id SHALL exist in `requirements_ears.md`

#### Scenario: Additional technical evidence does not move FR links to bullets
- **WHEN** a plan step includes step-level technical-evidence metadata for helper-enforced unresolved-work coverage or justification
- **THEN** the canonical functional-requirement links SHALL remain on the `### Step ...` heading
- **AND** checklist bullets SHALL remain plain execution detail rather than the FR-link surface
