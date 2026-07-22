## ADDED Requirements

### Requirement: Generic step executor iterates the action sequence with no per-step branches

The system SHALL provide a generic `executeStep(stepDef, bindings, deps)` executor in `runner/` that iterates a step's declared `Action[]` in order, collapsing the 13 near-identical `run_*_skill` launchers and the hard-coded 4.1/4.2 branches into **one** implementation with **no per-step branches** (`02_responsibility_translation_map.md` row 5 executor; `03_target_architecture.md ## Runner`). The executor SHALL branch only on the action's `kind` (`session` vs deterministic `check`/`write`), never on step id. Injected `deps` SHALL supply the ports and in-process functions (the `AgentRunner`, the runner-config loader, and the existing `sync/`, `context/`, `readiness/` functions) so the executor is unit-testable with stubs. Each action SHALL yield a typed result, and any action failure SHALL stop the step with a typed `StepResult` carrying diagnostics.

#### Scenario: Multi-action step runs actions in declared order

- **WHEN** `executeStep` runs step 4.1 whose actions are `[session(repo-br-scan, runIf: hasReadyClassRepo), session(task-to-br)]`
- **THEN** it evaluates and runs the actions in that order and returns a typed result, with the executor branching only on action `kind`, not on the step id being `4.1`

#### Scenario: Action failure stops the step

- **WHEN** a session action in a multi-action step fails (non-zero agent exit or a guard/output violation)
- **THEN** the executor stops the step at that action and returns a `StepResult` carrying the diagnostics, without running the remaining actions

### Requirement: Session action execution order preserves the D7 boundary

For a session action the executor SHALL perform, in order: evaluate `runIf` (skip with a notice when false — not a failure) → if `requiresSync`, run the in-process sync function **before** the session (D7: repo-mutating, in the operator process) → run the in-process context builder (read-only) and obtain its `readOnlyInputs` → load the model config for the action's `modelPhase` → snapshot the `readOnlyGuards` → build the prompt → `AgentRunner.run()` → verify the `readOnlyGuards` and assert `requiredOutputs` (`03_target_architecture.md ## Runner`, `## D7 boundary preserved`). Guard verification SHALL run regardless of the agent exit code, matching the shell (which verifies guards before surfacing the model rc). The executor SHALL NOT run the `overmind gate` verb — gate ownership stays with the model (`02_responsibility_translation_map.md` guiding rule).

#### Scenario: runIf false skips the session as a notice

- **WHEN** a session action's `runIf` predicate (e.g. `hasReadyClassRepo`) evaluates false against workspace state
- **THEN** the executor skips that session with a notice and continues, treating the skip as success rather than a failure

#### Scenario: Sync runs before the session; context supplies fromContext inputs

- **WHEN** a session with `requiresSync: true` and `fromContext` guards runs
- **THEN** the in-process sync runs before the session, the context builder supplies the read-only inputs used to snapshot the `fromContext` guards, and the guards are verified after the session

#### Scenario: Guards are verified even when the agent exits non-zero

- **WHEN** a session's agent process exits non-zero but a `fromContext` protected file was modified
- **THEN** the executor still reports the guard violation in the `StepResult`, not only the agent failure

### Requirement: Deterministic actions call named coordinator functions

For a deterministic action (`kind: "check" | "write"`) the executor SHALL call the named in-process coordinator function (e.g. the `br-clarification` readiness check for step 4.2's `check`). An action naming an unregistered or unknown function SHALL yield a `Diagnostic`, not a throw. The `write` primitive for scaffold-feature is a Slice 3 deliverable; this slice SHALL wire the deterministic dispatch and cover it with a stub function.

#### Scenario: Check action invokes the readiness function

- **WHEN** `executeStep` reaches step 4.2's `check(br-clarification-readiness)` action
- **THEN** it invokes the in-process `br-clarification` readiness function and folds its result into the step result

#### Scenario: Unknown deterministic action degrades with a diagnostic

- **WHEN** a deterministic action names a function with no registered implementation
- **THEN** the executor returns a `Diagnostic` identifying the unknown action name, without throwing

### Requirement: Session bindings scope to feature path and single class this slice

Session bindings SHALL cover the feature path and, for per-class steps (step 7), a single target class. The class-**list** binding (the reconciliation session covering all pending classes) is out of scope for this slice (Slice 4); the executor contract SHALL be designed so the list binding is an extension of the same contract, never a forked launcher (`03_target_architecture.md ## Decisions` decision 3).

#### Scenario: Per-class step binds a single class

- **WHEN** `executeStep` runs the per-class step 7 for a given class
- **THEN** the session binding carries that single class and the prompt/guards resolve the class-scoped artifact (`project_surface_struct_resp_map_<class>.md`)
