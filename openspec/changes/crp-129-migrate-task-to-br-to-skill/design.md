## Context

Overmind's pipeline today is `md (rule) + sh (orchestrator) + sh (helper)` with `awk`-based parsing. The settled migration design (`design_docs/to_skills_migration/migration_to_skill_architecture_overview.md`) moves it to agent **skills** backed by a **TypeScript core** (`asdlc-coordinator`), ending at `.ts` + `.md` source only, as a clean break with no backward compatibility. This change is the **pilot**: it lands the build foundation and migrates one step — `task-to-br` (step 4.1) — chosen because it is the earliest step with a quality gate and is runnable in isolation from a single golden-example input.

Current `task-to-br` assets being replaced: `overmind/scripts/feature_task_to_br.sh` (orchestrator), `overmind/scripts/helper/check_task_to_br_quality.sh` (gate, target `feature_br_summary.md` plus `user_br_input.md` / `missing_br_data.md`), and `tests/ai_scripts/check_task_to_br_quality_tests.sh`.

## Goals / Non-Goals

**Goals:**
- Stand up the npm-workspaces TS monorepo (`packages/asdlc-coordinator`, `installer`, `vscode-extension`; skill sources under `packages/installer/_data/skills/`) with a TS test runner.
- Provide a single bundled `overmind` CLI (`asdlc-coordinator`) with three subcommands: `capture <step> <feature_path>` (deterministically writes step-owned input capture artifacts), `context <step> <feature_path>` (deterministically assembles the step's dynamic context — resolved paths, captured inputs, config-driven branches — into one context block), and `gate <step> <path>` (the `0/1/2` exit protocol).
- Provide a minimal `overmind init` (`packages/installer`) that installs the bundled `overmind` CLI to `.overmind/overmind.js` and the skill to `.claude/skills/`.
- Migrate `task-to-br`: TS validator + context builder with behavior parity, the `overmind-task-to-br` skill, ported tests.
- Prove the end-to-end loop (skill → `overmind capture` when needed → `overmind context` → generate → `overmind gate` → exit-code repair loop) from a golden-example BR summary plus an explicit captured source.

**Non-Goals:**
- Other pipeline steps; the cross-step orchestrator/state-machine.
- Broader installer fan-out to `.codex/.github/.agents` and the version-check update flow (a minimal real `overmind init` IS in scope: gate + context CLIs → `.overmind/`, skill → `.claude/skills/`).
- Standalone-binary compilation of the gate (`bun`/`deno`/`pkg`) — deferred; plain Node is assumed.
- Rewriting `CLAUDE.md`'s bash-era rules (tracked, not done here).

## Decisions

- **TypeScript, not Python or bash.** The VS Code extension already requires a TS parser/readiness engine over the same ASDLC artifacts; TS lets that logic live once in `asdlc-coordinator` (shared by gates + extension) instead of two parsers. The worker repo stays Python (separate product, bound by file format, not code). *Alternatives:* keep bash (rejected: brittle awk, not prod-level); Python (rejected: forces a second parser for the extension).
- **Capture + context + gate hosted in `asdlc-coordinator` as one `overmind` CLI** — one bundled binary with three subcommands, not three binaries: `capture <step> <feature_path>` (a `capture/<step>` registry), `context <step> <feature_path>` (a `context/<step>` registry), and `gate <step> <path>` (a `validate/<step>` registry). The gate keeps the existing model↔gate contract (`0` pass / `1` recoverable / `2` error) so `SKILL.md` prose is independent of implementation language and tests can target the CLI directly.
- **Per-step orchestrator dissolves into the skill; its mechanical jobs become CLIs the model or UI invokes.** `feature_task_to_br.sh` did three jobs beyond hand-off: (a) capture input — choose local file or Jira and write `user_br_input.md`; (b) assemble dynamic context — resolve feature paths, read `user_br_input.md`, branch on Jira via `external_sources.yaml`; and (c) leave the gate to validate separately. `SKILL.md` is **not** a frozen prompt: the rule prose is **inlined** into it, but deterministic capture/context/gate mechanics are not. Jobs (a), (b), and the gate become subcommands of one bundled `asdlc-coordinator` `overmind` CLI: `overmind capture task-to-br <feature_path> --source-file <path>` or `--jira <ticket>` writes `user_br_input.md`; `overmind context <step> <feature_path>` emits one assembled context block; `overmind gate <step> <path>` validates. `SKILL.md` drives the model-owned loop: run capture when `user_br_input.md` is missing → run `overmind context` → generate/edit the artifact → run `overmind gate` → repair on exit `1` until `0`. The future VS Code extension should call the same non-interactive capture primitive from its UI rather than duplicating capture file-writing rules. This mirrors the yasdef worker skill (`scripts/build_implementation_context.py` + `scripts/check_implementation_readiness.py`, driven by its `SKILL.md`), but the capture/builder/gate live as TS in `asdlc-coordinator` (single parser, per the TypeScript decision) instead of per-skill Python (the worker is a separate Python product). For `task-to-br` the builder is thin (one input file + the Jira branch); building it in the pilot establishes the pattern for heavier steps (7, 8.x) and keeps context assembly deterministic rather than re-derived by the model each run.
- **npm workspaces; `asdlc-coordinator` as an in-repo module dep, bundled fat-jar-style.** *Alternatives:* pnpm (rejected for now — minimize new tooling for a bash-only repo and a non-JS-native maintainer); publishing `asdlc-coordinator` to a registry (deferred until an external consumer appears).
- **Clean-break removal.** The migrated bash files are deleted in this change, not kept in parallel — consistent with the no-backward-compatibility decision.
- **Validator parity via fixtures.** The TS validator reproduces the helper's checks; the ported tests use the same kinds of malformed/valid fixtures the bash suite used, so parity is demonstrable.

## Risks / Trade-offs

- **Behavior drift in the bash→TS port (capture, gate, and context builder)** → Port `check_task_to_br_quality.sh`'s checks one-for-one (each failure message covered by a fixture); reproduce `feature_task_to_br.sh`'s capture and context assembly (local story/Jira capture, resolved paths, captured inputs, Jira branch) in `overmind capture` and `overmind context` with fixture tests. Do both before deleting the bash files.
- **Introducing Node/npm to a bash-only repo (and contradicting `CLAUDE.md`)** → Acknowledge as the first migration step; bash + `tests/ai_scripts` conventions are legacy being drained; update `CLAUDE.md` as the migration proceeds (out of scope here).
- **Scope creep into a general installer/orchestrator** → Explicit non-goals; only a minimal install path for the single pilot skill.
- **Maintainer is not JS-proficient** → Favor the simplest tooling (npm workspaces, plain Node), keep the package surface small and conventional.

## Migration Plan

1. Scaffold the monorepo, `asdlc-coordinator` package surface, and the TS test runner.
2. Implement `parse/` for the BR artifacts and `validate/task-to-br.ts`; wire the `bin/overmind` CLI with a `gate <step> <path>` subcommand (dispatch + exit protocol).
3. Implement `capture/task-to-br.ts` (write `user_br_input.md` from an explicit local story file or Jira ticket) and `context/task-to-br.ts` (resolve paths, read `user_br_input.md`, Jira branch); add `capture <step> <feature_path>` and `context <step> <feature_path>` subcommands to the same `bin/overmind` CLI.
4. Port the gate tests to TS; add capture and context-builder tests (local story/Jira capture, assembled-block parity + the Jira branch); confirm against valid/invalid fixtures.
5. Author `packages/installer/_data/skills/overmind-task-to-br/` (`SKILL.md` with the inlined rule that drives `overmind capture` when needed → `overmind context` → generate → `overmind gate` → repair, plus `assets/` template + golden example).
6. Manual smoke: drop the golden-example BR summary plus local story source into a feature folder, run capture, then run the skill end to end.
7. Delete the replaced bash files and their bash test suite.

Rollback: revert the change; the deleted bash files return with it (single-commit/PR boundary).

## Open Questions

- Test runner choice (`node:test` vs `vitest`) — pick the lighter option that needs no extra config for a first step.
