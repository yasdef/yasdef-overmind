## ADDED Requirements

### Requirement: Typed registry defines the terminal feature-gate inventory

The coordinator SHALL define terminal eligibility, artifact selection, pipeline order, applicability, and repair ownership as typed metadata on the shared gate definitions introduced by CRP-165. Standalone gate dispatch and terminal-chain dispatch SHALL invoke the same registered validator implementation.

#### Scenario: Exact feature chain is declared

- **WHEN** the terminal gate definitions are loaded
- **THEN** they declare, in phase order, `repo-br-scan`, `task-to-br`, `br-clarification`, `requirements-ears`, optional `ears-review`, `contract-delta`, class-expanded `surface-map`, `technical-requirements`, `implementation-slices`, `prerequisite-gaps`, `implementation-plan`, and optional `plan-semantic-review`
- **AND** every definition identifies its artifact selector and owning repair step

#### Scenario: Feature gate coverage remains explicit

- **WHEN** a feature session in the step catalog resolves to a registered deterministic artifact gate
- **THEN** a contract test requires that gate to declare terminal metadata
- **AND** adding a feature gate without terminal classification fails the contract test

#### Scenario: Class gate uses shared dispatch

- **WHEN** `surface-map` is invoked by `gate surface-map ... --class <class>` and by the terminal chain for the same feature and class
- **THEN** both paths resolve the same registered validator and preserve its exit classification

#### Scenario: Every repair owner resolves through resume

- **WHEN** terminal gate definitions are loaded
- **THEN** each owning repair-step token resolves through the production `resolveStep(...)` path
- **AND** the resolved catalog id equals the token stored in terminal metadata

### Requirement: Terminal chain selects applicable existing feature artifacts

The terminal runner SHALL validate a feature path within an ASDLC workspace and expand the ordered chain using existing artifact paths and declared pipeline predicates. File-type and readability validation SHALL remain owned by each applicable artifact gate.

#### Scenario: Existing exact artifact is applicable

- **WHEN** an exact artifact selector path exists and its declared predicate passes
- **THEN** the owning gate is included in the ordered invocation set

#### Scenario: Malformed artifact entry is not treated as absent

- **WHEN** a declared artifact path exists as a directory or another invalid entry type
- **THEN** the owning validator is invoked and classifies the malformed target
- **AND** the entry is not reported as skipped

#### Scenario: Absent optional review artifact is skipped

- **WHEN** `requirements_ears_review.md` or `implementation_plan_semantic_review.md` does not exist
- **THEN** its owning review gate is reported as skipped
- **AND** absence alone does not fail the aggregate chain

#### Scenario: Existing pre-dual-source EARS ledger requires upgrade

- **WHEN** `requirements_ears_review.md` exists but lacks CRP-163's dual-source metadata or finding references
- **THEN** `ears-review` runs and returns its recoverable field diagnostics
- **AND** the aggregate fails with repair owner step `5.1` instead of treating the ledger as legacy-compatible

#### Scenario: Repository scan was intentionally inapplicable

- **WHEN** `feature_br_summary.md` exists but no project class repository has state `ready`
- **THEN** `repo-br-scan` is reported as skipped by its existing `hasReadyClassRepo` predicate
- **AND** the remaining applicable gates still run

#### Scenario: Repository is attached after BR scanning

- **WHEN** step `Scan repo and apply task-to-BR update` ran while no class repository was ready
- **AND** a repository is later attached and reconciled to state `ready` while `feature_br_summary.md` still lacks populated `## 13. Existing-System Context`
- **THEN** terminal applicability uses the current project state and invokes `repo-br-scan`
- **AND** its recoverable failure identifies step `4.1` as the repair owner

#### Scenario: Existing surface maps fan out by class

- **WHEN** backend and mobile surface-map artifacts exist and the frontend artifact is absent
- **THEN** the chain invokes `surface-map` with class `backend` and class `mobile` in stable supported-class order
- **AND** the frontend surface-map entry is reported as skipped

#### Scenario: Feature path cannot be validated

- **WHEN** the input does not resolve to a feature directory under `projects/<project-id>/<feature-folder>` in an ASDLC workspace
- **THEN** the chain returns exit `2` with a path diagnostic
- **AND** no artifact validator runs

#### Scenario: No recognized feature artifact is applicable

- **WHEN** the feature path is valid but none of the declared trigger artifacts exists
- **THEN** the chain returns exit `2` stating that no deterministic feature artifact was validated

### Requirement: Terminal chain runs every applicable gate and aggregates results

The terminal runner SHALL invoke every applicable gate without fail-fast, retain ordered per-entry results, and compute one aggregate `GateExitCode` without mutating feature or project artifacts.

#### Scenario: All applicable gates pass

- **WHEN** at least one gate is applicable and every applicable validator returns exit `0`
- **THEN** the aggregate returns exit `0`
- **AND** its result records every passed and skipped entry

#### Scenario: Recoverable failures are aggregated

- **WHEN** one or more applicable validators return exit `1` and none returns exit `2`
- **THEN** every later applicable gate still runs
- **AND** the aggregate returns exit `1` with every recoverable problem

#### Scenario: Runtime failure takes precedence

- **WHEN** one applicable gate returns exit `1` and another returns exit `2`
- **THEN** every applicable gate still runs
- **AND** the aggregate returns exit `2` while retaining diagnostics from both failures

#### Scenario: Earliest repair owner is stable

- **WHEN** gates owned by steps `5` and `8.3` both fail
- **THEN** the aggregate identifies step `5` as the repair resume step regardless of failure severity ordering

#### Scenario: Chain validation is read-only

- **WHEN** the terminal chain completes with any aggregate exit code
- **THEN** the bytes and existence of every file under the project and feature paths remain unchanged

### Requirement: CLI exposes the terminal chain as gate all

The installed coordinator SHALL support `node .overmind/overmind.js gate all <feature-path>` with no additional flags and SHALL return the terminal chain's aggregate exit code.

#### Scenario: Standalone chain output is auditable

- **WHEN** an operator runs `gate all` for a valid feature
- **THEN** output contains one stable row per expanded entry naming status, gate, artifact, and class when applicable
- **AND** the final summary reports passed, failed, and skipped counts

#### Scenario: Relative feature path uses CLI working directory

- **WHEN** `gate all` receives a relative feature path
- **THEN** it resolves the workspace and feature from the working directory supplied to the top-level CLI invocation

#### Scenario: Standalone recoverable failure

- **WHEN** an applicable artifact gate returns exit `1`
- **THEN** `gate all` prints the artifact, gate, and reported problems
- **AND** the process exits `1`

#### Scenario: Standalone runtime failure

- **WHEN** path resolution or an applicable validator returns exit `2`
- **THEN** `gate all` prints the runtime diagnostic
- **AND** the process exits `2`

#### Scenario: Existing individual gate dispatch remains compatible

- **WHEN** an operator invokes an existing `gate <step> <path>` command, including `surface-map --class <class>`
- **THEN** its syntax, output contract, and registered dispatch remain unchanged
- **AND** validator acceptance behavior remains unchanged except for the implementation-plan header requirement defined by this capability

### Requirement: Implementation-plan gate requires the template header

The existing implementation-plan validator SHALL apply one start-anchored structural regex requiring `implementation_plan.md` to begin with the exact first line `# Implementation Plan`, followed by LF or CRLF. A missing or alternate leading header SHALL return recoverable exit `1` with the diagnostic `implementation_plan.md must start with exact header: # Implementation Plan`. The regex SHALL treat the header as the mechanical sentinel and leave the following template preamble prose outside exact-text validation.

#### Scenario: Exact template header contributes no problem

- **WHEN** `implementation_plan.md` begins at byte zero with `# Implementation Plan` followed by LF or CRLF
- **THEN** header validation contributes no implementation-plan gate problem
- **AND** the gate may exit `0` when every other plan check passes

#### Scenario: Measured migrated plan begins directly with a step

- **WHEN** `implementation_plan.md` begins with `### Step 1.1` and has no leading `# Implementation Plan` line
- **THEN** the implementation-plan gate exits `1`
- **AND** it reports `implementation_plan.md must start with exact header: # Implementation Plan`

#### Scenario: Alternate top-level heading is rejected

- **WHEN** `implementation_plan.md` begins with `# Repository Implementation Plan`
- **THEN** the implementation-plan gate exits `1` with the exact-header diagnostic

#### Scenario: Terminal chain catches the measured plan-header loss

- **WHEN** all applicable feature artifacts other than `implementation_plan.md` pass their deterministic gates
- **AND** `implementation_plan.md` begins directly with a step and otherwise satisfies plan validation
- **THEN** the terminal chain returns exit `1` with repair owner step `8.3`
- **AND** feature completion and the after-review checkpoint remain blocked

### Requirement: Feature flow passes terminal success through the chain

The feature orchestrator SHALL invoke the same terminal chain after the last optional-review decision and SHALL require aggregate exit `0` before returning plan-complete success or creating the after-plan-review checkpoint.

#### Scenario: Final semantic review succeeds

- **WHEN** step `(optional) implementation plan semantic review` completes successfully
- **THEN** its CRP-165 post-session mutable-set checks finish first
- **AND** the terminal chain runs before the after-review checkpoint and feature success outcome

#### Scenario: Final semantic review is declined

- **WHEN** the operator declines step `(optional) implementation plan semantic review`
- **THEN** the terminal chain still runs against every applicable existing artifact before the flow returns `finished`

#### Scenario: Scanner reports no remaining required step

- **WHEN** the selected or explicitly resumed feature has no remaining required catalog step
- **THEN** the terminal chain runs before the flow emits an execution-finished message or success outcome

#### Scenario: Catalog reaches its end

- **WHEN** the feature loop reaches the end of the configured phase map
- **THEN** the terminal chain runs before the flow emits plan-complete success

#### Scenario: Earlier flow does not reach terminal completion

- **WHEN** an action fails, the operator stops, or a non-terminal phase ends without reaching the plan-completion boundary
- **THEN** the terminal chain is not invoked for that run

### Requirement: Terminal failure blocks completion and supports explicit repair

A non-zero terminal chain result SHALL propagate unchanged through the feature flow, suppress plan-complete success and the after-review checkpoint, and provide the earliest owning repair step without automatically retrying an action or agent.

#### Scenario: Live invalid EARS defect reaches the terminal hook

- **WHEN** artifact-presence progress is complete and `requirements_ears.md` contains invalid `WHEN ..., THEN THE ... SHALL ...` bullets while downstream artifacts pass their gates
- **THEN** the flow returns exit `1` terminal failure owned by step `5`
- **AND** no terminal success message or after-review checkpoint is produced

#### Scenario: Terminal runtime failure propagates

- **WHEN** an applicable terminal validator returns exit `2`
- **THEN** the feature flow carries exit `2` unchanged with the validator diagnostic and owning-step context
- **AND** it does not automatically retry the action or agent

#### Scenario: Explicit repair resume reopens cached feature

- **WHEN** terminal validation failed for the valid cached feature even though artifact-presence scanning otherwise calls it complete
- **AND** the operator invokes `overmind run --path <project> --resume <owning-step>`
- **THEN** feature selection reopens that cached feature at the explicit repair step
- **AND** completion remains blocked until a later terminal chain exits `0`

#### Scenario: Multiple defects resume from the earliest owner

- **WHEN** terminal validation reports failures in multiple pipeline phases
- **THEN** CLI repair guidance names the earliest failing owning step
- **AND** all later failure diagnostics remain visible

### Requirement: Canonical and installed guidance expose terminal validation

The canonical feature sequence, init progress template, repository runtime documentation, and generated installed quick-run guide SHALL state that feature plan completion requires the terminal deterministic gate chain and SHALL show the `gate all <feature-path>` command.

#### Scenario: Canonical completion contract is read

- **WHEN** an operator reads the feature sequence or `Create Shared Repository Implementation Plan` completion conditions
- **THEN** terminal `gate all` success is identified as a condition before plan-complete reporting

#### Scenario: Installed quick-run guide is generated

- **WHEN** a fresh or update installation writes `quickrun.md`
- **THEN** the guide includes `node .overmind/overmind.js gate all projects/<project-id>/<feature-folder>` and concise exit/repair guidance

#### Scenario: Standalone validation scope is documented

- **WHEN** an operator reads the repository runtime guidance
- **THEN** it states that `gate all` validates applicable artifacts that exist and does not establish required-artifact completeness by itself
- **AND** it identifies feature-flow sequencing as the owner of required-artifact completeness

### Requirement: Installed coordinator retains terminal enforcement

Fresh and updated ASDLC installations SHALL copy the newly built coordinator bundle containing `gate all` and the flow-end hook without introducing another runtime asset.

#### Scenario: Installed standalone chain runs

- **WHEN** an operator invokes `gate all` through an installed `.overmind/overmind.js`
- **THEN** the installed coordinator runs the same typed chain and returns the same aggregate classification as the source package

#### Scenario: Installed flow rejects terminal defect

- **WHEN** an installed-workspace feature reaches plan completion with a failing earlier deterministic artifact gate
- **THEN** the installed flow rejects completion before its terminal success output and after-review checkpoint
