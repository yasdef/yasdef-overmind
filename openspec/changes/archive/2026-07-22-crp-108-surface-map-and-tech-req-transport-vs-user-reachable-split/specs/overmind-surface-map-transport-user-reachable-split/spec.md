## ADDED Requirements

### Requirement: Surface map blocks record transport and user-reachable as separate subfields
Every Section 3 layer block and every Section 4 surface block in `project_surface_struct_resp_map_*.md` SHALL record two explicit subfields: `transport_layer` (internal callable code — clients, services, hooks, repositories, helpers) and `user_reachable_surface` (entry points an operator can invoke without code edits — routes, pages, screens, CLI commands, scheduled jobs, public HTTP endpoints). A single conflated `current_state` line SHALL NOT be used.

#### Scenario: Valid block with both subfields populated
- **WHEN** a surface map block describes a capability where both transport and a user-reachable surface exist
- **THEN** the block SHALL contain a `transport_layer:` line with the callable code path and a `user_reachable_surface:` line with the operator-invocable entry point

#### Scenario: Valid block with transport only
- **WHEN** a capability has transport-layer code but no operator-invocable surface
- **THEN** the block SHALL contain `transport_layer:` with the code path and `user_reachable_surface: none`

#### Scenario: Valid block with user-reachable only
- **WHEN** a capability is a bare route or screen with no backing transport helper
- **THEN** the block SHALL contain `transport_layer: none` and `user_reachable_surface:` with the entry point

#### Scenario: Conflated single-line entry is rejected
- **WHEN** a surface map block contains a single `current_state:` line that blends transport and reachability in prose
- **THEN** the quality helper SHALL exit non-zero and SHALL name the block and the missing subfield

### Requirement: none is the explicit marker for an absent subfield
When one of the two subfields is empty for a given block, the writer SHALL use the literal token `none` as the value rather than leaving the field blank or omitting it.

#### Scenario: Blank subfield is rejected
- **WHEN** a surface map block has `transport_layer:` with no value (blank)
- **THEN** the quality helper SHALL fail, treating blank the same as missing

#### Scenario: Omitted subfield is rejected
- **WHEN** a surface map block is present but one of the two subfields is entirely absent
- **THEN** the quality helper SHALL fail and SHALL identify which subfield is missing

#### Scenario: none token passes validation
- **WHEN** a surface map block has `user_reachable_surface: none`
- **THEN** the quality helper SHALL accept the block as structurally valid for that subfield

### Requirement: User-reachable definition is class-specific
The surface map rule and quality helper SHALL enforce the following per-class taxonomy when validating `user_reachable_surface` entries:
- **frontend**: a mounted route, page, or top-level screen an operator can navigate to
- **mobile**: a registered screen or deep link an operator can land on
- **backend**: an operator-reachable HTTP endpoint, CLI command, scheduled job, or admin tool — internal-only services and repositories do NOT qualify

#### Scenario: Backend transport-only entry does not satisfy user-reachable for backend
- **WHEN** a backend surface map block lists only an internal service call or repository method in `user_reachable_surface`
- **THEN** the quality helper SHALL reject the entry as not meeting the backend user-reachable definition

#### Scenario: Same path valid in both subfields for CLI
- **WHEN** a backend capability is a CLI command that is both the transport entry point and the operator-invocable surface
- **THEN** the same command identifier MAY appear in both `transport_layer` and `user_reachable_surface` and the helper SHALL accept it

### Requirement: user_reachable_surface is the ground truth consumed by downstream gates
Each `user_reachable_surface` entry SHALL be a concrete navigable token (a route path, full HTTP method+path, CLI command name, or job identifier) rather than prose, so that downstream prerequisite-gap tooling can parse and match it deterministically.

#### Scenario: Prose description in user_reachable_surface is rejected
- **WHEN** a `user_reachable_surface` value is a sentence or description rather than a concrete token
- **THEN** the quality helper SHALL fail and SHALL indicate that the value must be a parseable token

#### Scenario: Concrete route token passes
- **WHEN** `user_reachable_surface` contains a value like `/admin/login` or `POST /api/v2/orders`
- **THEN** the quality helper SHALL accept it as a valid token
