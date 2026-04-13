# Overmind Internal README

Overmind contains coordinator artifacts, bootstrap definitions, and helper scripts for the active ASDLC flow.
Its main functions:
- convert a usual epic/story to business requirements (EARS format) and an implementation plan (those 2 artifacts are input for any workers)
- manage (register/deregister/assign tasks) workers in a project
- consume feedback from workers and adjust feature plans according to it (currently not implemented)

For Overmind's place in yasdef architecture, see yasdef-core: https://github.com/yasdef/yasdef-core/blob/main/Readme.md

## Quick start

0. Read this carefully:
- ⚠️ This is pre-alpha — things may break. Use at your own risk. Take precautions before integrating this repo into your project!
1. copy yasdef-overmind to your local machine
2. run project_setup_first_init_machine.sh to establish and set up the asdlc folder for future project work - you need to provide the place where exactly the asdlc folder will exist in your system,
after this script finishes you don't need yasdef-orchestrator any more, but if you keep it, you can pull the latest changes from repo later and run the same script to update all asdlc scripts and rules
3. in asdlc folder run `.commands/project_setup_add_new_project.sh` to create a new project. On this step you may provide paths to project repos, for example backend and frontend (if they exist), if it's a completely new project we need a reference to best-practice MCP (this functionality is not supported yet). You can always add or change this info later in projects/<project_id>/init_progress_definition.yaml (see meta_info part)
4. when project is created, if it includes repos, you can collect info about common contracts, for this run script `.commands/init_common_contract_definition.sh --path projects/<project-id>`
project is created in a new branch so make sure you've merged it to your main/master before you proceed
--- here we finished on project level and go to feature level ---
5. to create a feature end-to-end run orchestrator `.commands/project_add_feature_e2e.sh --path projects/<project-id>` and it will guide you through the process, on some step you would need to save story or epic as a source within feature folder in .txt or .md file
6. when you are finished - please-please take a look at requirements_ears.md and implementation_plan.md yourself. It's the most critical part of future implementation and we don't have to rely on AI here completely. If you need to change or fix something - just run your usual agent, point it to the files and ask it to make changes.
--- here we finished with feature planning, but who will work it out? ---
7. register new workers with `.commands/project_register_worker.sh`, one run per worker with a strict class (backend|frontend|mobile|infrastructure). Currently orchestrator can't distribute tasks across multiple workers of same class so it doesn't make sense to register 2 workers of same class (2 backend for example)
8. now give worker uuid to the developer responsible for that worker so he can finish registration from his side

## Most critical issues
- coordinator (overmind) can't distribute tasks for multiple workers (f.e. 2 backend)
- coordinator (overmind) unable to take worker's output (see ai_audit.sh) and re-design implementation plan based on this new tasks
- coordinator (overmind) does not support new projects (type A) - for this we need MCP integration to provide best practices instead of current repo analysis, for the same reason currently project type B (code exists but we can refactor it based on our best practices) and type C (code exists and we must follow code, not our guidelines) are processed in the same (as type C) way
- we need more complex project-level management (update metainfo, add, change or delete repos etc.) 
- we need to read epic/story from jira, current way - add them as a text/md files can remain optional but not main
- we need sophisticated still convenient git management logic because asdlc folder belongs specific work place (laptop) but each project folder should be independent git-tracked repo to store all artefact in this project git (near codebase)

## Scripts

- `overmind/scripts/bootstrap_overmind.sh`
  Bootstraps coordinator branch/state: checks out or creates `overmind`, ensures `overmind/worker_registry.yaml`, commits registry changes, and pushes `overmind` to `origin`.

- `overmind/scripts/project_mgmt/project_setup_first_init_machine.sh`
  Bootstraps or updates ASDLC workspace under `<selected_parent>/asdlc`. In update mode, it repairs missing staged commands, refreshes `quickrun.md`, and synchronizes only whitelisted support assets (`.rules`, `.templates`, `.golden_examples`, `.helper`, `.setup`).

- `overmind/scripts/project_mgmt/project_setup_add_new_project.sh`
  Staged command (`<asdlc>/.commands/project_setup_add_new_project.sh`) that creates a new project record + project folder, seeds `init_progress_definition.yaml`, and commits scaffold changes on branch `add-project/<project_id>`.

- `overmind/scripts/project_mgmt/project_setup_update_project.sh`
  Staged command (`<asdlc>/.commands/project_setup_update_project.sh`) that updates existing project metadata and paths.

- `overmind/scripts/project_mgmt/init_progress_scanner.sh`
  Requires `--path <asdlc/projects/<project-id>/<feature-folder>>`, reads project `init_progress_definition.yaml`, and writes `<project>/step_state.md` with project-level + selected-feature checklist status.

- `overmind/scripts/init_common_contract_definition.sh`
  Staged-runtime command (`<asdlc>/.commands/init_common_contract_definition.sh --path <asdlc/projects/<project-id>>`) that builds project-level `common_contract_definition.md` from usable ready repositories.

- `overmind/scripts/project_mgmt/project_register_worker.sh`
  Staged command (`<asdlc>/.commands/project_register_worker.sh --path <asdlc/projects/<project-id>>`) that interactively registers one worker class (`backend`, `frontend`, `mobile`, `infrastructure`) and appends an active worker record into `<project>/workers.yaml` using canonical `meta_info.project_id`.

- `overmind/scripts/feature_br_scaffold.sh`
  Staged command (`<asdlc>/.commands/feature_br_scaffold.sh --path <asdlc/projects/<project-id>>`) that creates a feature folder and seeds `feature_br_summary.md`.

- `overmind/scripts/project_mgmt/project_add_feature_e2e.sh`
  Staged command (`<asdlc>/.commands/project_add_feature_e2e.sh --path <asdlc/projects/<project-id>> [--resume <step>]`) that discovers unfinished project feature folders first, asks whether to start a new feature or continue one of the unfinished features, keeps `projects/<project-id>/.project_add_feature_e2e_state.env` only as a last-selected cache, runs `init_progress_scanner.sh` for the selected feature, and orchestrates confirmed execution through Step `8.3`.

- `overmind/scripts/feature_task_to_br.sh`
  Staged command (`<asdlc>/.commands/feature_task_to_br.sh --feature_path <.../feature-folder>`) that captures business input and generates/updates BR artifacts.

- `overmind/scripts/feature_user_br_clarification.sh`
  Staged command (`<asdlc>/.commands/feature_user_br_clarification.sh --feature_path <.../feature-folder>`) for isolated BR clarification loop updates.

- `overmind/scripts/feature_scan_repo_for_br.sh`
  Staged command (`<asdlc>/.commands/feature_scan_repo_for_br.sh --feature_path <.../feature-folder>`) that enriches BR context from ready repository paths for project types `B/C`.

- `overmind/scripts/feature_br_check_ears_readiness.sh`
  Staged command (`<asdlc>/.commands/feature_br_check_ears_readiness.sh --feature_path <.../feature-folder>`) that validates BR readiness and toggles `ready_to_ears`.

- `overmind/scripts/feature_br_to_ears.sh`
  Staged command (`<asdlc>/.commands/feature_br_to_ears.sh --feature_path <.../feature-folder>`) that converts BR summary into `requirements_ears.md`.

- `overmind/scripts/feature_requirements_ears_review.sh`
  Staged command (`<asdlc>/.commands/feature_requirements_ears_review.sh --feature_path <.../feature-folder>`) that optionally reviews `requirements_ears.md` against `user_br_input.md`, updates EARS when the user accepts changes, and records findings in `requirements_ears_review.md`.

- `overmind/scripts/feature_contract_delta.sh`
  Staged command (`<asdlc>/.commands/feature_contract_delta.sh --feature_path <.../feature-folder>`) that creates `feature_contract_delta.md` from `requirements_ears.md` plus project `common_contract_definition.md`.

- `overmind/scripts/feature_repo_surface_and_exec_context.sh`
  Staged command (`<asdlc>/.commands/feature_repo_surface_and_exec_context.sh --feature_path <.../feature-folder>`) that generates one class-specific surface map per run:
  - `project_surface_struct_resp_map_backend.md`
  - `project_surface_struct_resp_map_frontend.md`
  - `project_surface_struct_resp_map_mobile.md`

- `overmind/scripts/feature_technical_requirements.sh`
  Staged command (`<asdlc>/.commands/feature_technical_requirements.sh --feature_path <.../feature-folder>`) that generates one shared `technical_requirements.md` for the feature from `requirements_ears.md`, `common_contract_definition.md`, and targeted evidence selected via the per-class surface maps.

- `overmind/scripts/feature_implementation_slices.sh`
  Staged command (`<asdlc>/.commands/feature_implementation_slices.sh --feature_path <.../feature-folder>`) that runs Step `8.1` and generates one shared `implementation_slices.md` artifact from `requirements_ears.md`, `technical_requirements.md`, `feature_contract_delta.md`, and relevant surface-map artifacts.

- `overmind/scripts/feature_implementation_plan.sh`
  Staged command (`<asdlc>/.commands/feature_implementation_plan.sh --feature_path <.../feature-folder>`) that runs Step `8.2` and generates one shared `implementation_plan.md` for the feature using `implementation_slices.md`, `requirements_ears.md`, `technical_requirements.md`, and `feature_contract_delta.md`.

- `overmind/scripts/feature_implementation_plan_semantic_review.sh`
  Staged command (`<asdlc>/.commands/feature_implementation_plan_semantic_review.sh --feature_path <.../feature-folder>`) that optionally runs Step `8.3` semantic review, asks the user which finding numbers to apply, updates `implementation_plan.md`, and records decisions in `implementation_plan_semantic_review.md`.

## Staged Feature-Path Contract

The following staged commands require `--feature_path <asdlc/projects/<project-id>/<feature-folder>>` and must run from `<asdlc>/.commands/`:

- `feature_scan_repo_for_br.sh`
- `feature_task_to_br.sh`
- `feature_user_br_clarification.sh`
- `feature_br_check_ears_readiness.sh`
- `feature_br_to_ears.sh`
- `feature_requirements_ears_review.sh`
- `feature_contract_delta.sh`
- `feature_repo_surface_and_exec_context.sh`
- `feature_technical_requirements.sh`
- `feature_implementation_slices.sh`
- `feature_implementation_plan.sh`
- `feature_implementation_plan_semantic_review.sh`

## Staged Project-Path Feature Orchestrator

- `project_register_worker.sh` requires `--path <asdlc/projects/<project-id>>`.
- `<project>/workers.yaml` stores top-level `project_id` plus worker entries with `uuid`, `class`, `status`, and `registered_at`.
- `project_add_feature_e2e.sh` requires `--path <asdlc/projects/<project-id>>`.
- Project-level startup discovers unfinished feature folders first; when any exist, the operator chooses whether to start a new feature or continue one of the unfinished features.
- The state file `.project_add_feature_e2e_state.env` stores only the last selected feature path as a convenience cache and does not override discovery or explicit user choice.
- New-feature flow creates a feature via `feature_br_scaffold.sh`, saves `feature_path`, then calls `init_progress_scanner.sh --path <saved-feature-path>` and resumes from scanner `next step`.
- Continue flow lists only unfinished features together with their scanner `next step`; `--resume <step>` overrides scanner-derived start after a feature is selected.

`--feature_path` must:
- exist and be a directory,
- be inside ASDLC `projects/`,
- contain `feature_br_summary.md`.

## Notes

- Run scripts from inside a git repository.
- Active quality helpers:
  - `overmind/scripts/helper/check_business_context_filled_from_repo.sh`
  - `overmind/scripts/helper/check_task_to_br_quality.sh`
  - `overmind/scripts/helper/check_common_contract_definition_quality.sh`
  - `overmind/scripts/helper/check_requirements_ears_quality.sh`
  - `overmind/scripts/helper/check_feature_contract_delta_quality.sh`
  - `overmind/scripts/helper/check_feature_technical_requirements_quality.sh`
  - `overmind/scripts/helper/check_implementation_slices_quality.sh`
  - `overmind/scripts/helper/check_implementation_plan_quality.sh`
  - `overmind/scripts/helper/check_feature_repo_surface_and_exec_context_be_quality.sh`
  - `overmind/scripts/helper/check_feature_repo_surface_and_exec_context_fe_quality.sh`
  - `overmind/scripts/helper/check_requirements_ears_review_quality.sh`
- Script tests are in `tests/ai_scripts/`.
- For adding a new Overmind phase scaffold, use the local skill `$overmind-new-pipeline-step`.
