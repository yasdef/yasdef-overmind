## ADDED Requirements

### Requirement: The agents-md context command binds the class session

`overmind context agents-md <project> --class <backend|frontend|mobile>` SHALL be the sole runtime binding for an agent guidelines session. It SHALL emit the workspace root, the project root, the target artifact `project_agents_md_claude_md_<class>.md`, the `overmind gate agents-md <target>` command, the class-specific template and golden-example skill assets, `external_sources_status`, `agents_md_status`, and the class's `project_stack_blueprint_<class>.md` as a read-only input. It SHALL exit `2` when the project is not `project_type_code: A`, when the named class is absent from `meta_info.project_classes`, or when that class's stack blueprint does not exist.

#### Scenario: Context binds the target, gate, assets, and source blueprint

- **WHEN** `overmind context agents-md <project> --class frontend` runs for a type `A` project with an active `frontend` class and an existing frontend blueprint
- **THEN** the context output names the target artifact, the `overmind gate agents-md` command for that target, the frontend template and golden-example assets, the external-sources status, the agents-md status, and the frontend blueprint as a read-only input

#### Scenario: Non-type-A project is rejected

- **WHEN** the context command runs for a project whose `project_type_code` is not `A`
- **THEN** it exits `2` and produces no binding

#### Scenario: Inactive class is rejected

- **WHEN** the context command names a class absent from `meta_info.project_classes`
- **THEN** it exits `2` and produces no binding

#### Scenario: Missing source blueprint is rejected

- **WHEN** the context command runs for an active class whose `project_stack_blueprint_<class>.md` does not exist
- **THEN** it exits `2`, reporting that the agent guidelines artifact is derived from the blueprint and cannot be produced first

### Requirement: Context reports whether the artifact is already present

The context command SHALL emit `agents_md_status` as `present` when `project_agents_md_claude_md_<class>.md` exists as a file at the project root, and `absent` otherwise.

#### Scenario: Present artifact is reported

- **WHEN** the class already has a `project_agents_md_claude_md_<class>.md`
- **THEN** the context output carries `agents_md_status: present`

#### Scenario: Absent artifact is reported

- **WHEN** the class has no agent guidelines artifact
- **THEN** the context output carries `agents_md_status: absent`

### Requirement: An already-present artifact is verified, not regenerated

When `agents_md_status` is `present`, the `overmind-agents-md` skill SHALL run the bound gate command against the existing artifact and stop. On gate exit `0` it SHALL leave the artifact byte-unchanged and report the class session complete. On gate exit `1` it SHALL repair only the reported problems. Rewriting or regenerating content that already passes the gate SHALL require explicit operator approval, on the same terms as initial creation.

#### Scenario: Present and passing artifact is left untouched

- **WHEN** the agents-md session runs for a class whose artifact is present and passes the gate
- **THEN** the artifact is left byte-unchanged and the session reports the class complete

#### Scenario: Present but failing artifact is repaired in place

- **WHEN** the agents-md session runs for a class whose present artifact fails the gate with a missing section
- **THEN** the session repairs the reported problem and reruns the same gate command

#### Scenario: Revision of a passing artifact requires approval

- **WHEN** the operator asks to change guidance in an artifact that already passes the gate
- **THEN** the skill obtains explicit operator approval before writing

### Requirement: Guidance is sourced through knowledge base, bounded fallback, then operator approval

The skill SHALL source the engineering guidance sections in a fixed order. When `external_sources_status` identifies an available stack knowledge base, the skill SHALL use it and SHALL tell the operator which source informed the proposal. When the knowledge base is unavailable or yields no confident proposal, the skill SHALL use bounded fallback proposals aligned with the class's approved stack. The skill SHALL NOT silently adopt a default, and SHALL NOT write the artifact until the operator explicitly approves or overrides the proposed guidance.

#### Scenario: Knowledge base informs the proposal and is disclosed

- **WHEN** a stack knowledge base is configured and yields class engineering guidance
- **THEN** the skill proposes from it and tells the operator which source informed the proposal

#### Scenario: Fallback is used when no knowledge base is available

- **WHEN** no stack knowledge base is reachable
- **THEN** the skill proposes bounded fallback guidance aligned with the class's approved stack choices

#### Scenario: No write without operator approval

- **WHEN** the operator has neither approved nor overridden the proposed guidance
- **THEN** no agent guidelines artifact is written

### Requirement: The agents-md session writes exactly one artifact and owns its gate loop

The `overmind-agents-md` skill SHALL write exactly the target artifact named by the context command and nothing else, preserving `init_progress_definition.yaml`, every stack blueprint, `.setup/external_sources.yaml`, peer agent guidelines artifacts, and every other project artifact. The skill SHALL run the bound `overmind gate agents-md` command after every write and repair until it exits `0`; on exit `2` it SHALL stop and report that validation cannot complete. The coordinator SHALL bind the gate command and SHALL NOT run the quality loop itself.

#### Scenario: Only the target artifact is written

- **WHEN** the agents-md session for `backend` completes
- **THEN** only `project_agents_md_claude_md_backend.md` is created or modified, and the project definition, the backend blueprint, and peer artifacts are unchanged

#### Scenario: The model repairs against the gate until it passes

- **WHEN** the gate exits `1` after a write
- **THEN** the skill repairs only the reported problems and reruns the same gate command until it exits `0`

#### Scenario: Coordinator binds but does not run the gate loop

- **WHEN** the agents-md session is prepared
- **THEN** the coordinator binds the `overmind gate agents-md <target>` command into the prompt and does not itself iterate the gate

### Requirement: The agents-md skill is packaged with per-class assets

The packaged skill `overmind-agents-md` SHALL ship a `SKILL.md` plus a template and a golden example for each of `backend`, `frontend`, and `mobile`, and SHALL be listed in the installer's packaged-skill fan-out. Templates define document structure only; golden examples are non-normative quality targets.

#### Scenario: Skill is installed with its class assets

- **WHEN** the installer packaged-skill set is inspected
- **THEN** `overmind-agents-md` is present with `SKILL.md`, a backend, frontend, and mobile template, and a backend, frontend, and mobile golden example

#### Scenario: Session binds the assets for its class

- **WHEN** the agents-md session for `mobile` is prepared
- **THEN** the prompt binds the mobile template and the mobile golden example
