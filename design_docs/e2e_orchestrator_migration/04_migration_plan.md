# E2E Orchestrator Migration — 4. Migration Plan

Six slices numbered 0–5, each an independent SDD change (OpenSpec CRP, same cadence as the skills migration: spec commit, then implementation commit). Each slice leaves the repo green and the operator workflow runnable end-to-end — the shell e2e keeps working until Slice 3 replaces it. Deletion happens inside the slice that proves parity, never later ("clean break, one step at a time keeps the repo testable, not old behavior alive").

Per-slice discipline (inherited from `design_docs/to_skills_migration/step_by_step_migration_for_particular_step.md`): build the responsibility inventory for the touched rows of `02_responsibility_translation_map.md` before implementation; any unowned behavior blocks the slice; deterministic guards may never be downgraded to advisory text; tests port in the same move as the code they cover.

---

## Slice 0 — Toolchain baseline

**Goal:** prod-level TS infrastructure in place before orchestrator code lands, applied to the already-migrated packages too (the 13-step coordinator/installer code is currently unlinted and only typechecked via build). Contract in `03_target_architecture.md ## Engineering baseline`.

- ESLint flat config (typescript-eslint type-checked presets) + Prettier + `.editorconfig` at the repo root, wired into every workspace; Prettier coverage is scoped to TypeScript and toolchain configuration files.
- `tsconfig.base.json` strictness additions (`noUncheckedIndexedAccess`, `noImplicitOverride`, `noFallthroughCasesInSwitch`, `verbatimModuleSyntax`); all existing-code fallout fixed in the same change.
- Scripts per workspace + root aggregate: `typecheck` (`tsc --noEmit`, tests included), `lint`, `format:check`.
- Single root `npm run verify` command: typecheck → lint → format-check → build → test (TS workspaces + the surviving `tests/ai_scripts/*.sh` suites); a green local run is the completion criterion for this and every later slice. `AGENTS.md` and `CLAUDE.md` remain gitignored local configuration. `engines` pins the Node floor. Coverage report-only. No remote CI, no git hooks.
- No behavior changes — pure infrastructure plus mechanical fixes; no new runtime dependencies (the coordinator's `dependencies` stays empty, per the zero-runtime-dependency rule).

## Slice 1 — Workspace + sequencing core (`overmind status`)

**Goal:** the pure foundation both the orchestrator and the extension stand on.

- `workspace/`: runtime-root detection, project discovery/validation, feature-folder discovery.
- `parse/` extension: one typed read for `project_type_code`, `project_classes`, `class_repo_paths` states.
- `sequencing/`: step catalog (`StepDefinition[]`) + state machine whose primary result is `ProgressReport` (per-step state for every declared step, project + feature scope, per-class step-7 detail, missing artifacts), with `nextStep()`, the checklist formatter, and dotted-step/resume-alias resolution as projections/utilities over it (contract in `03_target_architecture.md ## Key contracts`).
- **This is a new scanner, not a parity port** (decision 2 in `03_target_architecture.md ## Decisions`): the old scanner joins/omits steps relative to `init_progress_definition.yaml`; the definition file is the spec, the old output contract (checklist + canonical `next step:` line) is kept.
- CLI: `overmind status <path>` (project or feature path — mirrors the scanner's `--path` behavior).
- Tests: step-reporting tests derive from `init_progress_definition.yaml` (every declared step reported, correct type/class filtering); old `tests/ai_scripts/init_progress_scanner_tests.sh` scenarios inform the output-format contract and edge cases only.
- Acceptance criterion: the extension's `FeatureSummary` fields (`design_docs/overmind_vscode_extention/technical_requirements.md ## 7. Dashboard Data Contract` — `readiness`, `completedSteps`, `totalSteps`, `missingArtifacts`) are derivable from `ProgressReport` by pure projection, proven by a test in this slice — the "extension for free" claim is validated here, not discovered false in Slice 5.
- Diagnostics from day one (retrofit is invasive): the `Diagnostic` type and errors-as-values convention (`03_target_architecture.md ## Key contracts`) land in this slice. Acceptance criterion: malformed or missing definition inputs yield a `ProgressReport` with degraded step states and populated `diagnostics[]` — no throw — proven by a test.
- **Delete:** `overmind/scripts/project_mgmt/init_progress_scanner.sh` + its shell tests. **Rewire (full transitional surface, not just the mapping table):** `project_add_feature_e2e.sh` `scanner_status_line_for_feature`/`run_scanner_and_get_next_step` call `node .overmind/overmind.js status` instead. Because the new scanner reports precise definition step ids, the same edit must cover: (a) the **byte-exact canonical-line contract** — `next step: <num> (<name>)` and the literal `next step: none` — as an explicit TS-side contract test, since the shell e2e's regex parser stays a consumer until Slice 3; (b) correction of **both** shell mapping points, `map_scanner_step_to_phase` and the `fail_project_prerequisite_step` case labels (the compensating remaps become dead); (c) **e2e test-fixture updates** in `tests/ai_scripts/project_add_feature_e2e_tests.sh` for every expectation that shifts from a joined/omitted id to a precise id — the slice's spec includes an audit step enumerating them, and fixture breakage MUST NOT be resolved by making the scanner mimic the old imprecision. This is the only transitional shell edit in the plan; staging (`project_setup_first_init_machine.sh`) stops staging the scanner.

## Slice 2 — Runner config + agent runner + guards

**Goal:** everything needed to launch one model session correctly, as reusable modules.

- `config/`: typed loader + validation for the **unchanged** `.setup/models.md` pipe-table (decision 5 in `03_target_architecture.md ## Decisions`: format kept, awk replaced). Load problems surface as `Diagnostic` values in the loader's typed result — actionable at startup, renderable by CLI and extension alike. No workspace migration needed.
- `runner/`: the generic step executor iterating a step's declared action sequence (model sessions with `runIf` predicates, deterministic checks — no per-step branches); prompt builder over the session action; `AgentRunner` port + codex adapter; guards module implementing the full `readOnlyGuards` union (`fromContext`, `mustExistUnchanged`, `preserveExistence`) plus required-outputs assertion with empty-list-is-legal semantics.
- `interaction/`: port types + TTY adapter (needed by Slice 3; specified here so the runner result/interaction shapes co-evolve).
- Tests: config validation, prompt content parity against the 13 heredocs (assert skill name, bindings, exact commands, no final-response lines), stub agent adapter; guard tests cover all three modes — explicitly including the 7.1 shape (absent-stays-absent, exists-unchanged, empty `requiredOutputs`) alongside context-derived and must-exist cases.
- Deletes nothing yet (shell e2e still reads `models.md` until Slice 3 removes it).

## Slice 3 — Orchestrator loop (`overmind run`) — the pivot

**Goal:** `overmind run [--path] [--resume]` fully replaces `project_add_feature_e2e.sh`, including its phase-3 scaffold dependency.

- `orchestrator/` feature flow: feature selection + state cache (`state/`), new-vs-continue and `--resume` constraint matrix (incl. the `--resume 8.4` completed-feature case), linear phase loop, optional-phase semantics, `PhaseOutcome` mapping, restart guidance, checkpoint commits (`git/`), phase-7 class loop; the step-3/4.1/4.2 action sequences are catalog entries wired here, not orchestrator code (per `03_target_architecture.md ## Key contracts`).
- Scaffold primitive: `capture/scaffold-feature.ts` `scaffoldFeature()` — step 3's deterministic catalog action, dispatched by the executor under `overmind run` and importable in process by other consumers, nothing more (operator inputs via options or the interaction port; typed result carries the created feature path — no stdout scraping). Parity sources: `overmind/scripts/feature_br_scaffold.sh` + `tests/ai_scripts/init_br_scaffold_tests.sh`.
- Project-level pending-work detection (init steps **and** attach/reconciliation state — the latter read from `class_repo_paths.<class>` state + `contract_reconciled` in `init_progress_definition.yaml`, decision 9 in `03_target_architecture.md ## Decisions`) refuses with guidance — uniformly extending today's prereq guard. Until Slice 4 lands, the guidance names the legacy staged scripts; after Slice 4 it names `overmind project reconcile`. The pre-flight is **not** executed inside `overmind run` (decision 3 in `03_target_architecture.md ## Decisions`).
- Tests: port `tests/ai_scripts/project_add_feature_e2e_tests.sh` (2,400 lines — the behavioral spec of record) to the TS runner with a stub agent; every guard, decline path, resume path, and failure-guidance string family covered. Pre-flight-execution scenarios are re-targeted to detection-and-guidance behavior here and to the project flow in Slice 4.
- **Delete:** `project_add_feature_e2e.sh`, `feature_br_scaffold.sh`, and their shell tests (incl. `init_br_scaffold_tests.sh`); staging stops staging them; `QUICKRUN.md`/`overmind/README.md` switch the operator entrypoint to `overmind run` (and document the separated project-level flow).

## Slice 4 — Project-level flow (`overmind project reconcile`)

**Goal:** the separated project-level lifecycle command in TS; last model-session shell gone.

- New CLI verb `overmind project reconcile [--path <project>]` owning the whole unit: deferred-class attach prompting with retry-once rule (`repo/attach.ts`, parity source: `common_libs/persist_class_repo_attach.sh` + its tests), clean-worktree transaction guard, the reconciliation session, the per-class `contract_reconciled` flag lifecycle in `init_progress_definition.yaml` (decision 9 in `03_target_architecture.md ## Decisions`; set-on-success, clear-on-reattach, no dotfile markers), owned-paths commit unit with reconciliation-edit rollback.
- **Embedded skill migration:** reconciliation is still an old-style step — its rule text lives inside `project_contract_reconciliation.sh`. This slice migrates it to `overmind-contract-reconciliation` SKILL.md + a catalog `StepDefinition` following `design_docs/to_skills_migration/step_by_step_migration_for_particular_step.md` (incl. its gate/validator inventory in the slice's spec), executed by the shared generic executor with a class-list session binding.
- **No bespoke launcher rule:** if the executor cannot express the reconciliation session, extend the executor contract (as the class-list binding does) — never fork a one-off launcher; the 14th hand-written launcher is the regression this migration exists to prevent.
- Feature-flow guidance from Slice 3 switches from naming legacy scripts to naming this verb.
- **Delete:** `persist_class_repo_attach.sh`, `project_contract_reconciliation.sh`, and their shell tests.

## Slice 5 — Cleanup + extension enablement

**Goal:** end-state hygiene and the first extension consumption proof.

- Remove now-orphaned `common_libs` helpers and staging entries; sweep versioned docs (`overmind/README.md`, `QUICKRUN.md`) for dead references.
- `packages/vscode-extension`: minimal read-only dashboard wired to `workspace/` + `sequencing/` (proves the reuse claim).
- **Revise the extension design docs** (`design_docs/overmind_vscode_extention/requirements_ears.md`, `technical_requirements.md`, `implementation_plan.md`): replace every `.commands/*.sh` launching surface (Requirement 7 clauses, Requirement 9 verification, Run Scanner / Create Feature / Continue E2E actions, script allow-list) with the shipped `overmind` verbs and in-process core, per the mapping in `03_target_architecture.md ### Supersession of the extension design docs`; remove the supersession banners. Extension implementation must not restart from the old plan before this revision lands.
- Audit against `02_responsibility_translation_map.md ## Full parity gate`: every row resolved. The behavior-level sweep is already **complete** and the gate closed at that level in `05_parity_reconciliation.md ## Sweep result` (Slice 3 executed it before deleting the shell suites); Slice 5 only folds that result into the formal `02` write-up and revises the extension docs.

---

## Sequencing rationale & risk notes

- **0 → 1 → 2 → 3 is the critical path**; 4 and 5 are strictly after 3. Slice 0 is deliberately first: lint/strictness debt compounds per slice, and the `npm run verify` gate must be able to cover Slice 1 already.
- The riskiest slice is 3 (behavioral breadth). Mitigation: the ported test suite is written against the *shell* e2e's observable behavior first (from the existing tests), then the TS orchestrator must pass the same suite — parity by construction.
- Slice 1 carries the plan's main behavioral *change* (not just migration): the new scanner reports steps precisely per `init_progress_definition.yaml`, where the old one joined/omitted. The transitional rewire therefore touches the shell e2e's mapping points *and its test fixtures* — a budgeted cost on a script deleted two slices later, accepted because the only alternative (making the new scanner mimic the old imprecision to keep fixtures green) would defeat the migration's main behavioral fix. The updated e2e suite validates the combination before Slice 3.
- Each slice's OpenSpec change should carry its translation-map rows as the spec's parity checklist, mirroring how per-step skill migrations carried the instruction-parity table.

## Definition of done (whole effort)

1. `overmind run`, `overmind status`, and `overmind project reconcile` are the only entrypoints for the feature and project flows (feature creation happens through `overmind run`, which dispatches the `scaffoldFeature()` primitive at step 3); no `.sh` remains under `overmind/scripts/` for scanner, scaffold, e2e, attach, or reconciliation.
2. All shell test suites for deleted scripts are replaced by TS tests of at least equal scenario coverage.
3. `.setup/models.md` (unchanged format) is loaded through the typed, validated `config/` loader everywhere; no awk parsing remains.
4. `overmind status` step reporting matches `init_progress_definition.yaml` exactly — every declared step, no joining, no omissions.
5. The extension imports `workspace/` + `sequencing/` with zero orchestrator-CLI coupling.
6. Core data problems (parse failures, missing artifacts, inconsistent definitions) surface as `Diagnostic` values in typed results — no throws for data errors; the CLI and the extension render the same values.
7. `npm run verify` (typecheck, type-checked lint, format check, build, all tests) is green locally for every slice; no remote CI; `asdlc-coordinator`'s runtime `dependencies` list is still empty.
8. Every row in `02_responsibility_translation_map.md` is marked owned-or-retired; every decision in `03_target_architecture.md ## Decisions` is confirmed or explicitly revised.
