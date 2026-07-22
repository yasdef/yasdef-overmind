## 1. Remove the `scaffold` CLI verb

- [x] 1.1 Delete the `if (command === "scaffold")` dispatch branch in `packages/asdlc-coordinator/src/cli/run.ts` so the verb falls through to the unknown-command usage error with a non-zero exit code.
- [x] 1.2 Remove `scaffold` from the top-level usage string in `packages/asdlc-coordinator/src/cli/run.ts`, leaving the remaining supported commands listed.
- [x] 1.3 Delete the `runScaffold` handler from `packages/asdlc-coordinator/src/cli/run.ts`.
- [x] 1.4 Drop the `scaffoldFeature` import and any other import or adapter wiring in `cli/run.ts` left with no remaining consumer after `runScaffold` is gone; keep `CliAdapterOverrides` entries (`interaction`, `clock`, `projectGit`) still used by `run` and `project init`. Confirm with a typecheck / lint pass that nothing unused remains.

## 2. Verify the primitive and the `run` step 3 boundary

- [x] 2.1 Confirm `packages/asdlc-coordinator/src/capture/scaffold-feature.ts` preserves the step `3` registry dispatch, inputs, rendered feature output, and typed result — step `3` still dispatches the registered `scaffold-feature` action through the executor registry, adopting the typed `featurePath`.
- [x] 2.2 Remove the two CLI-verb tests in `packages/asdlc-coordinator/test/cli-run.test.ts` ("scaffold requires --path" and "standalone scaffold dispatch creates a feature and exits zero").
- [x] 2.3 Add a `cli-run.test.ts` assertion that `scaffold feature --path <project>` is now rejected as an unknown command: non-zero exit, usage text that does not name `scaffold`, and no feature directory created.
- [x] 2.4 Confirm the pending init/reconciliation checkpoint gate is covered at the `run` step `3` boundary — pending step `2`, interrupted init-only checkpoint, and declined reconciliation commit each refuse before feature ID/title input and before any write, naming the owning `project init` / `project reconcile` command. Add the missing orchestrator-level coverage if the existing `scaffold-feature.test.ts` primitive tests are the only place these scenarios run.
- [x] 2.5 Complete the step `3` checkpoint classification to inspect the applicable step `1.1` stack/agent-guidelines paths via `resolveProjectInitOwnership().initialBaselinePaths` (and reword two error-path diagnostics to drop the removed `scaffold feature` verb), so a type A project with committed shared files but an unfinalized step `1.1` artifact refuses feature creation; cover it with an orchestrator boundary test.

## 3. Fix generated operator guidance

- [x] 3.1 Remove the `node .overmind/overmind.js scaffold feature --path projects/<project-id>` line from the generated `quickrun.md` first-time happy path block in `packages/installer/src/init.ts`, so the path runs `project init` then `run`.
- [x] 3.2 Remove the `scaffold feature` entry from the generated Feature Commands block and its description bullet in `packages/installer/src/init.ts`.
- [x] 3.3 Rewrite the trailing happy-path prose in `packages/installer/src/init.ts` that says "After `scaffold feature`, fill in the generated feature inputs before running the workflow" to describe creating a feature through `run` ("Start a new feature") instead.
- [x] 3.4 Update the generated-content expectation in `packages/installer/test/init.test.ts` that asserts `node .overmind/overmind.js scaffold feature` appears in `quickrun.md`; assert its absence and assert the happy path retains `run`.

## 4. Update durable and design documentation

- [x] 4.1 Update `README.md` (the command reference near line 148 and the bundled-CLI-verb entry near lines 214-215) to drop `scaffold feature` and describe feature creation through `overmind run`.
- [x] 4.2 Update `overmind/README.md` so the pending-checkpoint refusal is documented at the `run` step `3` boundary rather than as a `scaffold feature` behavior.
- [x] 4.3 Narrow the shipped-verb allow-list in `design_docs/overmind_vscode_extention/requirements_ears.md` to read-only `overmind status` and terminal-hosted `overmind run`, removing `overmind scaffold feature`.
- [x] 4.4 Restate the Create Feature action in `design_docs/overmind_vscode_extention/implementation_plan.md` (the CRP-161 row and the Create Feature checklist item) as an in-process `scaffoldFeature()` primitive import rather than a CLI verb invocation.
- [x] 4.5 Update the "CLI verb remains for standalone use" statements in `design_docs/e2e_orchestrator_migration/03_target_architecture.md` and `design_docs/e2e_orchestrator_migration/02_responsibility_translation_map.md` to the primitive-import path, and drop `overmind scaffold feature` from the entrypoint list in `design_docs/e2e_orchestrator_migration/04_migration_plan.md`.
- [x] 4.6 Update `CLAUDE.md` / `AGENTS.md` only if a command, path, or convention they document changed.

## 5. Verify

- [x] 5.1 Run `npm test` and `npm run verify` from the repository root; run `npm run test --workspace overmind-installer` and `npm run test --workspace asdlc-coordinator`.
- [x] 5.2 Grep the repository for remaining `scaffold feature` references and confirm each survivor is an intentional historical record (archived changes, this change's own artifacts) rather than live guidance or code.
- [x] 5.3 Drive the flow end to end in a scratch workspace: `overmind scaffold feature` is rejected with usage text, and `overmind run --path projects/<id>` → "Start a new feature" creates exactly one feature and continues into the phase loop.
