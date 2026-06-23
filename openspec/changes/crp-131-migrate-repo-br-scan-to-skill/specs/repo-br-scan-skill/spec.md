## ADDED Requirements

### Requirement: repo-br-scan structural validation

The `repo-br-scan` validator SHALL validate a feature's business-context enrichment in `feature_br_summary.md` with behavior parity to the former `check_business_context_filled_from_repo.sh`. It SHALL report a recoverable problem (exit `1`) when any of the following hold:

- `## 1. Document Meta` is missing.
- `source_type` is missing from `## 1. Document Meta`, or is unfilled.
- `last_updated` is missing from `## 1. Document Meta`, is unfilled, or is not `YYYY-MM-DD`.
- `## 13. Existing-System Context` is missing, or contains no field lines.
- Any field under `## 13. Existing-System Context` is empty or `[UNFILLED]`.

The validator SHALL NOT enforce the strict `## 13` per-repository block format (that contract is model-enforced via the skill rule); it checks field completeness only.

#### Scenario: Missing Existing-System Context field

- **WHEN** `## 13. Existing-System Context` contains a field whose value is `[UNFILLED]`
- **THEN** the validator exits `1` with a message naming that unfilled field in `## 13. Existing-System Context`

#### Scenario: Unfilled or mis-formatted Document Meta

- **WHEN** `## 1. Document Meta -> last_updated` is unfilled or is not `YYYY-MM-DD`, or `source_type` is unfilled
- **THEN** the validator exits `1` with a distinct actionable line for that field

#### Scenario: Fully populated business context passes

- **WHEN** `## 1. Document Meta` has filled `source_type` and a `YYYY-MM-DD` `last_updated`, and every `## 13. Existing-System Context` field is filled
- **THEN** the validator exits `0` with a pass message

#### Scenario: Each failure is individually reported

- **WHEN** the artifact has multiple business-context problems
- **THEN** the gate prints a separate actionable `missing: ...` line for each problem

### Requirement: repo-br-scan context assembly with repo sync

The `repo-br-scan` context builder SHALL assemble the step's dynamic context for a feature path with parity to `feature_scan_repo_for_br.sh`. It SHALL resolve the target `feature_br_summary.md` (exit `2` if absent), resolve `init_progress_definition.yaml` from the nearest ancestor of the feature path, and collect the project's **ready** class repository paths from `meta_info.class_repo_paths` (entries with `state: ready` and an existing path, de-duplicated). Before emitting context, it SHALL synchronize each ready repository to its default branch using the D7 protocol (default-branch resolution, on-default-branch, clean tree, configured upstream, `git pull --rebase`, with an in-progress rebase aborted on failure). The assembled block SHALL include the workspace root, the target artifact path, the repositories-to-scan list, the gate command, and skill-relative asset/rule references.

#### Scenario: Ready repositories assembled after sync

- **WHEN** `overmind context repo-br-scan <feature-path>` runs and the project has ready class repo paths that satisfy D7
- **THEN** each ready repository is synchronized to its default branch
- **AND** the builder prints the assembled context block (including a `- <class>: <path>` line per ready repository and the `repo-br-scan` gate command) and exits `0`

#### Scenario: D7-unsynced repository blocks context

- **WHEN** a ready repository is not on its default branch, has uncommitted changes, has an ambiguous/absent default branch, has no upstream, or cannot be rebased onto its upstream
- **THEN** the builder exits `2` with the matching `BLOCKED: ... (D7) — ...` message
- **AND** it emits no repositories-to-scan context and leaves `feature_br_summary.md` untouched

#### Scenario: No ready classes is a no-op

- **WHEN** no `meta_info.class_repo_paths` entry has `state: ready`
- **THEN** the builder exits `0` with a no-op context block instructing the model that repo scan is a no-op for this feature and to finish without editing the artifact

#### Scenario: Context uses skill-relative asset paths

- **WHEN** `overmind context repo-br-scan <feature-path>` emits asset or rule references
- **THEN** those references use `assets/...` paths relative to the loaded `overmind-repo-br-scan` skill directory
- **AND** the context output does not hardcode `.claude/skills/...` or any other runner's skill-install directory

### Requirement: overmind-repo-br-scan skill

The repository SHALL provide an `overmind-repo-br-scan` agent skill sourced at `packages/installer/_data/skills/overmind-repo-br-scan/` containing `SKILL.md` (with the former `repo_br_scan_rule.md` inlined) and an `assets/` directory holding the BR-summary template and golden example. Dynamic context assembly (including the D7 repo sync) is provided by `overmind context repo-br-scan`; there is no `capture` step for `repo-br-scan`. The `SKILL.md` SHALL declare the allowed-write surface — only `## 1. Document Meta` (`last_updated`, `source_type`) and `## 13. Existing-System Context` — and read-only discipline for everything else, and SHALL instruct the model to: run `overmind context repo-br-scan <feature-path>`; finish without editing when the context reports a no-op; otherwise enrich only the allowed-write surface from repository evidence; then run `overmind gate repo-br-scan <feature-path>` after every write or repair and act on its exit code — finish on `0`, repair per each reported problem and rerun on `1`, and stop and inform the user on `2`. The `SKILL.md` SHALL state that `overmind context repo-br-scan` may block on a D7-unsynced repository and that the model must then stop and ask the user. The `SKILL.md` SHALL include the final response line `Repo scan phase to enrich BR is finished. Nothing else to do now; press Ctrl-C so orchestrator can start the next phase` so the transitional e2e orchestrator can advance the phase. The model SHALL own the loop; the skill SHALL NOT auto-run the context builder or gate from an orchestrator.

#### Scenario: Skill drives context-then-enrich-then-validate

- **WHEN** the operator invokes `overmind-repo-br-scan` for a feature whose project has a ready class repository
- **THEN** the model assembles context via `overmind context repo-br-scan <feature-path>`, enriches `## 13. Existing-System Context` (and `## 1` meta) from repository evidence, and runs `overmind gate repo-br-scan <feature-path>` before finalizing

#### Scenario: Skill finishes on no-op context

- **WHEN** `overmind context repo-br-scan` reports that no class repo path is ready (a no-op)
- **THEN** the model makes no edits to `feature_br_summary.md` and reports the repo-scan step complete

#### Scenario: Skill stops on a D7 block

- **WHEN** `overmind context repo-br-scan` exits `2` with a `BLOCKED: ... (D7)` message
- **THEN** the model stops, reports that the repository must be synchronized, and waits for user instructions

#### Scenario: Skill repairs on recoverable failure

- **WHEN** `overmind gate repo-br-scan` exits `1`
- **THEN** the model revises `feature_br_summary.md` to address each reported problem and reruns the gate until it exits `0` or `2`

### Requirement: Standalone runnability via golden example

The `overmind-repo-br-scan` skill SHALL be runnable in isolation without first executing upstream pipeline steps, by supplying a `feature_br_summary.md` (from the bundled `feature_br_summary_GOLDEN_EXAMPLE.md` or a minimal seed with `## 1. Document Meta` and `## 13. Existing-System Context`) plus a project `init_progress_definition.yaml` with at least one ready class repository.

#### Scenario: Repo-scan runs from a seeded summary and one ready repo

- **WHEN** a developer places a seeded `feature_br_summary.md` into a feature folder under a project whose `init_progress_definition.yaml` lists one ready, D7-clean git repository, and invokes the skill
- **THEN** the full loop (`overmind context repo-br-scan` sync+assemble → enrich → `overmind gate repo-br-scan` → exit code) runs without any other upstream artifact being produced first

### Requirement: e2e orchestrator drives the repo-br-scan skill

`project_add_feature_e2e.sh` phase 4.1 SHALL drive the `overmind-repo-br-scan` skill through a Codex session (instead of running a bash repo-scan script) when the project has a ready class repository, running the repo-scan skill before the task-to-BR skill, and SHALL keep repo scan a no-op when no class is ready while still running the task-to-BR skill.

#### Scenario: Phase 4.1 with a ready class runs both skill sessions

- **WHEN** phase 4.1 runs for a feature whose project has a ready class repo path
- **THEN** the orchestrator starts a `repo-br-scan` Codex session for the feature, then starts the task-to-BR Codex session
- **AND** the `repo-br-scan` session prompt is a thin launcher (load/follow the skill, runtime bindings, the exact `overmind context|gate repo-br-scan` commands) and does NOT restate the skill-owned final response line or gate handling
- **AND** the orchestrator advances the phase on the skill-emitted final response line, which is authored only in `SKILL.md`

#### Scenario: Phase 4.1 with no ready class skips repo scan

- **WHEN** phase 4.1 runs for a feature whose project has no ready class repo path
- **THEN** the orchestrator reports the repo scan is skipped as a no-op and still runs the task-to-BR Codex session
