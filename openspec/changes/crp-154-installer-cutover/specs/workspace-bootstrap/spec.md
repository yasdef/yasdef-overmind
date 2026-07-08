## ADDED Requirements

### Requirement: `overmind init` bootstraps a complete fresh ASDLC workspace

`overmind init` (the `packages/installer` bin, `installProject`) SHALL bootstrap a complete fresh ASDLC workspace in a single deterministic pass, installing the runtime CLI, every packaged skill for every supported runner, the runtime templates deterministic creation needs, the `.setup` defaults, the `asdlc_metadata.yaml` registry scaffold, the `projects/` directory, and generated `quickrun.md` operator guidance. Bootstrap is a fresh-install boundary only: because Overmind has never been deployed, there SHALL be no upgrade/update mode, no injected `ASDLC_PROJECTS_DIR_DEFAULT` command rewrite, no obsolete-staged-command cleanup, and no `.commands`, `.helper`, `.rules`, or `.golden_examples` staging.

#### Scenario: Fresh install produces the full workspace

- **WHEN** an operator runs `overmind init` in an empty target directory
- **THEN** the workspace contains the executable CLI at `.overmind/overmind.js`, every packaged skill under `.codex/skills/<skill>` and `.claude/skills/<skill>`, `.templates/init_progress_definition_TEMPLATE.yaml`, `.templates/feature_br_summary_TEMPLATE.md`, `.setup/models.md`, `.setup/external_sources.yaml`, an `asdlc_metadata.yaml` registry scaffold, a `projects/` directory, and a generated `quickrun.md`

#### Scenario: No update-mode or shell-staging artifacts are produced

- **WHEN** a workspace is bootstrapped
- **THEN** no `.commands/`, `.helper/`, `.rules/`, or `.golden_examples/` directory is created, no staged file has an injected `ASDLC_PROJECTS_DIR_DEFAULT` block, and no obsolete-command cleanup runs

### Requirement: Runtime templates and setup defaults are installed from an installer-owned payload

The installer SHALL own its support-asset payload under `packages/installer/_data/` and install exactly the runtime templates deterministic creation consumes — `init_progress_definition_TEMPLATE.yaml` (used by `capture/project.ts` for `overmind project create`) and `feature_br_summary_TEMPLATE.md` (used by `capture/scaffold-feature.ts`) — into the workspace `.templates/` directory, and the setup defaults `models.md` and `external_sources.yaml` into `.setup/`. `.setup/models.md` and `.setup/external_sources.yaml` SHALL be preserved when they already exist in the target workspace; runtime templates SHALL be installed from the packaged source.

#### Scenario: Runtime templates land where deterministic creation reads them

- **WHEN** `overmind init` completes
- **THEN** `.templates/init_progress_definition_TEMPLATE.yaml` and `.templates/feature_br_summary_TEMPLATE.md` exist with the byte content of the packaged installer payload, so `overmind project create` and `overmind scaffold feature` resolve their default templates without further staging

#### Scenario: Existing setup defaults are preserved

- **WHEN** a target workspace already contains `.setup/models.md` or `.setup/external_sources.yaml`
- **THEN** `overmind init` leaves those files unchanged rather than overwriting operator configuration

### Requirement: Required source validation precedes any workspace write

Before writing any workspace file, the installer SHALL validate that every required source in its payload exists — the bundled CLI, every packaged skill's `SKILL.md` (and `assets/` unless the skill is intentionally assetless), each runtime template, and each setup default — and SHALL fail with a clear error identifying the first missing source, performing no partial installation.

#### Scenario: Missing packaged source fails fast

- **WHEN** a required packaged skill, runtime template, or setup default is missing from the installer payload
- **THEN** `overmind init` exits non-zero with an error naming the missing source and writes no workspace files

#### Scenario: Complete payload validates and installs

- **WHEN** the installer payload is complete
- **THEN** validation passes and the full workspace is installed

### Requirement: Skills are installed byte-for-byte across every supported runner

The installer SHALL install every packaged skill into each supported runner skill directory (`.codex/skills/` and `.claude/skills/`) as a byte-for-byte copy of the canonical source, refreshing the target so no stale file survives a reinstall.

#### Scenario: Skill fan-out matches the canonical payload

- **WHEN** `overmind init` completes
- **THEN** for every packaged skill and every supported runner, `<runner>/skills/<skill>` contains a byte-for-byte copy of the packaged skill's `SKILL.md` and assets

### Requirement: Generated operator guidance is TypeScript-generated and shell-free

The installer SHALL generate `quickrun.md` in TypeScript (no shell heredoc) and the returned `InstallResult` SHALL report the bootstrapped workspace, including the CLI path, installed skill paths, installed runtime-template and setup-default paths, and the generated guidance path. The generated guidance and the install CLI output SHALL name only TypeScript/npm commands (`node .overmind/overmind.js ...`) and SHALL NOT reference any `.sh` script.

#### Scenario: Quick-run guidance names only TypeScript commands

- **WHEN** the generated `quickrun.md` is inspected
- **THEN** it describes the workspace layout and the `node .overmind/overmind.js` verbs (project create/reconcile/init, worker register/assign, run, scaffold, status, context/gate) and contains no `.sh` invocation

#### Scenario: Install result reports the bootstrapped workspace

- **WHEN** `installProject` returns
- **THEN** the result carries the CLI path, the installed skill paths, the installed runtime-template and setup-default paths, and the generated `quickrun.md` path, and the install bin renders its success output from that result
