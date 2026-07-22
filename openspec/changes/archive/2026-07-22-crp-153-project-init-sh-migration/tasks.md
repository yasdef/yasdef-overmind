## 1. Gates: stack-blueprint validator and common-contract adapter

- [x] 1.1 Add `packages/asdlc-coordinator/src/validate/stack-blueprint.ts` porting `check_project_stack_blueprint_quality.sh` to a deterministic `GateResult` with stable `0/1/2` semantics (`0` pass, `1` missing business-context content with `problems`, `2` cannot-run) over a single target path; export it from `packages/asdlc-coordinator/src/validate/index.ts`.
- [x] 1.2 Register `"stack-blueprint"` in the `gateRegistry` in `packages/asdlc-coordinator/src/cli/run.ts` so `overmind gate stack-blueprint <path>` renders the standard pass/`missing:`/`ERROR:` output; add package tests for the `0/1/2` exit-code contract.
- [x] 1.3 Add a thin initial-contract adapter/alias over `packages/asdlc-coordinator/src/validate/contract-reconciliation.ts` that preserves the retired `check_common_contract_definition_quality.sh` target-path and `0/1/2` exit-code contract for initial generation; add a test asserting it accepts/rejects the same `common_contract_definition.md` shapes as the reconciliation validator. Do not introduce a duplicate validator.

## 2. Step catalog and generic-executor wiring

- [x] 2.1 Fill in `STEP_CATALOG` in `packages/asdlc-coordinator/src/sequencing/step-catalog.ts`: step `1.1` gets a per-class `session("stack-blueprint", "project_stack_blueprint", ["project_stack_blueprint_<class>.md"])`; step `2` gets `session("common-contract", "common_contract_definition", ["common_contract_definition.md"], { readOnlyGuards: [{ mode: "fromContext" }] })`. No bespoke launcher.
- [x] 2.2 Add project-scoped context builders under `packages/asdlc-coordinator/src/context/`: `buildStackBlueprintContext(projectPath, klass)` (per-class template/golden, target path, `overmind gate stack-blueprint` command, cross-class peer-trigger command, external-sources status) and `buildCommonContractInitContext(projectPath, classes)` (rule/template/golden, target path, gate + peer-trigger commands, and type-A blueprint read-only inputs vs. type-B/C ready-repo evidence).
- [x] 2.3 Wire the new builders into the executor `context`/`classListContext` maps in `packages/asdlc-coordinator/src/runner/execute-step.ts`, keyed by `stack-blueprint` and `common-contract`; ensure both model rows load through `config/runner-config.ts` (phases `project_stack_blueprint`, `common_contract_definition`).
- [x] 2.4 Support project-scoped and project-scoped-per-class dispatch in the executor bindings (project path + single `<class>` for step 1.1; project path + class list for step 2), reusing the existing `<class>` token resolution for required outputs and guard paths.

## 3. `overmind project init` verb

- [x] 3.1 Add `runProjectInit` and the `init` subverb to the `project` branch in `packages/asdlc-coordinator/src/cli/run.ts` (`overmind project init --path <project>`); require `--path`, resolve the runtime root/project path, and update the usage string.
- [x] 3.2 Select the next pending project-init step from the `ProgressReport` (reuse `evaluate`/`nextStep`), with no hand-written per-step branches; apply project-type/active-class applicability so step 1.1 is a no-op for non-type-A projects and type-A projects with no active `backend`/`frontend`/`mobile` class, advancing selection to step 2.
- [x] 3.3 Dispatch the selected step through `executeStep` (step 1.1 once per applicable class), binding read-only guards and asserting required outputs; render the typed result and exit code without scraping printed text.
- [x] 3.4 After step 2's gate passes, commit the initialization baseline through the Unit-B project git port: stage `init_progress_definition.yaml`, `common_contract_definition.md`, and (type A) the applicable `project_stack_blueprint_<class>.md` files, assert no unexpected changes outside the baseline pathspec, and create the baseline commit; abort with a clear error on unexpected changes.

## 4. Packaged skills

- [x] 4.1 Author `packages/installer/_data/skills/overmind-stack-blueprint/` with `SKILL.md` (concise normative instructions; model runs `overmind gate stack-blueprint` and repairs until `0`) and the per-class stack-blueprint templates + golden examples as `assets/`.
- [x] 4.2 Author `packages/installer/_data/skills/overmind-common-contract/` with `SKILL.md` (writes only `common_contract_definition.md`; model runs the common-contract gate and repairs until `0`, and stops with the defined infeasibility message when the gate cannot pass) and the common-contract template + golden example as `assets/`.
- [x] 4.3 Add `overmind-stack-blueprint` and `overmind-common-contract` to `PACKAGED_SKILLS` in `packages/installer/src/init.ts`.

## 5. Absorbed helpers, guidance, and docs

- [x] 5.1 Fold `class_repo_paths.sh` usage into the existing `parse/project-definition.ts`, `repo/collect-ready-paths.ts`, and `repo/attach.ts` (ready class-repo evidence and active-class derivation); reuse `repo/cross-class-peer-trigger.ts` for no-peer behavior. No new parse/repo module.
- [x] 5.2 Update `packages/asdlc-coordinator/src/orchestrator/pending-work.ts` `initGuidance` to name `overmind project init --path <project>` for pending steps 1.1 and 2 instead of the shell commands; update the `pending-work` tests that assert the old command strings.
- [x] 5.3 Update `overmind/init_progress_definition_sequence_diagram.md` and `overmind/templates/init_progress_definition_TEMPLATE.yaml` together, replacing the literal `.helper/check_project_stack_blueprint_quality.sh` completion text with the TypeScript gate contract and describing `overmind project init` ownership.
- [x] 5.4 Update `overmind/README.md`, `QUICKRUN.md`, and generated quick-run guidance to name `overmind project init` and the TypeScript gate contracts; leave no active `.sh` invocation for init steps 1.1 and 2.

## 6. Tests

- [x] 6.1 Add executor/prompt-capture tests proving the model owns each gate loop: the stack-blueprint and common-contract prompts carry their gate commands and the coordinator does not iterate the gate itself.
- [x] 6.2 Add step-1.1 tests: one session per active stack class, per-class template/golden binding, required `project_stack_blueprint_<class>.md` output enforcement, and non-type-A / no-stack-class no-op.
- [x] 6.3 Add step-2 tests: writes only `common_contract_definition.md`; type-A blueprint read-only guard fails a mutating run; type-A binds blueprints as read-only context while type-B/C binds ready-repo evidence; baseline commit stages the expected pathspec and aborts on unexpected changes (via the injected git port).
- [x] 6.4 Add `overmind project init` CLI tests: next-pending selection, missing-`--path` usage error, project-type applicability advancing past step 1.1, and clean no-op when init is already complete.

## 7. Shell removal and staging cleanup

- [x] 7.1 Delete `overmind/scripts/init_project_stack_blueprints.sh`, `overmind/scripts/init_common_contract_definition.sh`, `overmind/scripts/helper/check_project_stack_blueprint_quality.sh`, `overmind/scripts/helper/check_common_contract_definition_quality.sh`, `overmind/scripts/helper/check_cross_class_peer_trigger.sh`, and `overmind/scripts/common_libs/class_repo_paths.sh`.
- [x] 7.2 Delete the six shell suites: `tests/ai_scripts/init_project_stack_blueprints_tests.sh`, `tests/ai_scripts/init_common_contract_definition_tests.sh`, `tests/ai_scripts/check_project_stack_blueprint_quality_tests.sh`, `tests/ai_scripts/check_common_contract_definition_quality_tests.sh`, `tests/ai_scripts/check_cross_class_peer_trigger_tests.sh`, and `tests/ai_scripts/class_repo_paths_coherence_tests.sh`.
- [x] 7.3 Remove the `.commands`/`.helper`/`common_libs` staging for the six deleted scripts from `overmind/scripts/project_mgmt/project_setup_first_init_machine.sh`; do **not** delete the first-init machine or `tests/ai_scripts/project_setup_asdlc_tests.sh` (Unit D owns both).
- [x] 7.4 Grep the tree to confirm the only remaining references to the six deleted scripts are Unit-D-owned (`project_setup_first_init_machine.sh` residual harness / `project_setup_asdlc_tests.sh`); record the coordinated-landing dependency with Unit D.
  - Note: active-source grep leaves only `overmind/scripts/project_mgmt/project_setup_first_init_machine.sh` obsolete-command cleanup entries and Unit-D-owned `tests/ai_scripts/project_setup_asdlc_tests.sh`; historical design/OpenSpec artifacts still mention the retired names as migration record. Unit D owns removing the residual shell test wiring and achieving the full `test:shell` green bar.

## 8. Verification

- [x] 8.1 Run the new package tests and the TypeScript suite (`npm run test:ts`), then `npm run typecheck`, `npm run lint`, `npm run format:check`, `npm run build`. This TypeScript bar is the standalone green target for this change.
- [x] 8.2 Run `git diff --check`. Do **not** treat full `npm test`/`test:shell`/`npm run verify` as a standalone bar here: they iterate `tests/ai_scripts/*.sh`, and the Unit-D-owned `project_setup_asdlc_tests.sh` still copies and asserts the six deleted init assets (`init_project_stack_blueprints.sh`, `init_common_contract_definition.sh`, `class_repo_paths.sh`, the two quality helpers, the peer-trigger helper) plus the old quickrun shell guidance, so `test:shell` stays red until Unit D removes the `test:shell` wiring and that suite. The full-suite/zero-shell green bar is coordinated with the Unit D landing.
- [x] 8.3 Assert `packages/asdlc-coordinator/package.json` still has `"dependencies": {}` (no runtime dependency introduced).
- [x] 8.4 Run strict OpenSpec validation for this change (`openspec validate crp-153-project-init-sh-migration --strict`).
