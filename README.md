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
2. run `npm install` and `npm run build` from the repo root, then run `overmind/scripts/project_mgmt/project_setup_first_init_machine.sh` to establish and set up the asdlc folder for future project work - you need to provide the place where exactly the asdlc folder will exist in your system,
after this script finishes, the staged ASDLC commands live under your generated `asdlc/` workspace, the shared gate/context CLI is staged at `.overmind/overmind.js`, and packaged Overmind skills are staged into the supported `.codex/skills/` and `.claude/skills/` runner directories; later updates can be pulled from this repo and re-applied by running the same setup script again
3. in asdlc folder run `.commands/project_setup_add_new_project.sh` to create a new project. This creates `projects/<project-id>/`, seeds `init_progress_definition.yaml`, initializes that project folder as its own git repository, and creates the first commit. On this step you may provide paths to project repos, for example backend and frontend (if they exist), if it's a completely new project you may optionally configure per-class stack guidance sources in `init_progress_definition.yaml`; if absent, the system falls back to model proposals during stack blueprint authoring. You can always add or change this info later in projects/<project_id>/init_progress_definition.yaml (see meta_info part).
3-a. it's possible to setup MCP server for stack blueprint authoring and MCP placeholder enrichment. To do this, first set knowledgebase mcp to your codex cli (see codex docs), second - after asdlc directory will be established - add this MCP to .setup/external_sources.yaml
4. finish required project-level init before feature work:
   - Type A projects: Initialize Repo ASDLC Metadata -> Define Project Stack Blueprints For Active Classes -> Create Cross-Repository Contract Definition For This Project -> start feature.
   - Type B/C projects: Initialize Repo ASDLC Metadata -> Create Cross-Repository Contract Definition For This Project -> start feature.
   - Initialize Repo ASDLC Metadata: create `init_progress_definition.yaml` with project type, classes, and repo/path metadata.
   - Define Project Stack Blueprints For Active Classes: for type A only, approve stack blueprints with `.commands/init_project_stack_blueprints.sh --path projects/<project-id>`.
   - Create Cross-Repository Contract Definition For This Project: create project-level `common_contract_definition.md` with `.commands/init_common_contract_definition.sh --path projects/<project-id>`.
   - Initialize and Enrich Business Requirements Structuring: start feature planning with `node .overmind/overmind.js run --path projects/<project-id>`.
   - `overmind run` (see p.5 below) refuses feature progression when an earlier project step is incomplete or a class repo is deferred or unreconciled, and directs the operator to `node .overmind/overmind.js project reconcile --path projects/<project-id>`.

--- here we finished on project level and go to feature level ---

5. to create a feature end-to-end run orchestrator `node .overmind/overmind.js run --path projects/<project-id>` and it will guide you through the process, on some step you would need to save story or epic as a source within feature folder in .txt or .md file
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

Attaching a deferred class repo (entering a valid path, which transitions the class to `ready` and records `policy: "C"`) and reconciling ready classes run through `node .overmind/overmind.js project reconcile --path <project-path>`. `overmind run` detects deferred or unreconciled classes and refuses with that guidance; the project-level reconciliation flow owns attachment and reconciliation. The operator-provided path is the only attach source.

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

When a class first attaches (`node .overmind/overmind.js project reconcile --path <project-path>`), `common_contract_definition.md` was authored from blueprint intent and was never reality-checked. A one-time reconciliation diffs it against the as-built API; the operator resolves interactively. This is a **stopgap** that clears the blueprint-era backlog once per class attach; ongoing drift is the feedback loop's job (deferred).

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

V-0.0.4
- multiple flow improvements and bug fixes

V-0.0.5 (current)
- per-class blueprint→repo transition: classes attach independently at feature start; `project_type_code` no longer drives feature-phase steps
- permanent per-layer evidence chain (repo scan → in-flight promise → blueprint → placeholder) with dated blueprint citations
- policy C divergence tagging when a materialized repo layer diverges from its blueprint
- concurrency-aware planning: sibling-feature promises, cross-feature `#### Depends on:`, and assignment holds for unmerged dependencies
- one-time contract reconciliation at first repo attach


## Staged Commands Input Contract

All staged commands are expected to run from `<asdlc>/.commands/`.

Scripts working on **project level** require:
- `--path <asdlc/projects/<project-id>>`
- `init_common_contract_definition.sh`
- `project_register_worker.sh`

The feature workflow and standalone scaffold run through the bundled CLI, not staged shell commands:
- `node .overmind/overmind.js run [--path <asdlc/projects/<project-id>>] [--resume <step>]`
- `node .overmind/overmind.js scaffold feature --path <asdlc/projects/<project-id>>`

Scripts working on **feature level** require:
- `--feature_path <asdlc/projects/<project-id>/<feature-folder>>`
- `feature_assing_workers.sh`

Progress status is read-only and accepts either scope:
- `node .overmind/overmind.js status <asdlc/projects/<project-id>[/<feature-folder>]>`

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
- Task-to-BR runs through the installed `overmind-task-to-br` skill backed by `.overmind/overmind.js`, not a staged shell command. The CLI owns deterministic capture of `user_br_input.md` via `node .overmind/overmind.js capture task-to-br <feature-path> --source-file <path>` or `--jira <ticket>` before context/gate. Jira capture records the ticket marker; the skill/context step owns MCP fetch and persistence of fetched story text.
- BR clarification runs through the installed `overmind-br-clarification` skill backed by `node .overmind/overmind.js context br-clarification <feature-path>` and `node .overmind/overmind.js gate br-clarification <feature-path>`. EARS readiness is deterministic: `node .overmind/overmind.js readiness br-clarification <feature-path>`.
- BR-to-EARS runs through the installed `overmind-requirements-ears` skill backed by `node .overmind/overmind.js context requirements-ears <feature-path>` and `node .overmind/overmind.js gate requirements-ears <feature-path>`.
- EARS review runs through the installed `overmind-ears-review` skill backed by `node .overmind/overmind.js context ears-review <feature-path>` and `node .overmind/overmind.js gate ears-review <feature-path>`.
- ASDLC setup/update requires the built bundle at `packages/asdlc-coordinator/dist/overmind.js`; run `npm install` and `npm run build` before `overmind/scripts/project_mgmt/project_setup_first_init_machine.sh`.
- example of external_sources configuraqtion for knowledge base MCP
```
sources:
  - name: yasdef-knowledge-kb
    type: stack_knowledge_base
    description: Approved stack blueprints, architecture references, and project bootstrap conventions
```

## Scripts

- `overmind/scripts/project_mgmt/project_setup_first_init_machine.sh`
  Bootstraps or updates ASDLC workspace under `<selected_parent>/asdlc`. Stages the shared CLI `.overmind/overmind.js` plus every packaged Overmind skill into the supported runner skill directories `.codex/skills/` and `.claude/skills/`. In update mode, it repairs missing staged commands, repairs missing or stale runner skill folders from canonical source, refreshes `quickrun.md`, and synchronizes only whitelisted support assets (`.rules`, `.templates`, `.golden_examples`, `.helper`, `.setup`).

- `overmind/scripts/project_mgmt/project_setup_add_new_project.sh`
  Staged command (`<asdlc>/.commands/project_setup_add_new_project.sh`) that creates a new project record + project folder, seeds `init_progress_definition.yaml`, initializes `projects/<project-id>/` as a git repository, and creates the first commit.

- `overmind/scripts/project_mgmt/project_setup_update_project.sh`
  Staged command (`<asdlc>/.commands/project_setup_update_project.sh`) that attaches a repo path to an existing project's deferred class. Interactive flow: pick project → pick deferred class → enter repo path (validates and resolves to absolute path) → persists `state: "ready"` + `path` in `init_progress_definition.yaml`. If the project is type A and all classes become `ready` after the attach, optionally prompts to reclassify to type B or C. Any prompt accepts `q` to quit cleanly without mutation.

- `overmind/scripts/init_common_contract_definition.sh`
  Staged-runtime command (`<asdlc>/.commands/init_common_contract_definition.sh --path <asdlc/projects/<project-id>>`) that builds project-level `common_contract_definition.md` from usable ready repositories.

- `overmind/scripts/project_mgmt/project_register_worker.sh`
  Staged command (`<asdlc>/.commands/project_register_worker.sh --path <asdlc/projects/<project-id>>`) that interactively registers one worker class (`backend`, `frontend`, `mobile`, `infrastructure`) and appends an active worker record into `<project>/workers.yaml` using canonical `meta_info.project_id`.

- `overmind scaffold feature` (bundled CLI verb)
  `node .overmind/overmind.js scaffold feature --path <asdlc/projects/<project-id>>` creates a feature folder and seeds `feature_br_summary.md`, returning the created path as a typed result.

- `overmind run` (bundled CLI verb)
  `node .overmind/overmind.js run [--path <asdlc/projects/<project-id>>] [--resume <step>]` discovers unfinished project feature folders first, asks whether to start a new feature or continue one of the unfinished features, keeps `projects/<project-id>/.overmind_feature_state.json` only as a last-selected cache, reads selected-feature progress through the in-process sequencing core, and orchestrates confirmed execution through Implementation Plan Semantic Review. It refuses before feature work when project-level initialization, class-repo attach, or reconciliation is pending and directs the operator to `node .overmind/overmind.js project reconcile --path <project-path>`.

- `packages/installer/_data/skills/overmind-task-to-br/SKILL.md`
  Installed skill that drives task-to-BR via `node .overmind/overmind.js capture task-to-br <feature-path> ...`, `node .overmind/overmind.js context task-to-br <feature-path>`, and `node .overmind/overmind.js gate task-to-br <feature-path>`.

- `packages/installer/_data/skills/overmind-br-clarification/SKILL.md`
  Installed skill that drives BR clarification via `node .overmind/overmind.js context br-clarification <feature-path>` and `node .overmind/overmind.js gate br-clarification <feature-path>`.

- `node .overmind/overmind.js readiness br-clarification <feature-path>`
  Deterministic CLI readiness transition that validates BR clarification and repo scan preconditions, then toggles `ready_to_ears`.

- `packages/installer/_data/skills/overmind-requirements-ears/SKILL.md`
  Installed skill that drives BR-to-EARS via `node .overmind/overmind.js context requirements-ears <feature-path>` and `node .overmind/overmind.js gate requirements-ears <feature-path>`.

- `packages/installer/_data/skills/overmind-ears-review/SKILL.md`
  Installed skill that drives optional EARS review via `node .overmind/overmind.js context ears-review <feature-path>` and `node .overmind/overmind.js gate ears-review <feature-path>`.

- `packages/installer/_data/skills/overmind-contract-delta/SKILL.md`
  Installed skill that creates `feature_contract_delta.md` through `node .overmind/overmind.js context contract-delta <feature-path>` and `node .overmind/overmind.js gate contract-delta <feature-path>`; the transitional phase-6 launcher runs `sync contract-delta` before starting the skill session.

- `packages/installer/_data/skills/overmind-surface-map/SKILL.md`
  Installed per-class skill that generates one class-specific surface map per run through `node .overmind/overmind.js context surface-map <feature-path> --class <backend|frontend|mobile>` and `node .overmind/overmind.js gate surface-map <feature-path> --class <backend|frontend|mobile>`; the transitional phase-7 class loop selects a pending class and runs `sync surface-map --class <class>` before starting the skill session. Output is one of:
  - `project_surface_struct_resp_map_backend.md`
  - `project_surface_struct_resp_map_frontend.md`
  - `project_surface_struct_resp_map_mobile.md`

- `packages/installer/_data/skills/overmind-surface-map-enrich/SKILL.md`
  Optional step 7.1 skill that enriches surface-map placeholder fields using a configured knowledge-base MCP source. The skill assembles context with `node .overmind/overmind.js context surface-map-enrich <feature-path>` and validates each modified class with `node .overmind/overmind.js gate surface-map <feature-path> --class <backend|frontend|mobile>`.

- `packages/installer/_data/skills/overmind-technical-requirements/SKILL.md`
  Installed Step 8 skill that generates one shared `technical_requirements.md` from `requirements_ears.md`, `common_contract_definition.md`, and applicable per-class surface maps. It assembles bindings with `node .overmind/overmind.js context technical-requirements <feature-path>` and validates with `node .overmind/overmind.js gate technical-requirements <feature-path>`.

- `packages/installer/_data/skills/overmind-implementation-slices/SKILL.md`
  Installed runner skill for Step 8.1. It uses `node .overmind/overmind.js context implementation-slices <feature-path>` and the model-invoked `gate implementation-slices` command to generate one shared `implementation_slices.md` from the bound read-only feature inputs.

- `overmind-prerequisite-gaps` skill
  Installed under `.codex/skills/` and `.claude/skills/`. It runs prerequisite gap trace using `node .overmind/overmind.js context prerequisite-gaps <feature-path>` and validates `prerequisite_gaps.md` with the corresponding gate command. It reads requirements, technical requirements, implementation slices, and bound sibling implementation plans while writing only `prerequisite_gaps.md`.

- `overmind-implementation-plan` skill
  Installed under `.codex/skills/` and `.claude/skills/`. It assembles Step 8.3 bindings with `node .overmind/overmind.js context implementation-plan <feature-path>` and validates the shared `implementation_plan.md` with `node .overmind/overmind.js gate implementation-plan <feature-path>`.

- `overmind-plan-semantic-review` skill
  Installed under `.codex/skills/` and `.claude/skills/`. It assembles Step 8.4 bindings with `node .overmind/overmind.js context plan-semantic-review <feature-path>`, validates the review ledger with `node .overmind/overmind.js gate plan-semantic-review <feature-path>`, and revalidates plan changes with the implementation-plan gate. It asks which findings to apply, updates `implementation_plan.md`, and records decisions in `implementation_plan_semantic_review.md`.

- `overmind/scripts/feature_assing_workers.sh`
  Staged command (`<asdlc>/.commands/feature_assing_workers.sh --feature_path <.../feature-folder>`) that requires a ready parseable `implementation_plan.md`, resolves active workers strictly by step repo class, asks for one class worker when multiple are available, and writes deterministic `#### Assigned:` values (worker UUID or class-scoped error message) on every step.
