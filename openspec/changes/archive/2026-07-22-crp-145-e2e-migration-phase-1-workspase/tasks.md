## 1. Responsibility inventory (blocks implementation)

- [x] 1.1 Build the responsibility inventory for the touched rows of `02_responsibility_translation_map.md` (rows 1–5, 13, 22, 23); confirm every behavior has a named TS owner in this slice — any unowned behavior blocks the slice
- [x] 1.2 Audit `init_progress_definition.yaml` (schema `overmind/templates/init_progress_definition_TEMPLATE.yaml`) for the exact fields the scanner honors (`step_number`, `phase_name`, `step_name`, `optional`, `finished_only_if_artefacts_present[].{file,special_folder,required_if,check_key_value}`); record which stay advisory (`finished_only_if_conditions_meet`)

## 2. Diagnostics core (lands first — retrofit is invasive)

- [x] 2.1 Add the shared `Diagnostic` type with the authoritative shape `{ severity, source, reason, stepId? }` to `packages/asdlc-coordinator/src/types/`, non-sensitive by construction (no extra fields — parse classification lives on `ProgressReport`, not on `Diagnostic`)
- [x] 2.2 Establish the errors-as-values convention in the touched modules (return `diagnostics[]`, degrade, never throw for data problems); export from `types/index.ts`

## 3. parse/ extension — typed definition metadata read

- [x] 3.1 Extend `parse/project-classes.ts` and siblings to expose `projectTypeCode`, `projectClasses`, and per-class `classRepoPaths` state (per `overmind/init_progress_definition_data_model.md`) in one typed read
- [x] 3.2 Degrade malformed/absent metadata to typed-missing/empty values with a `Diagnostic`; add tests (well-formed read + malformed degradation)

## 4. workspace/ module

- [x] 4.1 Implement runtime-root / staged-workspace detection (pure over fs; diagnostic on missing root, no throw)
- [x] 4.2 Implement project discovery (by `init_progress_definition.yaml` presence) + project-path resolve/validate
- [x] 4.3 Implement feature-folder discovery + infer-project-root-from-feature-path (reject feature-path == project-root as a diagnostic)
- [x] 4.4 Add tests for all three (valid resolve, missing root, invalid project path, feature-path == project-root)

## 5. sequencing/ — catalog + state machine + projections

- [x] 5.1 Define the `Action` union type (`session { skillName, modelPhase, requiresSync?, readOnlyGuards, requiredOutputs, runIf? }` | deterministic `check`/`write { name }`) and the declarative `StepDefinition[]` catalog (`{ id, label, optional, perClass, resumeAliases, actions: Action[] }`); populate concrete non-empty action sequences for the feature-phase steps (incl. `3 = [write(scaffold-feature)]`, `4.1 = [session(repo-br-scan, runIf: hasReadyClassRepo), session(task-to-br)]`, `4.2 = [session(br-clarification), check(readiness)]`, `7.1` session with `preserveExistence` guards + `requiredOutputs: []`); init-phase steps (1, 1.1, 2) are status-only and MAY carry `actions: []`; data only, not executed this slice; catalog ids equal definition `step_number` set
- [x] 5.2 Add tests asserting (a) catalog ids equal the definition's declared step ids exactly (no joins, no omissions), (b) every feature-phase step (3–8.4) has a non-empty typed `actions` sequence with the concrete metadata for the boundary steps 3/4.1/4.2/7.1, and (c) init-phase steps (1, 1.1, 2) are present as status-only entries permitted to carry `actions: []`
- [x] 5.3 Implement `evaluate(workspace, project, feature?) → ProgressReport`: every declared step, project + feature scope, per-step `state`, `missingArtifacts`, report-level `diagnostics[]`, report `featureTitle` (with `<feature not initialized>` fallback), and typed `definitionParsed: boolean` — so projections never re-read the filesystem and readiness `unknown` is a structured signal
- [x] 5.4 Implement the deterministic `done`/`pending`/`blocked` state rule (blocked = an unreadable evaluated artifact / malformed definition metadata the step's check must read, or a not-done required project-scope prerequisite for feature steps; downstream ordering alone is pending, not blocked; the advisory `input_required` / `finished_only_if_conditions_meet` fields are not parsed) and completion semantics matching the scanner: `special_folder` resolution (init → project root; feature → `/product`/legacy `product` → feature folder), `required_if` (project_type_code + project_classes `any_of`), `check_key_value` scoped match, and 7.1 any-matching-artifact mode
- [x] 5.5 Implement `nextStep()` projection (first non-done required step, skip optional/complete; project scope covers init steps)
- [x] 5.6 Implement per-class step-7 detail on the report (driven by `class_repo_paths` states)
- [x] 5.7 Implement resume-alias + dotted-step resolution as pure utilities over the catalog (parity with `map_resume_to_phase`); unknown alias → diagnostic, not throw
- [x] 5.8 Add step-reporting tests derived from `init_progress_definition.yaml` (every declared step reported; correct type/class filtering; check_key_value gating) plus state-rule tests (normal partial progress → downstream pending; pending project prerequisite → feature steps blocked; unreadable completion artifact / malformed definition metadata → that step blocked with a diagnostic; `input_required` / `finished_only_if_conditions_meet` not parsed)
- [x] 5.9 Add the diagnostics-not-throws acceptance test (malformed/missing definition → degraded `ProgressReport` + populated `diagnostics[]`, no throw)

## 6. Checklist + canonical-line formatter

- [x] 6.1 Implement the checklist formatter as a pure projection over `ProgressReport` (header, `---- PROJECT LEVEL TASKS ----`, `--- FEATURE LEVEL TASKS <name> ---` with `feature_title` fallback `<feature not initialized>`, `- [x]/[ ] <id> <name>` lines)
- [x] 6.2 Implement the byte-exact canonical line (`next step: <num> (<name>)` / literal `next step: none`)
- [x] 6.3 Add the canonical-line contract test (pending fixture + fully-complete fixture, byte-for-byte)

## 7. FeatureSummary projection ("extension for free")

- [x] 7.1 Implement the `FeatureSummary` projection over `ProgressReport` (`readiness`, `completedSteps`, `totalSteps`, `missingArtifacts`) per the readiness mapping (`ready`/`in_progress`/`blocked`/`unknown`)
- [x] 7.2 Add the projection test proving derivation (counts, union of missing artifacts, readiness mapping incl. `unknown` on parse failure) — validates the reuse claim in this slice

## 8. overmind status CLI verb

- [x] 8.1 Add the `status` branch to `cli/run.ts`: resolve workspace → `evaluate` → render checklist to stdout → render `diagnostics[]` to stderr + exit code; read-only, no `step_state_<feature>.md` write
- [x] 8.2 Support project-path and feature-path invocation as a positional argument (`overmind status <path>`, consistent with the existing positional dispatch; behavior-parity with the scanner's path handling, not a literal `--path` flag)
- [x] 8.3 Add CLI tests (feature-path prints checklist; project-path project-scope; invalid path → stderr diagnostic + non-zero exit, no throw)

## 9. Transitional rewire of the shell e2e

Fixture audit result: the suite already used precise ids for all status fixtures; the one stale joined-label expectation was `next step: 4.1 (Initialize and Enrich Business Requirements Structuring)`, now corrected to the definition-exact `next step: 4.1 (Scan repo and apply task-to-BR update)`. No legacy `next step: 4 (...)` fixture remains. Scanner invocation log expectations now name `overmind status <feature-path>`.

- [x] 9.1 Enumerate (in this file / spec audit) every `tests/ai_scripts/project_add_feature_e2e_tests.sh` expectation that shifts from a joined/omitted scanner id to a precise definition id
- [x] 9.2 Rewire `project_add_feature_e2e.sh` `scanner_status_line_for_feature` / `run_scanner_and_get_next_step` to call `node .overmind/overmind.js status`
- [x] 9.3 Correct `map_scanner_step_to_phase` (drop legacy `4 → 5` remap + name-substring fallbacks — now dead) and the `fail_project_prerequisite_step` case labels to precise project-step ids
- [x] 9.4 Update every enumerated e2e fixture to the precise id — never by making the scanner mimic the old imprecision

## 10. Delete + de-stage the shell scanner

- [x] 10.1 Delete `overmind/scripts/project_mgmt/init_progress_scanner.sh`
- [x] 10.2 Delete `tests/ai_scripts/init_progress_scanner_tests.sh`
- [x] 10.3 Stop staging the scanner in `project_setup_first_init_machine.sh`; remove the `init_progress_scanner_tests.sh` entry from **both** instruction files' test-suite lists in the same change (`AGENTS.md`, `CLAUDE.md`), per their maintenance rule to update changed commands in the same change

## 11. Verify

- [x] 11.1 Run `npm run verify` (typecheck → lint → format-check → build → test across TS workspaces + surviving `tests/ai_scripts/*.sh`, including the updated e2e suite); resolve all failures
- [x] 11.2 Confirm `asdlc-coordinator`'s runtime `dependencies` list is still empty
- [x] 11.3 Confirm the Slice 1 rows of `02_responsibility_translation_map.md` (1–5, 13, 22, 23) are demonstrably owned by the named TS modules with tests
