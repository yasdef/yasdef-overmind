## Why

Overmind's pipeline is implemented as `md (rule) + sh (orchestrator) + sh (helper)`, with brittle `awk`-based parsing that is POC-grade, hard to maintain, and not prod-level. The agreed direction (`design_docs/to_skills_migration/migration_to_skill_architecture_overview.md`) is to migrate to agent **skills** backed by a **TypeScript core**, ending at `.ts` + `.md` source only. This change lands the foundation and the first step (`task-to-br`, step 4.1) as the reference that proves the whole loop end to end.

## What Changes

- Add a **TypeScript npm-workspaces monorepo**: `packages/asdlc-coordinator`, `packages/installer`, `packages/vscode-extension` (placeholder), with skill sources under `packages/installer/_data/skills/` (the installer ships them as package data, matching the yasdef worker's `_data/skills/`), and a TS test runner wired up.
- Add the **`overmind` CLI** in `asdlc-coordinator` — one bundled binary with three subcommands: `overmind capture <step> <feature_path>` (deterministically writes step-owned input capture artifacts), `overmind context <step> <feature_path>` (deterministically assembles the step's dynamic context into one block for the model), and `overmind gate <step> <path>` (the `0 = pass / 1 = recoverable / 2 = error` exit protocol).
- Add a minimal **`overmind init`** in `packages/installer` that drops the bundled `overmind` CLI to `<project>/.overmind/overmind.js` and installs the skill to `<project>/.claude/skills/` — the install mechanism `design_docs/overmind_vscode_extention/distribution_and_update.md` relies on (broader runner fan-out deferred).
- Migrate **`task-to-br`** (step 4.1):
  - Reimplement its deterministic input capture as `asdlc-coordinator/capture/task-to-br.ts` (writes `user_br_input.md` from an explicit local story file or Jira ticket), its structural quality gate as `asdlc-coordinator/validate/task-to-br.ts` (behavior parity with `check_task_to_br_quality.sh`), and its context assembly as `asdlc-coordinator/context/task-to-br.ts` (parity with `feature_task_to_br.sh`'s prompt context after capture: resolved paths, captured inputs, Jira branch).
  - Add the **`overmind-task-to-br` skill** (`packages/installer/_data/skills/overmind-task-to-br/SKILL.md` with the rule inlined; the model runs `overmind capture` when `user_br_input.md` is absent → `overmind context` → generate → `overmind gate` → repair; `assets/` template + golden example).
  - Port the gate tests from `tests/ai_scripts/check_task_to_br_quality_tests.sh` to the TS test runner.
- **BREAKING / clean break:** remove the bash equivalents migrated by this change — `overmind/scripts/feature_task_to_br.sh`, `overmind/scripts/helper/check_task_to_br_quality.sh`, and `tests/ai_scripts/check_task_to_br_quality_tests.sh`. No dual bash+TS path, no backward compatibility.

## Capabilities

### New Capabilities
- `ts-build-foundation`: the npm-workspaces TypeScript monorepo, `asdlc-coordinator` package layout, TS test runner, and fat-jar-style bundling of `asdlc-coordinator` into shipped artifacts.
- `overmind-gate-cli`: the generic `overmind` CLI runtime — `capture <step> <feature_path>`, `context <step> <feature_path>`, and `gate <step> <path>` subcommand dispatch, the `0/1/2` exit-code protocol for `gate`, and the actionable pass/fail/error message contract.
- `task-to-br-skill`: the migrated step 4.1 as a whole — the `overmind-task-to-br` agent skill (inputs, gate-and-repair loop, output) plus the `task-to-br` structural validation rules it relies on.

### Modified Capabilities
<!-- None — openspec/specs/ is empty; there are no existing specs whose requirements change. -->

## Impact

- **New:** `packages/asdlc-coordinator/**`, `packages/installer/**` (incl. `packages/installer/_data/skills/overmind-task-to-br/**`), `packages/vscode-extension/**`, root `package.json` (npm workspaces) + TS config + test runner.
- **Removed:** `overmind/scripts/feature_task_to_br.sh`, `overmind/scripts/helper/check_task_to_br_quality.sh`, `tests/ai_scripts/check_task_to_br_quality_tests.sh`.
- **Tooling:** introduces Node/npm + TypeScript to a previously bash-only repo; first step that contradicts `CLAUDE.md`'s "plain shell only" rule (to be updated as the migration proceeds).
- **Dependencies:** Node.js runtime (assumed present via the VS Code extension); npm workspaces.
- **Out of scope:** other pipeline steps, the cross-step orchestrator/state-machine, broader installer fan-out to `.codex/.github/.agents`, and the version-check update flow. A minimal but real `overmind init` (the `overmind` CLI → `.overmind/overmind.js`, skill → `.claude/skills/`) IS in scope.
