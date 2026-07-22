## ADDED Requirements

### Requirement: br-clarification structural validation

The `br-clarification` validator SHALL validate a feature's BR-clarification completeness with behavior parity to the former `check_user_br_clarification_quality.sh`. It SHALL first run the existing `task-to-br` validator against `feature_br_summary.md` as the base business-context check; when that base check fails, the `br-clarification` validator SHALL surface the base result verbatim and exit with the base exit code. When the base check passes, the validator SHALL inspect `missing_br_data.md` `## 3. Unresolved Items Ledger (Rised)` and exit `1` when any tracked `- rised_item_N:` entry is explicitly unresolved with `rised=false`. Invalid unresolved markers such as `non-rised`, `not-rised`, or missing `rised=false`/`rised=true` SHALL be reported by the base `task-to-br` validator before the `br-clarification` unresolved-ledger check runs. Lines that are not `- rised_item_N:` ledger entries (including quoted examples) SHALL be ignored. The validator SHALL exit `0` when the base check passes and no tracked ledger entry is unresolved (including when the ledger is empty or absent), and exit `2` on runtime failure. The `overmind gate br-clarification` CLI SHALL print each br-clarification rule progress line immediately after that rule is evaluated, using `... PASS` or `... FAIL`, before the final gate pass/fail summary.

#### Scenario: Unresolved ledger item fails the gate

- **WHEN** the `task-to-br` base check passes but `missing_br_data.md` `## 3. Unresolved Items Ledger (Rised)` contains a `- rised_item_N:` entry with `rised=false`
- **THEN** the validator exits `1` with an actionable `missing:` line stating unresolved user BR clarification items remain and to continue until every `rised_item_N` is `rised=true`
- **AND** the CLI output includes a `PASS` progress line for the base business-context validation and a `FAIL` progress line for the unresolved BR clarification ledger check

#### Scenario: Base business-context failure is surfaced verbatim

- **WHEN** the `task-to-br` base check fails
- **THEN** the `br-clarification` validator prints the base check output and exits with the base check's exit code
- **AND** the CLI output includes a `FAIL` progress line for the base business-context validation

#### Scenario: Invalid rised marker is repaired by the skill loop

- **WHEN** the gate exits `1` because the base `task-to-br` validator reports that a ledger item must include `rised=false` or `rised=true`
- **THEN** the skill treats the issue as recoverable, adds `rised=false` to the affected `rised_item_N` entry, reruns the gate, and continues clarification from that unresolved item

#### Scenario: All items rised passes

- **WHEN** the base check passes and every tracked `- rised_item_N:` entry in `## 3. Unresolved Items Ledger (Rised)` is `rised=true`
- **THEN** the validator exits `0` with a pass result
- **AND** the CLI output includes `PASS` progress lines for base business-context validation, unresolved BR clarification ledger validation, and BR clarification completion for EARS readiness

#### Scenario: No unresolved ledger items passes immediately

- **WHEN** the base check passes and `missing_br_data.md` has an empty `## 3. Unresolved Items Ledger (Rised)` or no such section
- **THEN** the validator exits `0` (reproducing the former bash "skip when no non-rised items" behavior)
- **AND** the CLI output includes `PASS` progress lines for base business-context validation, unresolved BR clarification ledger validation, and BR clarification completion for EARS readiness

#### Scenario: Quoted example lines are ignored

- **WHEN** `## 3. Unresolved Items Ledger (Rised)` contains documentation/example lines that are not `- rised_item_N:` ledger entries
- **THEN** those lines do not affect the gate result

### Requirement: br-clarification context assembly

The `br-clarification` context builder SHALL assemble the step's dynamic context for a feature path with parity to the prompt context of `feature_user_br_clarification.sh`. It SHALL resolve the feature path, the target `feature_br_summary.md` (exit `2` if absent), and the `missing_br_data.md` ledger (exit `2` if absent, since clarification requires the prior task-to-br capture). The assembled block SHALL include the workspace root, the feature artifact root, the allowed-write artifact list (`feature_br_summary.md` and `missing_br_data.md` only), the exact `br-clarification` gate command, and skill-relative asset references; the step rule is inlined in `SKILL.md`, not emitted as a separate rule-file reference.

#### Scenario: Context assembled for a feature with a ledger

- **WHEN** `overmind context br-clarification <feature-path>` runs and both `feature_br_summary.md` and `missing_br_data.md` exist
- **THEN** the builder prints the assembled context block including the allowed-write list and the exact `br-clarification` gate command, and exits `0`

#### Scenario: Missing ledger blocks context

- **WHEN** `missing_br_data.md` is absent for the feature
- **THEN** the builder exits `2` with a message that the task-to-br capture must run before user BR clarification

#### Scenario: Context uses skill-relative asset paths

- **WHEN** `overmind context br-clarification <feature-path>` emits asset references
- **THEN** those references use `assets/...` paths relative to the loaded `overmind-br-clarification` skill directory
- **AND** the context output does not hardcode `.claude/skills/...`, `.codex/skills/...`, or any source-repo path

### Requirement: overmind-br-clarification skill

The packaged `overmind-br-clarification` skill SHALL provide the model-facing orchestrator for step 4.2 BR clarification, with `user_br_clarification_rule.md` inlined into `SKILL.md` and the BR-summary template plus golden example under `assets/`. `SKILL.md` SHALL instruct the model to: run `overmind context br-clarification <feature-path>`; ask only business-domain follow-up questions for unresolved `rised_item_N` ledger entries (never technical/architecture/deployment questions), following the sequential one-at-a-time protocol (overview list + brief process explanation, then one question per turn, with `skip for now` leaving an item `rised=false`); write answer content only to `feature_br_summary.md`; keep `missing_br_data.md` as a pointer-only question-state ledger using the `rised` flag (`rised=false` until discussed, `rised=true` only after the item is discussed and its answer written), one `- answers:` destination-pointer entry per discussed item with no answer narrative; append qualifying user-provided links to `## 16. Linked Artifacts` per the link-preservation rules; run `overmind gate br-clarification <feature-path>` after every answer round; and stop only when the gate exits `0` (every item answered, `rised=true`). The skill SHALL NOT declare the phase complete, emit the completion final response line, or allow the next phase while any item remains `rised=false`. The skill SHALL preserve BR section order, headings, keys, and one-line FR/BR item structure. Gate exit handling SHALL be: `0` complete; `1` continue the clarification loop — re-offer the items the user chose to `skip for now`, repair the artifact, and rerun the gate — without declaring completion; `2` stop and report the blocker. The literal final response line — `User BR clarification phase is finished. Nothing else to do now; press Ctrl-C so orchestrator can start the next phase` — SHALL appear only in `SKILL.md`.

#### Scenario: Skill drives the clarification gate loop

- **WHEN** the model loads `overmind-br-clarification` and the gate exits `1`
- **THEN** the model asks the unresolved business-only questions, writes answers to `feature_br_summary.md`, updates the matching `rised_item_N` to `rised=true` with a pointer-only `- answers:` entry, and reruns `overmind gate br-clarification`

#### Scenario: Skill finishes on gate pass with the final line

- **WHEN** the gate exits `0`
- **THEN** the model ends its final response with the exact final response line defined only in `SKILL.md`

#### Scenario: Skill stops on gate runtime failure

- **WHEN** the gate exits `2`
- **THEN** the model stops, reports the blocker, and waits for operator instructions without further edits

#### Scenario: Business-only question scope

- **WHEN** the model asks follow-up questions for unresolved ledger items
- **THEN** the questions are business-domain only and never ask about technical implementation, architecture, frameworks, deployment, or code structure

#### Scenario: Qualifying link preservation

- **WHEN** a user reply includes an HTTP(S) URL that answers or materially clarifies the currently discussed business question
- **THEN** the model writes only the question-relevant business content into `feature_br_summary.md` and appends one non-duplicate `LAR-NNN` entry to `## 16. Linked Artifacts`
- **AND** when a provided link does not answer the current item, the model neither uses its content nor records the link

### Requirement: Sequential one-at-a-time clarification protocol

The `overmind-br-clarification` skill SHALL drive clarification as a guided one-question-at-a-time conversation rather than presenting all questions at once. At the start of a clarification round the model SHALL first display the full list of currently unresolved business questions (one per unresolved `rised_item_N` ledger entry) and a brief explanation of the process (questions will be asked one by one; the user may answer or reply `skip for now` to defer any question). The model SHALL then ask only the first question and wait for the user's reply before asking the next, repeating until every listed question has been either answered or skipped. When the user answers, the model SHALL write the answer to `feature_br_summary.md`, set the matching entry to `rised=true`, and record its pointer-only `- answers:` entry, exactly as for any resolved item. When the user replies `skip for now` (or otherwise declines to answer) for a question, the model SHALL leave the matching `rised_item_N` entry at `rised=false`, write no answer content for it, and move on to the next question without re-prompting it in the same pass.

#### Scenario: Overview shown before the first question

- **WHEN** a clarification round begins with one or more unresolved `rised_item_N` entries
- **THEN** the model first lists all unresolved business questions and briefly explains the one-by-one process, then asks only the first question and waits for a reply

#### Scenario: Questions are asked sequentially

- **WHEN** the user replies to the current question
- **THEN** the model asks the next unresolved question (not all remaining at once), continuing until each listed question is answered or skipped

#### Scenario: Skip for now defers the question within the loop

- **WHEN** the user replies `skip for now` (or declines) to a question
- **THEN** the model leaves that `rised_item_N` at `rised=false`, writes no answer content for it, and proceeds to the next question (the skipped item is deferred, not finished)

#### Scenario: Phase keeps working until every item is answered

- **WHEN** a clarification pass ends with one or more questions still skipped (`rised=false`)
- **THEN** `overmind gate br-clarification` exits `1`, the model does NOT emit the completion final response line and does NOT advance to the next phase
- **AND** the model continues the loop — re-offering the deferred questions in a new round — until every item is answered (`rised=true`) and the gate exits `0`

#### Scenario: Unresolved session does not run the next phase

- **WHEN** the operator ends the clarification session while one or more items remain `rised=false`
- **THEN** `overmind gate br-clarification` still fails, so the readiness/next phase does not run — matching the former hard-fail-on-unresolved behavior of `feature_user_br_clarification.sh`

### Requirement: Feature e2e orchestrator drives the br-clarification skill

The `project_add_feature_e2e.sh` phase 4.2 SHALL launch the `overmind-br-clarification` skill via a Codex session (mirroring the phase 4.1 skill launchers) instead of the deleted `feature_user_br_clarification.sh`. The launcher prompt SHALL include only runtime bindings and the exact context/gate commands; it SHALL NOT duplicate the skill's literal final-response line or gate exit-code handling. After the skill session completes, the orchestrator SHALL run the deterministic EARS-readiness step (it SHALL NOT run the model gate itself).

#### Scenario: Phase 4.2 launches the clarification skill

- **WHEN** the e2e orchestrator runs phase 4.2 for a feature
- **THEN** it starts a Codex session telling the model to load `overmind-br-clarification` with the runtime bindings and the exact `context`/`gate` `br-clarification` commands
- **AND** the launcher prompt does not contain the skill's literal final-response line

#### Scenario: Readiness runs after the clarification skill

- **WHEN** the clarification skill session completes successfully in phase 4.2
- **THEN** the orchestrator runs the deterministic `readiness br-clarification` CLI step next, and does not itself run `overmind gate br-clarification`
