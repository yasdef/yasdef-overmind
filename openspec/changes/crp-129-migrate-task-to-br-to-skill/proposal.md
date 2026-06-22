## Why

Overmind's pipeline is implemented as `md (rule) + sh (orchestrator) + sh (helper)`, with brittle `awk`-based parsing that is POC-grade, hard to maintain, and not prod-level. The agreed direction (`design_docs/to_skills_migration/migration_to_skill_architecture_overview.md`) is to migrate to agent **skills** backed by a **TypeScript core**, ending at `.ts` + `.md` source only. This change lands the foundation and the first step (`task-to-br`, step 4.1) as the reference that proves the whole loop end to end.

## What Changes

- Add a **TypeScript npm-workspaces monorepo**: `packages/asdlc-coordinator`, `packages/installer`, `packages/vscode-extension` (placeholder), and a top-level `skills/` source dir, with a TS test runner wired up.
- Add the **`overmind-gate` CLI** in `asdlc-coordinator` with a stable invocation `overmind-gate <step> <path>` and the `0 = pass / 1 = recoverable / 2 = error` exit protocol.
- Add a minimal **`overmind init`** in `packages/installer` that drops the bundled gate to `<project>/.overmind/overmind-gate.js` and installs the skill to `<project>/.claude/skills/` — the install mechanism `design_docs/overmind_vscode_extention/distribution_and_update.md` relies on (broader runner fan-out deferred).
- Migrate **`task-to-br`** (step 4.1):
  - Reimplement its structural quality gate as `asdlc-coordinator/validate/task-to-br.ts` (behavior parity with `check_task_to_br_quality.sh`).
  - Add the **`overmind-task-to-br` skill** (`skills/overmind-task-to-br/SKILL.md` with rule inline + former orchestrator prompt logic; `assets/` template + golden example).
  - Port the gate tests from `tests/ai_scripts/check_task_to_br_quality_tests.sh` to the TS test runner.
- **BREAKING / clean break:** remove the bash equivalents migrated by this change — `overmind/scripts/feature_task_to_br.sh`, `overmind/scripts/helper/check_task_to_br_quality.sh`, and `tests/ai_scripts/check_task_to_br_quality_tests.sh`. No dual bash+TS path, no backward compatibility.

## Capabilities

### New Capabilities
- `ts-build-foundation`: the npm-workspaces TypeScript monorepo, `asdlc-coordinator` package layout, TS test runner, and fat-jar-style bundling of `asdlc-coordinator` into shipped artifacts.
- `overmind-gate-cli`: the generic gate runtime — `overmind-gate <step> <path>` invocation, the `0/1/2` exit-code protocol, and the actionable pass/fail/error message contract.
- `task-to-br-skill`: the migrated step 4.1 as a whole — the `overmind-task-to-br` agent skill (inputs, gate-and-repair loop, output) plus the `task-to-br` structural validation rules it relies on.

### Modified Capabilities
<!-- None — openspec/specs/ is empty; there are no existing specs whose requirements change. -->

## Impact

- **New:** `packages/asdlc-coordinator/**`, `packages/installer/**`, `packages/vscode-extension/**`, `skills/overmind-task-to-br/**`, root `package.json` (npm workspaces) + TS config + test runner.
- **Removed:** `overmind/scripts/feature_task_to_br.sh`, `overmind/scripts/helper/check_task_to_br_quality.sh`, `tests/ai_scripts/check_task_to_br_quality_tests.sh`.
- **Tooling:** introduces Node/npm + TypeScript to a previously bash-only repo; first step that contradicts `CLAUDE.md`'s "plain shell only" rule (to be updated as the migration proceeds).
- **Dependencies:** Node.js runtime (assumed present via the VS Code extension); npm workspaces.
- **Out of scope:** other pipeline steps, the cross-step orchestrator/state-machine, broader installer fan-out to `.codex/.github/.agents`, and the version-check update flow. A minimal but real `overmind init` (gate → `.overmind/`, skill → `.claude/skills/`) IS in scope.
