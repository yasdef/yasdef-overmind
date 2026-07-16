## ADDED Requirements

### Requirement: Documentation layers have distinct responsibilities
The repository SHALL use root `README.md` as the repository and product entry point, `overmind/README.md` as the durable operator guide, generated `quickrun.md` as the installed-workspace command cheat sheet, `overmind/init_progress_definition_sequence_diagram.md` as the canonical end-to-end process map, and `*_rule.md` files as the authoritative sources for operational and quality rules.

#### Scenario: Reader chooses the correct document
- **WHEN** a reader needs product onboarding, operational workflow guidance, installed command reminders, process sequencing, or exact normative behavior
- **THEN** the documentation map directs that reader respectively to root `README.md`, `overmind/README.md`, generated `quickrun.md`, the canonical process map, or the owning `*_rule.md`

### Requirement: Root README is a concise product entry point
Root `README.md` SHALL explain Overmind's purpose and maturity, installation, the shortest first-time happy path, the high-level lifecycle, essential operator-facing concepts, human checkpoints, produced planning outputs, public commands, current limitations, contributor verification, and links to deeper operational documentation.

#### Scenario: New reader follows the happy path
- **WHEN** a new reader opens root `README.md`
- **THEN** the reader can understand what Overmind currently does, install it, identify the commands from workspace creation through worker assignment, and locate detailed operator guidance without reading phase internals

#### Scenario: Product boundary is clear
- **WHEN** a product owner reads the product overview and lifecycle
- **THEN** the README states that Overmind currently produces and assigns planning artifacts and does not claim automatic implementation execution or worker-feedback ingestion

### Requirement: Operator README covers the complete lifecycle uniformly
`overmind/README.md` SHALL cover workspace setup, project creation and class configuration, repository reconciliation, project initialization, feature intake and BR clarification, EARS generation and optional review, contract and surface context, technical planning and optional semantic review, and worker registration and assignment handoff at comparable operator-facing detail.

#### Scenario: Every canonical phase is represented
- **WHEN** the operator guide is compared with the canonical step catalog
- **THEN** steps `1`, `1.1`, `2`, `3`, `4.1`, `4.2`, `5`, `5.1`, `6`, `7`, `7.1`, `8`, `8.1`, `8.2`, `8.3`, and `8.4` are represented directly or within a clearly named stage, with optional and per-class behavior identified where it affects the operator

#### Scenario: Stage descriptions use consistent information
- **WHEN** an operator reads any lifecycle stage
- **THEN** the guide identifies the stage purpose, public entry command, material prerequisite or input, primary output, and operator decision or checkpoint where applicable without expanding one stage into validator-level mechanics

### Requirement: Public commands and lifecycle boundaries are actionable
The READMEs SHALL distinguish `project create`, `project add-class`, `project reconcile`, `project init`, `run`, `run --resume`, `status`, `worker register`, and `worker assign` by the operator outcome each command owns.

#### Scenario: Project prerequisite blocks feature planning
- **WHEN** a reader needs to understand why feature planning cannot start before project initialization, repository attachment, or reconciliation is complete
- **THEN** the operator guide names the owning `project init` or `project reconcile` command and explains the resulting project state without copying internal checkpoint algorithms

#### Scenario: Planning handoff is reached
- **WHEN** `implementation_plan.md` has been produced and reviewed
- **THEN** the documentation directs the operator to register and assign workers and identifies this as a handoff rather than automatic implementation execution

### Requirement: Recovery semantics are documented once
`overmind/README.md` SHALL define exit `0` as success or continuation, exit `1` as a recoverable issue requiring artifact repair or same-step rerun/resume, and exit `2` as a blocking runtime or configuration failure requiring escalation or operator intervention. It SHALL explain `run`, `--resume`, and `status` as one recovery workflow.

#### Scenario: Recoverable gate failure
- **WHEN** a workflow gate returns exit `1`
- **THEN** the operator guide tells the reader to follow diagnostics and rerun or resume the reported owning step without presenting a fatal-runtime interpretation or a phase-specific field-edit algorithm

#### Scenario: Blocking gate failure
- **WHEN** validation cannot run and returns exit `2`
- **THEN** the operator guide distinguishes the condition from repairable content failure and directs the reader to resolve or escalate the runtime/configuration blocker

### Requirement: Human checkpoints and outputs are visible
The READMEs SHALL identify operator decisions and manual review responsibilities that materially affect the process, including project/class configuration, repository reconciliation, BR clarification, optional reviews, manual inspection of `requirements_ears.md` and `implementation_plan.md`, and worker assignment.

#### Scenario: Product owner reviews planning outputs
- **WHEN** feature planning reaches its final outputs
- **THEN** the documentation explicitly identifies `requirements_ears.md` and `implementation_plan.md` as critical human-review checkpoints before implementation handoff

### Requirement: README detail remains at the operator-visible level
The READMEs MUST NOT duplicate literal artifact-field formats, validation algorithms, mutable-artifact-to-gate inventories, deterministic ledger mechanics, or phase-specific repair procedures that belong to an owning rule, skill, or executable contract. They SHALL summarize only the operator-visible effect and provide navigation to the detailed owner when useful.

#### Scenario: Detailed phase rule exists
- **WHEN** a phase has an exact field or validation contract in an owning source
- **THEN** the README describes the phase outcome and operator action without reproducing that contract

#### Scenario: CRP changes an internal validation mechanic
- **WHEN** a future CRP changes internal enforcement without changing a public command, operator decision, output, or recovery action
- **THEN** the README does not receive an isolated changelog paragraph for that CRP

### Requirement: README duplication and historical accretion are removed
The refactor SHALL remove duplicate phase explanations and command inventories, historical release-note prose, internal design-decision shorthand, unfinished navigation text, and stale guidance while retaining current limitations that affect users.

#### Scenario: Same topic appears in multiple documents
- **WHEN** the same command or phase is currently explained in root `README.md`, `overmind/README.md`, and generated `quickrun.md`
- **THEN** one document owns the detailed explanation and the others contain only the shorter audience-appropriate summary or navigation link

### Requirement: Documentation matches executable sources
Workflow identifiers, optional and per-class behavior, public commands, installed paths, outputs, and exit semantics stated in the READMEs SHALL match the coordinator step catalog, CLI, installer, generated quick-run guide, and runner contracts current at implementation time.

#### Scenario: Documentation refactor is verified
- **WHEN** the README rewrite is complete
- **THEN** every documented public command, canonical phase, primary output, optional/per-class marker, cross-document link, and exit classification has been checked against its executable or authoritative source

### Requirement: Runtime behavior remains unchanged
The documentation refactor MUST NOT add or change a CLI command or flag, workflow transition, artifact schema, validator rule, runtime asset, dependency, or deployment behavior.

#### Scenario: CRP-168 is applied
- **WHEN** the implementation diff is reviewed
- **THEN** changes are limited to the two READMEs, the process-map wording or navigation needed for consistency, and the CRP artifacts themselves
