## Why

`overmind/scripts/project_mgmt/project_setup_asdlc.sh` currently executes a single initialization flow. We now need one entrypoint that asks the user which ASDLC setup operation to run, so the flow can support first-time machine setup, adding a new project, and updating an existing project without overloading one script body.

## What Changes

- Turn `overmind/scripts/project_mgmt/project_setup_asdlc.sh` into a dispatcher script that starts by asking:
  - `what's the plan, boss?`
  - `1. first init asdlc on this machine`
  - `2. add new project`
  - `3. update project`
- Route validated user choice to one of three helper scripts (one helper per option) and fail fast on invalid selection.
- Move the current `project_setup_asdlc.sh` implementation logic into helper script #2 (`add new project`) and remove that logic from the dispatcher.
- Introduce helper script #1 and helper script #3 as callable placeholders now; their concrete behavior/content will be provided in a later change input.
- Keep script behavior shell-only and avoid introducing new CLI flags/options.
- Update Overmind docs and script tests to reflect dispatcher prompt, option routing, and helper-script split.

## Capabilities

### New Capabilities

- `overmind-project-setup-asdlc-dispatcher`: `project_setup_asdlc.sh` SHALL present a fixed startup menu and dispatch execution to option-specific helper scripts.

### Modified Capabilities

- `overmind-repo-asdlc-metadata-bootstrap`: the existing repo ASDLC metadata initialization behavior SHALL remain intact but be executed via dispatcher option #2 helper instead of directly in `project_setup_asdlc.sh`.

## Impact

- Affected scripts:
  - `overmind/scripts/project_mgmt/project_setup_asdlc.sh`
  - new helper script for option #1 (first machine init; initial placeholder)
  - new helper script for option #2 (add new project; migrated current logic)
  - new helper script for option #3 (update project; initial placeholder)
- Affected tests:
  - `tests/ai_scripts/project_setup_asdlc_tests.sh`
  - new/updated tests for dispatcher menu, invalid input handling, and helper routing
- Affected docs:
  - `overmind/README.md`
  - any flow notes that describe direct single-flow behavior for `project_setup_asdlc.sh`
- No new command-line flags/options are introduced.
