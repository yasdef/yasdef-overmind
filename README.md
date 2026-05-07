# Overmind Internal README

Overmind contains coordinator artifacts, bootstrap definitions, and helper scripts for the active ASDLC flow.
Its main functions:
- convert a usual epic/story to business requirements (EARS format) and an implementation plan (those 2 artifacts are input for any workers)
- manage (register/deregister/assign tasks) workers in a project
- consume feedback from workers and adjust feature plans according to it (currently not implemented)

This repository contains the standalone Overmind project. The original extraction source was the `overmind/` subtree in `yasdef-core`.

## Quick start

0. Read this carefully:
- ⚠️ This is pre-alpha — things may break. Use at your own risk. Take precautions before integrating this repo into your project!
1. clone `yasdef-overmind` to your local machine
2. run `overmind/scripts/project_mgmt/project_setup_first_init_machine.sh` to establish and set up the asdlc folder for future project work - you need to provide the place where exactly the asdlc folder will exist in your system,
after this script finishes, the staged ASDLC commands live under your generated `asdlc/` workspace; later updates can be pulled from this repo and re-applied by running the same setup script again
3. in asdlc folder run `.commands/project_setup_add_new_project.sh` to create a new project. This creates `projects/<project-id>/`, seeds `init_progress_definition.yaml`, initializes that project folder as its own git repository, and creates the first commit. On this step you may provide paths to project repos, for example backend and frontend (if they exist), if it's a completely new project you may optionally configure per-class stack guidance sources in `init_progress_definition.yaml`; if absent, the system falls back to model proposals during Step `1.1` blueprint authoring. You can always add or change this info later in projects/<project_id>/init_progress_definition.yaml (see meta_info part).
3-a. it's possible to setup MCP server for step 1.1. and 7.1. can extract knowledge from it, for this first set knowledgebase mcp to your codex cli (see codex docs), second - after asdlc directory will be established - add this MCP to .setup/external_sources.yaml
4. finish required project-level init before feature work:
   - Type A projects: Step `1` -> Step `1.1` -> Step `2` -> Step `3` (start feature).
   - Type B/C projects: Step `1` -> Step `2` -> Step `3` (start feature).
   - Step `1`: create `init_progress_definition.yaml` with project type, classes, and repo/path metadata.
   - Step `1.1`: for type A only, approve stack blueprints with `.commands/init_project_stack_blueprints.sh --path projects/<project-id>`.
   - Step `2`: create project-level `common_contract_definition.md` with `.commands/init_common_contract_definition.sh --path projects/<project-id>`.
   - Step `3`: start feature planning with `.commands/project_add_feature_e2e.sh --path projects/<project-id>`.
   - `project_add_feature_e2e.sh` (see p.5 below) uses the scanner to block feature progression when an earlier project step is incomplete. For a brand-new feature, it may create the Step `3` feature scaffold before reporting the missing earlier step.

--- here we finished on project level and go to feature level ---

5. to create a feature end-to-end run orchestrator `.commands/project_add_feature_e2e.sh --path projects/<project-id>` and it will guide you through the process, on some step you would need to save story or epic as a source within feature folder in .txt or .md file
6. when you are finished - please-please take a look at requirements_ears.md and implementation_plan.md yourself. It's the most critical part of future implementation and we don't have to rely on AI here completely. If you need to change or fix something - just run your usual agent, point it to the files and ask it to make changes.
--- here we finished with feature planning, but who will work it out? ---
7. register new workers with `.commands/project_register_worker.sh`, one run per worker with a strict class (backend|frontend|mobile|infrastructure). Currently orchestrator can't distribute tasks across multiple workers of same class so it doesn't make sense to register 2 workers of same class (2 backend for example)
8. now give worker uuid to the developer responsible for that worker so he can finish registration from his side
9. when `implementation_plan.md` is ready for a feature, run `.commands/feature_assing_workers.sh --feature_path projects/<project-id>/<feature-folder>` to fill `#### Assigned:` for each step based on class-matched active workers

you can manualy run scripts for different steps after asdlc folder init, check  

## Most critical issues
- coordinator (overmind) can't distribute tasks for multiple workers (f.e. 2 backend)
- coordinator (overmind) unable to take worker's output (see ai_audit.sh) and re-design implementation plan based on this new tasks
- type B (code exists, refactor to best practices) and type C (code exists, follow existing patterns) are still processed identically as type C; type B-specific planning distinctions are not yet enforced
- we need more complex project-level management (update metainfo, add, change or delete repos etc.) 
- we need to read epic/story from jira, current way - add them as a text/md files can remain optional but not main
- ASDLC workspace artifacts currently live only in the local filesystem; there is no built-in artifact versioning flow yet

## Release-notes

V-0.0.1
- inint mode to setup asdlc folder in file system with all necessary scripts, rules etc
- add projects, add repos to project, scan repos for project metainfo
- add workers to project (types: backend|frontend|mobile|infra)
- add new feature flow end 2 end from story to requirement_ears and inplementation_plan
- assign workers to implementation plan

V-0.0.2
- planning flow significantly improved

V-0.0.3 (current)
- add blueprints on project level
- unblocked new projects (type-A) creation
- add cross-class transport section
- add MCP as a source for type-A projects


## Staged Commands Input Contract

All staged commands are expected to run from `<asdlc>/.commands/`.

Scripts working on **project level** require:
- `--path <asdlc/projects/<project-id>>`
- `init_common_contract_definition.sh`
- `project_register_worker.sh`
- `project_add_feature_e2e.sh`
- `feature_br_scaffold.sh`

Scripts working on **feature level** require:
- `--feature_path <asdlc/projects/<project-id>/<feature-folder>>`
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
- `feature_prerequisite_gaps.sh`
- `feature_implementation_plan.sh`
- `feature_implementation_plan_semantic_review.sh`
- `feature_assing_workers.sh`

Feature-level exception:
- `init_progress_scanner.sh` works on a feature folder but expects `--path <asdlc/projects/<project-id>/<feature-folder>>`.

`--feature_path` must:
- exist and be a directory
- be inside ASDLC `projects/`
- contain `feature_br_summary.md`

Project worker data lives in:
- `projects/<project-id>/workers.yaml`

## Notes

- The staged ASDLC workspace itself is just a normal folder and is not initialized as a git repository.
- `project_setup_add_new_project.sh` does not require git state for the staged ASDLC workspace.
- Each newly created ASDLC project folder under `projects/<project-id>/` is initialized as its own git repository with an initial commit containing `init_progress_definition.yaml`.
- Quality helper scripts live under `overmind/scripts/helper/`.
- Script tests are in `tests/ai_scripts/`.
- example of external_sources configuraqtion for knowledge base MCP
```
sources:
  - name: yasdef-knowledge-kb
    type: stack_knowledge_base
    description: Approved stack blueprints, architecture references, and project bootstrap conventions
```

## Scripts

- `overmind/scripts/project_mgmt/project_setup_first_init_machine.sh`
  Bootstraps or updates ASDLC workspace under `<selected_parent>/asdlc`. In update mode, it repairs missing staged commands, refreshes `quickrun.md`, and synchronizes only whitelisted support assets (`.rules`, `.templates`, `.golden_examples`, `.helper`, `.setup`).

- `overmind/scripts/project_mgmt/project_setup_add_new_project.sh`
  Staged command (`<asdlc>/.commands/project_setup_add_new_project.sh`) that creates a new project record + project folder, seeds `init_progress_definition.yaml`, initializes `projects/<project-id>/` as a git repository, and creates the first commit.

- `overmind/scripts/project_mgmt/project_setup_update_project.sh`
  Staged command (`<asdlc>/.commands/project_setup_update_project.sh`) that attaches a repo path to an existing project's deferred class. Interactive flow: pick project → pick deferred class → enter repo path (validates and resolves to absolute path) → persists `state: "ready"` + `path` in `init_progress_definition.yaml`. If the project is type A and all classes become `ready` after the attach, optionally prompts to reclassify to type B or C. Any prompt accepts `q` to quit cleanly without mutation.

- `overmind/scripts/project_mgmt/init_progress_scanner.sh`
  Requires `--path <asdlc/projects/<project-id>/<feature-folder>>`, reads project `init_progress_definition.yaml`, and writes `<project>/step_state.md` with project-level + selected-feature checklist status.

- `overmind/scripts/init_common_contract_definition.sh`
  Staged-runtime command (`<asdlc>/.commands/init_common_contract_definition.sh --path <asdlc/projects/<project-id>>`) that builds project-level `common_contract_definition.md` from usable ready repositories.

- `overmind/scripts/project_mgmt/project_register_worker.sh`
  Staged command (`<asdlc>/.commands/project_register_worker.sh --path <asdlc/projects/<project-id>>`) that interactively registers one worker class (`backend`, `frontend`, `mobile`, `infrastructure`) and appends an active worker record into `<project>/workers.yaml` using canonical `meta_info.project_id`.

- `overmind/scripts/feature_br_scaffold.sh`
  Staged command (`<asdlc>/.commands/feature_br_scaffold.sh --path <asdlc/projects/<project-id>>`) that creates a feature folder and seeds `feature_br_summary.md`.

- `overmind/scripts/project_mgmt/project_add_feature_e2e.sh`
  Staged command (`<asdlc>/.commands/project_add_feature_e2e.sh --path <asdlc/projects/<project-id>> [--resume <step>]`) that discovers unfinished project feature folders first, asks whether to start a new feature or continue one of the unfinished features, keeps `projects/<project-id>/.project_add_feature_e2e_state.env` only as a last-selected cache, runs `init_progress_scanner.sh` for the selected feature, and orchestrates confirmed execution through Step `8.4`.

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

- `overmind/scripts/feature_surface_map_mcp_placeholder_enrichment.sh`
  Staged command (`<asdlc>/.commands/feature_surface_map_mcp_placeholder_enrichment.sh --feature_path <.../feature-folder>`) that optionally runs Step `7.1`, finds unresolved surface-map placeholders, asks a configured knowledge-base MCP source for candidate replacements, applies only user-confirmed replacements, and commits changed surface maps.

- `overmind/scripts/feature_technical_requirements.sh`
  Staged command (`<asdlc>/.commands/feature_technical_requirements.sh --feature_path <.../feature-folder>`) that generates one shared `technical_requirements.md` for the feature from `requirements_ears.md`, `common_contract_definition.md`, and targeted evidence selected via the per-class surface maps.

- `overmind/scripts/feature_implementation_slices.sh`
  Staged command (`<asdlc>/.commands/feature_implementation_slices.sh --feature_path <.../feature-folder>`) that runs Step `8.1` and generates one shared `implementation_slices.md` artifact from `requirements_ears.md`, `technical_requirements.md`, `feature_contract_delta.md`, and relevant surface-map artifacts.

- `overmind/scripts/feature_prerequisite_gaps.sh`
  Staged command (`<asdlc>/.commands/feature_prerequisite_gaps.sh --feature_path <.../feature-folder>`) that runs Step `8.2` (Prerequisite Gap Trace) and generates `prerequisite_gaps.md` from `requirements_ears.md`, `technical_requirements.md`, and `implementation_slices.md`. For each EARS requirement, it derives externally-invocable prerequisites (frontend routes/pages/screens, backend HTTP endpoints/CLI commands/scheduled jobs/admin tools, mobile screens/deep links) and classifies each as `present_in_repo`, `scheduled_in_slices`, or `unmet`. The quality gate rejects any `unmet` entry; all missing prerequisites must be promoted to `implementation_slices.md` before Step `8.3` can begin.

- `overmind/scripts/feature_implementation_plan.sh`
  Staged command (`<asdlc>/.commands/feature_implementation_plan.sh --feature_path <.../feature-folder>`) that runs Step `8.3` and generates one shared `implementation_plan.md` for the feature using `prerequisite_gaps.md`, `implementation_slices.md`, `requirements_ears.md`, `technical_requirements.md`, and `feature_contract_delta.md`.

- `overmind/scripts/feature_implementation_plan_semantic_review.sh`
  Staged command (`<asdlc>/.commands/feature_implementation_plan_semantic_review.sh --feature_path <.../feature-folder>`) that optionally runs Step `8.4` semantic review, including Type A repo-scaffold-readiness suggestions, asks the user which finding numbers to apply, updates `implementation_plan.md`, and records decisions in `implementation_plan_semantic_review.md`.

- `overmind/scripts/feature_assing_workers.sh`
  Staged command (`<asdlc>/.commands/feature_assing_workers.sh --feature_path <.../feature-folder>`) that requires a ready parseable `implementation_plan.md`, resolves active workers strictly by step repo class, asks for one class worker when multiple are available, and writes deterministic `#### Assigned:` values (worker UUID or class-scoped error message) on every step.
