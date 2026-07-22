## ADDED Requirements

### Requirement: Session context is built before launch only when a from-context guard or a class-list builder consumes it

The orchestrator SHALL build a session action's deterministic context before launching the session when the action declares a read-only guard whose paths resolve from context (`{ mode: "fromContext" }`), or when the action routes through a project-level class-list context builder (whose pre-call validates the class-to-repo bindings before launch). When neither condition holds, the orchestrator SHALL NOT invoke the action's context builder before launch, and SHALL snapshot the action's read-only guards against an empty from-context input list.

#### Scenario: Session with no from-context guard and no class-list builder launches without building context

- **WHEN** the orchestrator executes a session action that declares no `fromContext` read-only guard and routes through no project-level class-list context builder, and that action's context builder would exit non-zero
- **THEN** the orchestrator does not invoke the context builder, and the session launches

#### Scenario: Session with a from-context guard builds context before launch

- **WHEN** the orchestrator executes a session action that declares a `fromContext` read-only guard and whose context builder exits zero
- **THEN** the orchestrator builds the deterministic context before launch and resolves the guard's paths from that context

#### Scenario: Project-level class-list session builds context to validate its bindings before launch

- **WHEN** the orchestrator executes a session action that declares no `fromContext` read-only guard but routes through a project-level class-list context builder, and one of its class-to-repo bindings is invalid
- **THEN** the orchestrator builds the deterministic context before launch, and the step fails on the invalid binding without launching a session

### Requirement: From-context sessions still fail on a context error

WHERE a session action declares a `fromContext` read-only guard, the orchestrator SHALL build its deterministic context before launch and SHALL fail the step when that context builder exits non-zero, launching no session.

#### Scenario: From-context context builder exits non-zero

- **WHEN** the orchestrator executes a session action that declares a `fromContext` read-only guard and whose context builder exits non-zero
- **THEN** the step fails with the context builder's exit code and diagnostic, and no session is launched

### Requirement: A freshly scaffolded feature can launch the task-to-br session

The orchestrator SHALL allow step `4.1` to launch the `task-to-br` session on a feature whose only artifact is `feature_br_summary.md`, so the skill can run its own capture step. The absence of `user_br_input.md` SHALL NOT cause step `4.1` to fail before the session launches.

#### Scenario: Step 4.1 reached on a newly scaffolded feature

- **WHEN** the orchestrator reaches step `4.1` for a feature that contains `feature_br_summary.md` and no `user_br_input.md`
- **THEN** the `task-to-br` session launches, and the step does not fail with a missing `user_br_input.md` error before launch
