# E2E Orchestrator Migration — 6. Shell Removal Plan

## Objective

Complete the repository-wide transition from shell orchestration to the existing TypeScript coordinator,
packaged skills, and TypeScript installer. The end state has no versioned or package-staged `.sh` files.

This plan starts from the current implementation and the contracts in:

- `design_docs/e2e_orchestrator_migration/01_current_e2e_functional_inventory.md`
- `design_docs/e2e_orchestrator_migration/02_responsibility_translation_map.md`
- `design_docs/e2e_orchestrator_migration/03_target_architecture.md`
- `design_docs/e2e_orchestrator_migration/04_migration_plan.md`
- `design_docs/to_skills_migration/migration_to_skill_architecture_overview.md`
- `overmind/init_progress_definition_sequence_diagram.md`
- `overmind/templates/init_progress_definition_TEMPLATE.yaml`

`design_docs/e2e_orchestrator_migration/05_parity_reconciliation.md` and CRP-144 through CRP-149 are
closed migration history, not inputs to the new slice specifications. Their implemented TypeScript
surfaces remain the baseline and are reused.

The current `.setup/models.md` format remains unchanged. This effort moves every remaining consumer to
the existing typed loader; it does not introduce another runner-config format.

## Current shell inventory

There are 15 production shell files and 11 shell test suites.

| Current shell file | Current responsibility | Target owner | Removal slice |
|---|---|---|---|
| `overmind/scripts/helper/check_feature_repo_surface_and_exec_context_be_quality.sh` | Unstaged backend surface-map validator with no production consumer | Existing `validate/surface-map.ts` | 0 |
| `overmind/scripts/helper/check_feature_repo_surface_and_exec_context_fe_quality.sh` | Unstaged frontend/mobile surface-map validator with no production consumer | Existing `validate/surface-map.ts` | 0 |
| `overmind/scripts/common_libs/check_implementation_plan_readiness.sh` | Assignment-time implementation-plan shape check | `validate/worker-assignment.ts` | 1 |
| `overmind/scripts/feature_assing_workers.sh` | Resolve active workers and rewrite plan assignments | `workers/assignment.ts` plus `overmind worker assign` | 1 |
| `overmind/scripts/project_mgmt/project_register_worker.sh` | Register one active class worker | `workers/registry.ts` plus `overmind worker register` | 1 |
| `overmind/scripts/project_mgmt/project_setup_add_new_project.sh` | Create project metadata, definition, folder, and initial git commit | `capture/project.ts` plus `overmind project create` | 2 |
| `overmind/scripts/project_mgmt/project_setup_update_project.sh` | Select a project and delegate attach/reconciliation | Existing `overmind project reconcile` | 2 |
| `overmind/scripts/common_libs/project_setup_common.sh` | Project type labels, YAML escaping, and repo-path resolution | `capture/project.ts`, `parse/`, and `workspace/` | 2 |
| `overmind/scripts/helper/check_project_stack_blueprint_quality.sh` | Stack-blueprint structural quality gate | `validate/stack-blueprint.ts` plus `overmind gate stack-blueprint` | 3 |
| `overmind/scripts/helper/check_common_contract_definition_quality.sh` | Common-contract structural quality gate | Existing `validate/contract-reconciliation.ts`, exposed for initial common-contract generation | 3 |
| `overmind/scripts/helper/check_cross_class_peer_trigger.sh` | Compute the cross-class peer trigger | Existing `repo/cross-class-peer-trigger.ts` | 3 |
| `overmind/scripts/common_libs/class_repo_paths.sh` | Read and validate class repo paths | Existing `parse/project-definition.ts`, `repo/collect-ready-paths.ts`, and `repo/attach.ts` | 3 |
| `overmind/scripts/init_project_stack_blueprints.sh` | Init step 1.1 model orchestration | `overmind-stack-blueprint` skill plus generic executor | 3 |
| `overmind/scripts/init_common_contract_definition.sh` | Init step 2 model orchestration | `overmind-common-contract` skill plus generic executor | 3 |
| `overmind/scripts/project_mgmt/project_setup_first_init_machine.sh` | Bootstrap/update deployment boundary and runtime asset staging | `packages/installer` | 4 |

The shell test suites move with the production behavior they cover:

| Shell test suite | TypeScript destination |
|---|---|
| `check_implementation_plan_readiness_tests.sh` | `packages/asdlc-coordinator/test/worker-assignment-validator.test.ts` |
| `feature_assign_workers_to_implementation_plan_tests.sh` | `packages/asdlc-coordinator/test/worker-assignment.test.ts` and CLI tests |
| `register_worker_tests.sh` | `packages/asdlc-coordinator/test/worker-registry.test.ts` and CLI tests |
| `project_setup_update_project_tests.sh` | Existing and extended project-reconciliation CLI/flow tests |
| `class_repo_paths_coherence_tests.sh` | Project-definition, ready-path, and attach/coherence tests |
| `check_project_stack_blueprint_quality_tests.sh` | `packages/asdlc-coordinator/test/stack-blueprint-validator.test.ts` |
| `check_common_contract_definition_quality_tests.sh` | Common-contract validator tests |
| `check_cross_class_peer_trigger_tests.sh` | Cross-class peer trigger tests |
| `init_project_stack_blueprints_tests.sh` | Project-init executor, context, prompt, and CLI tests |
| `init_common_contract_definition_tests.sh` | Project-init executor, context, guard, git, and CLI tests |
| `project_setup_asdlc_tests.sh` | `packages/installer/test/workspace-install.test.ts` |

## Target architecture

### Runtime commands

The staged `.overmind/overmind.js` bundle is the only runtime command implementation. It owns these
remaining operator surfaces:

- `overmind project create` — deterministic project creation.
- `overmind project init --path <project>` — project init steps 1.1 and 2 through the generic executor.
- `overmind project reconcile --path <project>` — existing attach and reconciliation flow.
- `overmind worker register --path <project>` — deterministic worker registration.
- `overmind worker assign --feature-path <feature>` — deterministic plan assignment.
- Existing `overmind run`, `status`, `scaffold`, `capture`, `context`, `gate`, `sync`, and `readiness`
  surfaces remain the feature-flow entrypoints.

Each new verb and option must be declared in its slice requirement artifacts before implementation. CLI
adapters collect arguments and render results; reusable coordinator modules own parsing, mutation, and
validation.

### Model-owned init steps

Project init steps adopt the same skill/executor architecture already used by feature steps:

- Step 1.1 uses a packaged `overmind-stack-blueprint` skill. It runs once per applicable active class,
  receives its class-specific template and golden example as skill assets, and invokes
  `overmind gate stack-blueprint` itself until the gate returns `0`.
- Step 2 uses a packaged `overmind-common-contract` skill. It binds ready repository evidence and any
  applicable stack blueprints, writes only `common_contract_definition.md`, and invokes the TypeScript
  common-contract gate itself until the gate returns `0`.
- `StepDefinition.actions` becomes non-empty for the init steps that the coordinator executes. Project
  type applicability, per-class expansion, model selection, read-only guards, required outputs, and
  checkpoint/commit policy are typed catalog/executor data.
- The top-level `overmind project init` flow selects the next pending project init step from
  `ProgressReport`; it does not introduce hand-written step launch branches.

Any change to init step ownership must update both
`overmind/init_progress_definition_sequence_diagram.md` and
`overmind/templates/init_progress_definition_TEMPLATE.yaml` in the same slice.

### Deterministic project and worker operations

Project creation, worker registration, and worker assignment are coordinator primitives rather than
skills. Their operator decisions use `InteractionPort`; clock, UUID generation, and git use injected
ports so tests remain deterministic.

Line-oriented YAML/Markdown mutation must preserve unrelated content. Each primitive returns a typed
result containing diagnostics and changed paths; the CLI performs no output parsing.

### Installer and deployed layout

`packages/installer` becomes the only bootstrap/update deployment boundary. Its `overmind init` flow
preserves the existing bootstrap-versus-update behavior while installing:

- `.overmind/overmind.js`;
- packaged skills for every supported runner;
- the two runtime templates required by deterministic project/feature creation;
- preserved `.setup/models.md` and `.setup/external_sources.yaml` defaults.

The installer owns an explicit manifest and explicit legacy tombstones. Updating an existing workspace
removes every package-owned legacy `.commands/*.sh`, `common_libs/*.sh`, and `.helper/*.sh` file. It
removes now-empty package-owned directories and preserves unmanaged operator files.

Operator guidance is generated or copied by the installer without shell heredocs. Runtime docs contain
only the bundled TypeScript CLI entrypoints.

## Migration slices

Each slice is an independent OpenSpec change with a spec commit and an implementation commit. A slice
deletes a shell implementation and its shell tests only after its TypeScript replacement passes the same
behavior inventory. `npm run verify` is green after every implementation commit.

### Slice 0 / candidate CRP-150 — Remove unowned shell validators and freeze the inventory

**Goal:** eliminate shell files that already have a TypeScript owner and establish the exact closure
inventory for later slices.

- Confirm the backend and frontend surface-map helper scripts have no production, packaged-skill, or
  staging consumer.
- Confirm `validate/surface-map.ts` is the only surface-map quality implementation used by installed
  skills and CLI gates.
- Delete the two unowned surface-map helper scripts.
- Record all remaining package-owned deployed shell filenames in the installer migration manifest. This
  manifest is the direct-upgrade cleanup contract used by Slice 4.
- Add a repository inventory test that reports unexpected new `.sh` production files while allowing the
  explicitly listed transitional files until their owning slice lands. The allow-list shrinks in every
  later slice and must be empty in Slice 4.

**Acceptance:** the two orphan validators are gone; no active command or skill references them; the
transitional shell inventory is exact and executable as a test.

### Slice 1 / candidate CRP-151 — Worker registration and assignment

**Goal:** move all worker lifecycle behavior into deterministic coordinator modules.

- Add typed worker registry parsing/mutation and worker assignment modules.
- Add `overmind worker register --path <project>` and
  `overmind worker assign --feature-path <feature>`.
- Preserve worker class validation, UUID uniqueness, active-worker filtering, multi-worker selection,
  assignment-time plan-shape validation, missing-worker error markers, and unrelated plan content.
- Keep the assignment readiness contract separate from the full implementation-plan quality gate; port
  exactly the current assignment-time checks.
- Port all worker/readiness shell scenarios to TypeScript tests before deleting their shell suites.
- Remove worker command staging and add their deployed filenames to the explicit installer tombstones.
- Delete `feature_assing_workers.sh`, `project_register_worker.sh`, and
  `check_implementation_plan_readiness.sh`.
- Update active operator docs and generated quick-run guidance to the new worker verbs.

**Acceptance:** worker registration and assignment run through `.overmind/overmind.js`; no worker behavior
depends on `common_libs`; direct CLI, mutation, decline, invalid-input, and multi-worker scenarios pass.

### Slice 2 / candidate CRP-152 — Project creation and reconciliation-only update path

**Goal:** replace project setup commands with coordinator project lifecycle verbs.

- Add a deterministic project-creation primitive and `overmind project create`.
- Preserve project ID/name normalization, type selection, ordered class selection, ready/deferred repo
  capture, canonical path validation, `asdlc_metadata.yaml` append, definition-template population,
  project-folder creation, project git initialization, local identity fallback, and initial commit.
- Use injected clock, UUID, interaction, filesystem temp fixtures, and git ports in tests.
- Make `overmind project reconcile` the sole update path for deferred-repo attachment and reconciliation;
  port any wrapper-only project-selection and operator-guidance scenarios that are still required.
- Port project creation/update support functions from `project_setup_common.sh` into the owning TypeScript
  modules.
- Remove the three command/lib staging entries and add their deployed filenames to installer tombstones.
- Delete `project_setup_add_new_project.sh`, `project_setup_update_project.sh`, and
  `project_setup_common.sh`, plus the update shell test suite.
- Update `README.md`, `QUICKRUN.md`, and generated guidance to the project CLI verbs.

**Acceptance:** a new project can be created and later reconciled without `.commands`; metadata and git
fixtures match the existing contracts; an old deployed wrapper is removable during update.

### Slice 3 / candidate CRP-153 — Project init steps 1.1 and 2

**Goal:** migrate the last model-session shell orchestrators and every remaining helper/common library.

- Package `overmind-stack-blueprint` and `overmind-common-contract` skills with their templates, golden
  examples, and concise normative instructions.
- Add stack-blueprint and initial-common-contract context builders and gate dispatch.
- Reuse the existing cross-class peer trigger and common-contract validator; add only the initial-contract
  adapter/alias needed to preserve its target-path and exit-code contract.
- Port the stack-blueprint quality helper to a deterministic TypeScript validator with stable gate exit
  codes `0`, `1`, and `2`.
- Extend the catalog and generic executor for project-scoped, per-class init actions. Load every model row
  through `config/runner-config.ts`.
- Add `overmind project init --path <project>` with project-type applicability and next-pending-step
  selection from `ProgressReport`.
- Preserve the current model prompt bindings, per-class template choice, ready-repo and blueprint evidence,
  no-peer behavior, read-only blueprint guards during common-contract creation, required outputs, and
  project initialization commit behavior.
- Update `overmind run` pending-work guidance to name `overmind project init`.
- Update the init sequence diagram and init progress definition template together. Replace the literal
  `.helper/check_project_stack_blueprint_quality.sh` completion text with the TypeScript gate contract.
- Port the five affected helper/init/coherence shell suites to focused TypeScript tests, including prompt
  capture and executor tests that prove the model owns the gate loop.
- Remove both init command staging entries, all three helper staging entries, and the remaining command-lib
  entry. Add deployed filenames to installer tombstones.
- Delete `init_project_stack_blueprints.sh`, `init_common_contract_definition.sh`,
  `check_project_stack_blueprint_quality.sh`, `check_common_contract_definition_quality.sh`,
  `check_cross_class_peer_trigger.sh`, and `class_repo_paths.sh`.

**Acceptance:** project init completes through skills plus the generic executor; `.setup/models.md` has no
shell consumer; `.helper` and `common_libs` contain no package-managed runtime files; all gate and init
tests are TypeScript.

### Slice 4 / candidate CRP-154 — TypeScript installer cutover and zero-shell closure

**Goal:** remove the final shell deployment boundary and all shell test infrastructure.

- Extend `packages/installer` from skill-only installation to complete ASDLC workspace bootstrap/update.
- Package the runtime CLI, skill manifest, runtime templates, setup defaults, quick-run content, exact
  support-asset manifest, and legacy tombstones under installer ownership.
- Preserve bootstrap/update detection, required-source validation, executable CLI installation,
  byte-for-byte skill refresh, preserved operator-edited setup files, added-file notices, and exact managed
  asset cleanup.
- Add direct-upgrade tests from a pre-cutover workspace containing every legacy staged shell command,
  helper, and common lib. Assert all tombstoned files are removed, still-supported runtime assets are
  refreshed, and unmanaged operator files are preserved.
- Port `project_setup_asdlc_tests.sh` to installer tests covering bootstrap, update, partial repair, stale
  asset removal, skill fan-out, CLI execution, and generated guidance.
- Add the source-repository setup invocation to `package.json` and update `README.md`, `QUICKRUN.md`, and
  `AGENTS.md` to use TypeScript/npm commands only.
- Delete `project_setup_first_init_machine.sh` and `project_setup_asdlc_tests.sh`.
- Remove shell staging code, injected `ASDLC_PROJECTS_DIR` rewriting, `.commands` creation, `.helper`
  creation, `common_libs` creation, and root `test:shell` wiring.
- Replace the transitional inventory assertion with a hard zero-shell assertion over versioned files and
  packaged assets.

**Acceptance:** fresh bootstrap and direct update both work through `packages/installer`; the repository
and package payload contain no `.sh`; `npm run verify` runs only TypeScript and Node-based tests.

## Cross-slice parity gates

Every removal slice must build a responsibility inventory from the shell implementation and its tests
before deletion. The inventory resolves each behavior to one of:

- a named TypeScript module and test;
- a named skill instruction plus deterministic TypeScript context/gate contract;
- a recorded behavior retirement approved in that slice's requirement artifacts.

The following invariants block shell deletion when unresolved:

1. Deterministic validation remains executable and keeps stable `0/1/2` gate semantics where the model
   consumes it.
2. The model invokes and repairs against gates; coordinator orchestrators bind gate commands but do not
   execute model-owned quality loops.
3. Runtime mutation remains in typed coordinator/installer functions, not skill prose.
4. Project, runtime-root, and class-repository git operations retain their distinct repository scopes.
5. Existing deployed workspaces have a tested direct-upgrade path that removes package-owned shell files.
6. Shell tests are deleted only in the slice that lands their TypeScript replacement.

## Verification by slice

Run the narrow package tests first, followed by:

```text
npm run typecheck
npm run lint
npm run format:check
npm run build
npm test
npm run verify
git diff --check
```

Before deleting any staged shell file, run an installer direct-upgrade fixture containing that filename.
After Slice 4, run a repository/package scan equivalent to:

```text
git ls-files '*.sh'
find packages overmind tests -type f -name '*.sh'
```

Both outputs must be empty.

## Definition of done

1. No versioned source, test, skill asset, installer payload, or generated package asset has a `.sh`
   filename.
2. Fresh and updated ASDLC workspaces receive no package-managed shell command, helper, or common library.
3. Direct update removes every known package-owned legacy `.sh` while preserving unmanaged operator files.
4. Project creation, project init, project reconciliation, worker registration, worker assignment, feature
   orchestration, status, scaffold, context, gates, sync, and readiness are TypeScript CLI/core surfaces.
5. Init steps 1.1 and 2 run through packaged skills, the generic executor, typed runner config, deterministic
   guards, and TypeScript gates.
6. Every former shell test scenario has a named TypeScript owner or an approved retirement in its removal
   slice; `tests/ai_scripts/` and `test:shell` are removed when empty.
7. `overmind/init_progress_definition_sequence_diagram.md` and
   `overmind/templates/init_progress_definition_TEMPLATE.yaml` describe the shipped project-init ownership
   and completion commands.
8. `README.md`, `QUICKRUN.md`, generated quick-run guidance, and `AGENTS.md` contain no active shell
   invocation.
9. `npm run verify` and installer fresh-install/direct-upgrade tests are green with
   `packages/asdlc-coordinator` runtime dependencies still empty.

## Main risks and controls

- **Bootstrap cutover:** removing the setup shell too early would strand existing workspaces. Keep it until
  the installer has fresh-bootstrap and direct-upgrade parity, then delete both paths in Slice 4.
- **Project YAML preservation:** project creation and worker operations rewrite structured text. Use
  fixture-based byte-preservation assertions for every unrelated block.
- **Init-step semantic drift:** the two remaining init scripts combine prompts, model bindings, gates,
  read-only guards, and git behavior. Port their responsibility inventories before writing the skills and
  require prompt/gate/guard tests before deletion.
- **Destructive deployed cleanup:** `.commands` and `common_libs` may contain operator files. Remove only
  explicit package-owned tombstones and remove directories only when empty.
- **CLI packaging ambiguity:** source-repository installer invocation and deployed `.overmind/overmind.js`
  invocation occur in different locations. Document and test both exact commands in the installer slice.
