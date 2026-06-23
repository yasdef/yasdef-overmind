## ADDED Requirements

### Requirement: surface-map structural validation is per-class

The `surface-map` validator SHALL validate a feature's `project_surface_struct_resp_map_<class>.md` for a requested class with behavior parity to the former `check_feature_repo_surface_and_exec_context_be_quality.sh` (class `backend`) and `..._fe_quality.sh` (class `frontend` or `mobile`). It SHALL exit `1` when the target is empty or whitespace-only, and SHALL exit `1` when the artifact contains any `[UNFILLED]` or `[OPTIONAL…]` placeholder. It SHALL require the per-class document title, and the sections `## 1. Document Meta`, `## 2. Feature Scope`, `## 3. Key Parts of Repo and Their Responsibilities`, and the per-class `## 4. … Surfaces Touched With Current Feature`. It SHALL require the nine meta keys `repo_name`, `service_name`, `project_type_code`, `project_classes`, `feature_id`, `feature_title`, `analyzed_repo_paths`, `source_inputs_used`, `last_updated` (each present and filled), with `project_type_code` one of `A`/`B`/`C` and `last_updated` matching `YYYY-MM-DD`. It SHALL require the three scope keys `feature_summary`, `in_scope_feature_delta`, `out_of_scope_notes` (filled). It SHALL require the seven per-class layer subsections (`### 3.1 …` through `### 3.7 …`), each with filled `responsibility_summary`, `main_repo_paths`, `key_components`, `transport_layer`, `user_reachable_surface`, plus the `### 3.8 Another Layer(s)` subsection. It SHALL require the eight per-class surface subsections (`### 4.1 …` through `### 4.8 …`), each with filled `surface_summary`, `applicability`, `repo_paths`, `why_feature_touches_it`, `expected_changes`, `evidence`, `transport_layer`, `user_reachable_surface`, and SHALL require at least one surface with `applicability: applicable`. The per-class config SHALL assert `project_classes` includes `backend` for the backend class, or `frontend` or `mobile` for the frontend/mobile class, and SHALL use that class's title, section-4 heading, and layer/surface names; `mobile` SHALL use the frontend config. The validator SHALL exit `0` on a structurally complete artifact with the per-class pass message, exit `1` with the same `quality gate failed: …` messages on any violation, and exit `2` on runtime failure. The validator SHALL read only the target artifact.

#### Scenario: Structurally complete backend surface map passes

- **WHEN** `overmind gate surface-map <feature-path> --class backend` runs against a `project_surface_struct_resp_map_backend.md` with the backend title, all four sections, the nine filled meta keys, the three scope keys, all seven backend layer subsections (plus `### 3.8`), all eight backend surface subsections with at least one `applicable`
- **THEN** the validator exits `0` with the backend pass message

#### Scenario: Frontend and mobile use the frontend config

- **WHEN** `overmind gate surface-map <feature-path> --class frontend` (or `--class mobile`) runs against a `project_surface_struct_resp_map_frontend.md` (or `…_mobile.md`) with the frontend/mobile title, section-4 heading, frontend layer/surface names, and `project_classes` including `frontend` or `mobile`
- **THEN** the validator applies the frontend config and exits `0` on a complete artifact

#### Scenario: Empty or placeholder target fails

- **WHEN** the target is empty, whitespace-only, or still contains a `[UNFILLED]` or `[OPTIONAL…]` placeholder
- **THEN** the validator exits `1` reporting the empty target or the remaining template placeholders

#### Scenario: Missing section, meta, scope, layer, or surface field fails

- **WHEN** the artifact is missing the title, a required section, a filled meta key (or has an invalid `project_type_code`/`last_updated`), a scope key, a layer subsection or one of its five fields (or `### 3.8`), or a surface subsection or one of its eight fields
- **THEN** the validator exits `1` naming the missing section/field

#### Scenario: No applicable surface fails

- **WHEN** no surface subsection is marked `applicability: applicable`
- **THEN** the validator exits `1` reporting that at least one surface should be applicable

#### Scenario: Wrong project_classes for the class fails

- **WHEN** `--class backend` is validated but `project_classes` does not include `backend`, or `--class frontend`/`mobile` is validated but `project_classes` includes neither `frontend` nor `mobile`
- **THEN** the validator exits `1` reporting the `project_classes` mismatch

#### Scenario: Runtime failure escalates

- **WHEN** the target path cannot be read for reasons other than emptiness
- **THEN** the validator exits `2` with a runtime error message

### Requirement: surface-map context assembly is per-class with blueprint fallback

The `surface-map` context builder SHALL assemble the step's dynamic context for a feature path and a requested class with parity to `feature_repo_surface_and_exec_context.sh`'s prompt. It SHALL resolve the feature path and its `projects/<id>` root (exit `2` if not under `projects/<id>/<feature>`), the read-only `init_progress_definition.yaml`, `requirements_ears.md`, and `feature_contract_delta.md` (exit `2` if any absent), and SHALL verify the requested class is an active `meta_info.project_classes` member (exit `2` otherwise). It SHALL resolve the class's scan scope: the class's **ready** repository path (running a read-only branch-state check, blocking exit `2` verbatim on wrong-branch/dirty) when ready, otherwise a blueprint fallback using `project_stack_blueprint_<class>.md` as planned structural evidence, exiting `2` only when neither a ready repo nor a blueprint exists. It SHALL collect committed siblings' `implementation_plan.md` as in-flight read-only evidence. On success the assembled block SHALL include the per-class binding (track label, skill-relative template + golden-example asset references for that class, the target artifact `project_surface_struct_resp_map_<class>.md`, the single allowed-write target), the scan scope (ready repo path or blueprint-fallback note), one `- read_only_input: <workspace-relative-path>` manifest entry per resolved read-only input (the three always-on inputs, the optional blueprint, and the in-flight plans), the `project_classes` meta value for the run, and the exact `surface-map --class <class>` gate command. It SHALL NOT perform repo writes.

#### Scenario: Context assembled for a class with a ready repo

- **WHEN** `overmind context surface-map <feature-path> --class backend` runs and the three required inputs exist and the backend class has a ready repo
- **THEN** the builder prints the backend binding (be template/golden assets, `project_surface_struct_resp_map_backend.md` target/allowed-write), the ready repo path as scan scope, a `read_only_input` manifest covering the three always-on inputs plus any blueprint and in-flight plans, and the exact `surface-map --class backend` gate command, and exits `0`

#### Scenario: Blueprint fallback when no repo is ready

- **WHEN** the requested class has no ready repo but `project_stack_blueprint_<class>.md` exists
- **THEN** the context emits a blueprint-fallback scan scope (no repo path) and includes the blueprint in the `read_only_input` manifest, and exits `0`

#### Scenario: Class not analyzable blocks context

- **WHEN** the requested class is not an active `project_classes` member, or it has neither a ready repo nor a stack blueprint
- **THEN** the builder exits `2` with a message naming the unusable class

#### Scenario: Missing required input or dirty repo blocks context

- **WHEN** `init_progress_definition.yaml`, `requirements_ears.md`, or `feature_contract_delta.md` is absent, or the class's ready repo is on the wrong branch or dirty
- **THEN** the builder exits `2` (verbatim for the repo branch-state block)

#### Scenario: Context uses skill-relative asset paths

- **WHEN** the context emits asset references
- **THEN** they use `assets/...` paths relative to the loaded `overmind-surface-map` skill directory, with no hardcoded `.codex`/`.claude`/source-repo paths

### Requirement: surface-map ready-repo sync is per-class

The `sync surface-map` verb SHALL sync the requested class's **ready** repository to its default branch before the model session, reusing the shared ready-path resolver and default-branch sync helper. A class with no ready repo (blueprint fallback) SHALL be a no-op exiting `0`. It SHALL exit `0` on success and exit `2` reporting the blocking repo message when the ready repo cannot be synced.

#### Scenario: Ready class repo synced before the session

- **WHEN** `overmind sync surface-map <feature-path> --class backend` runs and the backend class has a ready repo
- **THEN** that repo is synced to its default branch and the verb exits `0`

#### Scenario: Blueprint-fallback class sync is a no-op

- **WHEN** the requested class has no ready repo
- **THEN** the verb exits `0` without syncing

#### Scenario: Unsyncable repo blocks

- **WHEN** the requested class's ready repo cannot be synced
- **THEN** the verb exits `2` reporting the blocking repo message

### Requirement: surface-map CLI requires a valid class

The `gate`, `context`, and `sync` verbs for the `surface-map` step SHALL accept a `--class <backend|frontend|mobile>` option, validate the value against that set, and exit `2` with a usage error when the option is missing or the value is unknown. The class SHALL be passed through to the registered validator, context builder, and syncer.

#### Scenario: Missing or invalid class is a usage error

- **WHEN** `overmind gate|context|sync surface-map <feature-path>` runs without `--class`, or with `--class infra`
- **THEN** the CLI exits `2` with a usage error naming the supported classes

#### Scenario: Valid class is dispatched

- **WHEN** a verb runs with `--class backend`, `--class frontend`, or `--class mobile`
- **THEN** the CLI dispatches the corresponding per-class behavior

### Requirement: overmind-surface-map skill

The packaged `overmind-surface-map` skill SHALL provide the per-class model-facing orchestrator for step 7, with `feature_repo_surface_and_exec_context_rule.md` inlined into `SKILL.md` and both the backend and frontend/mobile templates plus golden examples under `assets/`. `SKILL.md` SHALL instruct the model to: run `overmind context surface-map <feature-path> --class <class>`; read the per-class binding and scan scope from the context block; scan only the listed repository path (or rely on the blueprint fallback as primary planned structural evidence when no repo is listed); draft `project_surface_struct_resp_map_<class>.md` from the bound per-class template and golden example; write only that one file and never modify `init_progress_definition.yaml`, `requirements_ears.md`, `feature_contract_delta.md`, the class blueprint, or any in-flight `implementation_plan.md`; and run `overmind gate surface-map <feature-path> --class <class>` after every write or repair. Gate exit handling SHALL be: `0` complete; `1` read the gate output, repair the artifact, and rerun the gate; `2` stop and report the blocker. The two literal track-parameterized final-response lines — the success line `Repo surface and execution context <track> phase is finished. Nothing else to do now; press Ctrl-C so orchestrator can start the next phase` and the infeasibility line `repo surface and execution context <track> gate cannot pass with current repository evidence. Please provide instructions what to do, or adjust requirements and rerun this phase` — SHALL appear only in `SKILL.md`, with `<track>` filled from the context-supplied track label.

#### Scenario: Skill drives the per-class gate loop

- **WHEN** the model loads `overmind-surface-map` for a class and the gate exits `1`
- **THEN** the model reads the gate output, repairs `project_surface_struct_resp_map_<class>.md`, and reruns `overmind gate surface-map --class <class>` without modifying any read-only input

#### Scenario: Skill finishes on gate pass with the track success line

- **WHEN** the gate exits `0`
- **THEN** the model ends its final response with the exact track-parameterized success line defined only in `SKILL.md`

#### Scenario: Skill uses the blueprint fallback as planned evidence

- **WHEN** the context scan scope is a blueprint fallback (no ready repo)
- **THEN** the model treats `project_stack_blueprint_<class>.md` as the primary planned structural evidence and does not invent repository facts

#### Scenario: Skill stops with the infeasibility line when the gate cannot pass

- **WHEN** the model determines the gate cannot pass with the current repository/blueprint evidence
- **THEN** it stops finalization and ends with the exact track-parameterized infeasibility line defined only in `SKILL.md`

#### Scenario: Read-only inputs and single-target boundary are preserved

- **WHEN** the model authors the surface map
- **THEN** it writes only `project_surface_struct_resp_map_<class>.md` and does not modify the definition, requirements, contract delta, class blueprint, or any in-flight plan

### Requirement: Feature e2e phase-7 loop drives the surface-map skill per class

The `project_add_feature_e2e.sh` phase-7 class loop SHALL, on "Analyze one class now", select a pending class and launch the `overmind-surface-map` skill for that class (via a Codex session) instead of the deleted `feature_repo_surface_and_exec_context.sh`. Before launching it SHALL run `overmind sync surface-map <feature-path> --class <class>`, preflight-check the installed `overmind-surface-map` skill and `.overmind/overmind.js`, and load the `feature_repo_surface_and_exec_context` model row, failing before launch when the skill/CLI is missing, the model command is not `codex`, or the sync blocks. The launcher prompt SHALL include only runtime bindings and the exact `context`/`gate surface-map --class <class>` commands; it SHALL NOT duplicate the skill's literal final-response lines or gate exit-code handling, and SHALL NOT run the model gate itself. To preserve the former read-only protection deterministically, the launcher SHALL derive the read-only set from the context `read_only_input` manifest, snapshot each input before the session, and assert each byte-unchanged after the session — on **every** exit path, evaluated before returning the model's exit code, with the read-only-corruption error winning when the model both mutates an input and exits non-zero. It SHALL also assert the per-class output `project_surface_struct_resp_map_<class>.md` was produced. Class selection SHALL be owned by the loop; the skill SHALL never prompt for the class. The `feature_repo_surface_and_exec_context.sh` entry SHALL be removed from the phase-7 loop.

#### Scenario: Phase 7 selects a class then syncs and launches the skill

- **WHEN** the operator chooses "Analyze one class now" and picks a pending class
- **THEN** the loop runs `overmind sync surface-map --class <class>`, then starts a Codex session telling the model to load `overmind-surface-map` with the runtime bindings and the exact `context`/`gate surface-map --class <class>` commands
- **AND** the launcher prompt contains neither literal final-response line

#### Scenario: Completed class advances the loop

- **WHEN** a class's surface map is produced and the loop refreshes status
- **THEN** that class is marked completed and the loop offers the remaining pending classes

#### Scenario: Orchestrator does not run the surface-map gate itself

- **WHEN** the phase-7 loop runs a class
- **THEN** the orchestrator does not invoke `overmind gate surface-map`; the model owns the gate loop

#### Scenario: Missing skill or CLI fails before launching

- **WHEN** the phase-7 loop runs a class but the installed `overmind-surface-map` skill or `.overmind/overmind.js` is absent
- **THEN** the orchestrator fails before launching the Codex session, reporting the missing skill or CLI

#### Scenario: Read-only input mutation fails the phase even on model failure

- **WHEN** the skill session mutates any read-only input (definition, requirements, contract delta, class blueprint, or an in-flight plan), including when the model also exits non-zero
- **THEN** the loop evaluates the read-only comparison before returning and fails with the read-only-corruption error rather than silently propagating the model exit code

#### Scenario: Missing required output fails the phase

- **WHEN** the skill session exits `0` but `project_surface_struct_resp_map_<class>.md` was not produced
- **THEN** the phase fails with an actionable required-output error
