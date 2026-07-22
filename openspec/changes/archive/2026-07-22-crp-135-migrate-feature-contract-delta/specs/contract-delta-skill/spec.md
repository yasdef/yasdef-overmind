## ADDED Requirements

### Requirement: contract-delta structural validation

The `contract-delta` validator SHALL validate a feature's `feature_contract_delta.md` with behavior parity to the former `check_feature_contract_delta_quality.sh`. It SHALL exit `1` when the target is empty or contains only whitespace, and SHALL exit `1` when the artifact still contains any `[UNFILLED]` placeholder. It SHALL require the sections `## 1. Document Meta`, `## 2. Delta Summary`, `## 3. Contract Delta Items`, and `## 4. Track Handoff Signals`. It SHALL require the meta keys `feature_id`, `feature_title`, `project_type_code`, `source_requirements_ears`, `source_common_contract_definition`, `delta_needed`, and `last_updated`, each present and filled, and SHALL require `delta_needed` (lowercased) to be `true` or `false`. When `delta_needed` is `true`, it SHALL require at least one `### Delta N:` block in section 3, SHALL reject `- no_contract_delta_required: true`, and SHALL require each Delta block to carry the fields `delta_kind`, `related_baseline_contract`, `change_scope`, `compatibility_impact`, and `verification_expectation`, each present and filled. When `delta_needed` is `false`, it SHALL require the exact line `- no_contract_delta_required: true` in section 3 and SHALL reject any present Delta block. It SHALL require the handoff keys `backend_handoff` and `frontend_mobile_handoff`, each present and filled, with the same key/value normalization the awk used (trim, quote-strip, treat empty or `[UNFILLED]` as unfilled). The validator SHALL NOT validate or require the optional `## 5. Cross-Class Transport/Contract Approach Mirror` section. The validator SHALL exit `0` on a structurally complete artifact, exit `1` with actionable `quality gate failed: …` messages on any structural violation, and exit `2` on runtime failure.

#### Scenario: Structurally complete delta passes

- **WHEN** `overmind gate contract-delta <feature-path>` runs against a `feature_contract_delta.md` with all four required sections, filled meta keys, a valid `delta_needed`, the matching section-3 shape for that `delta_needed` value, and both filled handoff keys
- **THEN** the validator exits `0` with a pass result

#### Scenario: Empty or unfilled target fails

- **WHEN** `feature_contract_delta.md` is empty, whitespace-only, or still contains an `[UNFILLED]` placeholder
- **THEN** the validator exits `1` reporting the empty target or the remaining `[UNFILLED]` placeholders

#### Scenario: Missing section or meta key fails

- **WHEN** the artifact is missing one of the four required sections, or a required meta key is missing or unfilled
- **THEN** the validator exits `1` naming the missing section or meta key

#### Scenario: delta_needed true requires complete Delta blocks

- **WHEN** `delta_needed: true` but section 3 has no `### Delta N:` block, declares `- no_contract_delta_required: true`, or a Delta block is missing one of `delta_kind`, `related_baseline_contract`, `change_scope`, `compatibility_impact`, `verification_expectation`
- **THEN** the validator exits `1` naming the offending condition or Delta block field

#### Scenario: delta_needed false requires the no-delta line and no blocks

- **WHEN** `delta_needed: false` but section 3 lacks `- no_contract_delta_required: true`, or one or more Delta blocks are still present
- **THEN** the validator exits `1` reporting the `delta_needed: false` inconsistency

#### Scenario: Missing handoff key fails

- **WHEN** `backend_handoff` or `frontend_mobile_handoff` is missing or unfilled in section 4
- **THEN** the validator exits `1` naming the missing handoff key

#### Scenario: Section 5 is gate-exempt

- **WHEN** two artifacts share identical, valid sections 1–4 and one includes a `## 5. Cross-Class Transport/Contract Approach Mirror` section while the other omits it entirely
- **THEN** the validator exits `0` for both, never failing on the presence, absence, or shape of section 5

#### Scenario: Runtime failure escalates

- **WHEN** the target path cannot be read for reasons other than emptiness
- **THEN** the validator exits `2` with a runtime error message

### Requirement: contract-delta context assembly

The `contract-delta` context builder SHALL assemble the step's dynamic context for a feature path with parity to the prompt context of `feature_contract_delta.sh`. It SHALL resolve the feature path and its `projects/<project-id>` root (exit `2` when the feature path does not resolve under `projects/<id>/<feature>`), the read-only `feature_br_summary.md`, the read-only `requirements_ears.md`, and the read-only project-level `common_contract_definition.md` (exit `2` if any is absent), and `init_progress_definition.yaml`. It SHALL collect the project's **ready** class repo paths via the shared ready-path resolver and run a read-only branch-state check on each, blocking (exit `2`, verbatim) on a wrong-branch or dirty repo. It SHALL collect **pending sibling contract deltas** — each committed sibling feature's `feature_contract_delta.md`, when present — as read-only inputs. It SHALL compute and emit a `cross_class_peer_trigger` value (`active` or `inactive`). On success the assembled block SHALL include the workspace root, the project root, the feature artifact root, one stable `- read_only_input: <workspace-relative-path>` entry for each resolved read-only input, the ready-repo list, the pending sibling-delta list, the `cross_class_peer_trigger` value, the single allowed-write target (`feature_contract_delta.md`), the exact `contract-delta` gate command, and skill-relative asset references for the template and golden example; the step rule is inlined in `SKILL.md`, not emitted as a separate rule-file reference. It SHALL NOT perform repo writes; repository default-branch sync is owned by the `sync contract-delta` verb.

#### Scenario: Context assembled for a feature with ready repos and sibling deltas

- **WHEN** `overmind context contract-delta <feature-path>` runs and `feature_br_summary.md`, `requirements_ears.md`, and the project `common_contract_definition.md` exist for a resolvable feature under `projects/<id>/`
- **THEN** the builder prints the assembled context block including one stable `read_only_input` manifest entry for each of the three base sources and each present pending sibling `feature_contract_delta.md`, the ready-repo list, the pending sibling-delta list, the `cross_class_peer_trigger` value, the single allowed-write target `feature_contract_delta.md`, and the exact `contract-delta` gate command, and exits `0`

#### Scenario: Missing required input blocks context

- **WHEN** `feature_br_summary.md`, `requirements_ears.md`, or the project `common_contract_definition.md` is absent for the feature, or the feature path does not resolve under `projects/<id>/<feature>`
- **THEN** the builder exits `2` with a message naming the missing input or the invalid feature path

#### Scenario: Cross-class peer trigger is computed deterministically

- **WHEN** the project `init_progress_definition.yaml` has `project_type_code: A` with a backend class present and either another class present or more than one backend
- **THEN** the context block emits `cross_class_peer_trigger: active`
- **AND** otherwise it emits `cross_class_peer_trigger: inactive`

#### Scenario: Dirty or wrong-branch ready repo blocks context

- **WHEN** a ready class repo is on the wrong branch or has a dirty working tree
- **THEN** the builder exits `2` with the verbatim block message and does not emit a context block

#### Scenario: Context uses skill-relative asset paths

- **WHEN** `overmind context contract-delta <feature-path>` emits asset references
- **THEN** those references use `assets/...` paths relative to the loaded `overmind-contract-delta` skill directory
- **AND** the context output does not hardcode `.claude/skills/...`, `.codex/skills/...`, or any source-repo path

### Requirement: contract-delta ready-repo sync

The `sync contract-delta` verb SHALL sync every **ready** class repo of the feature's project to its default branch before the model session, reusing the shared ready-path resolver and default-branch sync helper with parity to `sync repo-br-scan`. It SHALL exit `0` (reporting the synced count, or that there are no ready repos) on success, and exit `2` reporting the blocking repo messages when any ready repo cannot be synced. Repository writes (`git pull --rebase`) SHALL occur only in this verb, never in `context contract-delta`.

#### Scenario: Ready repos synced before the session

- **WHEN** `overmind sync contract-delta <feature-path>` runs with one or more ready class repos
- **THEN** each ready repo is synced to its default branch and the verb exits `0` reporting the synced count

#### Scenario: No ready repos is a no-op

- **WHEN** the project has no ready class repos
- **THEN** the verb exits `0` reporting no ready repos to sync

#### Scenario: Unsyncable repo blocks

- **WHEN** a ready repo cannot be synced to its default branch
- **THEN** the verb exits `2` reporting the blocking repo message

### Requirement: committed-sibling and cross-class-trigger TS modules

The shared `list_committed_sibling_features.sh` and `check_cross_class_peer_trigger.sh` logic SHALL be ported to reusable TypeScript modules used by the `contract-delta` context, while the original shell helpers remain in place for their un-migrated callers. The committed-sibling module SHALL identify a project's committed sibling features as sibling feature folders (excluding the current feature) that contain `implementation_plan.md`, with parity to the shell lib. The cross-class-trigger module SHALL compute `active` when `project_type_code` is `A`, a backend class is present, and either another class (`frontend` or `mobile`) is present or more than one backend exists, and `inactive` otherwise, with parity to the shell helper.

#### Scenario: Committed siblings identified by implementation_plan presence

- **WHEN** the committed-sibling module runs for a feature whose project has sibling folders, some with `implementation_plan.md` and some without
- **THEN** it returns exactly the sibling folders that contain `implementation_plan.md`, excluding the current feature

#### Scenario: Cross-class trigger parity with the shell helper

- **WHEN** the cross-class-trigger module evaluates an `init_progress_definition.yaml`
- **THEN** it returns `active`/`inactive` matching `check_cross_class_peer_trigger.sh` for the same definition

#### Scenario: Shared shell helpers retained for un-migrated callers

- **WHEN** this change is applied
- **THEN** `overmind/scripts/helper/check_cross_class_peer_trigger.sh` and `overmind/scripts/common_libs/list_committed_sibling_features.sh` remain present and unchanged, along with their `tests/ai_scripts` suites

### Requirement: overmind-contract-delta skill

The packaged `overmind-contract-delta` skill SHALL provide the model-facing orchestrator for step 6, with `feature_contract_delta_rule.md` inlined into `SKILL.md` and the contract-delta template plus golden example under `assets/`. `SKILL.md` SHALL instruct the model to: run `overmind context contract-delta <feature-path>`; compare `requirements_ears.md` against the `common_contract_definition.md` baseline for feature-level contract additions/changes only, restating no unchanged baseline contract; draft `feature_contract_delta.md` from the template, setting `delta_needed: true` with one `### Delta N:` block per independent feature-level delta (each carrying the five required fields) or `delta_needed: false` with the exact `- no_contract_delta_required: true` line and a `no_delta_reason`; author the optional `## 5. Cross-Class Transport/Contract Approach Mirror` section only when the context-supplied `cross_class_peer_trigger` is `active` (one `### Backend: <identity>` block per active backend mirroring `transport_protocol`/`schema_format` from `common_contract_definition.md` §7 verbatim by default, concrete values when the feature defines/refines them, otherwise the literal `<to be defined during first feature implementation plan>` placeholder; no §5 state machine), omitting the section entirely when `inactive`; report (but not resolve) overlaps against any pending sibling contract deltas; write only `feature_contract_delta.md` and never modify `feature_br_summary.md`, `requirements_ears.md`, `common_contract_definition.md`, or any pending sibling `feature_contract_delta.md`; and run `overmind gate contract-delta <feature-path>` after every write or repair. Gate exit handling SHALL be: `0` complete; `1` read the gate output, repair the artifact, and rerun the gate; `2` stop and report the blocker. The two literal final-response lines — the success line `Feature contract delta phase is finished. Nothing else to do now; press Ctrl-C so orchestrator can start the next phase` and the infeasibility line `feature contract delta gate cannot pass with current EARS/common-contract inputs. Please provide instructions what to do, or adjust requirements and rerun this phase` — SHALL appear only in `SKILL.md`.

#### Scenario: Skill drives the contract-delta gate loop

- **WHEN** the model loads `overmind-contract-delta` and the gate exits `1`
- **THEN** the model reads the gate output, repairs `feature_contract_delta.md`, and reruns `overmind gate contract-delta` without modifying any read-only input

#### Scenario: Skill finishes on gate pass with the success line

- **WHEN** the gate exits `0`
- **THEN** the model ends its final response with the exact success final-response line defined only in `SKILL.md`

#### Scenario: Skill honors the cross-class peer trigger for section 5

- **WHEN** the context block reports `cross_class_peer_trigger: inactive`
- **THEN** the model omits the `## 5. Cross-Class Transport/Contract Approach Mirror` section entirely
- **AND** when it reports `active`, the model writes one `### Backend:` block per active backend per the §5 authoring rules

#### Scenario: Skill stops with the infeasibility line when the gate cannot pass

- **WHEN** the model determines the gate cannot pass with the current EARS/common-contract inputs
- **THEN** it stops finalization and ends with the exact infeasibility final-response line defined only in `SKILL.md`, asking the operator for instructions

#### Scenario: Skill stops on gate runtime failure

- **WHEN** the gate exits `2`
- **THEN** the model stops, reports the blocker, and waits for operator instructions without further edits

#### Scenario: Read-only inputs and single-target boundary are preserved

- **WHEN** the model authors the contract delta
- **THEN** it writes only `feature_contract_delta.md` and does not modify `feature_br_summary.md`, `requirements_ears.md`, `common_contract_definition.md`, or any pending sibling `feature_contract_delta.md`

### Requirement: Feature e2e orchestrator drives the contract-delta skill

The `project_add_feature_e2e.sh` phase 6 SHALL launch the `overmind-contract-delta` skill via a Codex session (mirroring the phase 4.1 pre-sync launcher and the phase 5.1 read-only-guard launcher) instead of the deleted `feature_contract_delta.sh`. Before launching, it SHALL run `overmind sync contract-delta <feature-path>` to sync ready repos, invoke `overmind context contract-delta <feature-path>` once for deterministic guard setup, and SHALL preflight-check that the installed `overmind-contract-delta` skill and `.overmind/overmind.js` exist, failing before launching when either is absent, sync blocks, or context fails. The launcher SHALL parse the stable `read_only_input` entries and snapshot exactly that emitted set; it SHALL NOT independently invoke the retained shell sibling lister or reconstruct a second read-only set. It SHALL load the model configuration for the `feature_contract_delta` phase from `.setup/models.md` (the model command, model id, and any args) and SHALL invoke the model from that loaded configuration rather than hardcoding the command/model/args, requiring the configured command to be `codex` and failing the phase otherwise. The launcher prompt SHALL include only runtime bindings and the exact `context`/`gate contract-delta` commands; it SHALL NOT duplicate the skill's literal final-response lines, the §5 authoring rules, or gate exit-code handling. The phase SHALL NOT run the model gate itself. To preserve the former `ensure_readonly_inputs_unchanged` protection deterministically, the launcher SHALL assert every snapshotted input is byte-unchanged after the session, failing the phase with an actionable error if any was modified; it SHALL also assert the model produced `feature_contract_delta.md`. The read-only-input comparison SHALL run on **every** model exit path — including when the model session exits non-zero — and SHALL be evaluated before the launcher returns the model's exit code; when a read-only input drifted, the phase SHALL fail with the read-only-corruption error even if the model session also exited non-zero, so a model that both corrupts an input and fails cannot bypass the guard. The `feature_contract_delta.sh` entry SHALL be removed from the phase-6 `phase_scripts` list.

#### Scenario: Phase 6 syncs then launches the contract-delta skill

- **WHEN** the e2e orchestrator runs phase 6 for a feature
- **THEN** it runs `overmind sync contract-delta` for the feature, obtains the read-only manifest from `overmind context contract-delta`, then starts a Codex session telling the model to load `overmind-contract-delta` with the runtime bindings and the exact `context`/`gate` `contract-delta` commands
- **AND** the launcher prompt does not contain either of the skill's literal final-response lines

#### Scenario: Model configuration is loaded from the feature_contract_delta phase row

- **WHEN** phase 6 runs
- **THEN** the launcher loads the `feature_contract_delta` row from `.setup/models.md` and invokes the model using that row's configured command, model id, and args, rather than a hardcoded model or args
- **AND** when that row's configured command is not `codex`, the phase fails instead of launching

#### Scenario: Orchestrator does not run the contract-delta gate itself

- **WHEN** phase 6 runs
- **THEN** the orchestrator does not invoke `overmind gate contract-delta`; the model owns the gate loop

#### Scenario: Missing skill or CLI fails before launching

- **WHEN** phase 6 runs but the installed `overmind-contract-delta` skill or `.overmind/overmind.js` is absent from the runtime workspace
- **THEN** the orchestrator fails before launching the Codex session, reporting the missing skill or CLI

#### Scenario: Context failure blocks before launching

- **WHEN** the guard-setup `overmind context contract-delta` invocation exits non-zero or emits no `read_only_input` entries
- **THEN** phase 6 fails before launching the Codex session with an actionable context or manifest error

#### Scenario: Launcher snapshots the context-owned read-only set

- **WHEN** context emits base and pending-sibling `read_only_input` entries
- **THEN** the launcher snapshots exactly those paths and does not invoke `list_committed_sibling_features.sh` to discover another set

#### Scenario: Read-only input mutation fails the phase

- **WHEN** the skill session completes but any of `feature_br_summary.md`, `requirements_ears.md`, the project `common_contract_definition.md`, or a pending sibling `feature_contract_delta.md` differs from its pre-launch snapshot
- **THEN** phase 6 fails with an actionable error reporting that the read-only input must not be modified, and does not report the phase as successful

#### Scenario: Read-only mutation is caught even when the model exits non-zero

- **WHEN** the skill session mutates a read-only input **and** the model exits non-zero
- **THEN** the launcher evaluates the read-only-input comparison before returning, and phase 6 fails with the read-only-corruption error rather than silently propagating the model exit code and leaving the corrupted input

#### Scenario: Missing required output fails the phase

- **WHEN** the skill session exits `0` but `feature_contract_delta.md` was not produced
- **THEN** phase 6 fails with an actionable required-output error and does not report the phase as successful
