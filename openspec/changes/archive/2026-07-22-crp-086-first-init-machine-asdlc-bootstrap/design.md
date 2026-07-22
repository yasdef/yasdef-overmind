## Context

`project_setup_first_init_machine.sh` is currently a placeholder, so the machine-level ASDLC workspace bootstrap does not exist. Users can select option `1` in dispatcher flow, but there is no automated creation of ASDLC home layout, metadata scaffold, local staged commands, or quick-run instructions.

The requested behavior introduces a deterministic machine bootstrap layer that:
- provisions an `asdlc` workspace under a user-selected parent directory,
- prepares minimal metadata placeholders for later project onboarding,
- stages copy-based command wrappers under `.commands`,
- and standardizes default project folder targeting to `asdlc/projects`.

## Goals / Non-Goals

**Goals:**
- Implement interactive first-machine bootstrap in `project_setup_first_init_machine.sh`.
- Validate user-provided target path before filesystem mutations.
- Fail fast when target `asdlc` workspace already exists.
- Create canonical structure: `asdlc/`, `asdlc/projects/`, `asdlc/.commands/`.
- Create simple metadata YAML scaffold with required future fields.
- Copy add/update project scripts into `.commands` and configure default project folder to `asdlc/projects`.
- Create `asdlc/quickrun.md` documenting fast command usage.

**Non-Goals:**
- Implement full project record lifecycle in metadata YAML.
- Add new CLI flags/options for project setup scripts.
- Change core behavior of source scripts in `overmind/scripts/project_mgmt/` beyond what is required for staged-copy default-path support.

## Decisions

1. Keep source scripts canonical; configure behavior in staged copies.
Rationale: preserves repository-owned script behavior while enabling machine-local defaults in generated `.commands`.
Alternative considered: hardcode `asdlc/projects` in source scripts. Rejected because it couples repo scripts to local machine bootstrap output.

2. Use fail-fast semantics for existing `asdlc` root.
Rationale: avoids clobbering existing local workspace and keeps bootstrap idempotency explicit.
Alternative considered: merge/update existing workspace. Rejected due ambiguity and risk of unintended overwrites.

3. Use a simple metadata YAML scaffold with placeholder values.
Rationale: user requested storing metainfo later, so bootstrap should create a minimal structured container without enforcing full lifecycle logic yet.
Alternative considered: generate project identifiers and prompt for initial project data immediately. Rejected to keep first-init narrowly scoped.

4. Generate `quickrun.md` as local runbook.
Rationale: improves discoverability and ensures staged command entrypoints are executable without searching repository docs.
Alternative considered: document only in repo README. Rejected because quickrun should live next to machine-local staged commands.

## Risks / Trade-offs

- [Risk] Path validation may be inconsistent across macOS/Linux shells.
  Mitigation: use portable shell checks (`-d`, `mkdir -p`, write test in target) and explicit error messages.

- [Risk] Copy-time script rewriting could drift if source script structure changes.
  Mitigation: define a stable placeholder/config line in source scripts for default project folder and patch only that value in staged copies.

- [Risk] Users may run source scripts instead of staged `.commands` copies.
  Mitigation: quickrun explicitly points to staged command paths and explains intended usage.

- [Risk] Existing workflows may expect option `1` placeholder behavior.
  Mitigation: add regression tests for dispatcher option routing and new option `1` behavior.

## Migration Plan

1. Implement `project_setup_first_init_machine.sh` with path prompt/validation, fail-fast checks, directory/materialization logic, staged-copy generation, and quickrun generation.
2. Ensure add/update source scripts can accept a default project root configuration field that staged copies can set to `asdlc/projects`.
3. Update tests to cover:
   - valid bootstrap creation path
   - existing `asdlc` fail-fast behavior
   - staged command copy presence and executable mode
   - default projects-folder configuration in staged copies
   - quickrun content for create/update commands
4. Update `overmind/README.md` for first-machine bootstrap expectations and staged command usage.

Rollback strategy: restore option `1` placeholder script and remove bootstrap-specific staging logic.

## Open Questions

- Metadata YAML filename is not explicitly named yet; implementation should choose a stable name (for example `asdlc/meta.yaml`) and document it.
