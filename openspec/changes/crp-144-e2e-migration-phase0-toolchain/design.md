## Context

The repo is an npm-workspaces TypeScript monorepo (`packages/asdlc-coordinator`, `installer`, `vscode-extension`) introduced by the skills migration (crp-129 onward). It has no linter, no formatter, and no CI. Typechecking only happens as a side effect of `tsc` during `build`; the migrated 13-step coordinator/installer code is therefore unlinted and never typechecked with `--noEmit`. `tsconfig.base.json` is `strict: true` but omits the sharper strictness flags.

The E2E orchestrator migration (`design_docs/e2e_orchestrator_migration/`) will land orchestrator, scanner, runner, and config modules across Slices 1–5. Per `04_migration_plan.md ## Slice 0 — Toolchain baseline` and the contract in `03_target_architecture.md ## Engineering baseline`, the toolchain must exist *before* that code lands and must also be applied retroactively to the already-migrated code. Operator choices were fixed on 2026-07-04: ESLint + Prettier over Biome; no git hooks. Enforcement was subsequently revised (this change) from remote GitHub Actions CI to **local agent-driven verification**: the two agents that edit this repo — Claude (`CLAUDE.md`) and Codex (`AGENTS.md`) — run the full suite themselves. This supersedes the "GitHub Actions required for merge" line in the design docs, which are updated to the `npm run verify` model in this same change.

This slice is pure infrastructure plus mechanical fixes — no behavior changes, no new runtime dependencies.

## Goals / Non-Goals

**Goals:**
- Type-aware ESLint flat config + Prettier + `.editorconfig` at the root, wired into every workspace.
- `tsconfig.base.json` gains `noUncheckedIndexedAccess`, `noImplicitOverride`, `noFallthroughCasesInSwitch`, `verbatimModuleSyntax`; all resulting fallout fixed mechanically in the same change.
- `typecheck` / `lint` / `format:check` scripts per workspace + root aggregate; `typecheck` is `tsc --noEmit` (tests included), independent of build.
- One aggregate `npm run verify` (typecheck → lint → format-check → build → test over TS workspaces + `tests/ai_scripts/*.sh`), Node floor pinned, coverage report-only, mandated in both `AGENTS.md` and `CLAUDE.md` as the local gate the agents run before completing a change.
- Leave the repo green and every operator workflow runnable end-to-end.

**Non-Goals:**
- Any orchestrator/scanner/runner/config code (Slices 1–5).
- Coverage threshold gating (report-only now; gate arrives with the orchestrator slices).
- Remote CI (no GitHub Actions / no other remote pipeline) — enforcement is local and agent-run.
- Git hooks of any kind (checkpoint and model-session commits must not pass through hook machinery that can change their behavior).
- New test framework — tests stay on Node's built-in `node --test`.
- Changing skill bodies, gates, or artifact formats.

## Decisions

- **ESLint (flat config, type-checked presets) over Biome.** Rationale: type-aware rules are the whole point — `no-floating-promises` and the fs/spawn-safety rules catch exactly the mistakes an orchestrator produces, and Biome cannot do type-aware linting. Cost: type-checked linting needs `parserOptions.project`, making lint slower; accepted because the ruleset is what protects Slices 1–5. Flat config (`eslint.config.js`) is the current-generation ESLint format and avoids `.eslintrc` legacy.
- **Prettier as sole formatter + `eslint-config-prettier`.** One formatter, no stylistic tug-of-war. `eslint-config-prettier` disables every ESLint rule that could conflict, so `lint` never fights `format:check`. `.editorconfig` covers editor-level defaults for non-JS files too.
- **Strictness flags added now, fallout fixed in-slice.** Retrofitting after five slices is far more expensive. `noUncheckedIndexedAccess` is the highest-fallout flag; fixes are mechanical (guards / non-null assertions where provably safe) and must not change behavior. `verbatimModuleSyntax` may force `import type` rewrites — mechanical.
- **`typecheck` = `tsc --noEmit`, test files included, separate from `build`.** A fast check that also covers `test/**` (which the emit path may exclude), giving `verify` a build-independent gate.
- **Local agent-driven enforcement, no remote CI, no git hooks.** Operator decision (revising the design docs' GitHub Actions line). This repo's changes are made by two agents — Claude and Codex — so the gate lives where they act: a single `npm run verify` command they are instructed to run and confirm green before completing a change. Rationale for local-over-remote: the feedback loop is immediate (no push/wait cycle), it works offline, and it needs no repo-hosting/CI plumbing for a bash-and-TS project driven by agents. Rationale for no hooks: checkpoint commits (`git add -A`, tolerant of failure) and model-session commits must behave identically with and without automation; a hook would perturb that. Enforcement is therefore an *instruction*, mandated identically in `AGENTS.md` and `CLAUDE.md` so both agents share one contract.
- **One aggregate command, not just per-workspace scripts.** `verify` chains the six stages so "run the full suite" is a single memorable command both agents invoke — no risk of an agent running typecheck but forgetting lint or the shell suites. It composes the same per-workspace `typecheck`/`lint`/`format:check` scripts (which stay individually runnable for fast local iteration).
- **`verify` runs the shell suites too.** The `tests/ai_scripts/*.sh` suites remain the behavioral spec of record until the scripts they cover are deleted (Slices 1–4). `verify` runs them alongside the TS suites so the transition never regresses silently.
- **Coverage report-only.** `node --test` native coverage is emitted but not gated; a threshold gate is deferred until orchestrator code exists to hold to a bar.
- **Zero runtime dependencies preserved.** Every tool is a dev-dependency. `asdlc-coordinator.dependencies` stays `{}` so the bundled `overmind.js` remains a dependency-free single file. Adding a *runtime* dependency would require an explicit recorded decision — out of scope here.

## Risks / Trade-offs

- **[Strictness fallout larger than expected, tempting behavior-changing "fixes"]** → Every fix must be behavior-preserving; where a real bug is uncovered, fix minimally and note it, but do not fold feature work into this slice. The e2e/shell suites plus TS tests running green under `npm run verify` is the guard.
- **[Type-checked lint is slow / flaky on `parserOptions.project`]** → Point the ESLint TS parser at the workspace tsconfigs (which already include `src` + `test`); keep the config minimal. Slowness is acceptable in the full `verify` gate; the per-workspace `lint` stays runnable on its own for fast iteration.
- **[Local enforcement is only as strong as the agents' compliance — an agent could skip `verify`]** → The mandate is stated identically and prominently in both `AGENTS.md` and `CLAUDE.md` (the files each agent already reads), and the single-command design removes the excuse of "I ran most of it." Accepted residual risk: without a hook or remote gate, a non-compliant run isn't mechanically blocked — a deliberate trade of hard-blocking for the agent-driven, hook-free model the operator chose.
- **[The `verify` chain is slow, tempting agents to run subsets]** → Per-workspace `typecheck`/`lint`/`format:check` stay individually runnable for fast iteration; `verify` is the completion gate, not the inner-loop command.
- **[`verbatimModuleSyntax` + `NodeNext` ESM interop surprises]** → Mechanical `import type` conversions; `build` + `test` under `npm run verify` validate runtime behavior after the rewrites.

## Migration Plan

1. Add `tsconfig.base.json` strictness flags; run `tsc --noEmit` per workspace and fix all fallout mechanically.
2. Add root ESLint flat config, Prettier config + ignore, `.editorconfig`; add `eslint-config-prettier`. Fix lint fallout.
3. Add `typecheck` / `lint` / `format:check` scripts to each `packages/*/package.json` and root aggregates; pin `engines` (Node floor) at root.
4. Add the root aggregate `verify` script chaining typecheck → lint → format-check → build → test, where the test stage runs the TS suites and the `tests/ai_scripts/*.sh` suites; coverage report-only.
5. Update **both** `AGENTS.md` and `CLAUDE.md` for the new tooling conventions and the mandatory `npm run verify` local gate (identical wording in both).
6. Verify: `npm run verify` green locally (which is the whole gate).

Rollback: the slice is additive config + mechanical edits; reverting the commit restores the prior (build-only) toolchain with no data or runtime impact.

## Open Questions

- None blocking. The exact ESLint plugin set beyond typescript-eslint's type-checked preset (e.g., an import-order plugin) is an implementation detail chosen during Migration Plan step 2, constrained to dev-dependencies and formatter-compatible rules.
