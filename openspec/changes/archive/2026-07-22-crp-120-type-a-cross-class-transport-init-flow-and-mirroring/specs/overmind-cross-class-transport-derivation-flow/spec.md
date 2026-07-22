## ADDED Requirements

### Requirement: §5 derivation flow runs only when an in-project peer exists

For project type `A`, Step `1.1` SHALL run the §5 derivation flow on each active backend blueprint only when the project has at least one in-project cross-class peer for the backend (another active backend, an active frontend, or an active mobile class). When no such peer exists, Step `1.1` SHALL NOT touch §5.

#### Scenario: Backend with frontend peer triggers derivation

- **WHEN** a type `A` project has one active backend and one active frontend
- **THEN** Step `1.1` runs the §5 derivation flow on the backend blueprint

#### Scenario: Backend with mobile peer triggers derivation

- **WHEN** a type `A` project has one active backend and one active mobile class
- **THEN** Step `1.1` runs the §5 derivation flow on the backend blueprint

#### Scenario: Multi-backend triggers derivation per backend

- **WHEN** a type `A` project has two or more active backend classes and no other active class
- **THEN** Step `1.1` runs the §5 derivation flow on every active backend blueprint independently

#### Scenario: Lone backend skips derivation

- **WHEN** a type `A` project has exactly one active backend and no other active class
- **THEN** Step `1.1` does not run the §5 derivation flow on any blueprint

#### Scenario: No active backend skips derivation

- **WHEN** a type `A` project has no active backend class
- **THEN** Step `1.1` does not run the §5 derivation flow on any blueprint

### Requirement: §5 derivation order is MCP then stack inference then placeholder, reusing the existing harness

For each in-scope backend blueprint, Step `1.1` SHALL reuse the existing MCP-query / user-approval harness already used to author §2/§3/§4 and try sources in order: the configured `stack_knowledge_base` MCP source from `.setup/external_sources.yaml` first, then §5-specific inference from approved §2 stack choices, then the literal placeholder pair.

#### Scenario: MCP-confident proposal is presented

- **WHEN** `.setup/external_sources.yaml` declares a `stack_knowledge_base` source that is reachable and yields a confident transport/schema proposal
- **THEN** Step `1.1` presents that proposal for user approval through the existing approval flow

#### Scenario: Stack inference fallback is used when MCP is absent

- **WHEN** `.setup/external_sources.yaml` declares no reachable `stack_knowledge_base` source, and §5-specific inference from approved §2 stack choices yields a confident transport/schema proposal
- **THEN** Step `1.1` presents the inferred proposal for user approval through the existing approval flow

#### Scenario: Placeholder pair written when neither source is confident

- **WHEN** neither MCP nor stack inference yields a confident proposal
- **THEN** Step `1.1` writes the literal placeholder for both `transport_protocol` and `schema_format` with `user_approved: false`

### Requirement: Concrete §5 writes require user approval; placeholder writes do not

Step `1.1` SHALL write `transport_protocol` and `schema_format` with concrete values and `user_approved: true` only after explicit user approval of the proposal. Placeholder writes SHALL NOT require user approval.

#### Scenario: User approves a proposal

- **WHEN** the user approves a confident transport/schema proposal
- **THEN** Step `1.1` writes both fields with concrete values and `user_approved: true`

#### Scenario: User declines a proposal

- **WHEN** the user declines a confident transport/schema proposal
- **THEN** Step `1.1` writes the placeholder pair with `user_approved: false` and does not retry on the same source

#### Scenario: Placeholder write proceeds without approval

- **WHEN** Step `1.1` writes the placeholder pair
- **THEN** the write proceeds without prompting the user for approval

### Requirement: §5 derivation rule documents the flow narrative

`overmind/rules/project_stack_blueprint_rule.md` SHALL document the §5 derivation/approval narrative (MCP → stack inference → placeholder) without altering the structural §5 contract defined by the CRP-119 capability.

#### Scenario: Rule references derivation order

- **WHEN** the blueprint rule is read
- **THEN** the §5 derivation order (MCP, stack inference, placeholder) and the user-approval requirement for concrete writes are documented

### Requirement: Type `B` and type `C` flows are unchanged

The §5 derivation flow SHALL be a no-op for project types `B` and `C`.

#### Scenario: Type `B` Step `1.1` is unchanged

- **WHEN** a project is type `B`
- **THEN** Step `1.1` does not invoke the §5 derivation flow

#### Scenario: Type `C` Step `1.1` is unchanged

- **WHEN** a project is type `C`
- **THEN** Step `1.1` does not invoke the §5 derivation flow
