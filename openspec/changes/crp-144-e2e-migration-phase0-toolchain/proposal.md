## Why

The E2E orchestrator migration (`design_docs/e2e_orchestrator_migration/`) lands prod-level TypeScript orchestrator code across five subsequent slices, but the repo has no linting, no formatter, and only build-time typechecking — the already-migrated 13-step coordinator/installer code is currently unlinted and only typechecked via `build`. Lint/strictness debt compounds per slice, and the full verification suite must be able to gate Slice 1 already, so the toolchain baseline is deliberately first (`04_migration_plan.md ## Slice 0 — Toolchain baseline`, contract in `03_target_architecture.md ## Engineering baseline`). This is pure infrastructure plus mechanical fixes — no behavior changes.

Enforcement is **local and agent-driven, not remote CI**: the two agents that make changes in this repo (Claude via `CLAUDE.md`, Codex via `AGENTS.md`) run the full suite themselves before a change is complete. This change also revises the design docs to match (see Impact) — the earlier "GitHub Actions required for merge" line is replaced in the same change, not deferred.

## What Changes

- Add **ESLint flat config** using typescript-eslint's type-checked presets, **Prettier** as the sole formatter (conflicting stylistic lint rules disabled), and `.editorconfig` at the repo root, wired into every workspace. ESLint is chosen over Biome specifically for type-aware rules (`no-floating-promises` and friends catch the async/spawn/fs mistakes an orchestrator produces).
- Add **strictness options** to `tsconfig.base.json` (already `strict: true`): `noUncheckedIndexedAccess`, `noImplicitOverride`, `noFallthroughCasesInSwitch`, `verbatimModuleSyntax`. **All existing-code fallout is fixed mechanically in the same change** (applies to `asdlc-coordinator`, `installer`, `vscode-extension`).
- Add **scripts per workspace + root aggregate**: `typecheck` (`tsc --noEmit`, test files included, independent of the build), `lint`, and `format:check`.
- Add a **single aggregate `npm run verify` command** at the root that runs, in order, typecheck → lint → format-check → build → test, covering the TS workspaces **and** the surviving `tests/ai_scripts/*.sh` suites during the transition. **Enforcement is local and agent-driven:** both `AGENTS.md` (Codex) and `CLAUDE.md` (Claude) mandate running `npm run verify` and confirming it green before treating any change as complete. `engines` pins the Node floor. Coverage is report-only (via `node --test` native coverage); no threshold gate yet. **No remote CI workflow and no git hooks.**
- Update `CLAUDE.md` where the toolchain change affects documented conventions (the repo is no longer bash-only for tooling).
- **No new runtime dependencies:** `asdlc-coordinator`'s `dependencies` list stays **empty** (zero-runtime-dependency rule); all additions are dev-dependencies.

## Capabilities

### New Capabilities
- `engineering-baseline`: the prod-level TypeScript toolchain contract — type-aware ESLint flat config, Prettier + `.editorconfig`, the `tsconfig.base.json` strictness additions, the per-workspace + root `typecheck`/`lint`/`format:check` scripts, the local agent-driven enforcement model (aggregate `npm run verify`, mandated in both `AGENTS.md` and `CLAUDE.md`, Node floor pin, report-only coverage, no remote CI, no git hooks), and the zero-runtime-dependency guarantee.

### Modified Capabilities
<!-- None — openspec/specs/ is empty; there are no existing published specs whose requirements change. The prior ts-build-foundation capability (crp-129) is not modified: this change adds a distinct baseline capability rather than altering the monorepo/build contract. -->

## Impact

- **New:** root ESLint flat config, Prettier config + ignore, `.editorconfig`.
- **Modified:** `tsconfig.base.json` (strictness flags); root and each `packages/*/package.json` (`typecheck`/`lint`/`format:check` scripts, root aggregate `verify`, root `engines`, dev-dependencies); **both** `AGENTS.md` (Codex) and `CLAUDE.md` (Claude) — the tooling conventions and the mandatory `npm run verify` local gate.
- **Design docs updated in this change:** `03_target_architecture.md ## Engineering baseline` and `04_migration_plan.md ## Slice 0 — Toolchain baseline` previously specified a GitHub Actions workflow "required for merge." This change replaces that wording with the local agent-driven `npm run verify` model in the same change, so the source-of-truth design and this CRP stay consistent.
- **Mechanical code fixes:** any existing `.ts` under `packages/*/{src,test}` that the new strictness/lint rules flag — corrected in place with no behavior change.
- **Dependencies:** new **dev**-dependencies only (eslint, typescript-eslint, prettier, eslint-config-prettier, and any plugins); runtime `dependencies` unchanged (coordinator stays empty).
- **Out of scope:** any orchestrator/scanner/runner code (Slices 1–5), coverage-threshold gating, remote CI, git hooks, and any change to skill bodies, gates, or artifact formats.
