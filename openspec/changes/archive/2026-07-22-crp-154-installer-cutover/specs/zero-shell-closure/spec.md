## ADDED Requirements

### Requirement: The last shell files are removed

The repository SHALL NOT contain `overmind/scripts/project_mgmt/project_setup_first_init_machine.sh` or `tests/ai_scripts/project_setup_asdlc_tests.sh`. Their responsibilities are owned by `packages/installer` (fresh-workspace bootstrap) and the installer's TypeScript tests respectively. The now-empty `tests/ai_scripts/` directory SHALL be removed.

#### Scenario: First-init machine and its shell suite are gone

- **WHEN** the versioned tree is inspected
- **THEN** `overmind/scripts/project_mgmt/project_setup_first_init_machine.sh` and `tests/ai_scripts/project_setup_asdlc_tests.sh` do not exist, and `tests/ai_scripts/` is absent

### Requirement: Shell test wiring is removed from the build

Root `package.json` SHALL NOT define a `test:shell` script or iterate `tests/ai_scripts/*.sh`. The `test` script SHALL run only the TypeScript suite (`test:ts`), and `npm run verify` SHALL compose typecheck, lint, format check, build, and the TypeScript test suite with no shell-suite step.

#### Scenario: No shell test step remains

- **WHEN** root `package.json` scripts are inspected
- **THEN** there is no `test:shell` script, `test` delegates to `test:ts`, and no script shells out to `tests/ai_scripts`

#### Scenario: Verify runs green without shell suites

- **WHEN** `npm run verify` is run after this change
- **THEN** it runs typecheck, lint, format check, build, and the TypeScript tests to completion and passes, with no shell suite iterated

### Requirement: Source-repo bootstrap runs through the installer

Root `package.json` SHALL provide a setup invocation that bootstraps the ASDLC workspace through the installer bin (for example `node packages/installer/dist/src/bin/overmind.js init`) rather than a shell script, and `README.md`, `QUICKRUN.md`, and `AGENTS.md` SHALL describe workspace setup and test execution with TypeScript/npm commands only, containing no active `.sh` invocation or `bash tests/ai_scripts/...` command.

#### Scenario: Setup script invokes the installer

- **WHEN** an operator runs the root setup script
- **THEN** the installer bin runs and bootstraps the workspace, and no `.sh` script is invoked

#### Scenario: Docs carry no shell invocation

- **WHEN** `README.md`, `QUICKRUN.md`, and `AGENTS.md` are inspected
- **THEN** workspace setup and test commands are TypeScript/npm only, with no `overmind/scripts/...sh` invocation and no `bash tests/ai_scripts/...` list

### Requirement: A single end-state assertion guarantees zero shell

An installer-package test SHALL assert the repository-wide zero-shell end state over versioned files and packaged assets: when run inside a Git checkout no versioned file has a `.sh` filename, first-party source/test directories contain no `.sh` file when dependency and build output directories are pruned, and the packaged installer payload contains no `.sh` file. The first-party and packaged-payload scans SHALL be implemented without relying on platform-specific external `find` behavior. This single assertion replaces the transitional shell-inventory guard entirely; there SHALL be no maintained allow-list of permitted shell files.

#### Scenario: Zero-shell assertion holds

- **WHEN** the end-state assertion runs
- **THEN** inside a Git checkout `git ls-files '*.sh'` returns no path, a Node-based first-party filesystem scan of `packages`, `overmind`, and `tests` with `node_modules` and `dist` pruned returns no `.sh` path, and the packaged installer payload under `packages/installer/_data/` contains no `.sh` file

#### Scenario: A reintroduced shell file fails the assertion

- **WHEN** any `.sh` file is added to the versioned tree or the packaged payload
- **THEN** the end-state assertion fails
