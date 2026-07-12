## Why

`overmind scaffold feature --path <project>` is a second, weaker way to do what `overmind run` already does: selecting "Start a new feature" dispatches the same `scaffoldFeature()` primitive as catalog step `3`, and additionally persists the feature-state cache and continues into the phase loop. The standalone verb also cannot serve the one consumer the design docs keep it for — the VS Code extension "Create Feature" action — because the CLI accepts only `--path`, leaving the primitive's `featureId` and `featureTitle` inputs reachable only through interactive TTY prompts, which no webview form can drive. Meanwhile the generated `quickrun.md` first-time happy path tells the operator to run `scaffold feature` and then `run`, where the natural answer to `1. Start a new feature` scaffolds a second, empty feature folder.

## What Changes

- **BREAKING**: Remove the `scaffold` command from the `overmind` CLI. `overmind scaffold feature --path <project>` no longer exists; the usage line no longer advertises `scaffold`, and an invocation of the removed verb is rejected as an unknown command.
- Establish `overmind run` as the single feature-creation entrypoint. Starting a new feature under a project happens only through the `run` feature-selection flow, which dispatches step `3` and then continues into the feature phase loop.
- Keep the `scaffoldFeature()` capture primitive and its observable refusal contract from the pending init/reconciliation checkpoint gate established in `crp-160-init-phase-with-common-contracts`. The gate now refuses at the step `3` boundary inside `run` rather than at a standalone verb; the refusal condition, the no-write-before-refusal guarantee, and the owner-naming diagnostic are preserved. Its classification is completed to inspect the applicable step `1.1` stack/agent-guidelines paths alongside the shared files, closing the interrupted init-only checkpoint gap the shipped shared-files-only classifier missed.
- Make the coordinator package the extension's feature-creation surface: the VS Code extension consumes the `scaffoldFeature()` primitive as an in-process import, not a shelled-out CLI verb. The extension verb allow-list narrows to `overmind status` and terminal-hosted `overmind run`.
- Remove `scaffold feature` from the generated `quickrun.md` first-time happy path and Feature Commands so the documented path cannot produce a duplicate empty feature folder.
- Update durable operator documentation and the extension design docs to describe the primitive-import path and the single `run` entrypoint.

No new CLI flags are introduced. `--feature-id` / `--title` options are explicitly not added; the operator supplies feature ID and title through the `run` step `3` interaction, and the extension supplies them as primitive arguments.

## Capabilities

### New Capabilities

- `feature-creation-entrypoint`: the single `overmind run` feature-creation path, removal of the standalone `scaffold` CLI verb and its usage/unknown-command surface, preservation of the step `3` pending-checkpoint gate at the `run` boundary, the coordinator primitive as the extension's feature-creation surface, and the operator guidance that documents one entrypoint.

### Modified Capabilities

<!-- None. openspec/specs/ contains no consolidated capability specs; prior scaffold-invocation behavior was recorded under change-local specs and is superseded by the new capability above. -->

## Impact

- `packages/asdlc-coordinator/src/cli/run.ts`: delete the `scaffold` command dispatch and the `runScaffold` handler, drop `scaffold` from the top-level usage string, and remove the now-unused `scaffoldFeature` import and any adapter wiring (`interaction`, `clock`, `projectGit`, `detectRuntimeRoot`) that existed solely for that handler. `CliAdapterOverrides` entries that remain in use by `run` and `project init` are retained.
- `packages/asdlc-coordinator/src/capture/scaffold-feature.ts`: inputs, step `3` registry dispatch, rendered feature output, and typed result unchanged. Its pending-checkpoint classification is completed to inspect the applicable step `1.1` stack/agent-guidelines paths (via `resolveProjectInitOwnership().initialBaselinePaths`) alongside the shared files, closing the interrupted init-only checkpoint gap for type A projects, and two error-path checkpoint diagnostics are reworded to drop the now-removed `scaffold feature` verb. It remains step `3`'s deterministic catalog action, dispatched through the executor's action registry by `overmind run`, and remains the extension's import target.
- `packages/asdlc-coordinator/test/`: remove or retarget CLI-level `scaffold feature` tests; the primitive's own unit tests (`scaffold-feature.test.ts`) and the checkpoint-gate scenarios continue to cover the behavior, exercised through the primitive and through step `3` rather than the removed verb.
- `packages/installer/src/init.ts`: remove `scaffold feature` from the generated `quickrun.md` first-time happy path block, from the Feature Commands block, and from the accompanying command descriptions and the "After `scaffold feature`, fill in the generated feature inputs" guidance.
- `packages/installer/test/init.test.ts`: update the generated-content expectation that asserts `node .overmind/overmind.js scaffold feature` appears in `quickrun.md`, and assert its absence.
- `README.md` and `overmind/README.md`: drop the `scaffold feature` command reference and bundled-CLI-verb entry, and describe feature creation through `run`; keep the pending-checkpoint refusal documented at its new boundary.
- `design_docs/overmind_vscode_extention/requirements_ears.md` and `design_docs/overmind_vscode_extention/implementation_plan.md`: narrow the shipped-verb allow-list to `overmind status` and `overmind run`, and restate the Create Feature action as a coordinator-primitive import.
- `design_docs/e2e_orchestrator_migration/`: the `03_target_architecture.md` and `02_responsibility_translation_map.md` statements that the CLI verb "remains for standalone use" are superseded and updated to the primitive-import path.
