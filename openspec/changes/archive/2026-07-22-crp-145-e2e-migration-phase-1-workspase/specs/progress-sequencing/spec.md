## ADDED Requirements

### Requirement: Declarative step catalog

The system SHALL define the phase catalog as one declarative `StepDefinition[]` in `sequencing/`, where each entry is `{ id, label, optional, perClass, resumeAliases, actions: Action[] }` and catalog step ids are exactly the `step_number` values declared in `init_progress_definition.yaml` — no joining, no omissions (`03_target_architecture.md ## Key contracts`; decision 2 in `## Decisions`). This replaces the `PHASE_IDS` / `PHASE_OPTIONAL` arrays, `phase_label`, and the 13 hand-written launcher functions plus hard-coded 4.1/4.2 branches (`02_responsibility_translation_map.md` row 5).

The `Action` union is the closed set from `03_target_architecture.md ## Key contracts`:
- a **model session** `{ kind: "session", skillName, modelPhase, requiresSync?, readOnlyGuards, requiredOutputs, runIf? }`, where `runIf` is a name from the closed predicate set (e.g. `hasReadyClassRepo`) and `readOnlyGuards` is the typed union descriptor (`fromContext` | named files with `mustExistUnchanged` | named files with `preserveExistence`); or
- a **deterministic action** `{ kind: "check" | "write", name }` naming an in-process coordinator function.

Steps whose workflow this migration executes — the **feature-phase pipeline** (`phase_name: feature`: steps 3, 4.1, 4.2, 5, 5.1, 6, 7, 7.1, 8, 8.1–8.4) — SHALL carry a **concretely populated, ordered, non-empty** `Action[]` matching the definition, including the boundary cases: `3 = [write(scaffold-feature)]`, `4.1 = [session(repo-br-scan, runIf: hasReadyClassRepo), session(task-to-br)]`, `4.2 = [session(br-clarification), check(br-clarification readiness)]`, and `7.1 = [session(surface-map-enrich, readOnlyGuards: [external_sources.yaml: preserveExistence, init_progress_definition.yaml: preserveExistence], requiredOutputs: [])]`. `requiredOutputs: []` is a legal declaration, not an omission. **Status-only entries are legal:** the project-level **init-phase** steps (`phase_name: init`: 1, 1.1, 2) are detected for status/prerequisite reporting only — their launchers are separate, unmigrated work items (`03_target_architecture.md ## Non-goals`) — so they MAY declare an empty `actions: []`. Emptiness is therefore a scoped, phase-driven allowance (init steps), not a general escape hatch for feature steps. In this slice the catalog is **data only**: the state machine, checklist, and resume/dotted-step resolution read step identity, ordering, `optional`, `perClass`, `resumeAliases`, and (for later reuse) the action metadata — but the actions SHALL NOT be executed here (the generic executor and guard implementation are Slice 2).

#### Scenario: Catalog ids equal definition step ids

- **WHEN** the catalog is compared against the declared `step_number` set of `init_progress_definition.yaml`
- **THEN** every declared step id is present exactly once in the catalog and no catalog id is absent from or added beyond the definition

#### Scenario: Concrete action sequences per step

- **WHEN** the catalog entries for steps 3, 4.1, 4.2, and 7.1 are inspected
- **THEN** step 3 carries `[write(scaffold-feature)]`, step 4.1 carries `[session(repo-br-scan, runIf: hasReadyClassRepo), session(task-to-br)]`, step 4.2 carries `[session(br-clarification), check(br-clarification readiness)]`, and step 7.1 carries a single session with `readOnlyGuards` naming `external_sources.yaml` and `init_progress_definition.yaml` as `preserveExistence` and `requiredOutputs: []`

#### Scenario: Feature-phase steps declare a non-empty typed action sequence

- **WHEN** any feature-phase catalog entry (steps 3 through 8.4) is inspected
- **THEN** its `actions` is a non-empty ordered list whose elements each conform to the closed `Action` union (session with `skillName`/`modelPhase`/`readOnlyGuards`/`requiredOutputs`, or deterministic `check`/`write` with a `name`), so Slice 2's executor has a complete execution contract

#### Scenario: Init-phase steps may be status-only

- **WHEN** the init-phase catalog entries (steps 1, 1.1, 2) are inspected
- **THEN** they are present with correct id/label/optional/scope for status reporting and MAY carry an empty `actions: []`, since their launchers are outside this catalog migration

#### Scenario: Optional and per-class flags carried as data

- **WHEN** a step declared `optional: true` in the definition (e.g. 5.1, 7.1, 8.4) is read from the catalog
- **THEN** its `optional` flag is true, and per-class steps expose `perClass` so the state machine can compute per-class detail

### Requirement: ProgressReport as the primary evaluation

The system SHALL provide `evaluate(workspace, project, feature?) → ProgressReport` as the primary result of `sequencing/`: the typed evaluation of **every** declared step across project and feature scope. Each step entry SHALL carry `{ stepId, name, scope: project|feature, optional, state: done|pending|blocked, perClass?, missingArtifacts[] }`, and the report SHALL carry report-level metadata sufficient for all downstream projections without re-reading the filesystem — at minimum `diagnostics[]`, `featureTitle` (the resolved feature title, or the `<feature not initialized>` fallback), and a typed `definitionParsed: boolean` classification (`false` when `init_progress_definition.yaml` could not be parsed) so the `FeatureSummary` projection can determine `unknown` readiness from a structured field rather than string-matching a diagnostic. The `Diagnostic` type keeps its authoritative shape (`core-diagnostics` capability); classification lives on the report. Step completion SHALL honor the definition's `finished_only_if_artefacts_present` including `special_folder` resolution (init steps resolve from project root; feature steps resolve `/product`/legacy `product` to the feature folder), `required_if` (project_type_code and project_classes `any_of`), and `check_key_value` (scoped section key match), matching the scanner's evaluation semantics. This replaces `init_progress_scanner.sh`'s next-step/status computation (`02_responsibility_translation_map.md` row 4).

The per-step `state` SHALL be assigned by a deterministic rule (independent of the linear checklist rendering):
- **`done`** — all required artifacts (after `required_if` filtering) are present and pass `check_key_value`.
- **`blocked`** — a not-done step whose evaluation is prevented by a hard prerequisite: either (a) an artifact or definition input the step's completion check itself must read is unreadable — i.e. a `finished_only_if_artefacts_present` file that exists but cannot be read (e.g. for a `check_key_value`), or the `init_progress_definition.yaml` metadata needed to filter its `required_if` artifacts is malformed — with an accompanying `Diagnostic` emitted; or (b) it is a feature-scope step and a required project-scope step (project init) is not `done`. This uses only the fields already in scope (`finished_only_if_artefacts_present` + `meta_info`); the advisory `input_required` / `finished_only_if_conditions_meet` fields are NOT parsed. Downstream ordering alone does NOT make a step `blocked`.
- **`pending`** — any other not-done step: prerequisites satisfied and inputs readable, simply not yet complete (normal partial progress, including required steps after the first incomplete one).

The report readiness/blocked signals SHALL be derivable from these states so that `FeatureSummary.readiness` is a pure projection (a `blocked` step ⇒ `blocked`; only `pending` steps and no `blocked` ⇒ `in_progress`).

#### Scenario: Every declared step is reported with a state

- **WHEN** `evaluate` runs against a project with a valid definition and a partially completed feature
- **THEN** the report contains one entry per declared step (project and feature scope), each with a `done`, `pending`, or `blocked` state and its `missingArtifacts` when not done

#### Scenario: Normal partial progress — downstream required steps are pending, not blocked

- **WHEN** project init is complete and a feature has completed steps 3 and 4.1 but not 4.2 onward
- **THEN** step 4.2 and all later required steps are `pending` (prerequisites satisfied, inputs readable), no required step is `blocked`, and the projected readiness is `in_progress`

#### Scenario: Pending project prerequisite blocks feature steps

- **WHEN** a required project-scope step (e.g. step 2) is not `done` and the feature has feature-scope work outstanding
- **THEN** the outstanding feature-scope steps are reported `blocked` and the projected readiness is `blocked`

#### Scenario: Unreadable evaluated artifact blocks the specific step with a diagnostic

- **WHEN** an artifact a step's completion check must read (a `finished_only_if_artefacts_present` file, e.g. a `check_key_value` target) exists but is unreadable
- **THEN** that step is reported `blocked` with an accompanying `Diagnostic` (path and reason), while other steps whose evaluated artifacts are readable continue to be evaluated with their normal states

#### Scenario: required_if filtering by project type and class

- **WHEN** a step artifact is declared `required_if` a project class or `project_type_code` that the project does not have
- **THEN** that artifact does not contribute to the step's completion, matching the scanner's `matches_any_of` / `matches_project_type_code` semantics

#### Scenario: check_key_value gating

- **WHEN** a step declares `check_key_value` (e.g. 4.2 `ready_to_ears: true` in `## 1. Document Meta`) and the artifact exists but the key does not match
- **THEN** the step is reported not-done

#### Scenario: any-matching-artifact mode for optional MCP enrichment

- **WHEN** step 7.1 is evaluated and at least one active-class surface map has `was_enriched_with_mcp: true`
- **THEN** the step is reported done, matching the scanner's any-matching-artifact handling for 7.1

### Requirement: nextStep projection

The system SHALL provide `nextStep() → NextStep { stepId, name, scope, perClassPending? }` as a pure projection over `ProgressReport`: the first non-done **required** (non-optional) step in declaration order, skipping completed and optional steps exactly as the scanner's gating-prefix logic does. The project scope SHALL cover init steps so a later feature flow can detect pending project-level work.

#### Scenario: First pending required step is next

- **WHEN** all steps up to a required pending step are done and that step is the first non-done non-optional step
- **THEN** `nextStep()` returns that step's id, name, and scope

#### Scenario: Optional steps do not become next

- **WHEN** the only non-done steps are optional (e.g. 5.1, 7.1, 8.4)
- **THEN** `nextStep()` skips them and either returns the next required step or reports none when all required steps are done

### Requirement: Checklist and canonical next-step line formatting

The system SHALL format `ProgressReport` into the scanner's inherited output contract: a `# Overmind Bootstrap Checklist` header, a `---- PROJECT LEVEL TASKS ----` heading, a `--- FEATURE LEVEL TASKS <name> ---` heading (feature name taken from the report's `featureTitle`, which already carries the `<feature not initialized>` fallback — the formatter reads no filesystem), `- [x]`/`- [ ] <id> <name>` step lines, and a trailing canonical line that is byte-exactly `next step: <num> (<name>)` when a required step remains or the literal `next step: none` when all required steps are done. This is a **pure projection over the report** — it consumes only report fields (step states, `featureTitle`, `nextStep()`), never re-reading `feature_br_summary.md` or any artifact. The byte-exact line is preserved because the shell e2e's regex parser remains a consumer until Slice 3.

#### Scenario: Byte-exact canonical line with a pending step

- **WHEN** the report has a first pending required step with id `5` and name `Convert Business Requirements Structuring to EARS`
- **THEN** the formatted output's final line is exactly `next step: 5 (Convert Business Requirements Structuring to EARS)`

#### Scenario: Byte-exact canonical line when complete

- **WHEN** every required step in the report is done
- **THEN** the formatted output's final line is exactly `next step: none`

#### Scenario: Feature heading fallback

- **WHEN** the feature folder has no `feature_br_summary.md` or no `feature_title`
- **THEN** the feature heading renders `--- FEATURE LEVEL TASKS <feature not initialized> ---`

### Requirement: Resume-alias and dotted-step resolution

The system SHALL provide resume-alias and dotted-step resolution as pure utilities over the catalog, resolving operator-facing aliases and dotted numeric ids (e.g. `ears`/`4`/`br-to-ears` → `5`, `prerequisite-gaps` → `8.2`) to catalog step ids, preserving the semantics of the shell `map_resume_to_phase`. Unknown aliases SHALL be reported as a typed failure/diagnostic, not thrown.

#### Scenario: Alias resolves to catalog id

- **WHEN** the resume value `implementation-slices` is resolved
- **THEN** it resolves to catalog step id `8.1`

#### Scenario: Unknown resume value is a diagnostic

- **WHEN** an unrecognized resume value is resolved
- **THEN** a typed failure/diagnostic is returned and no exception is thrown

### Requirement: Per-class step-7 detail

The system SHALL compute per-class pending/completed detail for the per-class phase (step 7) within `ProgressReport`, driven by `class_repo_paths` states, replacing `refresh_phase7_status` / `select_phase7_pending_class` computation (`02_responsibility_translation_map.md` row 13). The per-class detail SHALL be data on the report; the loop that consumes it is out of scope for this slice (orchestrator, Slice 3).

#### Scenario: Per-class pending detail for active classes

- **WHEN** a project has multiple active classes and only some have produced their step-7 surface-map artifact
- **THEN** the report's step-7 `perClass` detail marks each active class pending or completed accordingly

### Requirement: FeatureSummary projection ("extension for free")

The system SHALL derive the extension's `FeatureSummary` fields — `readiness`, `completedSteps`, `totalSteps`, `missingArtifacts` (`design_docs/overmind_vscode_extention/technical_requirements.md ## 7. Dashboard Data Contract`) — as a **pure projection** over `ProgressReport`, with no independent computation. `completedSteps`/`totalSteps` are counts over step states, `missingArtifacts` is the union of per-step missing artifacts, and `readiness` maps as: `ready` = all steps done, `in_progress` = pending steps and no blockers, `blocked` = a pending project-scope prerequisite or unreadable inputs, `unknown` = definition parse failure. A test in this slice SHALL prove the projection, validating the reuse claim here rather than in Slice 5.

#### Scenario: FeatureSummary derives from the report

- **WHEN** the projection is applied to a `ProgressReport` with a known mix of done/pending steps and missing artifacts
- **THEN** `completedSteps`/`totalSteps` match the step-state counts, `missingArtifacts` equals the union of per-step missing artifacts, and `readiness` follows the mapping

#### Scenario: Unknown readiness on definition parse failure

- **WHEN** the definition cannot be parsed and the report carries `definitionParsed: false` (plus an explanatory diagnostic)
- **THEN** the projected `readiness` is `unknown`, determined by inspecting the typed `definitionParsed` field (not by string-matching a diagnostic `reason`), and the projection does not throw
