## ADDED Requirements

### Requirement: Optional Step 7.1 inspects existing surface maps for placeholders
Overmind SHALL provide optional Step `7.1` after Step `7` and before Step `8`. Step `7.1` SHALL inspect existing `project_surface_struct_resp_map_backend.md`, `project_surface_struct_resp_map_frontend.md`, and `project_surface_struct_resp_map_mobile.md` artifacts under the feature path and process only artifacts that exist.

#### Scenario: Existing backend map is inspected
- **WHEN** Step `7.1` runs for a feature that contains `project_surface_struct_resp_map_backend.md`
- **THEN** Step `7.1` scans the backend map for the literal `<to be defined during implementation>`

#### Scenario: Missing class map is skipped
- **WHEN** Step `7.1` runs for a feature without `project_surface_struct_resp_map_mobile.md`
- **THEN** Step `7.1` skips mobile enrichment without failing because the mobile map is absent

### Requirement: Placeholder detection happens before MCP lookup
Step `7.1` SHALL detect eligible placeholder fields before checking MCP reachability or querying any MCP source. If a surface map contains no literal `<to be defined during implementation>` placeholders, Step `7.1` SHALL leave that map unchanged and SHALL NOT perform MCP reachability checks for that map.

#### Scenario: No placeholders causes no-op
- **WHEN** a surface map contains no `<to be defined during implementation>` placeholders
- **THEN** Step `7.1` leaves the file unchanged
- **AND** Step `7.1` does not query MCP for that map

#### Scenario: Placeholders trigger source lookup
- **WHEN** a surface map contains at least one `<to be defined during implementation>` placeholder
- **THEN** Step `7.1` looks for a configured knowledge-base MCP source before attempting enrichment

### Requirement: Step 7.1 proposes MCP-backed replacements before editing
When eligible placeholders and a reachable configured knowledge-base MCP source exist, Step `7.1` SHALL request candidate replacements for those placeholders and present a user-facing summary before editing. The summary SHALL identify each proposed replacement, the target field or row, and the MCP source or evidence basis.

#### Scenario: Candidate replacement summary is shown
- **WHEN** MCP returns useful candidate replacements for placeholder fields
- **THEN** Step `7.1` presents a summary of proposed replacements before changing the surface map
- **AND** the summary includes the configured MCP source name

#### Scenario: Ambiguous guidance is not applied
- **WHEN** MCP guidance is absent, ambiguous, or does not confirm a concrete replacement
- **THEN** Step `7.1` leaves the placeholder unchanged

### Requirement: Step 7.1 edits only user-confirmed placeholder replacements
Step `7.1` SHALL update a surface-map file in place only for replacements explicitly confirmed by the user. Step `7.1` SHALL NOT rewrite non-placeholder content or apply unconfirmed candidate replacements.

#### Scenario: User confirms replacement
- **WHEN** the user confirms a proposed replacement for a placeholder field
- **THEN** Step `7.1` replaces only that confirmed placeholder value in the relevant surface-map file

#### Scenario: User rejects replacement
- **WHEN** the user rejects proposed replacements for a surface map
- **THEN** Step `7.1` leaves the surface-map file unchanged

### Requirement: Step 7.1 reruns the existing surface-map quality helper after edits
After Step `7.1` changes a surface-map file, it SHALL run the existing class-appropriate surface-map quality helper for that changed artifact. Backend maps SHALL use the backend helper, and frontend or mobile maps SHALL use the frontend/mobile helper.

#### Scenario: Backend quality helper runs after backend edit
- **WHEN** Step `7.1` updates `project_surface_struct_resp_map_backend.md`
- **THEN** it runs `check_feature_repo_surface_and_exec_context_be_quality.sh` against that file

#### Scenario: Frontend mobile quality helper runs after client edit
- **WHEN** Step `7.1` updates `project_surface_struct_resp_map_frontend.md` or `project_surface_struct_resp_map_mobile.md`
- **THEN** it runs `check_feature_repo_surface_and_exec_context_fe_quality.sh` against that file
