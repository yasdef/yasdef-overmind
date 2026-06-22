## Context

Overmind's pipeline today is `md (rule) + sh (orchestrator) + sh (helper)` with `awk`-based parsing. The settled migration design (`design_docs/to_skills_migration/migration_to_skill_architecture_overview.md`) moves it to agent **skills** backed by a **TypeScript core** (`asdlc-coordinator`), ending at `.ts` + `.md` source only, as a clean break with no backward compatibility. This change is the **pilot**: it lands the build foundation and migrates one step — `task-to-br` (step 4.1) — chosen because it is the earliest step with a quality gate and is runnable in isolation from a single golden-example input.

Current `task-to-br` assets being replaced: `overmind/scripts/feature_task_to_br.sh` (orchestrator), `overmind/scripts/helper/check_task_to_br_quality.sh` (gate, target `feature_br_summary.md` plus `user_br_input.md` / `missing_br_data.md`), and `tests/ai_scripts/check_task_to_br_quality_tests.sh`.

## Goals / Non-Goals

**Goals:**
- Stand up the npm-workspaces TS monorepo (`packages/asdlc-coordinator`, `installer`, `vscode-extension`; `skills/`) with a TS test runner.
- Provide the `overmind-gate <step> <path>` CLI with the `0/1/2` exit protocol.
- Provide a minimal `overmind init` (`packages/installer`) that installs the gate to `.overmind/overmind-gate.js` and the skill to `.claude/skills/`.
- Migrate `task-to-br`: TS validator with behavior parity, the `overmind-task-to-br` skill, ported tests.
- Prove the end-to-end loop (skill → gate → exit-code repair loop) from a golden-example input.

**Non-Goals:**
- Other pipeline steps; the cross-step orchestrator/state-machine.
- Broader installer fan-out to `.codex/.github/.agents` and the version-check update flow (a minimal real `overmind init` IS in scope: gate → `.overmind/`, skill → `.claude/skills/`).
- Standalone-binary compilation of the gate (`bun`/`deno`/`pkg`) — deferred; plain Node is assumed.
- Rewriting `CLAUDE.md`'s bash-era rules (tracked, not done here).

## Decisions

- **TypeScript, not Python or bash.** The VS Code extension already requires a TS parser/readiness engine over the same ASDLC artifacts; TS lets that logic live once in `asdlc-coordinator` (shared by gates + extension) instead of two parsers. The worker repo stays Python (separate product, bound by file format, not code). *Alternatives:* keep bash (rejected: brittle awk, not prod-level); Python (rejected: forces a second parser for the extension).
- **Gate hosted in `asdlc-coordinator` as a CLI** with a `validate/<step>` registry behind `overmind-gate <step> <path>`. Keeps the existing model↔gate contract (`0` pass / `1` recoverable / `2` error) so `SKILL.md` prose is independent of implementation language and tests can target the CLI directly.
- **Per-step orchestrator dissolves into the skill.** `feature_task_to_br.sh`'s prompt-building logic moves into `SKILL.md` (rule inlined); the model owns the generate-and-repair loop. The orchestrator never auto-runs the gate.
- **npm workspaces; `asdlc-coordinator` as an in-repo module dep, bundled fat-jar-style.** *Alternatives:* pnpm (rejected for now — minimize new tooling for a bash-only repo and a non-JS-native maintainer); publishing `asdlc-coordinator` to a registry (deferred until an external consumer appears).
- **Clean-break removal.** The migrated bash files are deleted in this change, not kept in parallel — consistent with the no-backward-compatibility decision.
- **Validator parity via fixtures.** The TS validator reproduces the helper's checks; the ported tests use the same kinds of malformed/valid fixtures the bash suite used, so parity is demonstrable.

## Risks / Trade-offs

- **Behavior drift between bash gate and TS validator** → Port `check_task_to_br_quality.sh`'s checks one-for-one and cover each failure message with a fixture test before deleting the bash gate.
- **Introducing Node/npm to a bash-only repo (and contradicting `CLAUDE.md`)** → Acknowledge as the first migration step; bash + `tests/ai_scripts` conventions are legacy being drained; update `CLAUDE.md` as the migration proceeds (out of scope here).
- **Scope creep into a general installer/orchestrator** → Explicit non-goals; only a minimal install path for the single pilot skill.
- **Maintainer is not JS-proficient** → Favor the simplest tooling (npm workspaces, plain Node), keep the package surface small and conventional.

## Migration Plan

1. Scaffold the monorepo, `asdlc-coordinator` package surface, and the TS test runner.
2. Implement `parse/` for the BR artifacts and `validate/task-to-br.ts`; wire `bin/overmind-gate` dispatch + exit protocol.
3. Port the gate tests to TS; confirm parity against valid/invalid fixtures.
4. Author `skills/overmind-task-to-br/` (`SKILL.md` + `assets/` template + golden example).
5. Manual smoke: drop the golden-example BR summary into a feature folder and run the skill end to end.
6. Delete the replaced bash files and their bash test suite.

Rollback: revert the change; the deleted bash files return with it (single-commit/PR boundary).

## Open Questions

- Test runner choice (`node:test` vs `vitest`) — pick the lighter option that needs no extra config for a first step.
