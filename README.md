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
3. in asdlc folder run `.commands/project_setup_add_new_project.sh` to create a new project. This creates `projects/<project-id>/`, seeds `init_progress_definition.yaml`, initializes that project folder as its own git repository, and creates the first commit. On this step you may provide paths to project repos, for example backend and frontend (if they exist), if it's a completely new project you may optionally configure per-class stack guidance sources in `init_progress_definition.yaml`; if absent, the system falls back to model proposals during stack blueprint authoring. You can always add or change this info later in projects/<project_id>/init_progress_definition.yaml (see meta_info part).
3-a. it's possible to setup MCP server for stack blueprint authoring and MCP placeholder enrichment. To do this, first set knowledgebase mcp to your codex cli (see codex docs), second - after asdlc directory will be established - add this MCP to .setup/external_sources.yaml
4. finish required project-level init before feature work:
   - Type A projects: Initialize Repo ASDLC Metadata -> Define Project Stack Blueprints For Active Classes -> Create Cross-Repository Contract Definition For This Project -> start feature.
   - Type B/C projects: Initialize Repo ASDLC Metadata -> Create Cross-Repository Contract Definition For This Project -> start feature.
   - Initialize Repo ASDLC Metadata: create `init_progress_definition.yaml` with project type, classes, and repo/path metadata.
   - Define Project Stack Blueprints For Active Classes: for type A only, approve stack blueprints with `.commands/init_project_stack_blueprints.sh --path projects/<project-id>`.
   - Create Cross-Repository Contract Definition For This Project: create project-level `common_contract_definition.md` with `.commands/init_common_contract_definition.sh --path projects/<project-id>`.
   - Initialize and Enrich Business Requirements Structuring: start feature planning with `.commands/project_add_feature_e2e.sh --path projects/<project-id>`.
   - `project_add_feature_e2e.sh` (see p.5 below) uses the scanner to block feature progression when an earlier project step is incomplete. For a brand-new feature, it may create the business requirements scaffold before reporting the missing earlier step.

--- here we finished on project level and go to feature level ---

5. to create a feature end-to-end run orchestrator `.commands/project_add_feature_e2e.sh --path projects/<project-id>` and it will guide you through the process, on some step you would need to save story or epic as a source within feature folder in .txt or .md file
6. when you are finished - please-please take a look at requirements_ears.md and implementation_plan.md yourself. It's the most critical part of future implementation and we don't have to rely on AI here completely. If you need to change or fix something - just run your usual agent, point it to the files and ask it to make changes.
--- here we finished with feature planning, but who will work it out? ---
7. register new workers with `.commands/project_register_worker.sh`, one run per worker with a strict class (backend|frontend|mobile|infrastructure). Currently orchestrator can't distribute tasks across multiple workers of same class so it doesn't make sense to register 2 workers of same class (2 backend for example)
8. now give worker uuid to the developer responsible for that worker so he can finish registration from his side
9. when `implementation_plan.md` is ready for a feature, run `.commands/feature_assing_workers.sh --feature_path projects/<project-id>/<feature-folder>` to fill `#### Assigned:` for each step based on class-matched active workers

you can manualy run scripts for different steps after asdlc folder init, check  

## Conceptual model

### Per-class transition lifecycle (D1)

`project_type_code` records how the project started (A = greenfield with blueprints; B/C = existing repo) and is **not read by feature-phase steps**. Classes transition independently from blueprint-backed to repo-backed on their own timeline. Each class's attachment state is tracked in `meta_info.class_repo_paths.<class>`:

- `state: "deferred"` — no repo attached; planning skips this class for scan-dependent steps and resolves from blueprint or placeholder.
- `state: "ready"` — repo is attached and scannable; planning scans this class. Recorded alongside `path` (absolute filesystem path) and `policy` (see below).

At feature start, `project_add_feature_e2e.sh` checks every deferred class: if the blueprint's `planned_repo_path` now holds a scannable git repository, it prompts the operator to attach it, transitioning the class to `ready` and recording `policy: "C"`.

### Policy C — divergence semantics

**Policy `C`** (the default at attach time): the repo is authoritative. A layer that is materialized in the repo but diverges from the blueprint is still resolved from the repo — silently tagged `divergent_from_blueprint: §<n>` (the matching blueprint Layer Bindings block). Blueprint is consulted only when the layer is entirely absent from the repo. Choosing `C` is an informed governance declaration; the system honors it without second-guessing.

Policy `B` (planned, phase 2): an interactive divergence review for structural mismatches, built on the Implementation Plan Semantic Review pattern.

### Evidence resolution chain (D3)

For every surface-map row, evidence resolves through this permanent per-class chain (one source per row, every non-repo source tagged):

```
repo scan (merged truth) → in-flight feature promises → blueprint (planned) → placeholder
```

- **Repo scan** — only when `class_repo_paths.<class>.state` is `"ready"`; reads the default branch only.
- **In-flight feature promises** — any sibling feature folder that holds an `implementation_plan.md` (planning is serial, so such a sibling has finished planning); tagged `(in-flight <feature-folder>)`.
- **Blueprint** — `project_stack_blueprint_<class>.md` when it exists; tagged `(planned)`; citation carries the blueprint's `last_updated` date from the Meta block.
- **Placeholder** — `<to be defined during implementation>` when no source resolves.

The chain is demand-driven: it runs only for surfaces this feature's requirements touch. "Absent" means the need is not satisfied — never an inventory claim about the repo. A blueprint is never retired; it remains fallback evidence for unmaterialized layers for the life of the project.

### Scanned-ref convention and operator merge discipline (D7)

All planning repo scans (task-to-BR scan, feature contract delta, surface mapping, and prerequisite-gap analysis) read the **committed default branch only**. Worker branches and uncommitted edits are invisible to planning; their content is represented by promises instead. **Implied discipline: accepted work must be merged to the repo's default branch before the next feature plans against it.**

Scripts enforce this gate: a ready class repo that is not on its default branch or has uncommitted changes is refused before scanning, with a clear `BLOCKED:` message directing the operator to merge or check out the default branch.

### Promise tier and concurrency (D7)

Planning is serial (assumed, one operator at a time) and execution is concurrent. A feature is a promise the moment its folder holds an `implementation_plan.md`; implemented steps surface via repo scan and the rest stay promises, with the per-row evidence chain sorting the source. There is no lifecycle state machine and no implementation-status analysis at planning time.

**Cross-feature `#### Depends on:` syntax:** entries without `/` are same-feature step IDs; entries containing `/` are cross-feature references with format `<feature-folder>/<step-id>` (example: `0003_customer_accounts/3.2`). The assignment step holds any step whose cross-feature dependency is not yet complete-and-merged, writing the exact assignment text `hold: depends on <feature-folder>/<step-id>`. Every re-run re-evaluates all holds.

A dead-but-undeleted feature folder keeps emitting promises and any dependent step stays held indefinitely; the operator's recourse is to delete the folder (there is no abandoned-feature concept — D7).

### First-attach contract reconciliation — stopgap (D6)

When a class first attaches (`project_contract_reconciliation.sh --path <project-path>`), `common_contract_definition.md` was authored from blueprint intent and was never reality-checked. A one-time reconciliation diffs it against the as-built API; the operator resolves interactively. This is a **stopgap** that clears the blueprint-era backlog once per class attach; ongoing drift is the feedback loop's job (deferred).

## Most critical issues
- coordinator (overmind) can't distribute tasks for multiple workers (f.e. 2 backend)
- coordinator (overmind) unable to take worker's output (see ai_audit.sh) and re-design implementation plan based on this new tasks
- type B-specific planning distinctions (interactive divergence review) are not yet enforced — tracked as phase 2
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

V-0.0.3
- add blueprints on project level
- unblocked new projects (type-A) creation
- add cross-class transport section
- add MCP as a source for type-A projects

V-0.0.4 (current)
- multiple flow improvements and bug fixes


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
  Requires `--path <asdlc/projects/<project-id>/<feature-folder>>`, reads project `init_progress_definition.yaml`, writes `projects/<project-id>/step_state_<feature-folder>.md` with project-level + selected-feature checklist status, and keeps stdout as the canonical machine-consumable scan output.

- `overmind/scripts/init_common_contract_definition.sh`
  Staged-runtime command (`<asdlc>/.commands/init_common_contract_definition.sh --path <asdlc/projects/<project-id>>`) that builds project-level `common_contract_definition.md` from usable ready repositories.

- `overmind/scripts/project_mgmt/project_register_worker.sh`
  Staged command (`<asdlc>/.commands/project_register_worker.sh --path <asdlc/projects/<project-id>>`) that interactively registers one worker class (`backend`, `frontend`, `mobile`, `infrastructure`) and appends an active worker record into `<project>/workers.yaml` using canonical `meta_info.project_id`.

- `overmind/scripts/feature_br_scaffold.sh`
  Staged command (`<asdlc>/.commands/feature_br_scaffold.sh --path <asdlc/projects/<project-id>>`) that creates a feature folder and seeds `feature_br_summary.md`.

- `overmind/scripts/project_mgmt/project_add_feature_e2e.sh`
  Staged command (`<asdlc>/.commands/project_add_feature_e2e.sh --path <asdlc/projects/<project-id>> [--resume <step>]`) that discovers unfinished project feature folders first, asks whether to start a new feature or continue one of the unfinished features, keeps `projects/<project-id>/.project_add_feature_e2e_state.env` only as a last-selected cache, runs `init_progress_scanner.sh` for the selected feature, and orchestrates confirmed execution through Implementation Plan Semantic Review.

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
  Staged command (`<asdlc>/.commands/feature_surface_map_mcp_placeholder_enrichment.sh --feature_path <.../feature-folder>`) that optionally runs MCP placeholder enrichment, finds unresolved surface-map placeholders, asks a configured knowledge-base MCP source for candidate replacements, applies only user-confirmed replacements, and commits changed surface maps.

- `overmind/scripts/feature_technical_requirements.sh`
  Staged command (`<asdlc>/.commands/feature_technical_requirements.sh --feature_path <.../feature-folder>`) that generates one shared `technical_requirements.md` for the feature from `requirements_ears.md`, `common_contract_definition.md`, and targeted evidence selected via the per-class surface maps.

- `overmind/scripts/feature_implementation_slices.sh`
  Staged command (`<asdlc>/.commands/feature_implementation_slices.sh --feature_path <.../feature-folder>`) that runs implementation slice planning and generates one shared `implementation_slices.md` artifact from `requirements_ears.md`, `technical_requirements.md`, `feature_contract_delta.md`, and relevant surface-map artifacts.

- `overmind/scripts/feature_prerequisite_gaps.sh`
  Staged command (`<asdlc>/.commands/feature_prerequisite_gaps.sh --feature_path <.../feature-folder>`) that runs prerequisite gap trace and generates `prerequisite_gaps.md` from `requirements_ears.md`, `technical_requirements.md`, `implementation_slices.md`, and bound sibling `implementation_plan.md` promise sources. For each EARS requirement, it derives externally-invocable prerequisites and classifies each as `present_in_repo`, `scheduled_in_slices`, `scheduled_in_feature <feature-folder>/<step-id>`, or `unmet`. The quality gate rejects any `unmet` entry.

- `overmind/scripts/feature_implementation_plan.sh`
  Staged command (`<asdlc>/.commands/feature_implementation_plan.sh --feature_path <.../feature-folder>`) that runs Implementation Plan and generates one shared `implementation_plan.md` for the feature using `prerequisite_gaps.md`, `implementation_slices.md`, `requirements_ears.md`, `technical_requirements.md`, and `feature_contract_delta.md`.

- `overmind/scripts/feature_implementation_plan_semantic_review.sh`
  Staged command (`<asdlc>/.commands/feature_implementation_plan_semantic_review.sh --feature_path <.../feature-folder>`) that optionally runs Implementation Plan Semantic Review, including Type A repo-scaffold-readiness suggestions, asks the user which finding numbers to apply, updates `implementation_plan.md`, and records decisions in `implementation_plan_semantic_review.md`.

- `overmind/scripts/feature_assing_workers.sh`
  Staged command (`<asdlc>/.commands/feature_assing_workers.sh --feature_path <.../feature-folder>`) that requires a ready parseable `implementation_plan.md`, resolves active workers strictly by step repo class, asks for one class worker when multiple are available, and writes deterministic `#### Assigned:` values (worker UUID or class-scoped error message) on every step.
