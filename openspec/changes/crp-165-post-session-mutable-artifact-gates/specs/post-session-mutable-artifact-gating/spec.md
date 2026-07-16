## ADDED Requirements

### Requirement: Review sessions share complete mutable-artifact gate contracts

One typed review-session contract SHALL define the ordered artifact-to-gate mapping for every artifact that EARS review and plan semantic review may edit. Each context builder SHALL render its allowed-write surface from the applicable contract, and the step catalog SHALL attach those same entries as the action's post-session gate set alongside its read-only guards and required outputs.

#### Scenario: EARS review declares both mutable artifacts

- **WHEN** step `5.1` is loaded from the catalog
- **THEN** its post-session set maps `requirements_ears.md` to `requirements-ears`
- **AND** it maps `requirements_ears_review.md` to `ears-review`
- **AND** the EARS-review context renders its allowed-write surface from those same typed entries

#### Scenario: Plan semantic review declares both mutable artifacts

- **WHEN** step `8.4` is loaded from the catalog
- **THEN** its post-session set maps `implementation_plan.md` to `implementation-plan`
- **AND** it maps `implementation_plan_semantic_review.md` to `plan-semantic-review`
- **AND** the plan-semantic-review context renders its mutable targets and allowed-write surface from those same typed entries

#### Scenario: CRP-163 EARS source protection is retained

- **WHEN** CRP-163 and this change are applied together
- **THEN** step `5.1` retains its dedicated read-only guards for `feature_br_summary.md` and `user_br_input.md`
- **AND** it also declares the two mutable-artifact gates without widening the write surface

### Requirement: Coordinator runs every declared post-session gate

After a configured review agent exits `0`, the coordinator SHALL invoke every gate in the session action's declared post-session set against the current feature state before reporting action success. It SHALL run the whole ordered set even when an earlier gate returns non-zero.

#### Scenario: EARS review final state is fully revalidated

- **WHEN** an EARS-review agent exits `0`
- **THEN** the coordinator runs `requirements-ears` for `requirements_ears.md`
- **AND** it runs `ears-review` for `requirements_ears_review.md`
- **AND** action success is considered only after both results are available

#### Scenario: Plan semantic review final state is fully revalidated

- **WHEN** a plan-semantic-review agent exits `0`
- **THEN** the coordinator runs `implementation-plan` for `implementation_plan.md`
- **AND** it runs `plan-semantic-review` for `implementation_plan_semantic_review.md`
- **AND** action success is considered only after both results are available

#### Scenario: First gate fails but later gate still runs

- **WHEN** the first declared post-session gate returns non-zero
- **THEN** the coordinator still invokes every remaining declared gate
- **AND** it retains diagnostics for every failed artifact

#### Scenario: Session has no post-session gate set

- **WHEN** a successful session action does not declare `postSessionGates`
- **THEN** the executor preserves its existing guard and required-output behavior without invoking a post-session gate

#### Scenario: Agent session itself fails

- **WHEN** the agent exits non-zero
- **THEN** the executor returns the existing agent failure without running post-session gates

### Requirement: Post-session gate failures preserve classification and artifact identity

Every failed post-session gate SHALL produce an error diagnostic naming its declared artifact and gate. The session action SHALL return exit `1` when one or more gates are recoverably invalid and no exit-`2` condition exists, and SHALL return exit `2` when any gate cannot run, any declared gate is unregistered, or another post-session integrity check fails.

#### Scenario: Recoverable mutable-artifact defect

- **WHEN** `requirements-ears` returns exit `1` and `ears-review` returns exit `0`
- **THEN** the EARS-review action fails with exit `1`
- **AND** its diagnostic names `requirements_ears.md`, `requirements-ears`, and the reported EARS problems

#### Scenario: Runtime gate failure takes precedence

- **WHEN** one declared gate returns exit `1` and another returns exit `2`
- **THEN** the coordinator retains diagnostics from both gates
- **AND** the session action fails with exit `2`

#### Scenario: Declared gate is unavailable

- **WHEN** a session action declares a gate absent from the injected registry
- **THEN** the coordinator records an exit-`2` configuration diagnostic naming the artifact and gate
- **AND** it continues running the other declared gates before failing the action

#### Scenario: All mutable artifacts pass

- **WHEN** the agent exits `0`, existing guard/output checks pass, and every declared post-session gate exits `0`
- **THEN** the session action succeeds with exit `0`

#### Scenario: Orchestrator preserves failed-gate classification

- **WHEN** a post-session action returns exit `1` or exit `2`
- **THEN** the feature flow result carries that same classification unchanged
- **AND** the orchestrator does not automatically re-invoke the action or agent for exit `1`

### Requirement: Failed mutable-artifact gates block review completion and checkpointing

The feature orchestrator SHALL treat any non-zero post-session mutable-artifact gate result as a failed step action and SHALL NOT complete or checkpoint that review step in the run that produced the failure. Completing the review requires a run whose full declared gate set passes; repair is operator-driven by rerunning or resuming the owning review. This gate is enforced per run: it does not, by itself, re-block a later run on a previously failed review.

#### Scenario: Invalid EARS survives an otherwise complete review ledger

- **WHEN** `requirements_ears_review.md` passes `ears-review`
- **AND** `requirements_ears.md` contains invalid `WHEN ..., THEN THE ... SHALL ...` bullets that fail `requirements-ears`
- **THEN** step `5.1` fails before checkpointing
- **AND** the diagnostic identifies the invalid EARS artifact and owning gate

#### Scenario: Invalid plan survives an otherwise complete semantic-review ledger

- **WHEN** `implementation_plan_semantic_review.md` passes `plan-semantic-review`
- **AND** `implementation_plan.md` fails `implementation-plan`
- **THEN** step `8.4` fails before checkpointing
- **AND** the diagnostic identifies the invalid plan artifact and owning gate

#### Scenario: Repair run passes the whole mutable set

- **WHEN** the operator reruns or resumes the owning review and both declared mutable-artifact gates then pass
- **THEN** the review step may complete and follow the existing checkpoint path

### Requirement: CLI and executor use the same validator registry

Standalone non-class `overmind gate` dispatch and post-session executor dispatch SHALL resolve gate names through one typed validator registry while preserving current validator behavior and standalone CLI syntax.

#### Scenario: Same EARS validator is used through both paths

- **WHEN** `requirements-ears` is invoked through the standalone CLI and through a post-session action against the same feature state
- **THEN** both paths use the same validator mapping and produce the same gate exit classification

#### Scenario: Existing CLI command remains compatible

- **WHEN** an operator runs an existing `node .overmind/overmind.js gate <step> <path>` command
- **THEN** command syntax and validator acceptance rules remain unchanged

#### Scenario: Existing clarification progress remains visible

- **WHEN** the standalone CLI dispatches `br-clarification` through the shared registry
- **THEN** it supplies the current progress sink and emits the same clarification-loop progress output as before registry extraction

### Requirement: Canonical workflow definitions expose full mutable-set completion

The canonical init progress sequence and template SHALL state at `(optional) requirement_ears extra review` and `(optional) implementation plan semantic review` that completion requires both mutable artifacts to pass their owning post-session gates.

#### Scenario: Workflow completion contract is consulted

- **WHEN** an operator or implementation reads the canonical definitions for steps `5.1` and `8.4`
- **THEN** each review step identifies both its normative artifact gate and its ledger gate as completion conditions

### Requirement: Installed coordinator retains post-session enforcement

Fresh and updated ASDLC installations SHALL receive the bundled coordinator containing the same catalog mappings and executor enforcement as the source package, without a new runtime command or skill asset.

#### Scenario: Installed runtime completes a review session

- **WHEN** a review session is dispatched through an installed `.overmind/overmind.js`
- **THEN** the installed coordinator applies the full declared mutable-artifact gate set before accepting the session
