## 1. Class Metadata Model And Mutation

- [ ] 1.1 Add typed class policy/state/path records for policy `A|B|C`, including coherence rules that allow `A` only as deferred with an empty path and require ready records to carry a non-empty canonical path.
- [ ] 1.2 Extend project-definition parsing to accept classless `project_classes: []` and `class_repo_paths: {}` plus policy `A` without weakening diagnostics for malformed class records.
- [ ] 1.3 Add a deterministic mutation that inserts or replaces class records, keeps `project_classes` and `class_repo_paths` in canonical class order, clears `contract_reconciled` on changed records, and preserves unrelated metadata and the complete `steps` block.
- [ ] 1.4 Add parser/mutation tests for empty definitions, each valid policy/state shape, incoherent combinations, canonical ordering, replacement, reconciliation invalidation, YAML escaping, and byte-preservation outside the owned class blocks.

## 2. Reusable Class-Management Primitive

- [ ] 2.1 Add a focused class-management module with a typed result and the add-new-class/all-done session loop over `backend|frontend|mobile|infrastructure`.
- [ ] 2.2 Implement the policy menu (`A|B|C|escape/back`), policy-A deferred proposal, and policy-B/C add-now/add-later branch while keeping project type metadata untouched.
- [ ] 2.3 Reuse existing non-empty-directory path resolution; on validation failure emit the diagnostic and return to the add-now/add-later decision for retry or defer.
- [ ] 2.4 Implement existing-class current/proposed rendering, identical-proposal no-op, explicit replacement confirmation, and declined/escaped proposal discard.
- [ ] 2.5 Stage accepted proposals in memory and atomically persist once on all done; treat input closure before all done as a clean stop with no session mutation.
- [ ] 2.6 Add the clean-project-worktree baseline and one optional project-repository commit for a changed session, returning typed inspection/stage/commit outcomes and preserving an explicitly declined uncommitted update.
- [ ] 2.7 Add primitive tests covering multiple additions, immediate finish, every policy branch, escape, invalid-path retry/defer, new and existing classes, confirmed/declined replacement, EOF rollback, dirty baseline, and one-commit session behavior.

## 3. Base Project Creation Split

- [ ] 3.1 Refactor `createProject` to capture only project name and project-level type before mutation and render `project_classes: []` plus `class_repo_paths: {}` in the initial definition.
- [ ] 3.2 Preserve existing name normalization, metadata append, template preservation, folder creation, git initialization/identity fallback, initial commit, typed diagnostics, and failure cleanup for the classless base project.
- [ ] 3.3 After successful base creation, ask whether to add project classes; on yes invoke the shared class-management primitive with the created project root, and on no/EOF finish without rolling back the project.
- [ ] 3.4 Update project-creation unit and CLI tests for classless success, type re-prompting before creation, optional handoff yes/no/EOF, unchanged base-creation failures, and no repeated project selection.

## 4. Standalone Class Command

- [ ] 4.1 Add argumentless `overmind project add-class-and-repo` dispatch and usage output without introducing a path flag or changing unrelated project verbs.
- [ ] 4.2 Extract/reuse project resolution so invocation inside a project selects it, one discovered project auto-selects, multiple projects prompt with a finish choice, and the selected project is printed before class management.
- [ ] 4.3 Wire the same interaction, temp-file, and project-git seams used by the deterministic primitive through `CliAdapterOverrides` for tests.
- [ ] 4.4 Add CLI tests for current-project, single-project, multi-project, finish, no-project, unknown-argument, EOF, successful mutation, declined replacement, and commit rendering paths.

## 5. Reconciliation Ownership Change

- [ ] 5.1 Remove deferred-class attachment prompts and the attach primitive dependency from `runProjectReconciliationFlow`; compute pending work only from ready classes without `contract_reconciled: true`.
- [ ] 5.2 Update `project reconcile` guidance to identify `project add-class-and-repo` as the class/repository mutation command and describe reconciliation-only behavior.
- [ ] 5.3 Update pending-work/readiness diagnostics so missing or deferred class configuration directs operators to `project add-class-and-repo`, while ready unreconciled classes continue to direct them to `project reconcile`.
- [ ] 5.4 Update reconciliation, pending-work, and CLI tests for deferred-class no-op behavior, ready-class reconciliation, unchanged project type, and absence of repository-path prompts.

## 6. Documentation And Compatibility

- [ ] 6.1 Update `README.md` and `QUICKRUN.md` with the two entry points, class-policy/state table, post-create handoff, later replacement confirmation, and required class-management-before-reconciliation order.
- [ ] 6.2 Confirm existing definitions with absent class policy remain readable and add compatibility fixtures without rewriting deployed/runtime project files.
- [ ] 6.3 Confirm `packages/asdlc-coordinator/package.json` keeps empty runtime dependencies and no new CLI flags or parallel lifecycle commands were introduced.

## 7. Verification

- [ ] 7.1 Run `npm run test --workspace asdlc-coordinator`, `npm run test --workspace overmind-installer`, and focused changed-flow tests.
- [ ] 7.2 Run `npm test`, `npm run verify`, `git diff --check`, and strict OpenSpec validation for `crp-158-split-project-init-and-class-management`.
