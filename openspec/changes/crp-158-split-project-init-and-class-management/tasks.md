## 1. Policy-Aware Attachment

- [x] 1.1 Rewrite `validateClassRecordCoherence` in `packages/asdlc-coordinator/src/repo/attach.ts` to require a `policy` on every class row and accept only `A|B|C`, with `A` valid only alongside `state: "deferred"` and an empty path, `ready` bound to a non-empty canonical path, and `deferred` bound to an empty path; drop the current missing-policy tolerance and the `B|C` restriction.
- [x] 1.2 Replace the hardcoded `policy: "C"` in `applyClassAttachment` (`src/parse/project-definition.ts`) with the policy supplied by the caller, and thread that policy through `attachClassRepo`.
- [x] 1.3 Update parse/attach tests for each policy value, incoherent policy/state combinations, and preservation of unrelated metadata and the `steps` block.

## 2. Reconcile Policy Prompt

- [x] 2.1 Treat deferred policy `A` classes as intentionally repo-less for `overmind run`, while allowing `src/orchestrator/run-project-reconciliation-flow.ts` to prompt them so the operator can keep `A` or convert them to `B`/`C`.
- [x] 2.2 Prompt deferred policy `B`/`C` classes for repository paths after durably recording the selected policy, while preserving the existing validation, single-retry, blank-defers, and closed-input rules.
- [x] 2.3 Pass the selected policy into attachment for `B`/`C`.
- [x] 2.4 Update the reconciliation-intent guidance to name `overmind project add-class` as the class-membership command.
- [x] 2.5 Update reconciliation and pending-work tests for policy-`A` non-blocking behavior, public `A` to `B`/`C` binding through reconcile, recorded `B`/`C` policy, selected-policy persistence after invalid path or EOF, blank/EOF path handling, invalid policy/path retry, repeated prompting of still-deferred `B`/`C` classes, and distinct repo-binding vs contract-reconciliation guidance.

## 3. Creation Without Repository Capture

- [x] 3.1 Remove repository-path capture and validation from `createProject` (`src/capture/project.ts`).
- [x] 3.2 Allow an empty class selection and seed every selected class as `state: "deferred"`, `path: ""`, `policy: "A"` in canonical order.
- [x] 3.3 Report after creation that `overmind project reconcile` binds repositories.
- [x] 3.4 Preserve existing name normalization, metadata append, template preservation, folder creation, git initialization/identity fallback, initial commit, typed diagnostics, and failure cleanup.
- [x] 3.5 Update project-creation unit and CLI tests for classless creation, deferred/`A` class rows, absence of repository prompts, and unchanged base-creation failures.

## 4. Class Membership Command

- [x] 4.1 Add the membership mutation to `src/parse/project-definition.ts`: insert a class row or reset an existing one to deferred/empty/`A`, clearing `contract_reconciled`, in canonical order across `project_classes` and `class_repo_paths` while preserving unrelated class row content.
- [x] 4.2 Add `src/capture/project-class.ts` with the add/change primitive and a typed result, showing current policy/state/path before a change and requiring explicit confirmation.
- [x] 4.3 Add the argumentless `overmind project add-class` verb in `src/cli/run.ts` with existing project discovery (current project, single project, interactive selection) and no path flag.
- [x] 4.4 Apply the project-repository transaction boundary: clean-worktree baseline before membership prompts, one optional commit after the write, typed diagnostics on inspection/stage/commit failure.
- [x] 4.5 Add tests for add, change/reset, declined confirmation, closed input, canonical ordering, `contract_reconciled` clearing, project selection paths, unknown argument, dirty baseline before membership prompts, and commit rendering.

## 5. Documentation

- [x] 5.1 Update `README.md` and `QUICKRUN.md` with the create → reconcile flow, the class-policy meanings, `overmind project add-class`, and the reset-then-reconcile path for a mis-bound class.

## 6. Verification

- [x] 6.1 Run `npm run test --workspace asdlc-coordinator` and `npm run test --workspace overmind-installer`.
- [x] 6.2 Run `npm test`, `npm run verify`, `git diff --check`, and strict OpenSpec validation for `crp-158-split-project-init-and-class-management`.
