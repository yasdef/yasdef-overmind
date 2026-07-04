## ADDED Requirements

### Requirement: Project reconciliation is a separate CLI flow

The system SHALL expose `overmind project reconcile [--path <project>]` as the only project-level entrypoint for deferred-class attachment and contract reconciliation. The command SHALL accept no operational options other than optional `--path` and help, SHALL resolve projects through the existing workspace boundary, and SHALL perform no feature selection or feature-step execution.

#### Scenario: Explicit project is reconciled
- **WHEN** the operator runs `overmind project reconcile --path <project>` with a valid project inside the workspace
- **THEN** the CLI resolves that project and runs only the project reconciliation flow

#### Scenario: One project is selected automatically
- **WHEN** `--path` is omitted and the workspace contains exactly one valid project
- **THEN** the CLI selects it, prints the selection, and continues without a menu

#### Scenario: Multiple projects use interaction selection
- **WHEN** `--path` is omitted and multiple projects are available
- **THEN** the CLI mirrors `overmind run` by offering those projects and a command-specific finish choice through `InteractionPort`

#### Scenario: Project selection can finish cleanly
- **WHEN** the operator selects finish or the input stream closes during multi-project selection
- **THEN** the CLI exits zero without selecting a project or performing project mutations

#### Scenario: Invalid arguments fail before mutation
- **WHEN** `--path` lacks a value, an unknown option is supplied, or the resolved path is outside the workspace or lacks `init_progress_definition.yaml`
- **THEN** the CLI exits non-zero with an actionable diagnostic and performs no attach, agent, state, or git mutation

### Requirement: Deferred class attachment preserves policy-C interaction semantics

The flow SHALL enumerate deferred class records in definition order and prompt each class through `InteractionPort` with the policy-C meaning. A blank or closed response SHALL retain that class as deferred. A nonblank response SHALL be passed to the deterministic attach primitive; one invalid attempt SHALL render its diagnostic and allow exactly one retry, after which failure or blank input SHALL retain the class as deferred and continue to later classes.

#### Scenario: Valid repo attaches a deferred class
- **WHEN** the operator supplies an existing local git repo for a deferred class
- **THEN** its record becomes `state: "ready"`, stores the canonical absolute `path`, stores `policy: "C"`, and has no true `contract_reconciled` value

#### Scenario: Blank input keeps a class deferred
- **WHEN** the operator submits blank input for a deferred class
- **THEN** that class record remains unchanged and the flow continues to the next deferred class

#### Scenario: Invalid path is retried once
- **WHEN** the first supplied path is empty only after trimming, missing, not a directory, or not a git worktree
- **THEN** the flow reports the specific validation problem and offers one further path attempt for that class

#### Scenario: Second invalid or blank response ends that class attempt
- **WHEN** the retry is invalid or blank
- **THEN** the class remains deferred, no third prompt is issued, and later deferred classes are still processed

#### Scenario: Blueprint file is not required for attachment
- **WHEN** a deferred class has no class blueprint but the operator supplies a valid repo
- **THEN** the attachment succeeds because the class definition and repo, not a blueprint file, define attachment eligibility

### Requirement: Attachment writes are deterministic and invalidate prior reconciliation

The TypeScript attach primitive SHALL validate project, class, and repo inputs; preserve unrelated definition content; update only the selected class lifecycle fields; and validate the resulting class record. Every successful attachment or reattachment SHALL clear that class's `contract_reconciled` completion state. Failures SHALL return typed actionable diagnostics rather than spawning shell or parsing shell output.

#### Scenario: Reattachment clears completion
- **WHEN** the attach primitive changes the repo path of a class whose `contract_reconciled` field is true
- **THEN** the resulting parsed class record is ready with policy C and `contractReconciled` false

#### Scenario: Unknown class is rejected
- **WHEN** the attach primitive receives a class absent from `meta_info.class_repo_paths`
- **THEN** it fails with a diagnostic naming the class and definition without changing the file

#### Scenario: Post-write coherence failure is surfaced
- **WHEN** the resulting class record fails the shared class-repo-path coherence validation
- **THEN** the primitive returns a failure diagnostic and the project flow restores its transaction-owned definition state

### Requirement: The project worktree must have a safe mutation baseline

Before the first accepted attachment or pending reconciliation session, the flow SHALL inspect the explicit project-folder git root. A git worktree SHALL be clean before any mutation. Missing git or a project that is not a git worktree SHALL use pass-through behavior without cleanliness or commit operations. A no-op run SHALL not require a git baseline.

#### Scenario: Dirty project refuses before attachment
- **WHEN** a git-backed project has any tracked, staged, or untracked change before project work begins
- **THEN** the flow exits non-zero before changing class state or launching reconciliation and names the project worktree cleanliness requirement

#### Scenario: Non-git project passes through
- **WHEN** the project folder is not a git worktree and project reconciliation is pending
- **THEN** attachment, reconciliation, and definition flag updates can complete without a commit prompt

#### Scenario: No pending work is a side-effect-free success
- **WHEN** no deferred class is attached and every ready class has `contract_reconciled: true`
- **THEN** the command reports no pending work and succeeds without runner-config loading, agent launch, file mutation, or commit interaction

### Requirement: Pending ready classes reconcile in one batch after attachment

After all deferred-class prompts finish, the flow SHALL recompute the class records and select every ready class whose `contract_reconciled` value is not true. It SHALL execute the project reconciliation catalog step exactly once with the complete class list. Repositories shared by multiple classes SHALL be inspected once while all class-to-repo mappings remain in context.

#### Scenario: All accepted attachments precede reconciliation
- **WHEN** multiple deferred classes receive valid repo paths
- **THEN** every attachment write completes before one reconciliation session begins with all newly ready unreconciled classes

#### Scenario: Existing unreconciled ready class joins the batch
- **WHEN** a class was already ready before the command but its `contract_reconciled` field is absent or false
- **THEN** it is included with newly attached classes in the same session

#### Scenario: Shared repo is deduplicated for inspection
- **WHEN** two pending classes resolve to the same canonical repo path
- **THEN** the session context lists one unique inspection path and retains both in-scope class mappings

#### Scenario: Reconciliation failure does not reprompt attachment
- **WHEN** accepted attachments are followed by an agent, context, guard, or required-output failure
- **THEN** the flow fails without treating reconciliation failure as a repo-path failure or consuming another attach response

### Requirement: Reconciliation flags are success-bound and marker-free

`meta_info.class_repo_paths.<class>.contract_reconciled` SHALL be the sole completion source. The flow SHALL set it true for every class in the successful batch only after the shared executor succeeds. A failed or partial batch SHALL set none of those flags, so a later run retries the full pending batch. Legacy `.contract_reconciled_<class>` files SHALL neither satisfy pending-work detection nor be created, changed, removed, or committed.

#### Scenario: Successful batch marks every covered class
- **WHEN** one reconciliation session succeeds for multiple pending ready classes and transaction verification passes
- **THEN** every covered definition record has `contract_reconciled: true`

#### Scenario: Failed batch marks no covered class
- **WHEN** the reconciliation session or deterministic post-session checks fail
- **THEN** every class in that batch remains unreconciled and the next command selects the complete batch again

#### Scenario: Legacy marker no longer unblocks a class
- **WHEN** a ready class lacks `contract_reconciled: true` but has `.contract_reconciled_<class>`
- **THEN** the class remains pending and the marker is left untouched

### Requirement: Project transaction permits only two owned paths

For git-backed projects, the completed reconciliation unit SHALL contain changes only to `init_progress_definition.yaml` and `common_contract_definition.md`. The flow SHALL detect every other changed path after the session. On unexpected changes or session failure, it SHALL restore reconciliation-owned contract edits and flags to the post-attach baseline, retain successful attachment fields, leave unexpected paths available for inspection, report them, and fail without offering a commit.

#### Scenario: Expected owned changes pass verification
- **WHEN** attachment and reconciliation change only the definition and common contract
- **THEN** transaction verification succeeds and proceeds to the commit decision when those paths differ from HEAD

#### Scenario: Unexpected model output triggers scoped rollback
- **WHEN** reconciliation creates or modifies a path outside the two owned files
- **THEN** the flow names that path, restores contract edits and reconciliation flags, preserves accepted attachments, leaves the unexpected path untouched, and exits non-zero

#### Scenario: Definition guard catches model mutation
- **WHEN** the model session changes `init_progress_definition.yaml`
- **THEN** the shared executor's deterministic guard fails the session and the transaction leaves no reconciliation flags or model contract edits

### Requirement: Commit interaction is scoped and conservative

When a verified git-backed reconciliation unit has owned changes, the flow SHALL ask `Commit reconciliation results? [y/N]` through `InteractionPort`. Confirmation SHALL stage and commit exactly the two owned paths using message `Reconcile contract and attach repos`, then verify a clean project worktree. Any other response SHALL leave the verified owned changes uncommitted and return a stopped-by-operator success outcome. No-change and non-git flows SHALL skip the prompt.

#### Scenario: Operator confirms commit
- **WHEN** the operator answers yes to a verified changed unit
- **THEN** exactly `init_progress_definition.yaml` and `common_contract_definition.md` are committed and the project worktree is verified clean

#### Scenario: Operator declines commit
- **WHEN** the operator answers no or closes input
- **THEN** the owned changes remain uncommitted, the command reports that choice, and no feature flow starts

#### Scenario: Commit operation fails
- **WHEN** staging, committing, or post-commit status verification fails
- **THEN** the CLI exits non-zero with an actionable project-root git diagnostic and does not claim reconciliation completion

### Requirement: Feature flow hands project work to the new command

Feature pending-work detection SHALL reject deferred or ready-unreconciled class state before feature selection and SHALL render an exact runnable `overmind project reconcile --path <project>` guidance command. It SHALL use definition fields only and SHALL continue to detect rather than execute project lifecycle work.

#### Scenario: Deferred class blocks feature flow with new guidance
- **WHEN** `overmind run` finds any non-ready configured class
- **THEN** it exits non-zero before feature selection and names `overmind project reconcile --path <project>`

#### Scenario: Unreconciled ready class blocks feature flow with new guidance
- **WHEN** `overmind run` finds a ready class without `contract_reconciled: true`
- **THEN** it exits non-zero before feature selection with the same project-reconcile command and no legacy-script guidance

### Requirement: Legacy project-flow shell is removed after parity

After TypeScript behavior-family coverage is in place, the source, staging, docs, and active tests SHALL contain no invocation of `persist_class_repo_attach.sh` or `project_contract_reconciliation.sh`, and no staging of `project_contract_reconciliation_rule.md`. The dedicated shell tests SHALL be replaced by TypeScript coordinator, installer, and setup tests covering responsibility-map rows 18–20.

#### Scenario: Replaced shell surface is absent
- **WHEN** Slice 4 is complete
- **THEN** fresh/update setup uses the bundled CLI and installed skill without copying either replaced script or the standalone reconciliation rule, while retaining the common-contract quality helper required by project initialization

#### Scenario: Historical behavior families have owners
- **WHEN** the Slice 4 parity map is reviewed
- **THEN** every deferred-class, reconciliation-session, and reconciliation-commit behavior family is covered by a named TypeScript test or an explicit architecture divergence
