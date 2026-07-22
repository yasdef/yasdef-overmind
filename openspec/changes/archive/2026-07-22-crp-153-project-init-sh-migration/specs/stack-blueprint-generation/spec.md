## ADDED Requirements

### Requirement: Stack blueprint quality gate is a deterministic TypeScript validator

The stack-blueprint quality gate SHALL be a deterministic TypeScript validator (`packages/asdlc-coordinator/src/validate/stack-blueprint.ts`) exposed as `overmind gate stack-blueprint <path>`, with stable exit-code semantics: `0` when the target blueprint passes, `1` when required business-context content is missing (rendering each missing item), and `2` when validation cannot run. The repository SHALL NOT contain `overmind/scripts/helper/check_project_stack_blueprint_quality.sh`. The gate SHALL validate the single target file named on the command line, matching the shell gate's `<target>` argument.

#### Scenario: Passing blueprint exits zero

- **WHEN** `overmind gate stack-blueprint projects/<project>/project_stack_blueprint_backend.md` runs against a compliant blueprint
- **THEN** the gate prints its pass message and exits `0`

#### Scenario: Missing content exits one with details

- **WHEN** the target blueprint is missing required content
- **THEN** the gate reports the missing items and exits `1`

#### Scenario: Unrunnable validation exits two

- **WHEN** the target path is absent or otherwise cannot be validated
- **THEN** the gate writes an error and exits `2`

#### Scenario: Shell gate is absent

- **WHEN** the versioned production tree is inspected
- **THEN** `overmind/scripts/helper/check_project_stack_blueprint_quality.sh` does not exist and `stack-blueprint` is registered in the `overmind gate` registry

### Requirement: Step 1.1 runs as a packaged stack-blueprint skill per applicable class

Init step 1.1 SHALL run as a packaged `overmind-stack-blueprint` skill executed once per applicable active class (`backend`, `frontend`, `mobile`) for a type `A` project. The skill SHALL carry prose plus the class-specific stack-blueprint template and golden example as assets only; parsing, mutation, and the gate SHALL be TypeScript. Each per-class session SHALL require the output `project_stack_blueprint_<class>.md` and SHALL be bound the class-specific template, golden example, the `overmind gate stack-blueprint` command for its target, the cross-class peer-trigger command, and the external-sources status.

#### Scenario: One session per active stack class

- **WHEN** step 1.1 runs for a type `A` project with active `backend` and `frontend` classes
- **THEN** the stack-blueprint session is dispatched once for `backend` and once for `frontend`, each producing its `project_stack_blueprint_<class>.md`

#### Scenario: Per-class template and golden are bound

- **WHEN** the stack-blueprint session for a class is prepared
- **THEN** the prompt binds that class's template and golden example, the `overmind gate stack-blueprint <target>` command, the cross-class peer-trigger command, and the external-sources status

#### Scenario: Missing required blueprint output fails the step

- **WHEN** a stack-blueprint session ends without writing its `project_stack_blueprint_<class>.md`
- **THEN** the step fails on the missing required output

#### Scenario: Stack-blueprint skill is packaged and installed

- **WHEN** the installer packaged-skill set is inspected
- **THEN** `overmind-stack-blueprint` is present with `SKILL.md` and its template/golden assets and is listed in the installer's packaged-skill fan-out

### Requirement: The model owns the stack-blueprint gate loop

The `overmind-stack-blueprint` skill SHALL instruct the model to run `overmind gate stack-blueprint` and repair the blueprint until it exits `0`. The coordinator SHALL bind the gate command but SHALL NOT run the model-owned quality loop. Executor and prompt-capture tests SHALL prove the model — not coordinator code — invokes and repairs against the gate.

#### Scenario: Coordinator binds but does not run the gate loop

- **WHEN** step 1.1 is executed
- **THEN** the coordinator binds the `overmind gate stack-blueprint` command into the session and does not itself iterate the gate, and prompt-capture tests assert the gate command appears in the model prompt
