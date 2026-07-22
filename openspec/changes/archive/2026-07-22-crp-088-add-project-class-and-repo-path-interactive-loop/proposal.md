## Why

When initializing a new ASDLC project, project classes and repository paths were not collected through a guided loop for the project definition. This caused inconsistent `project_classes` setup and missing repo-path capture for selected classes.

## What Changes

- Extend `project_setup_add_new_project.sh` with an interactive project-class selection loop for each new project record.
- Prompt class options repeatedly until user selects `5` (done):
  - `1. backend`
  - `2. frontend`
  - `3. mobile`
  - `4. infrastructure`
  - `5. all done, nothing else to add`
- On each valid class selection, add class to project definition metadata, inform user what was already added, and remove already-selected classes from subsequent prompts.
- After class-selection loop ends, iterate each selected class and ask:
  - `we need to add repo path in your system for <project class>`
  - `1. yes, ready to add`
  - `2. no, I'll add it later`
- If user selects `1`, prompt for repo path and validate that path exists and is not empty.
- Persist selected classes and collected repo-path state in `projects/<project_id>/init_progress_definition.yaml` under `meta_info.project_classes` and `meta_info.class_repo_paths`.

## Capabilities

### New Capabilities
- `overmind-asdlc-project-class-selection-loop`: Add-project flow SHALL support iterative class selection with explicit done action, running summary of selected classes, and shrinking menu options as classes are added.
- `overmind-asdlc-project-class-repo-path-capture`: Add-project flow SHALL ask per selected class whether repo path is ready now, validate provided path when chosen, and persist path state.

### Modified Capabilities
- `overmind-asdlc-project-record-registration`: Project record remains minimal in `asdlc/asdlc_metadata.yaml`; class/path onboarding data is written into project `init_progress_definition.yaml`.

## Impact

- Affected scripts:
  - `overmind/scripts/project_mgmt/project_setup_add_new_project.sh`
- Affected metadata/runtime:
  - `asdlc/asdlc_metadata.yaml` project record remains minimal (`project`, `name`, `internal_folder`, `created_at`)
  - `asdlc/projects/<project-id>/init_progress_definition.yaml` receives `meta_info.project_classes` and `meta_info.class_repo_paths`
- Affected tests:
  - `tests/ai_scripts/project_setup_asdlc_tests.sh`
- Affected docs:
  - `overmind/README.md` (add-project interactive onboarding flow)
- No new CLI flags/options are introduced.
