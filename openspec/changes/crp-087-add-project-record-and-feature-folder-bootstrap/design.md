## Context

`overmind/scripts/project_mgmt/project_setup_add_new_project.sh` currently initializes repo-level metadata in `overmind/init_progress_definition.yaml` and does not manage ASDLC-local project inventory under `asdlc/asdlc_metadata.yaml`. After first-machine bootstrap, users need a project-level flow that can register individual projects, create per-project folders in `asdlc/projects`, and seed each project folder with `init_progress_definition.yaml` from a local ASDLC template.

The requested change also introduces a dependency between first-machine bootstrap and add-project flow: machine bootstrap must prepare `asdlc/templates/init_progress_definition_TEMPLATE.yaml` so subsequent project creation can run fully from local ASDLC assets.

## Goals / Non-Goals

**Goals:**
- Extend add-project flow to append a new project record to top-level `projects` in `asdlc/asdlc_metadata.yaml`.
- Generate one project id per project creation and reuse that id in both metadata (`project`) and folder naming.
- Create a project workspace under `asdlc/projects/<project-id>` and seed `init_progress_definition.yaml` from local ASDLC template.
- Ensure first-machine bootstrap creates `asdlc/templates` and copies `init_progress_definition_TEMPLATE.yaml` there.
- Keep implementation shell-only and avoid new CLI flags/options.

**Non-Goals:**
- Redesign repo-level metadata semantics in `overmind/init_progress_definition.yaml`.
- Introduce external YAML tooling dependencies.
- Implement downstream lifecycle updates for fields like `name`, `internal_folder`, `created_at` beyond initial record creation.

## Decisions

1. Resolve ASDLC root from staged script location rather than adding new flags.
Rationale: staged commands live under `asdlc/.commands`, so script can derive ASDLC root (`..`) deterministically with no CLI/API changes.
Alternative considered: pass `--asdlc_root` or env-only contract. Rejected due explicit no-new-options constraint and weaker UX.

2. Use a single generated project id as the project identity source of truth.
Rationale: guarantees metadata record and folder naming remain linked and traceable.
Alternative considered: independent IDs for metadata and folder. Rejected due avoidable drift risk.

3. Store project folder name as `<normalized-project-name>-<epoch_milliseconds>`.
Rationale: human-readable + collision-resistant naming while preserving deterministic linkage to metadata.
Alternative considered: random-id-only folder names. Rejected due poor operator readability.

4. Update `asdlc_metadata.yaml` via controlled append logic with temporary file replacement.
Rationale: avoids external parsers while preserving stable file shape (`meta` and `projects` top-level).
Alternative considered: in-place line edits with `sed -i`. Rejected due portability and corruption risk.

5. Localize template artifact during first-machine bootstrap.
Rationale: add-project flow should not depend on repository `overmind/templates` path once running in ASDLC-local workspace.
Alternative considered: copy template lazily during add-project. Rejected because bootstrap is the canonical point for staging ASDLC-local command dependencies.

## Risks / Trade-offs

- [Risk] YAML append logic can corrupt metadata if unexpected file structure is present.
  Mitigation: validate required top-level keys before mutation, write through temp file, fail fast on malformed structure.

- [Risk] Project name normalization may produce empty or ambiguous slugs.
  Mitigation: require non-empty project name input and reject normalization outputs that collapse to empty.

- [Risk] Template copy drift between repo template and staged ASDLC template.
  Mitigation: always refresh template during first-machine bootstrap and add tests asserting copy location and project-seed behavior.

- [Risk] Git commit behavior in ASDLC bootstrap may fail on environments without identity config.
  Mitigation: keep existing warning-only commit behavior and ensure add-project flow does not depend on successful commit.

## Migration Plan

1. Update `project_setup_first_init_machine.sh` to create `asdlc/templates` and copy `init_progress_definition_TEMPLATE.yaml` into it.
2. Update `project_setup_add_new_project.sh` to:
   - resolve ASDLC-local paths,
   - prompt/normalize project name,
   - generate project id and created timestamp,
   - append project record to `asdlc/asdlc_metadata.yaml`,
   - create `asdlc/projects/<project-id>`,
   - copy template to `<project-folder>/init_progress_definition.yaml`.
3. Extend `tests/ai_scripts/project_setup_asdlc_tests.sh` for metadata record append, folder creation, template seed, and failure paths.
4. Run targeted script tests and verify change artifact readiness via OpenSpec status.

Rollback strategy: revert script changes to current add-project flow and remove ASDLC-local project record/folder seeding behavior.

## Open Questions

- Confirm required `created_at` format (`YYYY-MM-DDTHH:MM:SSZ` vs date-only) for project records.
