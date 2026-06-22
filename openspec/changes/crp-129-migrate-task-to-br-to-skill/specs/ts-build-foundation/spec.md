## ADDED Requirements

### Requirement: TypeScript npm-workspaces monorepo

The repository SHALL provide a single npm-workspaces monorepo whose root `package.json` declares workspaces for `packages/asdlc-coordinator`, `packages/installer`, and `packages/vscode-extension`, plus a top-level `skills/` directory holding canonical skill sources. TypeScript SHALL be the implementation language; no new `.sh` files SHALL be introduced.

#### Scenario: Install resolves the workspace graph

- **WHEN** a developer runs `npm install` at the repository root
- **THEN** all workspace packages are linked locally and `packages/installer` and `packages/vscode-extension` can import `asdlc-coordinator` as an in-repo dependency without it being published to a registry

#### Scenario: No bash is added by the foundation

- **WHEN** the foundation is created
- **THEN** every new source file is `.ts` or `.md` (with `.yaml`/`.json` permitted for data/config) and no new `.sh` file exists under `packages/` or `skills/`

### Requirement: asdlc-coordinator package layout

The `asdlc-coordinator` package SHALL expose `parse/`, `validate/`, `readiness/`, and `types/` modules and a `bin/overmind-gate` executable entrypoint.

#### Scenario: Package surface is present

- **WHEN** the `asdlc-coordinator` package is built
- **THEN** the `parse/`, `validate/`, `readiness/`, and `types/` modules resolve and the `overmind-gate` binary is runnable

### Requirement: TypeScript test runner

The monorepo SHALL provide a single test command at the repository root that executes the TypeScript test suites across packages.

#### Scenario: Root test command runs the suites

- **WHEN** a developer runs the repository-root test command
- **THEN** the TypeScript tests for `asdlc-coordinator` (including the `task-to-br` validator tests) execute and report pass/fail

### Requirement: Self-contained shipped artifacts

Shipped artifacts SHALL bundle `asdlc-coordinator` so they run without relying on a workspace symlink or `node_modules` resolution at runtime.

#### Scenario: Gate CLI bundle is standalone

- **WHEN** the build produces the installable `overmind-gate.js`
- **THEN** `asdlc-coordinator` code is bundled into that single file and it executes on plain Node without a separate dependency install

### Requirement: Minimal project install (`overmind init`)

The `installer` package SHALL provide a minimal `overmind init` that installs the bundled gate to `<project>/.overmind/overmind-gate.js` and installs a skill into `<project>/.claude/skills/<skill>/`. This is the mechanism by which skills and the gate reach a runtime project. Broader fan-out to `.codex/.github/.agents` and update/version handling are out of scope for this change.

#### Scenario: init provisions the gate and the skill

- **WHEN** `overmind init` runs in a project
- **THEN** `<project>/.overmind/overmind-gate.js` exists, `<project>/.claude/skills/overmind-task-to-br/SKILL.md` exists, and the skill can invoke the gate at `.overmind/overmind-gate.js`
