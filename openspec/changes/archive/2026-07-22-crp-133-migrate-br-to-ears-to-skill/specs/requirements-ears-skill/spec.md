## ADDED Requirements

### Requirement: requirements-ears structural validation

The `requirements-ears` validator SHALL validate a feature's `requirements_ears.md` with behavior parity to the former `check_requirements_ears_quality.sh`. It SHALL exit `1` when the target is empty or contains only whitespace. It SHALL parse `### Requirement <N> — <Title>` and `### NFR <N> — <Title>` blocks and SHALL require each block to contain `**User Story:**`, `**Acceptance Criteria (EARS):**`, and `**Verification:**`; an `**Acceptance Criteria (EARS):**` section SHALL contain at least one bullet and at least one bullet matching an allowed EARS pattern. Allowed EARS patterns (matched case-insensitively) SHALL be: `WHEN <event>, THE <System> SHALL <response>.`; `IF <condition>, THEN THE <System> SHALL <response>.`; `WHILE <state>, THE <System> SHALL <response>.`; `WHERE <feature/constraint>, THE <System> SHALL <response>.`; the combined `WHEN <event> AND WHILE <state>, THE <System> SHALL <response>.`; and the bare `THE <System> SHALL <response>.` form. The validator SHALL enforce, independently for `Requirement` and `NFR` blocks, sequential 1-based numbering with no duplicates and no gaps. It SHALL fail when no `Requirement`/`NFR` blocks are found. It SHALL exit `0` on a structurally complete artifact, exit `1` with actionable failure messages on any structural violation, and exit `2` on runtime failure. The validator SHALL NOT read or mutate `feature_br_summary.md`.

#### Scenario: Structurally complete EARS artifact passes

- **WHEN** `overmind gate requirements-ears <feature-path>` runs against a `requirements_ears.md` whose `Requirement`/`NFR` blocks each contain `**User Story:**`, `**Acceptance Criteria (EARS):**` (with at least one valid EARS-pattern bullet), and `**Verification:**`, with sequential 1-based numbering
- **THEN** the validator exits `0` with a pass result

#### Scenario: Empty target fails

- **WHEN** `requirements_ears.md` is empty or whitespace-only
- **THEN** the validator exits `1` reporting the target EARS requirements is empty

#### Scenario: Missing block field fails

- **WHEN** a `Requirement`/`NFR` block is missing `**User Story:**`, `**Acceptance Criteria (EARS):**`, or `**Verification:**`
- **THEN** the validator exits `1` with a message naming the missing field and the offending block heading

#### Scenario: Invalid EARS bullet pattern fails

- **WHEN** an acceptance-criteria bullet does not match any allowed EARS pattern
- **THEN** the validator exits `1` reporting the invalid EARS bullet pattern and the offending block

#### Scenario: Acceptance criteria with no valid pattern fails

- **WHEN** an `**Acceptance Criteria (EARS):**` section has no bullets, or no bullet matching an allowed EARS pattern
- **THEN** the validator exits `1` reporting the missing/invalid acceptance criteria for that block

#### Scenario: Non-sequential or duplicate numbering fails

- **WHEN** `Requirement` or `NFR` numbering does not start at 1, skips a value, or repeats a value
- **THEN** the validator exits `1` reporting the numbering violation for that block type

#### Scenario: No blocks found fails

- **WHEN** the target contains no `### Requirement <N>` or `### NFR <N>` blocks
- **THEN** the validator exits `1` reporting that no Requirement/NFR blocks were found

#### Scenario: Runtime failure escalates

- **WHEN** the target path cannot be read for reasons other than emptiness
- **THEN** the validator exits `2` with a runtime error message

### Requirement: requirements-ears context assembly

The `requirements-ears` context builder SHALL assemble the step's dynamic context for a feature path with parity to the prompt context of `feature_br_to_ears.sh`. It SHALL resolve the feature path, the read-only `feature_br_summary.md` source (exit `2` if absent), and the `requirements_ears.md` target. It SHALL verify the `ready_to_ears` precondition by reading `## 1. Document Meta` of `feature_br_summary.md` and SHALL exit `2` when `ready_to_ears` is missing or not `true`, with a message instructing the operator to run `readiness br-clarification` for the feature first. On success the assembled block SHALL include the workspace root, the feature artifact root, the target EARS artifact path (`requirements_ears.md`), the read-only BR source path, the allowed-write artifact list (`requirements_ears.md` only), the exact `requirements-ears` gate command, and skill-relative asset references for the EARS template and golden example; the step rule is inlined in `SKILL.md`, not emitted as a separate rule-file reference.

#### Scenario: Context assembled for a ready feature

- **WHEN** `overmind context requirements-ears <feature-path>` runs, `feature_br_summary.md` exists with `ready_to_ears: true`, and the feature folder is resolvable
- **THEN** the builder prints the assembled context block including the explicit target EARS artifact path (`requirements_ears.md`), the read-only BR source, the allowed-write list (`requirements_ears.md` only), and the exact `requirements-ears` gate command, and exits `0`

#### Scenario: Missing BR summary blocks context

- **WHEN** `feature_br_summary.md` is absent for the feature
- **THEN** the builder exits `2` with a message that the upstream BR summary is required

#### Scenario: Not-ready feature blocks context

- **WHEN** `feature_br_summary.md` `## 1. Document Meta` has `ready_to_ears` missing or not `true`
- **THEN** the builder exits `2` instructing the operator to run `readiness br-clarification` for the feature first

#### Scenario: Context uses skill-relative asset paths

- **WHEN** `overmind context requirements-ears <feature-path>` emits asset references
- **THEN** those references use `assets/...` paths relative to the loaded `overmind-requirements-ears` skill directory
- **AND** the context output does not hardcode `.claude/skills/...`, `.codex/skills/...`, or any source-repo path

### Requirement: overmind-requirements-ears skill

The packaged `overmind-requirements-ears` skill SHALL provide the model-facing orchestrator for step 5 BR→EARS, with `br_to_ears.md` inlined into `SKILL.md` and the EARS template plus golden example under `assets/`. `SKILL.md` SHALL instruct the model to: run `overmind context requirements-ears <feature-path>`; convert the readiness-approved `feature_br_summary.md` into deterministic, testable, business-facing atomic EARS requirements using the template as structural contract and the golden example as style contract; use only facts present in the BR summary, marking any minimal necessary inference inline with `[Inference]` and recording missing facts as `Unresolved gap:` notes without starting a new user-question loop; split mixed obligations into atomic bullets and keep functional obligations in `Requirement` blocks and quality constraints in `NFR` blocks; preserve deterministic source-order processing and sequential numbering; propagate `## 16. Linked Artifacts` from the BR per the document-level registry and per-requirement association rules; write answer content only to `requirements_ears.md` and never modify `feature_br_summary.md`; and run `overmind gate requirements-ears <feature-path>` after every write or repair. Gate exit handling SHALL be: `0` complete; `1` read the gate output, repair `requirements_ears.md`, and rerun the gate; `2` stop and report the blocker. The skill SHALL evaluate whether gate compliance is feasible with the current BR input; when it is not feasible, the skill SHALL stop and emit the exact infeasibility line. The two literal final-response lines — the success line `BR->requirement-EARS phase is finished. Nothing else to do now; press Ctrl-C so orchestrator can start the next phase` and the infeasibility line `based on provided reasons, EARS gate cannot pass with current BR input. Please provide instructions what to do, or adjust requirements and rerun this phase` — SHALL appear only in `SKILL.md`.

#### Scenario: Skill drives the EARS gate loop

- **WHEN** the model loads `overmind-requirements-ears` and the gate exits `1`
- **THEN** the model reads the gate output, repairs `requirements_ears.md`, and reruns `overmind gate requirements-ears` without modifying `feature_br_summary.md`

#### Scenario: Skill finishes on gate pass with the success line

- **WHEN** the gate exits `0`
- **THEN** the model ends its final response with the exact success final-response line defined only in `SKILL.md`

#### Scenario: Skill stops with the infeasibility line when conversion cannot pass

- **WHEN** the model determines gate compliance is not feasible with the current BR facts and allowed inferences
- **THEN** the model stops finalization and ends with the exact infeasibility final-response line defined only in `SKILL.md`, asking the operator for instructions

#### Scenario: Skill stops on gate runtime failure

- **WHEN** the gate exits `2`
- **THEN** the model stops, reports the blocker, and waits for operator instructions without further edits

#### Scenario: Read-only BR source is preserved

- **WHEN** the model produces or repairs `requirements_ears.md`
- **THEN** it writes only `requirements_ears.md` and does not modify `feature_br_summary.md`

#### Scenario: Source-of-truth and inference discipline

- **WHEN** the model drafts EARS requirements
- **THEN** it uses only facts present in `feature_br_summary.md`, marks any minimal necessary inference inline with `[Inference]`, records missing facts as `Unresolved gap:` notes, and does not start a new user-question loop

#### Scenario: Linked Artifacts propagation

- **WHEN** `feature_br_summary.md` `## 16. Linked Artifacts` contains one or more entries
- **THEN** the model emits a `## Linked Artifacts` registry in `requirements_ears.md` copying those entries verbatim, adds `**Linked Artifacts:**` fields only to the requirements they are relevant to, and references no `LAR-NNN` id absent from the registry
- **AND** when the BR `## 16. Linked Artifacts` is empty, the EARS output omits the `## Linked Artifacts` section entirely

### Requirement: Feature e2e orchestrator drives the requirements-ears skill

The `project_add_feature_e2e.sh` phase 5 SHALL launch the `overmind-requirements-ears` skill via a Codex session (mirroring the phase 4.2 skill launcher) instead of the deleted `feature_br_to_ears.sh`. The launcher prompt SHALL include only runtime bindings and the exact `context`/`gate requirements-ears` commands; it SHALL NOT duplicate the skill's literal final-response lines or gate exit-code handling. The phase SHALL NOT run a deterministic post-skill step (step 5 has no state flip of its own) and SHALL NOT run the model gate itself.

#### Scenario: Phase 5 launches the requirements-ears skill

- **WHEN** the e2e orchestrator runs phase 5 for a feature
- **THEN** it starts a Codex session telling the model to load `overmind-requirements-ears` with the runtime bindings and the exact `context`/`gate` `requirements-ears` commands
- **AND** the launcher prompt does not contain either of the skill's literal final-response lines

#### Scenario: Orchestrator does not run the EARS gate itself

- **WHEN** phase 5 runs
- **THEN** the orchestrator does not invoke `overmind gate requirements-ears`; the model owns the gate loop

#### Scenario: Missing skill or CLI fails before launching

- **WHEN** phase 5 runs but the installed `overmind-requirements-ears` skill or `.overmind/overmind.js` is absent from the runtime workspace
- **THEN** the orchestrator fails before launching the Codex session, reporting the missing skill or CLI
