## MODIFIED Requirements

### Requirement: `overmind init` bootstraps a complete fresh ASDLC workspace

`overmind init` (the `packages/installer` bin, `installProject`) SHALL bootstrap a complete ASDLC workspace in a single deterministic pass against the operator-resolved target directory, installing the runtime CLI, every packaged skill for every supported runner, the runtime templates deterministic creation needs, the `.setup` defaults, the `asdlc_metadata.yaml` registry scaffold, the `projects/` directory, and generated `quickrun.md` operator guidance. The install pass SHALL NOT produce any retired shell staging: no injected `ASDLC_PROJECTS_DIR_DEFAULT` command rewrite, no obsolete-staged-command cleanup, and no `.commands`, `.helper`, `.rules`, or `.golden_examples` staging.

#### Scenario: Fresh install produces the full workspace

- **WHEN** an operator runs `overmind init` and resolves the prompt to an empty target directory
- **THEN** the workspace contains the executable CLI at `.overmind/overmind.js`, every packaged skill under `.codex/skills/<skill>` and `.claude/skills/<skill>`, `.templates/init_progress_definition_TEMPLATE.yaml`, `.templates/feature_br_summary_TEMPLATE.md`, `.setup/models.md`, `.setup/external_sources.yaml`, an `asdlc_metadata.yaml` registry scaffold, a `projects/` directory, and a generated `quickrun.md`

#### Scenario: No shell-staging artifacts are produced

- **WHEN** a workspace is bootstrapped or updated
- **THEN** no `.commands/`, `.helper/`, `.rules/`, or `.golden_examples/` directory is created, no staged file has an injected `ASDLC_PROJECTS_DIR_DEFAULT` block, and no obsolete-command cleanup runs

## ADDED Requirements

### Requirement: The install target is resolved interactively from the operator with no cwd fallback

The `overmind init` bin SHALL ask the operator for the ASDLC workspace target path on stdin before any filesystem read or write of a target. The answer SHALL be resolved to an absolute path (a leading `~` expands to the operator home directory; a relative path resolves against the invoking working directory). The bin SHALL NOT treat the current working directory as an implicit target: blank input or closed stdin SHALL end the run with no directory created and no file written, and no CLI flag or argument SHALL bypass the prompt.

#### Scenario: Operator-entered path is the install target

- **WHEN** the operator answers the prompt with a path
- **THEN** the install runs against that resolved absolute path regardless of the directory `overmind init` was invoked from

#### Scenario: Blank or closed input installs nothing

- **WHEN** the operator answers the prompt with blank input or stdin closes without an answer
- **THEN** `overmind init` exits without creating any directory or writing any file, and reports that no target was selected

#### Scenario: `npm run setup` never implicitly targets the source repo

- **WHEN** `npm run setup` is run from the `yasdef-overmind` checkout and the operator answers the prompt with a workspace path outside the checkout
- **THEN** the workspace is bootstrapped at the answered path and no workspace file is created inside the source checkout

### Requirement: The resolved target is classified as clean install, update, or refusal

The installer SHALL branch deterministically on the resolved target before writing: a path that does not exist, or an existing empty directory, SHALL take the clean-install branch (creating the directory when missing); an existing directory containing `asdlc_metadata.yaml` SHALL take the update branch; an existing non-empty directory without `asdlc_metadata.yaml` SHALL be refused with a blocking error (exit `2`) naming the target, with no file written. A target path that exists but is not a directory SHALL also be refused with a blocking error and no write. The classification logic SHALL be exported deterministic TypeScript testable without stdin.

#### Scenario: Missing target directory is created and cleanly installed

- **WHEN** the operator resolves the prompt to a path that does not exist
- **THEN** the directory is created and the full fresh workspace is installed into it

#### Scenario: Existing workspace takes the update branch

- **WHEN** the resolved target directory contains `asdlc_metadata.yaml`
- **THEN** the install pass runs as an update against that workspace and exits `0`

#### Scenario: Non-empty non-workspace target is refused

- **WHEN** the resolved target is an existing non-empty directory without `asdlc_metadata.yaml`
- **THEN** `overmind init` exits `2` with an error naming the target and writes nothing into it

### Requirement: The update branch keeps the existing per-asset semantics

Updating an existing workspace SHALL keep the per-asset semantics the installer already has, unchanged: package-owned payload is refreshed (`.overmind/overmind.js`, every packaged skill replaced byte-for-byte with no stale file surviving, `.templates/*`, `quickrun.md`), and operator-owned content is preserved (`asdlc_metadata.yaml`, `.setup/models.md`, `.setup/external_sources.yaml`, everything under `projects/`).

#### Scenario: Update refreshes package payload and preserves operator data

- **WHEN** `overmind init` updates a workspace that has modified `.setup/models.md`, a populated `asdlc_metadata.yaml`, project folders under `projects/`, and a stale extra file inside an installed skill folder
- **THEN** the CLI, skills, runtime templates, and `quickrun.md` match the current packaged payload, the stale skill file is gone, and `asdlc_metadata.yaml`, `.setup/models.md`, `.setup/external_sources.yaml`, and the `projects/` content are byte-identical to before the update
