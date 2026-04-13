## Why

`overmind/scripts/project_mgmt/project_setup_add_new_project.sh` currently initializes repo metadata only and does not register individual ASDLC projects or create per-project work folders from a local ASDLC template. This blocks consistent project inventory and repeatable project workspace bootstrap under `asdlc/projects`.

## What Changes

- Enhance `project_setup_add_new_project.sh` to append a new project record under top-level `projects` in ASDLC metadata.
- New record shape SHALL be:
  - `project: <project_id>`
  - `name:`
  - `internal_folder:`
  - `created_at:`
- Generate one project id per added project and reuse the same id in both metadata record and project workspace naming.
- Create a new folder under `asdlc/projects` named as `<normalized-project-name>-<epoch_milliseconds>`.
- Create `init_progress_definition.yaml` inside the new project folder from `init_progress_definition_TEMPLATE.yaml`.
- Ensure template source is staged into `asdlc/templates/init_progress_definition_TEMPLATE.yaml` during machine bootstrap so add-project flow uses local ASDLC templates.

## Capabilities

### New Capabilities
- `overmind-asdlc-project-record-registration`: Register each new project as a structured entry in ASDLC metadata with project-id-backed identity and project fields.
- `overmind-asdlc-project-workspace-bootstrap`: Create per-project workspace folder under `asdlc/projects` and seed `init_progress_definition.yaml` from local ASDLC template.
- `overmind-asdlc-template-localization`: Ensure ASDLC machine bootstrap provides local `asdlc/templates/init_progress_definition_TEMPLATE.yaml` for downstream project creation.

### Modified Capabilities
- None.

## Impact

- Affected scripts:
  - `overmind/scripts/project_mgmt/project_setup_add_new_project.sh`
  - `overmind/scripts/project_mgmt/project_setup_first_init_machine.sh` (template localization into `asdlc/templates`)
- Affected runtime layout:
  - `asdlc/asdlc_metadata.yaml` (`projects` list entries)
  - `asdlc/templates/init_progress_definition_TEMPLATE.yaml`
  - `asdlc/projects/<project-id>/init_progress_definition.yaml`
- Affected tests:
  - `tests/ai_scripts/project_setup_asdlc_tests.sh`
- No new CLI flags/options are introduced.
