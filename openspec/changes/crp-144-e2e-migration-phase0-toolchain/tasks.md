## 1. TypeScript strictness

- [ ] 1.1 Add `noUncheckedIndexedAccess`, `noImplicitOverride`, `noFallthroughCasesInSwitch`, and `verbatimModuleSyntax` to `tsconfig.base.json` (keep `strict: true`)
- [ ] 1.2 Run `tsc --noEmit` per workspace (`asdlc-coordinator`, `installer`, `vscode-extension`) and enumerate the fallout
- [ ] 1.3 Fix all strictness fallout mechanically (index guards, `import type` for `verbatimModuleSyntax`, switch fallthrough, `override`) with no behavior change
- [ ] 1.4 Confirm `tsc --noEmit` is clean across all workspaces (src + test)

## 2. Formatting (Prettier + editorconfig)

- [ ] 2.1 Add Prettier as a root dev-dependency with a root Prettier config and ignore file
- [ ] 2.2 Add `.editorconfig` at the repository root
- [ ] 2.3 Run Prettier once to normalize existing files (formatting-only, no behavior change)

## 3. Linting (type-aware ESLint flat config)

- [ ] 3.1 Add eslint, typescript-eslint, and `eslint-config-prettier` as root dev-dependencies
- [ ] 3.2 Create the root ESLint flat config with typescript-eslint type-checked presets, pointing the TS parser at the workspace tsconfigs so `src` + `test` are type-aware
- [ ] 3.3 Enable the key type-aware rules (at minimum `no-floating-promises`) and disable formatter-conflicting rules via `eslint-config-prettier`
- [ ] 3.4 Run lint across all workspaces and fix fallout mechanically (no behavior change)

## 4. Scripts (per-workspace + root aggregate)

- [ ] 4.1 Add `typecheck` (`tsc --noEmit`, tests included, build-independent), `lint`, and `format:check` scripts to each `packages/*/package.json`
- [ ] 4.2 Add root aggregate `typecheck`, `lint`, and `format:check` scripts that fan out across workspaces
- [ ] 4.3 Add an `engines` field pinning the Node floor to the root `package.json`

## 5. Local verification gate (`npm run verify`)

- [ ] 5.1 Add a root `verify` script chaining, in order, typecheck → lint → format-check → build → test
- [ ] 5.2 Make the test stage run the TS workspace suites AND the `tests/ai_scripts/*.sh` suites; ensure `verify` exits non-zero if any stage fails
- [ ] 5.3 Emit `node --test` coverage as report-only (no threshold gate)
- [ ] 5.4 Confirm no remote CI workflow (`.github/workflows/*`) and no git hooks are introduced

## 6. Agent mandates & verification

- [ ] 6.1 Update `AGENTS.md` (Codex): add the TS tooling conventions and mandate running `npm run verify` (and confirming it green) before completing a change; keep the shell-suite guidance
- [ ] 6.2 Update `CLAUDE.md` (Claude): add the same TS tooling conventions and the identical `npm run verify` mandate
- [ ] 6.3 Verify `asdlc-coordinator`'s runtime `dependencies` is still empty and all new tools are dev-dependencies only
- [ ] 6.4 Run `npm run verify` locally and confirm the full suite (TS + shell) is green
