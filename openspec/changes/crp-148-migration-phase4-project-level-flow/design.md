## Context

`design_docs/e2e_orchestrator_migration/04_migration_plan.md ## Slice 4 — Project-level flow (`overmind project reconcile`)` assigns responsibility-map rows 18–20 to a separate project lifecycle flow. Slice 3 already detects deferred or unreconciled class state and refuses feature execution, but its guidance still names staged legacy scripts and its read path temporarily accepts `.contract_reconciled_<class>` markers. The remaining live implementation is split between `persist_class_repo_attach.sh`, `project_contract_reconciliation.sh`, rule/helper files, and transaction code removed from the old feature e2e script.

The coordinator already provides workspace/project resolution, typed project-definition parsing, `InteractionPort`, runner config, the generic step executor, `AgentRunner`, and an explicit-root git adapter. The installer already packages skills for `.codex` and `.claude`. This slice must compose those seams rather than introduce another launcher or parsing path. The project directory can be its own git worktree, distinct from the ASDLC runtime-root worktree used for feature checkpoints.

Constraints are the zero-runtime-dependency rule, Node's built-in test runner, no new CLI options beyond the planned optional `--path`, same-slice removal of replaced shell, no direct edits to deployed runtime folders, and local `npm run verify` as the completion gate. Reconciliation remains interactive: attach inputs, model/operator decisions, and commit confirmation all use inherited stdio or `InteractionPort`.

## Goals / Non-Goals

**Goals:**

- Add the complete `overmind project reconcile [--path <project>]` use case and CLI adapter.
- Preserve deferred-class attach behavior, including policy C, validation, ordered prompts, blank-to-defer, and one retry after an invalid path.
- Reconcile every ready class whose definition field is not true in one shared-executor model session, then set all covered flags only on success.
- Migrate reconciliation instructions and the common-contract quality helper into an installed skill, TypeScript context, and TypeScript gate with explicit parity coverage.
- Preserve the project-worktree clean baseline, owned-path verification, rollback, and y/N commit semantics without dotfile markers.
- Replace Slice 3's legacy guidance and marker bridge, delete the last model-session shell and attach helper, and retain equal behavior-family coverage in TypeScript.

**Non-Goals:**

- Extension UI consumption and the Slice 5 formal parity/documentation sweep.
- Continuous contract-drift detection after first attachment.
- Automatic repo discovery, clone, or creation; the operator supplies existing local git repo paths.
- New auto-advance profiles, non-interactive class/commit flags, or a compatibility mode for legacy scripts and markers.
- Changes to `common_contract_definition.md`, `init_progress_definition.yaml`, or `.setup/models.md` formats beyond the already-decided `contract_reconciled` field lifecycle.

## Decisions

### D1 — One project-flow use case owns attach, reconcile, state, and commit

`runProjectReconciliationFlow(project, deps)` performs this order: resolve and validate the project; derive deferred classes; if a mutation may occur, establish the project-worktree baseline; prompt every deferred class in definition order; recompute ready/unreconciled classes; execute one reconciliation session for that full list; set all covered `contract_reconciled` fields; verify owned paths; then offer the commit. A blank attach response leaves that class deferred and does not prevent later class prompts. A failed attach is retried once; a failed second attempt leaves the class deferred and processing continues. Reconciliation starts only after the entire attach loop.

This remains one use case because clean-baseline and rollback correctness span the three responsibilities. The alternative—independent attach and session commands coordinated by the CLI—would expose partially ordered state and duplicate transaction policy in the adapter.

If no attachment is accepted and every ready class is already reconciled, the command reports no pending project reconciliation work and succeeds without loading runner config, launching an agent, mutating files, or asking for a commit.

### D2 — Project selection reuses workspace resolution and the CLI adds no hidden controls

`project reconcile` accepts only optional `--path <project>` and help. With `--path`, the same workspace-containment and project-definition validation used by `run` applies. Without it, project selection intentionally matches the current `overmind run` adapter semantics in `packages/asdlc-coordinator/src/cli/run.ts`: one project is selected automatically; multiple projects go through `InteractionPort` with a command-specific finish choice; selecting finish or closing the input stream returns zero without selecting a project; and no projects is an actionable failure. This is a Slice 4 change-level decision derived from the planned optional `--path`, not a new migration-document requirement. Reusing the existing selection behavior avoids two meanings for the same optional project argument. Unknown options and missing values fail before project mutation.

The CLI constructs the TTY, runner, filesystem, and git dependencies, loads the `project_contract_reconciliation` model phase only when a session is pending, renders typed diagnostics, and maps completed/no-op/operator-finished outcomes to zero and failures to non-zero. This keeps all flow policy in the use case and all rendering/exit policy in the adapter.

### D3 — Attachment is a deterministic TypeScript primitive with field invalidation

`repo/attach.ts` validates that the project contains `init_progress_definition.yaml`, the class exists, the supplied repo path is nonblank, resolves to a directory, and identifies a git worktree. It updates that class to `state: "ready"`, the canonical absolute `path`, and `policy: "C"`, then validates the written class record. The edit preserves unrelated definition content and reports parse/write/coherence failures as diagnostics.

Every successful attachment write clears `contract_reconciled` for that class, even when the caller is reattaching an already-ready class through the shared primitive. This implements `design_docs/e2e_orchestrator_migration/03_target_architecture.md ## Decisions` decision 9: repo identity changes invalidate reconciliation. Clearing means removing the true field or writing false according to the existing serializer's minimal stable convention; the parser result must be false either way. The project flow itself prompts only deferred classes, matching the Slice 4 scope.

The primitive replaces `persist_class_repo_attach.sh`; it does not spawn shell or awk. The post-write coherence test that currently exposes an already-written invalid record is retained as a typed failure, and transaction rollback in D6 prevents that state from escaping a git-backed project-flow run.

### D4 — Reconciliation is a catalog `StepDefinition` executed once with a class list

Export a project-reconciliation `StepDefinition` with one session action: skill `overmind-contract-reconciliation`, model phase `project_contract_reconciliation`, `mustExistUnchanged` guard for project `init_progress_definition.yaml`, and required output `common_contract_definition.md`. It is catalog data but not inserted into the numbered feature `STEP_CATALOG`, because it is a project lifecycle action rather than an `init_progress_definition.yaml` numbered phase.

Extend executor/runtime bindings with `classes: string[]` and a project path. The generic prompt builder emits repeated `--class <class>` arguments for the reconciliation context command; executor dispatch, config loading, prompt construction, runner invocation, guard verification, and required-output assertion remain the same implementation used by feature sessions. Duplicate repo paths are deduplicated for inspection in context while class-to-repo mappings remain complete. No project-specific agent launcher is allowed.

The action's deterministic guard preserves the old `cmp` guarantee on `init_progress_definition.yaml`; attached repositories are model read-only sources enforced by skill ownership instructions, while D6 independently restricts the project transaction's writable paths.

### D5 — Skill, context, and gate split model semantics from deterministic mechanics

Create `overmind-contract-reconciliation` using the migration guide's ownership split:

- `SKILL.md` inlines `project_contract_reconciliation_rule.md`: first-attach purpose; in-scope role attribution; out-of-scope producer protection; operator approve/reject/revise loop; only `common_contract_definition.md` writable; no source-repo edits; exact gate repair handling; and the existing success/blocker final lines.
- `assets/` contains `common_contract_definition_TEMPLATE.md` and `common_contract_definition_GOLDEN_EXAMPLE.md` as structural/style references, not normative rules.
- `context contract-reconciliation <project> --class <class>...` resolves the project, validates every requested class as ready with a present git repo, emits unique repo paths, complete in-scope class mappings, out-of-scope class/state lines, target/read-only/allowed-write paths, skill-relative assets, and the exact gate command. Missing/duplicate/unknown classes and invalid repo records produce actionable diagnostics.
- `gate contract-reconciliation <project>` ports `check_common_contract_definition_quality.sh` one-for-one to TypeScript and validates `<project>/common_contract_definition.md`, preserving `0` success, `1` recoverable content issues with actionable `missing: quality gate failed: ...` messages, and `2` missing/unreadable/invalid runtime inputs.

The model owns context/write/gate/repair. The executor does not invoke the gate CLI. The context builder is also called in-process before the session so guards and prompt bindings use typed data; the model receives the exact command so it can rebuild authoritative context as required by the skill contract.

`check_common_contract_definition_quality.sh` remains a live staged dependency of `init_common_contract_definition.sh`, so Slice 4 deliberately leaves the shell helper and its dedicated tests in place while adding the TypeScript reconciliation gate. This accepted interim duplication lasts until the initialization step migrates. Shared valid/invalid fixtures SHALL exercise both implementations in Slice 4 so their checks and exit classification cannot drift silently.

### D6 — The project worktree transaction protects a post-attach reconciliation baseline

Before the first accepted attach or pending reconciliation session, query the explicit project root through the git port. Missing git or a non-git project is a pass-through: the flow still updates state and reconciles, but skips cleanliness checks and commit interaction. A git worktree must be clean before any mutation; dirty or uninspectable status fails before attachment or agent launch.

For git projects, snapshot the two owned paths at two points: the initial clean state for full flow failure recovery, and the post-attach/pre-session state for reconciliation rollback. The only permitted changed paths at completion are `init_progress_definition.yaml` and `common_contract_definition.md`. After the model returns, first let the executor enforce definition immutability, then set all pending class flags, then inspect the worktree.

If any unexpected path changed, restore the two owned paths to the post-attach/pre-session snapshot, which removes reconciliation flags and contract edits while retaining successful attachments, leave unexpected paths untouched for operator inspection, report each unexpected path, and fail without a commit prompt. If the session or required-output/guard check fails, flags remain unset and the same post-attach rollback applies to contract edits. This makes the next run retry the full still-unreconciled class list without erasing accepted attachments.

The alternative of resetting the whole worktree is rejected because it would delete evidence and violate preservation of unrelated operator/model output. The alternative of leaving contract edits or flags after a failed transaction is rejected because it could incorrectly unblock feature execution.

### D7 — Commit is y/N over exactly two owned paths

When a git-backed reconciliation unit has owned changes, ask `Commit reconciliation results? [y/N]` through `InteractionPort`. Confirmation stages and commits only `init_progress_definition.yaml` and `common_contract_definition.md` with `Reconcile contract and attach repos`, then verifies the project worktree is clean. A staging, commit, or post-commit status failure is fatal and actionable. A negative/closed response leaves the valid owned changes uncommitted, reports that choice, and returns a clean stopped-by-operator outcome; because this command is separate, there is no feature phase to continue accidentally.

No-change units skip the prompt. Non-git projects also skip it. Marker files are absent from every pathspec and are never created, read, removed, or committed.

### D8 — `contract_reconciled` is the only completion source

Pending classes are ready entries whose `contract_reconciled` value is not true. A successful single session sets true for every class in its class-list binding only after executor success. A failed or partial session sets none. The next run batches every still-pending ready class again, making the idempotent reconciliation session the retry boundary.

Remove the legacy-marker fallback from pending-work detection. Feature-flow refusal names `overmind project reconcile --path <project>` for deferred and unreconciled classes. Legacy markers are ignored and left untouched; no migration reads them into definition state because the architecture explicitly chooses a clean break rather than long-lived compatibility.

### D9 — Parity is behavior-family based and shell removal happens last

Tests map responsibility rows 18–20 and the historical `deferred_class_*`, `reconciliation_*`, and `commit_reconciliation_*` families to TypeScript modules. Coverage includes ordered multi-class prompts, blank defer, invalid path plus one retry, attach without blueprint, all attaches before one session, shared-repo deduplication, failure retry state, dirty baseline refusal, read-only definition guard, owned/unexpected path verification and rollback, commit confirmation/decline/failure, context/rule instruction parity, and gate `0/1/2` behavior.

Only after that coverage and installer/setup tests pass are `persist_class_repo_attach.sh`, `project_contract_reconciliation.sh`, `project_contract_reconciliation_rule.md`, their staging entries, and their dedicated shell tests deleted. Deleting `project_contract_reconciliation_rule.md` extends the migration plan's literal script/test delete list but is required by its embedded-skill migration: the rule is inlined into `overmind-contract-reconciliation/SKILL.md`, and retaining the standalone file would create a second normative source contrary to the clean-break skill architecture. `check_common_contract_definition_quality.sh`, its staging entry, and `tests/ai_scripts/check_common_contract_definition_quality_tests.sh` remain for `init_common_contract_definition.sh`. Existing `project_setup_update_project.sh` callers must move to the TypeScript attach primitive or be updated within this change; no active reference to `persist_class_repo_attach.sh` remains.

## Risks / Trade-offs

- **Definition edits combine attachment and reconciliation state** → take the post-attach snapshot before the session so failure rollback can clear flags/contract edits while retaining accepted repo attachments.
- **A model writes an unexpected path outside the owned unit** → detect it through explicit-root project status, restore only owned reconciliation edits, leave the unexpected path visible, and fail with its path.
- **Multiple classes share one repo** → retain every class mapping for ownership reasoning but deduplicate physical repo inspection paths in context and tests.
- **The TypeScript gate and shell quality helper drift during their interim coexistence** → retain the shell helper for `init_common_contract_definition.sh`, drive both implementations with shared parity fixtures, and defer consolidation to that initialization step's migration.
- **Legacy markers silently keep projects unblocked** → remove the bridge in the same change and add tests proving a marker without a true field remains pending with new-command guidance.
- **Installer/setup deletion breaks fresh or update runtimes** → stage the skill to both supported runner targets first, test fresh/update repair, remove only reconciliation script/rule staging, retain the initialization quality-helper staging, and assert `.overmind/overmind.js` remains the only CLI.
- **Commit failure after flags are written leaves local changes** → return failure with the two owned paths still inspectable; do not claim completion or run feature work. A later command can retry commit or reconciliation after the operator restores a clean baseline.

## Migration Plan

1. Record the old rule/prompt/helper/guard/test responsibility inventory and the row 18–20 behavior-family mapping.
2. Port common-contract validation and context, create the skill payload/assets, register CLI handlers, and prove gate/instruction/installer parity.
3. Add the deterministic attach primitive and definition-field mutation helpers with parser, invalidation, coherence, and failure tests.
4. Add class-list runner bindings and the project-reconciliation catalog definition; prove one generic-executor call, one model phase, guard enforcement, and multi/shared-repo context.
5. Add the explicit-project-root transaction/rollback/commit operations and compose `runProjectReconciliationFlow` over injected interaction, runner, git, and filesystem dependencies.
6. Wire `project reconcile` argument/project selection and diagnostics; switch feature pending-work guidance and remove marker recognition.
7. Update installer/setup/operator docs and all callers, delete replaced scripts/rule/helper/tests and stale staging references, then run focused suites and `npm run verify`.

Rollback before release is a code revert. During implementation, shell deletion is last so a failed intermediate branch can be reverted without state migration. After use, rollback requires restoring any affected project's two owned files from git or the operator-approved commit; attached repo paths are ordinary definition fields and no hidden marker migration exists.

## Open Questions

- None. Slice 4's command shape, status field, interaction semantics, transaction ownership, shared-executor requirement, and clean-break policy are fixed by the migration design documents.
