## Context

Slice 1 of the E2E orchestrator migration builds the **pure functional core** — `workspace/` + `sequencing/`, plus a `parse/` extension and the cross-cutting `Diagnostic` type — that the orchestrator (Slices 3–4) and the VS Code extension (Slice 5) both stand on. Nothing here spawns a process, writes an artifact, or talks to an operator; every module is a pure function over `(definition, artifact tree)` fs reads (`03_target_architecture.md ## Core principle: functional core, imperative shell`).

Current state: `packages/asdlc-coordinator/src/` already holds `parse/`, `context/`, `validate/`, `readiness/`, `sync/`, `capture/`, `repo/`, and the `cli/run.ts` dispatch (`gate|context|capture|sync|readiness`). The runtime scanner is still the bash `overmind/scripts/project_mgmt/init_progress_scanner.sh`, invoked by the shell e2e (`project_add_feature_e2e.sh`) via `.commands/init_progress_scanner.sh --path <feature>` and parsed with a `next step:` regex. `init_progress_definition.yaml` (schema: `overmind/templates/init_progress_definition_TEMPLATE.yaml`) is the per-project runtime source of truth listing every step (`step_number`, `phase_name`, `step_name`, `optional`, `finished_only_if_artefacts_present[]` with `special_folder` / `required_if` / `check_key_value`).

Constraints: `asdlc-coordinator`'s runtime `dependencies` stays empty (zero-runtime-dependency rule); Node's built-in test runner only; `npm run verify` (Slice 0) green locally is the completion gate; no changes to skill bodies, gates, or artifact formats.

## Goals / Non-Goals

**Goals:**
- A pure `sequencing/` state machine whose primary result is `ProgressReport` — the typed evaluation of **every** declared step (project + feature scope), from which `nextStep()`, the checklist, the canonical `next step:` line, and the extension's `FeatureSummary` are pure projections.
- A **new, definition-as-spec** scanner: step reporting reflects `init_progress_definition.yaml` exactly (no joining, no omissions), while preserving the old scanner's *output contract* (checklist layout + byte-exact `next step: <num> (<name>)` / `next step: none`).
- A `workspace/` layer (runtime-root detection, project discovery/validation, feature discovery) and a typed `parse/` read (`projectTypeCode`, `projectClasses`, `classRepoPaths` state) reusable unchanged by the extension.
- Errors-as-values from day one: a shared `Diagnostic` type; pure modules degrade instead of throwing on data problems.
- `overmind status <path>` CLI verb; the shell e2e rewired onto it; the shell scanner and its tests deleted; fixtures corrected for the precision change.

**Non-Goals:**
- No runner/config/orchestrator/git/interaction/state modules (Slices 2–4), no scaffold primitive or `overmind run` (Slice 3), no `overmind project reconcile` (Slice 4), no extension code (Slice 5).
- No new `init_progress_definition.yaml` fields (e.g. `contract_reconciled` lands in Slice 4).
- No change to the definition format, skill bodies, gates, or artifact formats.
- No auto-advance / interactivity (feature flow is later slices).

## Decisions

### D1 — `ProgressReport` is primary; everything else projects over it
`evaluate(workspace, project, feature?) → ProgressReport` returns per-step `{ stepId, name, scope: project|feature, optional, state: done|pending|blocked, perClass?, missingArtifacts[] }` plus report-level `diagnostics[]`. `nextStep()`, the checklist formatter, the canonical line, per-class step-7 detail, and `FeatureSummary` are **pure functions of the report**, never independent computations (`03_target_architecture.md ## Key contracts` — "the reuse claim is carried by `ProgressReport`, not by `NextStep`"). *Why:* the extension's readiness model and the CLI's checklist must be the same computation with two renderers — proven here by a `FeatureSummary` projection test, so the "extension for free" claim is validated in Slice 1, not discovered false in Slice 5. *Alternative rejected:* a `nextStep`-first design (as the shell scanner effectively is) would force the extension to recompute step states, forking the model.

### D2 — Definition-as-spec, not parity-port (migration's main behavioral change)
The catalog/state-machine reports **every** `step_number` in `init_progress_definition.yaml`, with `required_if` (project_type_code / project_classes) and `check_key_value` honored per the template, and `special_folder` resolution matching the scanner (init steps always resolve from project root; feature steps resolve `/product` → feature folder). It does **not** reproduce the old scanner's joining (`4` standing in for 4.1/4.2/5) or name-substring fallbacks. Step-reporting tests derive from the definition file; old shell scanner tests inform output *format* and edge cases only (decision 2 in `03_target_architecture.md ## Decisions`). *Why:* the definition file is the contract; the old imprecision is a bug, and `map_scanner_step_to_phase` exists only to paper over it. *Trade-off:* the shell e2e's fixtures shift — see Migration Plan.

### D3 — Output contract preserved byte-exactly
`overmind status` prints the same shape the scanner did: `# Overmind Bootstrap Checklist`, a `---- PROJECT LEVEL TASKS ----` heading, a `--- FEATURE LEVEL TASKS <name> ---` heading (feature title from `feature_br_summary.md ## 1. Document Meta` `feature_title`, else `<feature not initialized>`), `- [x]/[ ] <id> <name>` lines, and a trailing `next step: <num> (<name>)` or the literal `next step: none`. A dedicated TS **contract test** asserts the canonical line byte-for-byte, because the shell e2e's regex parser stays a consumer until Slice 3. *Why:* the consumer (`parse_scanner_next_step_line`) is unchanged this slice; only the producer moves. *Note:* the scanner's side effect of writing `step_state_<feature>.md` is not part of the `status` command contract — `status` is read-only compute to stdout (supersession table, `03_target_architecture.md ### Supersession of the extension design docs`).

### D4 — Errors are values; pure modules never throw for data problems
A shared `Diagnostic { severity: error|warning, source: <path>, reason, stepId? }` in `types/`. Malformed YAML, missing/unreadable artifacts, and inconsistent definitions produce `diagnostics[]` and degrade the affected item (`blocked` step state, or `unknown` readiness) rather than crashing (`03_target_architecture.md ## Diagnostics`). Throwing is reserved for programmer errors. Diagnostics are non-sensitive by construction (paths and reasons, never file content). *Why:* retrofitting this after five slices is invasive; the extension's "degrade to unknown, don't crash the dashboard" NFR comes for free only if the core is built this way from the start.

### D5 — `overmind status <path>` accepts project or feature path (positional)
A new `status` branch in the existing `cli/run.ts` dispatch. The path is a **positional argument** (`overmind status <path>`), consistent with the existing positional dispatch (`overmind <command> <step> <path>`); the scanner's `--path` is mirrored in *behavior* (project-or-feature path acceptance), not as a literal flag (`04_migration_plan.md ## Slice 1`). The CLI is a thin adapter: it resolves the workspace, calls `evaluate`, renders the checklist to stdout, and renders `diagnostics[]` to stderr with exit codes — it never invents diagnostics (adapters render, never invent). Given a feature path it renders both project and feature scopes; given a project path it renders project scope with the feature title fallback.

### D6 — Reuse existing parsers; extend `parse/`, don't fork
The typed `projectTypeCode` / `projectClasses` / `classRepoPaths` read extends `parse/project-classes.ts` and siblings (map row 3, "Existing, extend"), reusing the existing markdown/definition parsing utilities rather than re-implementing YAML slicing. `classRepoPaths` state is read per the shape in `overmind/init_progress_definition_data_model.md`.

### D7 — Catalog is declarative data, executed by no code this slice
`StepDefinition { id, label, optional, perClass, resumeAliases, actions: Action[] }` lands as **data** in `sequencing/step-catalog.ts`; `actions` shapes (session/deterministic) are typed but **not executed** here — the runner is Slice 2, the orchestrator Slice 3. This slice only *reads* the catalog for step identity, ordering, optional flags, labels, resume aliases, and per-class flags used by `evaluate`, the checklist, and resume/dotted-step resolution. *Why:* the catalog is the single source both the state machine and the later executor read; defining it now (even with unused action metadata) keeps catalog ids equal to definition ids from the start.

## Risks / Trade-offs

- **Fixture churn masks a real bug** → The audit step (Migration Plan step 4) enumerates every shifted fixture from the spec *before* editing; fixtures are corrected to the precise id, never by softening the scanner. A reviewer diffs the fixture changes against the enumerated list.
- **Byte-exact line drift breaks the still-live shell e2e parser** → The TS canonical-line contract test pins `next step: <num> (<name>)` and `next step: none` exactly; run the full `tests/ai_scripts/project_add_feature_e2e_tests.sh` under `npm run verify` before completion.
- **Definition/catalog divergence** → A test asserts catalog step ids are exactly the definition's `step_number` set (no joins, no omissions) for the template and representative fixtures; a divergence is a diagnostic, not a silent skip.
- **Over-reading the definition schema** → Only the fields the scanner honors (`step_number`, `phase_name`, `step_name`, `optional`, `finished_only_if_artefacts_present[].{file,special_folder,required_if,check_key_value}`) are consumed; `finished_only_if_conditions_meet` remains advisory prose, exactly as today.
- **Scope creep into runner/orchestrator** → `actions` metadata is defined but never executed; any temptation to run it is out of scope (Slice 2+).

## Migration Plan

1. **Responsibility inventory** for touched rows of `02_responsibility_translation_map.md` (rows 1–5, 13, 22, 23) — confirm every behavior has a named TS owner before implementation; any unowned behavior blocks the slice.
2. **Land the core:** `types/` Diagnostic → `parse/` extension → `workspace/` → `sequencing/` (catalog + `evaluate` + projections), each with tests, degrading via diagnostics.
3. **Land the CLI:** `status` branch in `cli/run.ts`; canonical-line contract test.
4. **Fixture audit + rewire (transitional):** enumerate in the spec every `tests/ai_scripts/project_add_feature_e2e_tests.sh` expectation that shifts from a joined/omitted id to a precise id; rewire `project_add_feature_e2e.sh` `scanner_status_line_for_feature` / `run_scanner_and_get_next_step` to `node .overmind/overmind.js status`; correct **both** `map_scanner_step_to_phase` and the `fail_project_prerequisite_step` case labels (now dead compensation); update the enumerated fixtures to precise ids — never by making the scanner mimic the old imprecision.
5. **Delete + de-stage:** remove `init_progress_scanner.sh` and `tests/ai_scripts/init_progress_scanner_tests.sh`; `project_setup_first_init_machine.sh` stops staging the scanner.
6. **Verify:** `npm run verify` green (TS workspaces + surviving `tests/ai_scripts/*.sh`, including the updated e2e suite).

**Rollback:** revert the change; the shell scanner and its staging return with the rewire. No persisted state or artifact format changes to unwind.

## Open Questions

- None blocking. The `status`-on-project-path rendering detail (D5) follows the scanner's path semantics; if a project-path invocation should suppress the feature heading entirely (rather than show the `<feature not initialized>` fallback), that is a cosmetic choice resolvable during implementation without a spec change.
