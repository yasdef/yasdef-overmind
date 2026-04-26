## ADDED Requirements

### Requirement: Type A Step 2 waits for approved blueprints
For project type `A`, Step `2` SHALL run only after Step `1.1` has produced all required active-class stack blueprints and those blueprints pass the CRP-114 quality helper.

#### Scenario: Step 2 blocked before blueprints exist
- **WHEN** a type `A` project has active classes and required stack blueprints are missing
- **THEN** Step `2` cannot be considered ready

#### Scenario: Step 2 ready after blueprints pass quality
- **WHEN** a type `A` project has all required active-class stack blueprints and each passes quality validation
- **THEN** Step `2` can proceed

### Requirement: Step 2 treats blueprints as read-only project context
For project type `A`, Step `2` SHALL treat approved stack blueprints as read-only project context for planned repo/service/class structure. Step `2` SHALL NOT modify stack blueprint files.

#### Scenario: Step 2 receives blueprint context
- **WHEN** Step `2` runs for a type `A` project
- **THEN** the prompt/context includes the required active-class stack blueprint paths as read-only inputs

#### Scenario: Step 2 does not modify blueprints
- **WHEN** Step `2` completes for a type `A` project
- **THEN** stack blueprint files remain unchanged

### Requirement: Blueprints are not contract schema definitions
Step `2` SHALL NOT treat stack blueprints as API contract schemas or shared request/response definitions. Stable cross-project contract governance SHALL remain owned by `common_contract_definition.md`.

#### Scenario: Blueprint stack choices inform context only
- **WHEN** a type `A` blueprint declares planned stack and layer conventions
- **THEN** Step `2` may use that information as project context but does not copy it as contract schema content

#### Scenario: Contract schemas are authored in common contract definition
- **WHEN** a type `A` project needs shared request or response definitions
- **THEN** those definitions are authored in `common_contract_definition.md`, not in the stack blueprint

### Requirement: Type B and C Step 2 behavior remains unchanged
For project types `B` and `C`, Step `2` SHALL continue to use existing repository-backed or existing project evidence rules and SHALL NOT require stack blueprint inputs.

#### Scenario: Type B Step 2 does not require blueprints
- **WHEN** Step `2` runs for a type `B` project with no stack blueprints
- **THEN** Step `2` proceeds according to existing type `B` rules

#### Scenario: Type C Step 2 does not require blueprints
- **WHEN** Step `2` runs for a type `C` project with no stack blueprints
- **THEN** Step `2` proceeds according to existing type `C` rules
