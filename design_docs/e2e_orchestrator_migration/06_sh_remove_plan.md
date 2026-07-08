# E2E Orchestrator Migration — 6. Shell Removal Plan

## Framing: this finishes the rewrite; it is not a compatibility migration

Overmind has never been installed. No persistent ASDLC workspace exists anywhere — not an
operator install, not an internal one, not a developer one. There is nothing deployed to upgrade,
no old shell setup that must stay runnable, and no backward-compatibility surface to protect.

The remaining `.sh` files are the last scaffolding from the pre-TypeScript world. They are behavior
*reference*, not a contract to reproduce line-for-line. We delete them and write the correct
TypeScript in their place — the same way we would if this were code we had just written today and
were now cleaning up.

Three consequences shape the whole plan:

- **No parity ceremony.** No "prove parity before deletion", no responsibility-inventory-as-blocking-gate,
  no cross-slice parity gates, no monotonically shrinking transitional allow-list. Delete each shell
  file when its TypeScript owner lands, and delete its shell test with it.
- **No transitional shell to keep alive.** The feature orchestrator (CRP-144–149) is already
  TypeScript; the surfaces below are standalone. Nothing consumes them at runtime, so there is no
  ordering constraint imposed by "keep the e2e testable". Order is chosen for architectural cohesion,
  not to keep old behavior running.
- **The bar is architecture, not the shell.** The target is architecture-correct, best-practices
  TypeScript aligned with `03_target_architecture.md` and `04_migration_plan.md` — exactly the standard
  the already-migrated code holds. The spec of record is the **artifact contracts**
  (`overmind/templates/init_progress_definition_TEMPLATE.yaml`, gate `0/1/2` semantics, per-class
  templates and golden examples, project metadata/git fixtures), not the shell implementation. The
  shell is a hint about intent; where it is awkward or accidental, we do the right thing instead of
  copying it.

## Inputs

The end state reuses the contracts and already-migrated surfaces in:

- `design_docs/e2e_orchestrator_migration/01_current_e2e_functional_inventory.md`
- `design_docs/e2e_orchestrator_migration/02_responsibility_translation_map.md`
- `design_docs/e2e_orchestrator_migration/03_target_architecture.md`
- `design_docs/e2e_orchestrator_migration/04_migration_plan.md`
- `design_docs/to_skills_migration/migration_to_skill_architecture_overview.md`
- `overmind/init_progress_definition_sequence_diagram.md`
- `overmind/templates/init_progress_definition_TEMPLATE.yaml`

`05_parity_reconciliation.md` and CRP-144–149 are closed history. Their TypeScript surfaces
(`workspace/`, `sequencing/`, `config/`, `runner/`, `orchestrator/`, `git/`, the generic executor,
the skill/executor architecture) are the baseline this plan extends and reuses rather than
re-derives. `.setup/models.md` keeps its pipe-table format and is loaded only through the existing
typed `config/runner-config.ts`; no new runner-config format is introduced.

## What is left

Two surface-map validators (`check_feature_repo_surface_and_exec_context_{be,fe}_quality.sh`) are
already deleted — their sole owner is `validate/surface-map.ts`. That leaves **13 production shell
files and 11 shell test suites**, in four architectural groups:

| Shell file | Old responsibility | TypeScript owner (target) | Unit |
|---|---|---|---|
| `scripts/feature_assing_workers.sh` | Resolve active workers, rewrite plan assignments | `workers/assignment.ts` + `overmind worker assign` | A |
| `scripts/project_mgmt/project_register_worker.sh` | Register one active class worker | `workers/registry.ts` + `overmind worker register` | A |
| `scripts/common_libs/check_implementation_plan_readiness.sh` | Assignment-time plan-shape check | `validate/worker-assignment.ts` | A |
| `scripts/project_mgmt/project_setup_add_new_project.sh` | Create project metadata, definition, folder, initial commit | `capture/project.ts` + `overmind project create` | B |
| `scripts/project_mgmt/project_setup_update_project.sh` | Select project, delegate attach/reconcile | Existing `overmind project reconcile` | B |
| `scripts/common_libs/project_setup_common.sh` | Type labels, YAML escaping, repo-path resolution | `capture/project.ts`, `parse/`, `workspace/` | B |
| `scripts/init_project_stack_blueprints.sh` | Init step 1.1 model orchestration | `overmind-stack-blueprint` skill + generic executor | C |
| `scripts/init_common_contract_definition.sh` | Init step 2 model orchestration | `overmind-common-contract` skill + generic executor | C |
| `scripts/helper/check_project_stack_blueprint_quality.sh` | Stack-blueprint quality gate | `validate/stack-blueprint.ts` + `overmind gate stack-blueprint` | C |
| `scripts/helper/check_common_contract_definition_quality.sh` | Common-contract quality gate | Existing `validate/contract-reconciliation.ts`, exposed for initial generation | C |
| `scripts/helper/check_cross_class_peer_trigger.sh` | Cross-class peer trigger | Existing `repo/cross-class-peer-trigger.ts` | C |
| `scripts/common_libs/class_repo_paths.sh` | Read/validate class repo paths | Existing `parse/project-definition.ts`, `repo/collect-ready-paths.ts`, `repo/attach.ts` | C |
| `scripts/project_mgmt/project_setup_first_init_machine.sh` | Deployment boundary + runtime asset staging | `packages/installer` | D |

The 11 shell test suites are deleted with the code they cover. They are not ported scenario-for-scenario;
each unit's TypeScript tests are written to specify correct behavior against the artifact contracts,
consulting the shell suites only where they capture a genuine edge case worth keeping.

## Target end state (from `03_target_architecture.md`)

**Runtime commands.** The staged `.overmind/overmind.js` bundle is the only runtime entrypoint. It
gains the remaining operator verbs on top of the existing `run | status | scaffold | capture | context
| gate | sync | readiness | project reconcile` dispatch:

- `overmind project create` — deterministic project creation.
- `overmind project init --path <project>` — init steps 1.1 and 2 via the generic executor.
- `overmind worker register --path <project>` — deterministic worker registration.
- `overmind worker assign --feature-path <feature>` — deterministic plan assignment.

CLI adapters collect arguments and render typed results; reusable coordinator modules own parsing,
mutation, and validation. Every new verb/option is declared in its unit's requirement artifacts.

**Model-owned init steps.** Init steps 1.1 and 2 adopt the same skill + generic-executor architecture
already used by feature steps — no bespoke launchers. Step 1.1 uses a packaged `overmind-stack-blueprint`
skill (once per applicable active class, class-specific template + golden example as assets, model runs
`overmind gate stack-blueprint` until `0`). Step 2 uses a packaged `overmind-common-contract` skill
(binds ready-repo evidence and applicable blueprints, writes only `common_contract_definition.md`,
model runs the common-contract gate until `0`). Applicability, per-class expansion, model selection,
read-only guards, required outputs, and commit policy are typed catalog/executor data;
`StepDefinition.actions` becomes non-empty for these steps. `overmind project init` selects the next
pending project-init step from `ProgressReport` — no hand-written step branches.

**Deterministic primitives.** Project creation, worker registration, and worker assignment are pure
coordinator primitives, not skills. Operator decisions go through `InteractionPort`; clock, UUID, and
git use injected ports for deterministic tests. Line-oriented YAML/Markdown mutation preserves unrelated
content; each primitive returns a typed result with diagnostics and changed paths, and the CLI does no
output parsing.

**Installer.** `packages/installer` becomes the fresh-workspace deployment boundary. `overmind init`
installs `.overmind/overmind.js`, packaged skills for every supported runner, the runtime templates
deterministic creation needs, and `.setup/models.md` + `.setup/external_sources.yaml` defaults. Operator
guidance is generated/copied without shell heredocs. Because nothing was ever deployed, this is a
fresh-install boundary only — no upgrade path, no deployed-shell cleanup, no historical staging inventory.

## Work units

Five independent OpenSpec changes. Units A, B, and C are mutually independent and may land in any
order; unit D lands last among the shell units because it owns the fresh-install boundary and the final
zero-shell state; unit E touches no shell and may land at any time. Each shell unit lands
architecture-correct TypeScript, deletes its shell (implementation **and** tests) in the same change,
and leaves `npm run verify` green.

### Unit A / CRP-151 — Worker lifecycle

Move all worker registration and assignment into deterministic coordinator modules.

- Add typed worker registry parse/mutation (`workers/registry.ts`), assignment (`workers/assignment.ts`),
  and the assignment-time plan-shape validator (`validate/worker-assignment.ts`), kept distinct from the
  full implementation-plan quality gate.
- Add `overmind worker register --path <project>` and `overmind worker assign --feature-path <feature>`.
- Behavior the artifact contracts require: worker-class validation, UUID uniqueness, active-worker
  filtering, multi-worker selection, missing-worker error markers, and preservation of unrelated plan
  content. Injected clock/UUID/interaction ports (the worker primitives perform no git work; the
  git seam in "Deterministic primitives" applies to project creation in unit B).
- Delete `feature_assing_workers.sh`, `project_register_worker.sh`,
  `check_implementation_plan_readiness.sh`, and their three shell suites; remove their command staging.
- Update `README.md`/`QUICKRUN.md` and generated quick-run guidance to the new worker verbs.

### Unit B / CRP-152 — Project lifecycle (create + reconcile-only update)

Replace project-setup commands with coordinator project-lifecycle verbs.

- Add the deterministic project-creation primitive (`capture/project.ts`) and `overmind project create`.
  Contract to preserve: project ID/name normalization, type selection, ordered class selection,
  ready/deferred repo capture, canonical path validation, `asdlc_metadata.yaml` append,
  definition-template population, project-folder creation, project git init with local-identity
  fallback, and the initial commit. Injected clock/UUID/interaction/temp-fixture/git ports.
- Make the existing `overmind project reconcile` the sole update path; fold any still-useful
  project-selection/operator-guidance behavior from the update wrapper into it.
- Absorb the reusable helpers from `project_setup_common.sh` (type labels, YAML escaping, repo-path
  resolution) into `capture/project.ts`, `parse/`, and `workspace/` where they architecturally belong.
- Delete `project_setup_add_new_project.sh`, `project_setup_update_project.sh`,
  `project_setup_common.sh`, and the update shell suite; remove their staging.
- Update `README.md`/`QUICKRUN.md` and generated guidance to the project verbs.

### Unit C / CRP-153 — Project init steps 1.1 and 2

Migrate the last model-session shell orchestrators and every remaining helper/common library.

- Package `overmind-stack-blueprint` and `overmind-common-contract` skills with their templates, golden
  examples, and concise normative instructions.
- Port `check_project_stack_blueprint_quality.sh` to a deterministic `validate/stack-blueprint.ts` with
  stable `0/1/2` gate exit codes. Reuse the existing `repo/cross-class-peer-trigger.ts` and the
  common-contract validator, adding only the initial-contract adapter/alias needed to preserve its
  target-path and exit-code contract. Fold `class_repo_paths.sh` into the existing
  `parse/project-definition.ts`, `repo/collect-ready-paths.ts`, and `repo/attach.ts`.
- Extend the catalog and generic executor for project-scoped, per-class init actions; load every model
  row through `config/runner-config.ts`. Add `overmind project init --path <project>` with project-type
  applicability and next-pending-step selection from `ProgressReport`.
- Contract to preserve: model prompt bindings, per-class template choice, ready-repo/blueprint evidence,
  no-peer behavior, read-only blueprint guards during common-contract creation, required outputs, and
  project-init commit behavior. Update `overmind run` pending-work guidance to name `overmind project init`.
- Update `overmind/init_progress_definition_sequence_diagram.md` and
  `overmind/templates/init_progress_definition_TEMPLATE.yaml` together; replace the literal
  `.helper/check_project_stack_blueprint_quality.sh` completion text with the TypeScript gate contract.
- Delete `init_project_stack_blueprints.sh`, `init_common_contract_definition.sh`,
  `check_project_stack_blueprint_quality.sh`, `check_common_contract_definition_quality.sh`,
  `check_cross_class_peer_trigger.sh`, `class_repo_paths.sh`, and their six shell suites; remove all
  their staging. TypeScript tests must include prompt-capture and executor tests proving the model owns
  the gate loop.

### Unit D / CRP-154 — Installer cutover and zero-shell closure

Remove the final shell deployment boundary and all shell test infrastructure.

- Extend `packages/installer` from skill-only installation to complete fresh ASDLC workspace bootstrap:
  runtime CLI, skill manifest, runtime templates, setup defaults, quick-run content, and the exact
  support-asset manifest under installer ownership. Preserve required-source validation, executable CLI
  installation, byte-for-byte skill installation, and generated guidance.
- Write fresh-bootstrap installer tests (skill fan-out, CLI execution, generated guidance). Because
  nothing was ever deployed, there is no upgrade/cleanup/injected-`ASDLC_PROJECTS_DIR` behavior to carry.
- Add the source-repo setup invocation to `package.json`; update `README.md`, `QUICKRUN.md`, and
  `AGENTS.md` to TypeScript/npm commands only.
- Delete `project_setup_first_init_machine.sh` and `project_setup_asdlc_tests.sh`; remove all shell
  staging code, `.commands`/`.helper`/`common_libs` creation, and root `test:shell` wiring. Remove
  `tests/ai_scripts/` once empty.
- Add a single end-state zero-shell assertion over versioned files and packaged assets (this replaces
  the transitional inventory guard entirely — there is no longer a set of "allowed" shell files to track).

### Unit E / CRP-155 — Remove back-compat residue from the prior migration

The e2e sh→TS migration (CRP-144–149) is otherwise clean, but two pieces of the same "recognize the old
thing to keep compatibility" reflex leaked into the TypeScript. Applying the same fresh-install lens —
nothing was ever installed, so there is no prior state and no prior caller to stay compatible with —
both are dead ceremony and are deleted. This unit is independent of the shell files and may land in any
order; it is listed here so the effort closes with zero back-compat residue, not just zero shell.

- **Retired shell `.env` feature-state cache.** `packages/asdlc-coordinator/src/state/feature-state.ts`
  exports `LEGACY_FEATURE_STATE_FILE_NAME` (`.project_add_feature_e2e_state.env`) "recognized only to be
  ignored", and `packages/asdlc-coordinator/test/feature-state.test.ts` has a
  `"legacy env state is ignored, not migrated"` scenario that writes that file and asserts it is ignored.
  Ignoring is already the default — production `readFeatureState` only reads
  `.overmind_feature_state.json` and never references the constant — so both the constant and the test
  only mean something if old `.env` files exist to be ignored, and none do (decision 4 in
  `03_target_architecture.md ## Decisions`: the old `.env` is simply ignored, a run re-asks feature
  selection once). Delete the exported constant and the dedicated test scenario.
- **`InstallResult.skillPath` compatibility field.** `packages/installer/src/init.ts` keeps a singular
  `skillPath` (the Claude `overmind-task-to-br` path) alongside `skillPaths[]` "retained from CRP-129",
  wired through `packages/installer/src/bin/overmind.ts` (`Installed skill to <one path>`) and asserted
  in `packages/installer/test/init.test.ts`. It is an internal interface that was never shipped, so no
  caller depends on it, and the single-path CLI message is a vestige of an installer that now fans out
  many skills. Drop the field, update the CLI to report the installed skills from `skillPaths`, and drop
  the stale test assertion.

**Acceptance:** `LEGACY_FEATURE_STATE_FILE_NAME` and `InstallResult.skillPath` no longer exist; the CLI
install output is derived from `skillPaths`; `npm run verify` is green. (The `technical-requirements.ts`
section-6 "retired loose-entry format" reject rule is deliberately **kept** — it is a model-mistake
guardrail, not deployment back-compat, and is not in scope here.)

## Architecture invariants

These are quality rules the TypeScript must satisfy — not compatibility obligations. They hold in every
unit:

1. Deterministic validators the model consumes keep stable `0/1/2` gate semantics.
2. The model invokes and repairs against gates; coordinator orchestrators bind gate commands but never
   run the model-owned quality loop, and no unit introduces a bespoke launcher — new sessions are catalog
   entries executed by the generic executor.
3. Runtime mutation lives in typed coordinator/installer functions, never in skill prose, and preserves
   unrelated file content (fixture-based byte-preservation assertions on every untouched block).
4. Project, runtime-root, and class-repository git operations keep their distinct repository scopes.
5. Skills carry prose + assets only; parsing, mutation, and gates are TypeScript.

## Verification

Per unit, narrow package tests first, then:

```text
npm run typecheck
npm run lint
npm run format:check
npm run build
npm test
npm run verify
git diff --check
```

At the end of unit D:

```text
git ls-files '*.sh'
find packages overmind tests -type f -name '*.sh'
```

Both outputs must be empty.

## Definition of done

1. No versioned source, test, skill asset, installer payload, or generated package asset has a `.sh`
   filename; `tests/ai_scripts/` and `test:shell` are gone.
2. Fresh ASDLC workspaces receive no package-managed shell command, helper, or common library.
3. Project creation, project init, project reconcile, worker registration, worker assignment, and the
   existing feature/status/scaffold/context/gate/sync/readiness surfaces are all TypeScript CLI/core.
4. Init steps 1.1 and 2 run through packaged skills, the generic executor, typed runner config,
   deterministic guards, and TypeScript gates.
5. `overmind/init_progress_definition_sequence_diagram.md` and
   `overmind/templates/init_progress_definition_TEMPLATE.yaml` describe the shipped project-init
   ownership and completion commands; `README.md`, `QUICKRUN.md`, generated guidance, and `AGENTS.md`
   contain no active shell invocation.
6. `npm run verify` and the installer fresh-install tests are green, with `packages/asdlc-coordinator`
   runtime `dependencies` still empty.
