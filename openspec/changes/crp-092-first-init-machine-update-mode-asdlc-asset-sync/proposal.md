## Why

`overmind/scripts/project_mgmt/project_setup_first_init_machine.sh` update mode currently repairs only missing staged command scripts under `asdlc/.commands/`. That leaves existing ASDLC homes without local copies of repo-owned rules, templates, golden examples, and helper scripts, so update mode does not produce a fully consistent machine-local Overmind environment.

## What Changes

- Extend first-init-machine staging so repo-owned support assets are copied into local ASDLC directories:
  - `asdlc/.rules/` from `overmind/rules/`
  - `asdlc/.templates/` from `overmind/templates/`
  - `asdlc/.golden_examples/` from `overmind/golden_examples/`
  - `asdlc/.helper/` from `overmind/scripts/helper/`
  - `asdlc/.setup/` from `overmind/setup/`
- Change update mode so it synchronizes those staged support-asset directories to the current repository contents instead of only checking `.commands` for missing files.
- Preserve the existing `asdlc/templates/init_progress_definition_TEMPLATE.yaml` compatibility path used by current add-project flow, while keeping it aligned with the canonical template source.
- Keep `.commands` repair behavior narrowly scoped unless a staged command is missing; do not introduce new CLI flags/options.
- Update docs and script tests to cover support-asset staging, support-asset refresh, directory creation, and compatibility-path behavior.

## Capabilities

### New Capabilities

- `overmind-asdlc-local-support-asset-staging`: First-init-machine flow stages repo-owned rules, templates, golden examples, helper scripts, and setup files into deterministic local ASDLC support-asset directories.
- `overmind-asdlc-support-asset-sync`: Update mode refreshes staged local support assets so an existing ASDLC home matches the current repository-owned support-asset set.

### Modified Capabilities

- None.

## Impact

- Affected scripts:
  - `overmind/scripts/project_mgmt/project_setup_first_init_machine.sh`
- Affected runtime output under `<selected_parent>/asdlc/`:
  - `.rules/`
  - `.templates/`
  - `.golden_examples/`
  - `.helper/`
  - `.setup/`
  - `templates/init_progress_definition_TEMPLATE.yaml`
- Affected tests:
  - `tests/ai_scripts/project_setup_asdlc_tests.sh`
- Affected docs:
  - `overmind/README.md`
- No new CLI flags/options are introduced.
