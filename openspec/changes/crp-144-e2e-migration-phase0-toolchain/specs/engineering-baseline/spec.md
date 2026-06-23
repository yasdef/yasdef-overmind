## ADDED Requirements

### Requirement: Type-aware ESLint flat config

The repository SHALL provide a single ESLint flat config at the repository root using typescript-eslint's type-checked presets, wired into every workspace so that all `.ts` sources under `packages/*/{src,test}` are linted with type-aware rules. The config SHALL enable the type-aware rules that catch orchestrator-class mistakes (at minimum `no-floating-promises`). Stylistic rules that conflict with the formatter SHALL be disabled (via `eslint-config-prettier`) so that linting and formatting never disagree.

#### Scenario: Lint runs type-aware across all workspaces

- **WHEN** a developer runs the root `lint` script
- **THEN** ESLint uses the flat config with type information for `asdlc-coordinator`, `installer`, and `vscode-extension` sources and tests, and reports pass/fail

#### Scenario: Floating promise is flagged

- **WHEN** a `.ts` source introduces an unawaited promise that `no-floating-promises` covers
- **THEN** `lint` reports an error rather than passing silently

#### Scenario: Formatter and linter do not conflict

- **WHEN** a file is formatted by Prettier and then linted
- **THEN** ESLint reports no stylistic conflicts, because formatter-conflicting rules are disabled

### Requirement: Prettier formatting and editorconfig

Prettier SHALL be the sole code formatter for the repository, configured at the root and accompanied by a `.editorconfig` file. A `format:check` capability SHALL verify formatting without writing changes.

#### Scenario: Format check detects unformatted code

- **WHEN** a developer runs the root `format:check` script against code that violates Prettier's formatting
- **THEN** the command exits non-zero and names the offending files without modifying them

#### Scenario: Editorconfig present at root

- **WHEN** the baseline is in place
- **THEN** a `.editorconfig` file exists at the repository root

### Requirement: TypeScript strictness additions

The shared `tsconfig.base.json` SHALL remain `strict: true` and SHALL additionally enable `noUncheckedIndexedAccess`, `noImplicitOverride`, `noFallthroughCasesInSwitch`, and `verbatimModuleSyntax`. All existing-code fallout from these options SHALL be fixed mechanically within this change with no behavior change; the repository SHALL typecheck clean under the added options.

#### Scenario: Base config declares the added strictness options

- **WHEN** `tsconfig.base.json` is inspected
- **THEN** it sets `strict: true` plus `noUncheckedIndexedAccess`, `noImplicitOverride`, `noFallthroughCasesInSwitch`, and `verbatimModuleSyntax`

#### Scenario: Existing code typechecks clean under the new options

- **WHEN** `typecheck` runs across all workspaces after the strictness options are added
- **THEN** it reports zero errors, all pre-existing fallout having been fixed in this change

### Requirement: Per-workspace and root quality scripts

Each workspace and the repository root SHALL provide `typecheck`, `lint`, and `format:check` scripts. The `typecheck` script SHALL run `tsc --noEmit` with test files included and SHALL be independent of the build. The root scripts SHALL aggregate the workspace scripts.

#### Scenario: Typecheck is build-independent and includes tests

- **WHEN** a developer runs a workspace `typecheck` script
- **THEN** it runs `tsc --noEmit` over both `src` and `test` files and produces no build output

#### Scenario: Root aggregates workspace scripts

- **WHEN** a developer runs the root `typecheck`, `lint`, or `format:check` script
- **THEN** the corresponding check runs across every workspace and a single pass/fail result is reported

### Requirement: Local full-suite verification gate

Enforcement SHALL be local and agent-driven, not remote CI. The repository root SHALL provide a single aggregate command `npm run verify` that runs, in order, typecheck → lint → format-check → build → test. The test stage SHALL run the TypeScript workspace suites AND the surviving `tests/ai_scripts/*.sh` suites; the command SHALL fail if any stage fails. The command SHALL report coverage without gating on a threshold. Both agent instruction files — `AGENTS.md` (Codex) and `CLAUDE.md` (Claude) — SHALL mandate running `npm run verify` and confirming it green before a change is treated as complete. The change SHALL NOT add a remote CI workflow and SHALL NOT add git hooks.

#### Scenario: verify runs all stages in order

- **WHEN** a developer or agent runs `npm run verify`
- **THEN** it runs typecheck, then lint, format-check, build, and test in that order, exiting non-zero if any stage fails

#### Scenario: Shell suites run alongside TS tests

- **WHEN** the `verify` test stage runs
- **THEN** it executes the TypeScript workspace test suites and the `tests/ai_scripts/*.sh` suites, and both must pass

#### Scenario: Both agents mandate the gate

- **WHEN** `AGENTS.md` and `CLAUDE.md` are inspected
- **THEN** each instructs its agent to run `npm run verify` and confirm it green before treating a change as complete

#### Scenario: Coverage is report-only

- **WHEN** `verify` produces a coverage report
- **THEN** the command is not failed on any coverage threshold

#### Scenario: No remote CI or git hooks are added

- **WHEN** the change is inspected
- **THEN** no remote CI workflow (e.g., `.github/workflows/*.yml`) and no git hook (e.g., husky, pre-commit, `.git/hooks` wiring) is introduced; enforcement lives only in the agent-run local `verify` command

### Requirement: Tests use Node's built-in runner

Tests SHALL run on Node's built-in test runner (`node --test`); no third-party test framework (e.g., Vitest, Jest, Mocha) SHALL be introduced as a dependency. Coverage SHALL be produced via the runner's native coverage. This preserves the no-test-framework-dependency posture of `03_target_architecture.md ## Engineering baseline`.

#### Scenario: No test-framework dependency is added

- **WHEN** the repository's dev-dependencies are inspected after this change
- **THEN** no third-party test framework is present and the workspace `test` scripts invoke `node --test`

### Requirement: Node engine floor pinned

The root `package.json` SHALL declare an `engines.node` field pinning the minimum supported Node version, so the toolchain runs on a known Node floor for every developer and agent.

#### Scenario: Root package pins the Node floor

- **WHEN** the root `package.json` is inspected after this change
- **THEN** it contains an `engines.node` field specifying the minimum Node version

### Requirement: Zero runtime dependencies preserved

All toolchain additions SHALL be dev-dependencies. The `asdlc-coordinator` package's runtime `dependencies` list SHALL remain empty so the bundled `overmind.js` stays a single file with no runtime `node_modules`.

#### Scenario: Coordinator runtime dependencies stay empty

- **WHEN** `packages/asdlc-coordinator/package.json` is inspected after this change
- **THEN** its `dependencies` object is empty and every new tool (eslint, typescript-eslint, prettier, eslint-config-prettier, and any plugins) appears only under dev-dependencies
