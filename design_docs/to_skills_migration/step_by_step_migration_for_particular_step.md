# Step-by-Step Migration For One Overmind Step To Skill + JS

Use this guide to migrate one existing Overmind step from `md rule + sh orchestrator + sh helper` to `SKILL.md + asdlc-coordinator JS/TS primitives`.

Reference implementation: CRP-129 (`task-to-br` skill + JS core), CRP-130 (runner skill installation), post-CRP fixes (`project_add_feature_e2e.sh` launches the skill; skill instruction parity repaired).

## Overview: Core Operations Only

1. Take `overmind/rules/<step>_rule.md`; inline it into `packages/installer/_data/skills/overmind-<step>/SKILL.md`.
2. Take `overmind/templates/<step>_TEMPLATE.*`; copy it to `packages/installer/_data/skills/overmind-<step>/assets/`.
3. Take `overmind/golden_examples/<step>_GOLDEN_EXAMPLE.*`; copy it to `packages/installer/_data/skills/overmind-<step>/assets/`.
4. Take the model prompt from `overmind/scripts/<step>.sh`; split it:
   - Durable behavior goes into `SKILL.md`.
   - Runtime paths and dynamic context go into `packages/asdlc-coordinator/src/context/<step>.ts`.
   - Human/source capture goes into `packages/asdlc-coordinator/src/capture/<step>.ts`, if the step needs capture.
5. Take `overmind/scripts/helper/check_<step>_quality.sh`; rewrite it as `packages/asdlc-coordinator/src/validate/<step>.ts`.
6. Register the new step in `packages/asdlc-coordinator/src/cli/run.ts` for `capture`, `context`, and `gate` as applicable.
7. Register exports in `packages/asdlc-coordinator/src/capture/index.ts`, `context/index.ts`, and `validate/index.ts`.
8. Add tests that prove old helper behavior, capture behavior, context output, and CLI exit codes.
9. Update `packages/installer/src/init.ts` so the skill installs to `.codex/skills/overmind-<step>/` and `.claude/skills/overmind-<step>/`.
10. Update legacy setup staging, if still used, so fresh setup and update mode copy the skill and keep `.overmind/overmind.js` as the only CLI.
11. Update transitional e2e, if still used, so it starts Codex with a small prompt: load the skill, provide runtime bindings, run capture/context/gate commands, follow gate exits.
12. Compare old prompt + rule + helper against `SKILL.md` + `capture/context/gate`; fix every lost instruction before deleting old files.
13. Delete the old step shell script, old helper, and old shell tests only after TS tests and installer/setup/e2e tests pass.

## 0. Inputs

Define these names before editing:

- `STEP_ID`: workflow step number, for example `4.1`.
- `STEP_KEY`: CLI key, for example `task-to-br`.
- `SKILL_NAME`: `overmind-<STEP_KEY>`, for example `overmind-task-to-br`.
- `MODEL_PHASE`: row key in `.setup/models.md`, for example `task_to_br`.
- `OLD_SCRIPT`: old model orchestrator, for example `overmind/scripts/feature_task_to_br.sh`.
- `OLD_RULE`: old rule file, for example `overmind/rules/task_to_br_rule.md`.
- `OLD_HELPER`: old quality helper, for example `overmind/scripts/helper/check_task_to_br_quality.sh`.
- `OLD_TESTS`: old shell tests for the helper/orchestrator.
- `TARGET_ARTIFACTS`: step-owned output artifacts.
- `READ_ONLY_INPUTS`: artifacts the step may read but must not mutate.
- `CAPTURE_ARTIFACTS`: step-owned input capture files, if any.

## 1. Preflight Inventory

1. Read `.codex/skills/overmind-step-architecture/SKILL.md`.
2. Read `.codex/skills/overmind-step-deployability/SKILL.md`.
3. Read `overmind/init_progress_definition_sequence_diagram.md`.
4. Read `overmind/templates/init_progress_definition_TEMPLATE.yaml`.
5. Read `OLD_SCRIPT`, `OLD_RULE`, `OLD_HELPER`, old templates, old golden examples, and `OLD_TESTS`.
6. Extract the old model prompt from `OLD_SCRIPT`.
7. Extract every old final response line, stop message, retry rule, and resume hint.
8. Extract every old runtime path binding and artifact ownership rule.
9. Extract every old helper check and failure message.
10. Extract every old test scenario.
11. Extract every old **deterministic guard/assertion that runs outside the model prompt** — for example read-only-input immutability checks (snapshot + `cmp`), required-output-produced assertions, and idempotency/no-op guards. These are deterministic mechanics, not model instructions, and are the easiest thing to lose in a migration because they live in the orchestrator script, not in the rule.

Record an inventory before implementation:

| Old responsibility | New owner |
|---|---|
| User/source capture | `packages/asdlc-coordinator/src/capture/<step>.ts`, or none |
| Dynamic context assembly | `packages/asdlc-coordinator/src/context/<step>.ts` |
| Artifact generation/repair loop | `packages/installer/_data/skills/<skill>/SKILL.md` |
| Structural quality gate | `packages/asdlc-coordinator/src/validate/<step>.ts` |
| Deterministic post-run guard (read-only-input immutability, output-produced assertion) | e2e launcher now (snapshot + assert), TS orchestrator later — never advisory `SKILL.md` text alone |
| Cross-step sequencing | TS orchestrator later, or current legacy e2e wrapper temporarily |
| Runtime installation | `packages/installer/src/init.ts` and current setup staging |

Do not start implementation until every old responsibility has a new owner.

## 2. Ownership Rules

Apply these rules consistently:

1. The skill is the model-facing orchestrator for the step.
2. JS/TS owns deterministic mechanics only: capture, context, parsing, validation, path normalization, readiness calculations.
3. The model owns the whole artifact loop: draft artifact, run gate, read gate output, repair artifact, rerun gate, and stop only when the gate passes or blocks.
4. The gate is a model-invoked validator, not an orchestrator-invoked phase check. Shell/e2e/TS orchestrators may provide the exact gate command in the prompt/context, but they must not run it for model-owned artifact quality. This restricts the `overmind gate <step>` **CLI verb** only. A deterministic primitive (for example a `readiness` handler) MAY import and call the shared validator **function** (`validate/<step>.ts`) in-process as a non-repairing precondition check — that is the rule-2 deterministic-validation reuse path — but it MUST NOT shell out to `node .overmind/overmind.js gate <step>`. Keep the CLI gate verb model-only; reuse the function, not the verb.
5. The gate exit code is an instruction to the model:
   - `0`: gate passed; the model reports the step complete.
   - `1`: artifact is invalid but recoverable; the model reads the gate output, repairs the artifact, and reruns the gate.
   - `2`: validation cannot complete; the model stops, reports the blocker, and waits for operator instructions.
6. Skills are not independent processes or standalone startup commands. A runner/orchestrator starts the model session and tells the model to load the installed skill.
7. The shell e2e runner may launch a skill during the transition, but it must not duplicate the skill's semantic logic.
8. Model-facing completion text, for example `press Ctrl-C so orchestrator can start the next phase`, belongs only in `SKILL.md`; do not duplicate the literal instruction in orchestrator prompts.
9. Do not put per-skill scripts in the skill folder. Use shared `.overmind/overmind.js`.
10. Do not copy `.overmind/overmind.js` into runner skill directories.
11. Supported runner skill targets are `.codex/skills/<skill>/` and `.claude/skills/<skill>/`. `.github` and `.agents` remain deferred unless separately designed.
12. Deterministic guards the old orchestrator performed outside the model prompt — read-only-input immutability assertions, required-output-produced checks, idempotency guards — are deterministic mechanics, not skill-owned semantic logic. They MUST be preserved, never replaced by advisory allowed-write/`SKILL.md` prose. During the transition they live in the e2e launcher (snapshot the read-only input before the session, `cmp`-assert it unchanged after, fail the phase on drift); when sequencing moves to TS they move into the orchestrator. The model-facing allowed-write list and `SKILL.md` ownership rules are defense-in-depth on top of the deterministic guard, not a substitute for it. (A read-only-input `cmp` check in the e2e launcher does not violate Rule 7's "no duplicated semantic logic" — it is deterministic mechanics, not skill semantics.)

## 3. Implement JS/TS Primitives

1. Add or reuse parsers under `packages/asdlc-coordinator/src/parse/`.
2. Add shared types under `packages/asdlc-coordinator/src/types/` if the step needs new result shapes.
3. Implement capture only if the step writes an input-capture artifact:
   - File: `packages/asdlc-coordinator/src/capture/<step>.ts`.
   - Export from `packages/asdlc-coordinator/src/capture/index.ts`.
   - Register in `captureRegistry` in `packages/asdlc-coordinator/src/cli/run.ts`.
   - Require explicit non-interactive inputs such as `--source-file`, `--jira`, or step-specific options.
   - Validate ownership boundaries. For file inputs, reject unsupported extensions, missing files, directories, empty files, and files outside the allowed feature/project folder.
   - Do not overwrite existing capture artifacts unless the command has an explicit `--overwrite` contract.
4. Implement context:
   - File: `packages/asdlc-coordinator/src/context/<step>.ts`.
   - Export from `packages/asdlc-coordinator/src/context/index.ts`.
   - Register in `contextRegistry`.
   - Emit one deterministic context block.
   - Include workspace root, feature/project path, target artifacts, read-only inputs, allowed write artifacts, asset references, and exact gate command.
   - Include external-source instructions only when the captured source requires them.
   - Use skill-relative asset paths such as `assets/<file>`, not `.claude/...`, `.codex/...`, or source-repo paths.
5. Implement validation:
   - File: `packages/asdlc-coordinator/src/validate/<step>.ts`.
   - Export from `packages/asdlc-coordinator/src/validate/index.ts`.
   - Register in `gateRegistry`.
   - Port old helper checks one-for-one before adding new checks.
   - Return actionable problem strings for exit `1`.
   - Return clear runtime error text for exit `2`.
6. Keep the CLI shape:
   - `node .overmind/overmind.js capture <step> <path> <options>`
   - `node .overmind/overmind.js context <step> <path>`
   - `node .overmind/overmind.js gate <step> <path>`

## 4. Create The Skill Package

1. Create `packages/installer/_data/skills/<SKILL_NAME>/`.
2. Add `SKILL.md`.
3. Add `assets/` with every required template and golden example.
4. Inline the old rule into `SKILL.md`. Do not keep a separate skill rule asset unless a later design explicitly requires it.
5. Write `SKILL.md` with this structure:
   - YAML frontmatter: `name`, `description`.
   - Purpose paragraph.
   - `Required Invocation`.
   - Exact capture command, if capture is needed.
   - Exact context command.
   - Allowed write artifact list.
   - Exact gate command.
   - Gate exit-code handling.
   - Final response line, if the old step had one or the orchestrator depends on it. Keep the literal line only in `SKILL.md`.
   - `Assets` with skill-relative asset paths.
   - Inlined rule.
   - Runtime path binding section.
   - Quality criteria.
6. The skill must ask the operator only for missing human decisions. It must not ask for deterministic values that the CLI/context command can provide.
7. If a future VS Code UI will collect input, put that write contract in `capture <step>`. The skill should ask the operator now and run the same capture command the UI will call later.

## 5. Preserve Instruction Quality

Before deleting old files, compare `OLD_SCRIPT` + `OLD_RULE` against `SKILL.md` + context/capture/gate.

Required parity checks:

1. Stage goal matches the current sequence diagram and template. Remove stale ordering such as "before repo scan" if the step now runs after a scan.
2. Artifact allow-list is explicit.
3. Read-only inputs are explicit.
4. Runtime path bindings are explicit and authoritative.
5. All old section/heading/key preservation rules survive.
6. All old "do not invent facts" and traceability rules survive.
7. All old unresolved-data handling rules survive.
8. All old user-question scope limits survive.
9. All old answer-lifecycle boundaries survive. If another step owns answers, say so.
10. All old external-source branches survive, including Jira/MCP handling if applicable.
11. All old linked-artifact or metadata extraction rules survive.
12. All old final response lines survive in `SKILL.md` only.
13. Asset paths are skill-relative.
14. The model is told to run the gate after every write or repair.
15. Exit-code behavior is exact.
16. The skill does not rely on a shell orchestrator to run the gate.
17. The context command does not hardcode source-repo paths or runner-specific paths.
18. The e2e wrapper prompt is small and only supplies runtime bindings plus exact commands; it must not duplicate skill-owned instructions or literal final-response lines.
19. Every old deterministic guard survives in a deterministic owner (e2e launcher now, TS orchestrator later), not as advisory text only. In particular, every read-only-input immutability assertion is preserved: a model that mutates a read-only input must still fail the phase, not silently corrupt it.

Use this comparison table:

| Old instruction/check | New location | Status |
|---|---|---|
| Old prompt final line | `SKILL.md` only | kept/changed/missing |
| Old rule hard constraint | `SKILL.md` | kept/changed/missing |
| Old dynamic path binding | `context/<step>.ts` and `SKILL.md` | kept/changed/missing |
| Old capture prompt | `capture/<step>.ts` and `SKILL.md Required Invocation` | kept/changed/missing |
| Old helper validation | `validate/<step>.ts` | kept/changed/missing |
| Old deterministic guard (read-only-input immutability, output-produced assertion) | e2e launcher / TS orchestrator (deterministic, not advisory text) | kept/changed/missing |
| Old helper tests | TS tests | ported/not ported |

Any `missing` row blocks the migration.

## 6. Install And Stage The Skill

Update the TypeScript installer:

1. Update `packages/installer/src/init.ts`.
2. Ensure the canonical skill source is `packages/installer/_data/skills/<SKILL_NAME>/`.
3. Validate required payload before writing runner targets:
   - `SKILL.md`
   - `assets/`
4. Install the skill to every supported runner target:
   - `.codex/skills/<SKILL_NAME>/`
   - `.claude/skills/<SKILL_NAME>/`
5. Keep `.overmind/overmind.js` as the single shared CLI.
6. Remove stale installed skill folder contents before copying the canonical source.
7. Return install metadata that includes all installed skill paths.

Update legacy ASDLC setup staging while it still exists:

1. Update `overmind/scripts/project_mgmt/project_setup_first_init_machine.sh`.
2. Add/extend skill source constants.
3. Add/extend supported runner skill target constants.
4. Add preflight checks for the canonical skill folder, `SKILL.md`, and `assets/`.
5. Copy the canonical skill folder into `.codex/skills/<SKILL_NAME>/` and `.claude/skills/<SKILL_NAME>/` during fresh setup and update mode.
6. Ensure update mode repairs missing or stale runner skill folders.
7. Ensure setup still stages `.overmind/overmind.js` once.
8. Do not copy the CLI into skill folders.

## 7. Wire Transitional E2E Execution

Use this section only while the old shell e2e runner still controls cross-step sequencing.

1. Add or reuse a `.setup/models.md` phase row for the skill invocation.
2. In the e2e script, add constants:
   - `MODELS_FILE`
   - `MODEL_PHASE`
   - `TASK_SKILL_FILE` or step-specific equivalent
   - `OVERMIND_CLI_FILE`
3. Add a `load_model_config` helper if the script does not already have one.
4. Add `build_<step>_skill_prompt`.
5. The prompt must include only:
   - skill name
   - runtime root
   - current working directory
   - feature/project path
   - target artifact paths
   - `.overmind/overmind.js` path
   - exact capture/context/gate commands
   - allowed behavior when capture artifact exists or is missing
6. The prompt must not include literal model-facing completion text from the skill, including final lines such as `press Ctrl-C so orchestrator can start the next phase`.
7. Add `run_<step>_skill`.
8. Run Codex from the ASDLC runtime root.
9. Require `MODEL_CMD=codex` for now.
10. Check that the installed skill and `.overmind/overmind.js` exist before launching.
11. If the migrated skill is part of a combined phase, run remaining deterministic legacy scripts first or after it according to the sequence definition.
12. If a legacy deterministic substep no-ops because no repo path is ready, still run the skill when the step's captured business input is required.
13. Capture the model exit code without leaking `set -e`.
14. Print restart guidance that resumes at the correct step.
15. Do not run the JS gate from the shell e2e runner. The model/skill owns the gate loop.
16. Re-add every deterministic post-run guard the old orchestrator performed. For each read-only input, snapshot it before launching the skill and `cmp`-assert it byte-unchanged after the session, failing the phase with an actionable error on drift; likewise re-assert any required output the old script checked was produced. This is deterministic mechanics, not duplicated skill semantic logic, so it is allowed in the launcher even though Rule 7 forbids duplicating skill-owned instructions.

## 8. Delete Or Neutralize Old Bash

For a clean-break migrated step:

1. Do not keep backward compatibility for the migrated bash path.
2. Do not add new flags, aliases, fallback modes, or compatibility switches to select old vs new behavior.
3. Delete migrated bash as soon as the skill + JS replacement has parity tests and the runtime launcher is wired.
4. Delete as much of the old bash surface as the current sequence allows in the same migration change.
5. Delete `OLD_SCRIPT`.
6. Delete `OLD_HELPER`.
7. Delete old helper/orchestrator tests.
8. Remove deleted files from setup staging arrays.
9. Remove deleted files from shell test listings.
10. Remove references from docs, quickrun, README, and tests.
11. Keep only a transitional e2e launcher if cross-step orchestration has not yet moved to TS.

If the old step is partially migrated, delete every migrated old part immediately and keep only deterministic shell code still required by the current sequence. Mark clearly which remaining shell part is still required and which part is now skill-owned.

## 9. Tests

Add or update tests before removing old tests.

JS/TS tests:

1. Parser tests for new artifact shapes.
2. `capture <step>` tests:
   - success path
   - missing args
   - exactly-one-source rules
   - invalid paths
   - no-overwrite behavior
3. `context <step>` tests:
   - required files missing
   - expected runtime paths
   - expected asset references
   - expected external-source branch
   - expected gate command
4. `gate <step>` tests:
   - exit `0` valid artifact
   - exit `1` each recoverable quality issue
   - exit `2` missing/invalid runtime inputs
   - actionable `missing: ...` output

Installer tests:

1. Fresh install copies `.overmind/overmind.js`.
2. Fresh install copies the skill to `.codex/skills/<SKILL_NAME>/`.
3. Fresh install copies the skill to `.claude/skills/<SKILL_NAME>/`.
4. Runner skill folders contain `SKILL.md` and `assets/`.
5. Runner skill folders do not contain a CLI copy.
6. Install fails before writing runner targets when the packaged skill payload is incomplete.

Legacy setup tests while setup shell remains:

1. Fresh ASDLC setup stages the skill into both supported runner folders.
2. Update mode repairs missing/stale skill folders.
3. Update mode preserves `.overmind/overmind.js`.
4. Quickrun docs mention the installed skill and CLI correctly.

Legacy e2e tests while e2e shell remains:

1. Stub `codex`.
2. Assert the prompt says to load the skill.
3. Assert the prompt includes exact capture/context/gate commands.
4. Assert the prompt says the model owns gate handling.
5. Assert missing capture input makes the model ask for exactly one source.
6. Assert existing capture input does not trigger a new source request.
7. Assert the e2e runner starts the skill after any required deterministic phase work.
8. Assert the e2e runner still starts the skill when deterministic repo scan no-ops but the step requires captured business input.

## 10. Verification Commands

Run the narrowest applicable set, then broaden when shared installer/setup/e2e code changed.

Required after changing `asdlc-coordinator`:

```bash
npm test --workspace packages/asdlc-coordinator
```

Required after changing installer skill payload or installer install logic:

```bash
npm test --workspace packages/installer
```

Required after changing setup staging:

```bash
bash tests/ai_scripts/project_setup_asdlc_tests.sh
```

Required after changing feature e2e skill launch:

```bash
bash tests/ai_scripts/project_add_feature_e2e_tests.sh
```

Always run:

```bash
git diff --check
```

If the change is tracked by OpenSpec:

```bash
openspec validate <change-id> --strict
```

## 11. Manual Smoke

Run this in a temporary ASDLC runtime workspace:

1. Build packages.
2. Install or stage the runtime workspace.
3. Confirm `.overmind/overmind.js` exists.
4. Confirm `.codex/skills/<SKILL_NAME>/SKILL.md` exists.
5. Confirm `.claude/skills/<SKILL_NAME>/SKILL.md` exists.
6. Create the minimal project/feature artifacts needed by the step.
7. If the step has capture, run `node .overmind/overmind.js capture <STEP_KEY> <path> <options>`.
8. Run `node .overmind/overmind.js context <STEP_KEY> <path>`.
9. Run `node .overmind/overmind.js gate <STEP_KEY> <path>` against an incomplete artifact and confirm exit `1`.
10. Fix the artifact or use a valid fixture and confirm exit `0`.
11. Launch the skill through the runner or e2e wrapper.
12. Confirm the model final line matches the `SKILL.md` contract.

## 12. Definition Of Done

A step migration is done only when all items are true:

1. `SKILL.md` exists under `packages/installer/_data/skills/<SKILL_NAME>/`.
2. Required templates and golden examples exist under `assets/`.
3. `capture`, `context`, and `gate` commands exist for the step when needed.
4. `capture`, `context`, and `gate` are registered in the CLI registry.
5. The gate preserves `0/1/2` behavior.
6. Old helper checks are covered by TS tests.
7. Old prompt/rule instructions are preserved or intentionally updated with a documented reason.
8. Runtime path binding is explicit in both context output and skill text.
9. The skill uses skill-relative asset paths.
10. The model is instructed to run the gate after every write or repair.
11. The installer stages the skill to `.codex` and `.claude`.
12. `.overmind/overmind.js` remains the only CLI copy.
13. Setup/update mode repairs installed skill folders.
14. Transitional e2e launches the skill if the TS orchestrator does not yet own sequencing.
15. Transitional e2e does not duplicate skill-owned model-facing instructions or literal final-response lines.
16. Required tests pass.
17. `git diff --check` passes.
18. No old deleted script/helper/test references remain.
19. Every old deterministic guard (read-only-input immutability assertion, output-produced check) is preserved in a deterministic owner and covered by a test; none was downgraded to advisory `SKILL.md`/allowed-write text only.

## 13. Common Failure Patterns

Avoid these:

1. Moving old prompt text into `SKILL.md` without checking current step order.
2. Keeping stale phrases such as "before repo scan" after the sequence changed.
3. Letting the shell e2e runner execute the gate directly.
4. Asking the operator for values available from `context <step>`.
5. Hardcoding `.claude/skills/...` or `.codex/skills/...` in context output.
6. Copying `.overmind/overmind.js` into skill folders.
7. Deleting old bash before TS tests prove helper parity.
8. Losing final response lines needed by the orchestrator.
9. Duplicating literal final-response instructions in both `SKILL.md` and an orchestrator/e2e prompt.
10. Failing to preserve answer-lifecycle ownership between adjacent steps.
11. Treating templates as rules.
12. Dropping a deterministic orchestrator guard (e.g., the read-only-input `cmp` immutability check) and relying on the allowed-write list / `SKILL.md` prose instead — turning a guaranteed failure into silent corruption of a read-only input that flows into every downstream step.
