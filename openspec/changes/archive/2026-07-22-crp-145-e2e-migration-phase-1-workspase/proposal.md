## Why

The E2E orchestrator migration (`design_docs/e2e_orchestrator_migration/`) replaces the bash e2e/scanner with a TypeScript functional core. Slice 0 (`crp-144`) landed the toolchain baseline; this change is Slice 1 — **the pure foundation both the orchestrator and the VS Code extension stand on** (`04_migration_plan.md ## Slice 1 — Workspace + sequencing core (`overmind status`)`, contracts in `03_target_architecture.md ## Key contracts`).

Slice 1 also carries the migration's main behavioral **change** (not just a port): the old `init_progress_scanner.sh` is known-imprecise — it joins some steps and omits others relative to `init_progress_definition.yaml`. The TS `sequencing/` module is a **new** scanner whose spec is the definition file itself (decision 2 in `03_target_architecture.md ## Decisions`): every declared step reported, no joining, no omissions. Only the old scanner's *output contract* (rendered checklist + canonical `next step: <num> (<name>)` line) is inherited. This precision is why the transitional rewire of `project_add_feature_e2e.sh` must touch its mapping points **and its test fixtures** — a budgeted cost on a script deleted two slices later, accepted because making the new scanner mimic the old imprecision would defeat the migration's main fix.

## What Changes

- Add **`workspace/`**: runtime-root/staged-workspace detection, project discovery + validation (by `init_progress_definition.yaml` presence), and feature-folder discovery — pure over fs reads (map rows 1–2).
- Extend **`parse/`**: one typed read exposing `projectTypeCode`, `projectClasses`, and per-class `classRepoPaths` state from `init_progress_definition.yaml`, replacing the awk metadata blocks (map row 3).
- Add **`sequencing/`**: a declarative `StepDefinition[]` step catalog and a state machine whose **primary result is `ProgressReport`** (typed evaluation of every declared step — state, project/feature scope, per-class step-7 detail, missing artifacts, report-level diagnostics). `nextStep()`, the checklist formatter, the canonical `next step:` line, and dotted-step/resume-alias resolution are pure **projections/utilities** over the report (map rows 4–5, partial 13).
- Add **`overmind status <path>`** CLI verb (project or feature path — mirrors the scanner's `--path` behavior), extending the existing `capture|context|gate|sync|readiness` dispatch (map row 22). Its printed output preserves the scanner's checklist + byte-exact `next step:` line contract.
- Add the cross-cutting **`Diagnostic`** type and the **errors-as-values** convention for pure modules from day one (retrofit is invasive): malformed/missing definition inputs yield a degraded `ProgressReport` with populated `diagnostics[]` — no throw (map row 23).
- **Acceptance proofs, as tests in this slice:** (a) step-reporting derives from `init_progress_definition.yaml` (every declared step, correct type/class filtering); (b) the extension's `FeatureSummary` fields (`readiness`, `completedSteps`, `totalSteps`, `missingArtifacts`) are derivable from `ProgressReport` by pure projection — the "extension for free" claim, validated here not in Slice 5; (c) malformed/missing inputs degrade with diagnostics rather than throwing; (d) the byte-exact canonical-line contract (`next step: <num> (<name>)` and literal `next step: none`).
- **BREAKING (transitional, intentional):** the new scanner reports precise definition step ids where the old one joined/omitted. **Rewire** `project_add_feature_e2e.sh` `scanner_status_line_for_feature` / `run_scanner_and_get_next_step` to call `node .overmind/overmind.js status` instead; correct **both** shell mapping points (`map_scanner_step_to_phase` and the `fail_project_prerequisite_step` case labels become dead compensation for the old drift); update every shifted e2e test fixture in `tests/ai_scripts/project_add_feature_e2e_tests.sh`. Fixture breakage MUST NOT be resolved by making the scanner mimic the old imprecision. This is the only transitional shell edit in the plan.
- **Delete:** `overmind/scripts/project_mgmt/init_progress_scanner.sh` and its shell tests (`tests/ai_scripts/init_progress_scanner_tests.sh`); staging (`project_setup_first_init_machine.sh`) stops staging the scanner.
- **No new runtime dependencies:** `asdlc-coordinator`'s `dependencies` list stays empty (zero-runtime-dependency rule).

## Capabilities

### New Capabilities
- `workspace-model`: runtime-root/staged-workspace detection, project discovery + validation, feature-folder discovery, and the extended typed definition read (`projectTypeCode`, `projectClasses`, per-class `classRepoPaths` state) — the pure workspace layer the CLI and the extension both consume.
- `progress-sequencing`: the declarative step catalog and the `evaluate → ProgressReport` state machine, with `nextStep()`, checklist + canonical-line formatting, dotted-step/resume-alias resolution, per-class step-7 detail, and the `FeatureSummary` projection — all pure over the report. Definition-as-spec: every declared step reported precisely.
- `core-diagnostics`: the shared `Diagnostic` type and the errors-as-values convention for the pure core (no throws for data problems; degrade + `diagnostics[]`), carried by `ProgressReport.diagnostics`.
- `overmind-status-command`: the `overmind status <path>` CLI verb and its inherited output contract (checklist + byte-exact `next step:` line), the transitional rewire of `project_add_feature_e2e.sh`, and the deletion of the shell scanner + its tests + its staging.

### Modified Capabilities
<!-- None — openspec/specs/ is empty; there are no published specs whose requirements change. The prior toolchain-baseline capability (crp-144 engineering-baseline) is not modified; this change adds distinct new capabilities. -->

## Impact

- **New (`packages/asdlc-coordinator/src/`):** `workspace/`, `sequencing/` (step catalog + state machine + projections), a new `Diagnostic` type in `types/`, and the `status` branch in `cli/run.ts`.
- **Extended:** `parse/project-classes.ts` and siblings — typed `projectTypeCode` / `projectClasses` / `classRepoPaths` read.
- **New tests (TS):** step-reporting derived from `init_progress_definition.yaml`; `FeatureSummary` projection; diagnostics-not-throws; byte-exact canonical-line contract test (the shell e2e's regex parser stays a consumer until Slice 3).
- **Transitional shell edits:** `project_add_feature_e2e.sh` (call `overmind status`; dead-out both mapping points) and `tests/ai_scripts/project_add_feature_e2e_tests.sh` fixtures for every shifted step id; `project_setup_first_init_machine.sh` staging stops staging the scanner.
- **Deleted:** `overmind/scripts/project_mgmt/init_progress_scanner.sh`, `tests/ai_scripts/init_progress_scanner_tests.sh`.
- **Verification:** green local `npm run verify` (typecheck → lint → format-check → build → test across TS workspaces and the surviving `tests/ai_scripts/*.sh` suites) is the completion criterion.
- **Out of scope:** runner/config/orchestrator/git/interaction/state modules (Slices 2–4), scaffold primitive and `overmind run` (Slice 3), project reconcile (Slice 4), the VS Code extension implementation (Slice 5). No changes to skill bodies, gates, or artifact formats.
