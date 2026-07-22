## ADDED Requirements

### Requirement: Step 2 runs as a packaged common-contract skill writing only the contract file

Init step 2 SHALL run as a packaged `overmind-common-contract` skill that writes only `common_contract_definition.md`. The repository SHALL NOT contain `overmind/scripts/init_common_contract_definition.sh`. The skill SHALL carry prose plus the common-contract template and golden example as assets only; parsing, mutation, and the gate SHALL be TypeScript. The step-2 session SHALL require the `common_contract_definition.md` output and SHALL be bound the common-contract rule/template/golden references, the target path, the common-contract gate command, and the cross-class peer-trigger command.

#### Scenario: Step 2 produces the common contract

- **WHEN** step 2 runs for a project
- **THEN** the session writes `common_contract_definition.md` and the step requires that output

#### Scenario: Common-contract skill is packaged and installed

- **WHEN** the installer packaged-skill set is inspected
- **THEN** `overmind-common-contract` is present with `SKILL.md` and its template/golden assets and is listed in the installer's packaged-skill fan-out

#### Scenario: Common-contract shell launcher is absent

- **WHEN** the versioned production tree is inspected
- **THEN** `overmind/scripts/init_common_contract_definition.sh` does not exist and no packaged staging references it

### Requirement: Step 2 binds evidence by project type

The common-contract session SHALL bind evidence according to project type: for type `A`, the approved `project_stack_blueprint_<class>.md` files SHALL be bound as read-only project context (not as contract schemas or scan evidence); for types `B`/`C`, the authoritative `ready` class-repo paths (existing directories resolved to canonical paths, derived from the existing parse/repo modules) SHALL be bound as repository evidence. No-peer behavior SHALL be served by the existing `repo/cross-class-peer-trigger.ts`.

#### Scenario: Type-A binds blueprints as read-only context

- **WHEN** step 2 runs for a type `A` project
- **THEN** the applicable blueprints are bound as read-only project context and the ready-repo evidence branch is not used

#### Scenario: Type-B/C binds ready class-repo evidence

- **WHEN** step 2 runs for a type `B` or `C` project
- **THEN** the authoritative ready class-repo paths are bound as repository evidence and no blueprint context is required

### Requirement: Approved blueprints are guarded read-only during step 2

Step 2 SHALL guard the approved `project_stack_blueprint_<class>.md` files as read-only for type `A` projects using the existing read-only-guard machinery driven from the session context's read-only inputs, so that a step-2 run that modifies any approved blueprint fails the guard. For projects without blueprints (types `B`/`C`) the guard set SHALL be empty.

#### Scenario: Modifying a blueprint during step 2 fails the guard

- **WHEN** the step-2 session modifies an approved `project_stack_blueprint_<class>.md`
- **THEN** the read-only guard verification fails the step

#### Scenario: No blueprint guard for non-type-A projects

- **WHEN** step 2 runs for a type `B`/`C` project with no blueprints
- **THEN** no blueprint read-only guard is applied and the step proceeds

### Requirement: Common-contract gate reuses the reconciliation validator via an initial-contract adapter

The common-contract quality gate for initial generation SHALL reuse the existing `validate/contract-reconciliation.ts` validator through a thin initial-contract adapter/alias that preserves the retired shell gate's target-path and `0/1/2` exit-code contract. The repository SHALL NOT contain `overmind/scripts/helper/check_common_contract_definition_quality.sh` or `overmind/scripts/helper/check_cross_class_peer_trigger.sh`. A second, duplicate common-contract validator SHALL NOT be introduced.

#### Scenario: Initial-contract gate matches the reconciliation validator

- **WHEN** the initial-contract gate validates a `common_contract_definition.md`
- **THEN** it accepts and rejects the same shapes as `validate/contract-reconciliation.ts` and returns `0`/`1`/`2` against the target path

#### Scenario: Helper shell gates are absent

- **WHEN** the versioned production tree is inspected
- **THEN** `overmind/scripts/helper/check_common_contract_definition_quality.sh` and `overmind/scripts/helper/check_cross_class_peer_trigger.sh` do not exist and no staging references them

### Requirement: The model owns the common-contract gate loop

The `overmind-common-contract` skill SHALL instruct the model to run the common-contract gate and repair the contract until it exits `0`, and to stop with the defined infeasibility message when the gate cannot pass with current evidence. The coordinator SHALL bind the gate command but SHALL NOT run the model-owned quality loop. Executor and prompt-capture tests SHALL prove the model — not coordinator code — invokes and repairs against the gate.

#### Scenario: Coordinator binds but does not run the gate loop

- **WHEN** step 2 is executed
- **THEN** the coordinator binds the common-contract gate command into the session and does not itself iterate the gate, and prompt-capture tests assert the gate command appears in the model prompt
