## 1. Migration Inventory and Test Map

- [x] 1.1 Record a row 18–20 responsibility inventory mapping `persist_class_repo_attach.sh`, `project_contract_reconciliation.sh`, `project_contract_reconciliation_rule.md`, `check_common_contract_definition_quality.sh`, deterministic guards, assets, staging entries, and active callers to their new TypeScript/skill owners.
- [x] 1.2 Record the historical `deferred_class_*`, `reconciliation_*`, and `commit_reconciliation_*` behavior families and assign each to a named TypeScript, installer, or setup test, documenting any architecture-driven divergence.
- [x] 1.3 Add failing coordinator tests for the project reconciliation flow ordering, retry/state lifecycle, transaction, marker-free pending detection, and CLI outcome requirements before implementing the flow.

## 2. Contract Reconciliation Skill and Gate

- [x] 2.1 Port every `check_common_contract_definition_quality.sh` check and stable `0`/`1`/`2` result into `validate/contract-reconciliation.ts`, register `gate contract-reconciliation`, and run shared valid/invalid parity fixtures against both the TypeScript gate and the shell helper retained for `init_common_contract_definition.sh`.
- [x] 2.2 Implement and register `context contract-reconciliation <project> --class <class>...` with typed project/class validation, unique repo paths, complete in-scope/out-of-scope mappings, runtime paths, allowed writes, skill-relative assets, and exact gate command tests.
- [x] 2.3 Create `packages/installer/_data/skills/overmind-contract-reconciliation/SKILL.md` by inlining the durable legacy rule, gate loop, ownership constraints, operator decision flow, and exact final lines without duplicating them in generic prompts.
- [x] 2.4 Copy `common_contract_definition_TEMPLATE.md` and `common_contract_definition_GOLDEN_EXAMPLE.md` into the skill assets and add the old-prompt/rule/helper-to-new-owner parity table with no missing instruction or deterministic check.
- [x] 2.5 Register the canonical skill in the installer and setup fresh/update paths for both `.codex` and `.claude`, with tests for complete install, stale repair, incomplete payload failure, and no CLI copy in skill folders.

## 3. Deterministic Class Attachment

- [x] 3.1 Add definition mutation helpers that preserve unrelated YAML, set `state: "ready"`, canonical `path`, and `policy: "C"`, clear `contract_reconciled`, and round-trip through the typed project-definition parser.
- [x] 3.2 Implement `repo/attach.ts` validation for project, known class, nonblank existing directory, git worktree, canonical path, write failures, and post-write class-record coherence without shell or awk.
- [x] 3.3 Add attachment tests for valid policy-C writes, missing blueprint acceptance, unknown class, invalid paths, reattachment invalidation, unrelated-content preservation, and coherence failure diagnostics.

## 4. Shared Executor Class-List Session

- [x] 4.1 Extend runner bindings, context dispatch, and prompt construction with project path plus ordered class lists and repeated `--class` arguments while preserving all existing feature and single-class behavior.
- [x] 4.2 Add the project reconciliation catalog `StepDefinition` outside the numbered feature catalog with skill `overmind-contract-reconciliation`, model phase `project_contract_reconciliation`, definition immutability guard, and required common-contract output.
- [x] 4.3 Add shared-executor tests proving one session for all pending classes, inherited class mappings with shared-repo deduplication, config/context failure before launch, non-zero agent propagation, definition mutation failure, required-output failure, and no gate invocation.

## 5. Project Worktree Transaction and Flow

- [x] 5.1 Extend the explicit-root git port with project clean-status, owned-path status/stage/commit, and post-commit verification operations, including missing-git and non-worktree typed results.
- [x] 5.2 Implement project transaction snapshots and scoped restoration for the initial definition plus post-attach definition/common-contract baseline, preserving accepted attachments while clearing failed reconciliation edits and flags.
- [x] 5.3 Implement `runProjectReconciliationFlow` over injected interaction, attachment, executor, filesystem, and git dependencies in the specified order: baseline, all attach prompts, pending recomputation, one session, flags, owned-path verification, commit decision.
- [x] 5.4 Add flow tests for ordered multi-class prompts, blank defer, exactly one invalid-path retry, later-class continuation, all attaches before reconciliation, existing ready pending classes, successful/failed flag batches, and no-op side-effect freedom.
- [x] 5.5 Add transaction tests for dirty baseline refusal, non-git pass-through, unexpected-path reporting with scoped rollback, session/guard rollback, owned-path-only commit, declined commit, commit failure, and clean post-commit verification.

## 6. CLI and Feature-Flow Cutover

- [x] 6.1 Add `overmind project reconcile [--path <project>]` parsing, explicit/automatic/interactive project selection, dependency construction, diagnostic rendering, and exit mapping with no additional operational flags.
- [x] 6.2 Add CLI tests proving project selection matches `overmind run` semantics for explicit path, single-project auto-selection, multi-project selection, finish and closed-input exit zero, plus invalid path/options, no-op, success, stopped commit, and failure outcomes.
- [x] 6.3 Remove legacy marker recognition from pending-work detection and change deferred/unreconciled feature-flow diagnostics to the exact runnable `overmind project reconcile --path <project>` command, with tests proving markers no longer unblock work.
- [x] 6.4 Update `overmind/README.md`, `QUICKRUN.md`, setup output, and repository command references to describe the separated project command and its clean-worktree/commit behavior.

## 7. Clean Break and Verification

- [x] 7.1 Move every active `project_setup_update_project.sh` or setup caller from `persist_class_repo_attach.sh` to the TypeScript attach path and verify no runtime workflow depends on the helper.
- [x] 7.2 Delete `persist_class_repo_attach.sh`, `project_contract_reconciliation.sh`, the standalone reconciliation rule, their source/update staging entries, and their dedicated shell tests; retain `check_common_contract_definition_quality.sh`, its staging, and its dedicated tests for `init_common_contract_definition.sh`.
- [x] 7.3 Update `AGENTS.md` in the same change if canonical test commands, paths, or conventions changed, and assert no active source, test, setup, or operator-doc reference names a deleted legacy flow.
- [x] 7.4 Run focused coordinator and installer tests, applicable `tests/ai_scripts/` setup/update suites, and the row 18–20 parity checklist; resolve every failure before broad verification.
- [x] 7.5 Run `npm run verify`, confirm `packages/asdlc-coordinator` runtime dependencies remain empty, run `openspec validate crp-148-migration-phase4-project-level-flow --strict`, and run `git diff --check`.
