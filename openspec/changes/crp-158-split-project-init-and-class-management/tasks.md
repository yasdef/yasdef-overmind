## 1. Policy-Aware Attachment

- [ ] 1.1 Widen `validateClassRecordCoherence` in `packages/asdlc-coordinator/src/repo/attach.ts` from `B|C` to `A|B|C`, accepting policy `A` only with `state: "deferred"` and an empty path, and keeping `ready` bound to a non-empty canonical path.
- [ ] 1.2 Replace the hardcoded `policy: "C"` in `applyClassAttachment` (`src/parse/project-definition.ts`) with the policy supplied by the caller, and thread that policy through `attachClassRepo`.
- [ ] 1.3 Update parse/attach tests for each policy value, incoherent policy/state combinations, and preservation of unrelated metadata and the `steps` block.

## 2. Reconcile Policy Prompt

- [ ] 2.1 Add the policy prompt (`A|B|C`) ahead of the repository-path prompt in the deferred-class loop of `src/orchestrator/run-project-reconciliation-flow.ts`.
- [ ] 2.2 Keep policy `A` path-free: record `policy: "A"` with deferred state and an empty path without requesting a path.
- [ ] 2.3 Pass the selected policy into attachment for `B`/`C`, preserving the existing path validation, single-retry, blank-defers, and closed-input rules.
- [ ] 2.4 Update the reconciliation-intent guidance to name `overmind project add-class` as the class-membership command.
- [ ] 2.5 Update reconciliation tests for the policy prompt, policy-`A` no-path behavior, recorded `B`/`C` policy, blank/EOF at the policy prompt, invalid-path retry, and repeated prompting of a still-deferred class.

## 3. Creation Without Repository Capture

- [ ] 3.1 Remove repository-path capture and validation from `createProject` (`src/capture/project.ts`).
- [ ] 3.2 Allow an empty class selection and seed every selected class as `state: "deferred"`, `path: ""`, `policy: "A"` in canonical order.
- [ ] 3.3 Report after creation that `overmind project reconcile` binds repositories.
- [ ] 3.4 Preserve existing name normalization, metadata append, template preservation, folder creation, git initialization/identity fallback, initial commit, typed diagnostics, and failure cleanup.
- [ ] 3.5 Update project-creation unit and CLI tests for classless creation, deferred/`A` class rows, absence of repository prompts, and unchanged base-creation failures.

## 4. Class Membership Command

- [ ] 4.1 Add the membership mutation to `src/parse/project-definition.ts`: insert a class row or reset an existing one to deferred/empty/`A`, clearing `contract_reconciled`, in canonical order across `project_classes` and `class_repo_paths`.
- [ ] 4.2 Add `src/capture/project-class.ts` with the add/change primitive and a typed result, showing current policy/state/path before a change and requiring explicit confirmation.
- [ ] 4.3 Add the argumentless `overmind project add-class` verb in `src/cli/run.ts` with existing project discovery (current project, single project, interactive selection) and no path flag.
- [ ] 4.4 Apply the project-repository transaction boundary: clean-worktree baseline before the write, one optional commit after it, typed diagnostics on inspection/stage/commit failure.
- [ ] 4.5 Add tests for add, change/reset, declined confirmation, closed input, canonical ordering, `contract_reconciled` clearing, project selection paths, unknown argument, dirty baseline, and commit rendering.

## 5. Documentation

- [ ] 5.1 Update `README.md` and `QUICKRUN.md` with the create → reconcile flow, the class-policy meanings, `overmind project add-class`, and the reset-then-reconcile path for a mis-bound class.

## 6. Verification

- [ ] 6.1 Run `npm run test --workspace asdlc-coordinator` and `npm run test --workspace overmind-installer`.
- [ ] 6.2 Run `npm test`, `npm run verify`, `git diff --check`, and strict OpenSpec validation for `crp-158-split-project-init-and-class-management`.
