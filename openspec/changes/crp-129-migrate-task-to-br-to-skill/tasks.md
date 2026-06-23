## 1. Monorepo scaffold (ts-build-foundation)

- [x] 1.1 Add root `package.json` with npm workspaces (`packages/*`); skill sources live under `packages/installer/_data/skills/` (installer package data)
- [x] 1.2 Add root TypeScript config (`tsconfig.base.json`) and per-package `tsconfig.json`
- [x] 1.3 Choose and wire the TS test runner (`node:test` or `vitest`); add a root `npm test` script that runs package suites
- [x] 1.4 Create empty package shells: `packages/asdlc-coordinator`, `packages/installer`, `packages/vscode-extension` (each with `package.json`)
- [x] 1.5 Verify `npm install` links the workspace graph and `installer` can import `asdlc-coordinator` locally

## 2. asdlc-coordinator core + `overmind` CLI (overmind-gate-cli)

- [x] 2.1 Create `asdlc-coordinator` module surface: `parse/`, `validate/`, `context/`, `readiness/` (stub), `types/`
- [x] 2.2 Implement `types/` for BR artifacts and the validator result shape (problems list + status)
- [x] 2.3 Implement `parse/` readers for `feature_br_summary.md`, `user_br_input.md`, `missing_br_data.md` (markdown sections/fields)
- [x] 2.4 Implement the `bin/overmind` CLI with three subcommands: `capture <step> <feature_path>` → `capture/<step>` registry, `gate <step> <path>` → `validate/<step>` registry, and `context <step> <feature_path>` → `context/<step>` registry
- [x] 2.5 Implement the `gate` exit-code protocol: `0` pass, `1` recoverable (one actionable line per problem), `2` usage/runtime error (missing args, missing target, unknown step)
- [x] 2.6 Add a build/bundle step producing a single self-contained `overmind.js` (asdlc-coordinator bundled in)

## 3. task-to-br validator (task-to-br-skill)

- [x] 3.1 Implement `validate/task-to-br.ts` with parity to `check_task_to_br_quality.sh`: user_br_input epic_or_story content; missing_br_data.md presence/ledger; Document Meta `source_type`/`last_updated`; `2.1` summary; `3.1` business goal; ≥1 `FR-N`; ≥1 `BR-N`; unresolved Open Questions / Needs validation / Open scope boundaries moved to the ledger; ledger `rised` flags + Latest User Answers / Loop Decision gating
- [x] 3.2 Register `task-to-br` in the gate dispatch registry
- [x] 3.3 Confirm each failure path emits a distinct actionable `missing: …` message matching the spec scenarios
- [x] 3.4 Implement `context/task-to-br.ts` with parity to `feature_task_to_br.sh`'s prompt context: resolve feature paths, read `user_br_input.md` fields (feature id/title, epic/story, request summary, extra context), reference the missing-data/template/golden assets, and the Jira branch (read `external_sources.yaml`); emit one assembled context block. Register `task-to-br` in the context dispatch registry
- [x] 3.5 Implement `capture/task-to-br.ts` to write `user_br_input.md` from an explicit local `.txt/.md` story file or Jira ticket, preserving the old capture half of `feature_task_to_br.sh` as a non-interactive CLI primitive for future VS Code UI use

## 4. Tests (port from bash)

- [x] 4.1 Port `tests/ai_scripts/check_task_to_br_quality_tests.sh` cases to TS tests for `validate/task-to-br`
- [x] 4.2 Add valid + invalid fixtures (including a golden-example-based valid case)
- [x] 4.3 Add CLI-level tests asserting exit codes `0/1/2` and message format for `overmind gate task-to-br`
- [x] 4.4 Add tests for `context/task-to-br` (assembled-block parity + the Jira branch) via `overmind context task-to-br`
- [x] 4.5 Run `npm test` and confirm green
- [x] 4.6 Add CLI tests for `capture task-to-br` local-file capture, Jira capture, no-overwrite behavior, and capture-to-context flow

## 5. overmind-task-to-br skill (task-to-br-skill)

- [x] 5.1 Create `packages/installer/_data/skills/overmind-task-to-br/SKILL.md` with frontmatter (`name`, `description` trigger), the former `task_to_br_rule.md` inlined, and the inputs/output-paths/read-only discipline the model needs (dynamic context assembly itself is `overmind context`, not inlined)
- [x] 5.2 Add `assets/feature_br_summary_TEMPLATE.md` and `assets/feature_br_summary_GOLDEN_EXAMPLE.md`
- [x] 5.3 In `SKILL.md`, instruct the model-owned loop: run `node .overmind/overmind.js capture task-to-br <feature-path> ...` when `user_br_input.md` is missing → run `node .overmind/overmind.js context task-to-br <feature-path>` → write/repair artifacts → run `node .overmind/overmind.js gate task-to-br <feature-path>` → handle `0` finish / `1` repair-and-rerun / `2` stop-and-ask
- [x] 5.4 Implement a minimal `overmind init` in `packages/installer`: drop the bundled `overmind` CLI to `<project>/.overmind/overmind.js` and install the skill (from `packages/installer/_data/skills/overmind-task-to-br/`) to `<project>/.claude/skills/overmind-task-to-br/` (broader fan-out to `.codex/.github/.agents` + version-check update flow deferred)
- [x] 5.5 Verify a fresh `overmind init` makes the skill runnable end to end (the skill resolves the CLI at `.overmind/overmind.js`)

## 6. Smoke + clean-break removal

- [x] 6.1 Smoke test: drop `feature_br_summary_GOLDEN_EXAMPLE.md` plus a local `.txt`/`.md` story source into a feature folder, start with no `user_br_input.md`, then run the capture/context/skill loop without upstream steps
- [x] 6.2 Delete `overmind/scripts/feature_task_to_br.sh`
- [x] 6.3 Delete `overmind/scripts/helper/check_task_to_br_quality.sh`
- [x] 6.4 Delete `tests/ai_scripts/check_task_to_br_quality_tests.sh` and remove its entry from `CLAUDE.md`'s test list
- [x] 6.5 Confirm no remaining references to the deleted bash files in scripts/docs/tests
- [x] 6.6 Wire `project_setup_first_init_machine.sh` to stage `packages/asdlc-coordinator/dist/overmind.js` into ASDLC workspaces as `.overmind/overmind.js`, with fresh setup, update repair, and missing-bundle tests
- [x] 6.7 Remove agent-specific `.claude/skills/...` asset paths from `overmind context task-to-br`; keep task-to-BR assets referenced as loaded-skill-relative `assets/...` paths
