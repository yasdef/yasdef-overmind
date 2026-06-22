## 1. Monorepo scaffold (ts-build-foundation)

- [ ] 1.1 Add root `package.json` with npm workspaces (`packages/*`) and a top-level `skills/` dir
- [ ] 1.2 Add root TypeScript config (`tsconfig.base.json`) and per-package `tsconfig.json`
- [ ] 1.3 Choose and wire the TS test runner (`node:test` or `vitest`); add a root `npm test` script that runs package suites
- [ ] 1.4 Create empty package shells: `packages/asdlc-coordinator`, `packages/installer`, `packages/vscode-extension` (each with `package.json`)
- [ ] 1.5 Verify `npm install` links the workspace graph and `installer` can import `asdlc-coordinator` locally

## 2. asdlc-coordinator core + overmind-gate CLI (overmind-gate-cli)

- [ ] 2.1 Create `asdlc-coordinator` module surface: `parse/`, `validate/`, `readiness/` (stub), `types/`
- [ ] 2.2 Implement `types/` for BR artifacts and the validator result shape (problems list + status)
- [ ] 2.3 Implement `parse/` readers for `feature_br_summary.md`, `user_br_input.md`, `missing_br_data.md` (markdown sections/fields)
- [ ] 2.4 Implement `bin/overmind-gate` CLI: parse `<step> <path>`, dispatch to a `validate/<step>` registry
- [ ] 2.5 Implement the exit-code protocol: `0` pass, `1` recoverable (one actionable line per problem), `2` usage/runtime error (missing args, missing target, unknown step)
- [ ] 2.6 Add a build/bundle step producing a self-contained `overmind-gate.js` (asdlc-coordinator bundled in)

## 3. task-to-br validator (task-to-br-skill)

- [ ] 3.1 Implement `validate/task-to-br.ts` with parity to `check_task_to_br_quality.sh`: user_br_input epic_or_story content; missing_br_data.md presence/ledger; Document Meta `source_type`/`last_updated`; `2.1` summary; `3.1` business goal; ≥1 `FR-N`; ≥1 `BR-N`; unresolved Open Questions / Needs validation / Open scope boundaries moved to the ledger; ledger `rised` flags + Latest User Answers / Loop Decision gating
- [ ] 3.2 Register `task-to-br` in the gate dispatch registry
- [ ] 3.3 Confirm each failure path emits a distinct actionable `missing: …` message matching the spec scenarios

## 4. Tests (port from bash)

- [ ] 4.1 Port `tests/ai_scripts/check_task_to_br_quality_tests.sh` cases to TS tests for `validate/task-to-br`
- [ ] 4.2 Add valid + invalid fixtures (including a golden-example-based valid case)
- [ ] 4.3 Add CLI-level tests asserting exit codes `0/1/2` and message format for `overmind-gate task-to-br`
- [ ] 4.4 Run `npm test` and confirm green

## 5. overmind-task-to-br skill (task-to-br-skill)

- [ ] 5.1 Create `skills/overmind-task-to-br/SKILL.md` with frontmatter (`name`, `description` trigger), the former `task_to_br_rule.md` inlined, and the former orchestrator prompt logic (inputs, output paths, read-only discipline)
- [ ] 5.2 Add `assets/feature_br_summary_TEMPLATE.md` and `assets/feature_br_summary_GOLDEN_EXAMPLE.md`
- [ ] 5.3 In `SKILL.md`, instruct: write/repair artifacts → run `node .overmind/overmind-gate.js task-to-br <feature-path>` → handle `0` finish / `1` repair-and-rerun / `2` stop-and-ask; the model owns the loop
- [ ] 5.4 Implement a minimal `overmind init` in `packages/installer`: drop the bundled gate to `<project>/.overmind/overmind-gate.js` and install the skill to `<project>/.claude/skills/overmind-task-to-br/` (broader fan-out to `.codex/.github/.agents` + version-check update flow deferred)
- [ ] 5.5 Verify a fresh `overmind init` makes the skill runnable end to end (the skill resolves the gate at `.overmind/overmind-gate.js`)

## 6. Smoke + clean-break removal

- [ ] 6.1 Smoke test: drop `feature_br_summary_GOLDEN_EXAMPLE.md` into a feature folder and run the skill end to end (no upstream steps)
- [ ] 6.2 Delete `overmind/scripts/feature_task_to_br.sh`
- [ ] 6.3 Delete `overmind/scripts/helper/check_task_to_br_quality.sh`
- [ ] 6.4 Delete `tests/ai_scripts/check_task_to_br_quality_tests.sh` and remove its entry from `CLAUDE.md`'s test list
- [ ] 6.5 Confirm no remaining references to the deleted bash files in scripts/docs/tests
