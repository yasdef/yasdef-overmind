## ADDED Requirements

### Requirement: Contract reconciliation is an installed skill

The installer SHALL package `overmind-contract-reconciliation` with `SKILL.md` and an `assets/` directory containing the common-contract template and golden example. Fresh install and update mode SHALL install or repair the complete payload in both `.codex/skills/overmind-contract-reconciliation/` and `.claude/skills/overmind-contract-reconciliation/`; the skill folders SHALL not contain a copy of `.overmind/overmind.js`.

#### Scenario: Fresh install creates both runner skills
- **WHEN** a runtime workspace is initialized from the canonical package payload
- **THEN** both supported runner folders contain `SKILL.md`, `assets/common_contract_definition_TEMPLATE.md`, and `assets/common_contract_definition_GOLDEN_EXAMPLE.md`

#### Scenario: Update repairs stale skill payload
- **WHEN** an installed runner skill is missing or stale during update mode
- **THEN** setup replaces it from the canonical payload while preserving the single shared `.overmind/overmind.js`

#### Scenario: Incomplete canonical payload fails before runner writes
- **WHEN** the packaged skill lacks `SKILL.md` or required assets
- **THEN** installation fails before modifying either runner target

### Requirement: Skill instructions preserve reconciliation ownership and scope

`SKILL.md` SHALL inline the durable reconciliation rule and SHALL identify `common_contract_definition.md` as its only writable artifact. It SHALL use only context-listed in-scope repositories as as-built evidence; reconcile only roles owned or consumed by in-scope classes; protect contract surface owned by out-of-scope classes; never infer absence as drift; and require operator approve, reject, or revise decisions before applying corrections. Attached repo sources and `init_progress_definition.yaml` SHALL remain read-only.

#### Scenario: In-scope source-of-truth correction is allowed
- **WHEN** repository evidence contradicts a contract field whose source of truth is an in-scope class
- **THEN** the skill presents the mismatch for operator decision and can write the approved correction to the common contract

#### Scenario: Out-of-scope producer remains untouched
- **WHEN** an in-scope repo lacks or consumes a surface whose producer is out of scope
- **THEN** the skill does not remove or rewrite the producer's canonical shape and records an approved consumer mismatch as `planning_implication: reconcile consumer drift`

#### Scenario: Operator approves no correction
- **WHEN** every proposed correction is rejected or no mismatch is found
- **THEN** the skill leaves `common_contract_definition.md` unchanged and still completes only under the gate contract

### Requirement: Context is typed, project-scoped, and class-list aware

`overmind context contract-reconciliation <project> --class <class>...` SHALL resolve the project and requested classes without shell output parsing. It SHALL require at least one unique class, validate each class exists and is ready with a present git repo, and emit deterministic runtime bindings: workspace/project roots, target contract, read-only definition and repo sources, allowed-write list, unique repo inspection paths, complete in-scope class mappings, out-of-scope class/state mappings, skill-relative assets, and the exact gate command.

#### Scenario: Multiple classes produce one deterministic context
- **WHEN** two ready classes with distinct repos are requested
- **THEN** the context contains both class mappings, both unique repo paths, every other configured class as out of scope, and one target/gate contract

#### Scenario: Shared repo retains class ownership information
- **WHEN** multiple requested classes resolve to one canonical repo path
- **THEN** the repo appears once in the unique inspection list and once per class in the class mapping list

#### Scenario: Invalid class binding blocks before agent launch
- **WHEN** a requested class is unknown, duplicated, not ready, has an empty path, or resolves to a missing/non-git directory
- **THEN** context returns an actionable diagnostic and the executor launches no agent

### Requirement: Common-contract quality gate preserves stable exit semantics

`overmind gate contract-reconciliation <project>` SHALL validate `<project>/common_contract_definition.md` using a TypeScript port of every check in `check_common_contract_definition_quality.sh`. A structurally and semantically valid artifact SHALL exit `0`; recoverable content failures SHALL exit `1` with actionable `missing: quality gate failed: ...` messages; missing, unreadable, or invalid runtime inputs SHALL exit `2` with a clear helper-failure diagnostic. Because `init_common_contract_definition.sh` still consumes the shell helper, Slice 4 SHALL retain that helper and SHALL run shared parity fixtures against both implementations until the initialization consumer migrates.

#### Scenario: Valid common contract passes
- **WHEN** all six required sections, document metadata, repository blocks, contract blocks, decisions, uncertainties, and planning signals satisfy the existing gate rules
- **THEN** the gate exits `0`

#### Scenario: Recoverable content issue returns one
- **WHEN** a required heading/key/block is absent or unfilled, an enum value is invalid, a count is inconsistent, or canonical shape is narrative rather than compact and structured
- **THEN** the gate exits `1` and identifies each repairable issue without changing the artifact

#### Scenario: Runtime input failure returns two
- **WHEN** the project path or target contract is missing, unreadable, or cannot be parsed by the validator runtime
- **THEN** the gate exits `2` and distinguishes the runtime failure from content repair

#### Scenario: Interim shell and TypeScript gates remain aligned
- **WHEN** shared valid and invalid common-contract fixtures run through both the surviving shell helper and `gate contract-reconciliation`
- **THEN** both implementations agree on pass, recoverable-content failure, and runtime-failure classification and equivalent quality findings

### Requirement: The model owns the gate repair loop

The skill SHALL instruct the model to run context, edit only the target, run the exact gate after every write or repair, repair all exit-1 findings, and stop without further edits on exit `2`. The generic executor SHALL not invoke the gate CLI. The existing exact cannot-pass and successful final response lines SHALL appear only in `SKILL.md`, not in the generic runner prompt.

#### Scenario: Gate reports recoverable problems
- **WHEN** the model receives gate exit `1`
- **THEN** it reads every reported issue, repairs only `common_contract_definition.md`, and reruns the gate before finishing

#### Scenario: Gate cannot execute
- **WHEN** the gate exits `2`
- **THEN** the model stops, reports the blocker, performs no further edits, and uses the skill's exact cannot-pass final line when applicable

#### Scenario: Generic prompt does not duplicate final text
- **WHEN** the shared prompt builder launches the reconciliation catalog step
- **THEN** it names the skill and runtime commands but contains neither skill-owned exact final response line

### Requirement: Reconciliation uses the shared executor with deterministic guards

The project reconciliation session SHALL be represented by a catalog `StepDefinition` using model phase `project_contract_reconciliation`, a class-list binding, a `mustExistUnchanged` guard for `init_progress_definition.yaml`, and required output `common_contract_definition.md`. The shared executor SHALL perform context, runner-config resolution, prompt construction, one inherited-stdio agent launch, guard verification, and required-output verification without a project-specific launcher or gate invocation.

#### Scenario: One class-list session launches through shared runner
- **WHEN** one or more ready classes are pending reconciliation
- **THEN** the executor resolves the configured model phase and launches exactly one agent session carrying every class binding

#### Scenario: Model changes the project definition
- **WHEN** the agent exits after modifying `init_progress_definition.yaml`
- **THEN** the shared guard returns failure even if the agent exit code is zero

#### Scenario: Required contract is removed
- **WHEN** the agent exits without `common_contract_definition.md` present
- **THEN** the shared required-output assertion fails the session and no reconciliation flag is set

#### Scenario: Runner config is invalid
- **WHEN** `.setup/models.md` lacks a valid registered `project_contract_reconciliation` phase
- **THEN** the flow returns an actionable config diagnostic before agent launch or reconciliation flag writes

### Requirement: Instruction and validator parity are proven before deletion

The migration SHALL record a comparison of the old script prompt, `project_contract_reconciliation_rule.md`, `check_common_contract_definition_quality.sh`, template, golden example, deterministic definition guard, and shell tests against their skill/context/gate/executor/TestScript owners. Every old instruction, check, exact completion line, runtime binding, and test behavior SHALL be preserved or explicitly documented as an architecture-driven change before legacy deletion.

#### Scenario: Parity inventory has no missing owner
- **WHEN** the old-to-new reconciliation inventory is completed
- **THEN** every row is marked kept, intentionally changed with rationale, or ported to a named deterministic/test owner, with no missing row
