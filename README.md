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
2. run `npm install`, `npm run build`, and `npm run setup` from the repo root, then answer the `ASDLC workspace path:` prompt. A missing path or empty directory is bootstrapped; an existing workspace containing `asdlc_metadata.yaml` is updated. The selected ASDLC workspace receives `.overmind/overmind.js`, packaged Overmind skills in `.codex/skills/` and `.claude/skills/`, runtime templates in `.templates/`, setup defaults in `.setup/`, `asdlc_metadata.yaml`, `projects/`, and `quickrun.md`.
3. in asdlc folder run `node .overmind/overmind.js project create` to create a new project. This creates `projects/<project-id>/`, seeds `init_progress_definition.yaml`, initializes that project folder as its own git repository, and creates the first commit. Creation asks for project name, project type, and class membership only; selected classes start as policy `A` with empty repo paths, meaning feature work can proceed without repo evidence for those classes. Use `node .overmind/overmind.js project add-class` later to add a missing class or reset a wrongly bound class to policy `A`, then use `node .overmind/overmind.js project reconcile --path projects/<project-id>` when existing repositories need binding or ready repositories need contract reconciliation.
   3-a. it's possible to setup MCP server for stack blueprint authoring and MCP placeholder enrichment. To do this, first set knowledgebase mcp to your codex cli (see codex docs), second - after asdlc directory will be established - add this MCP to .setup/external_sources.yaml
4. finish required project-level init before feature work:
   - Type A projects: Initialize Repo ASDLC Metadata -> Define Project Stack Blueprints And Agent Guidelines For Active Classes -> Create Cross-Repository Contract Definition For This Project -> start feature.
   - Type B/C projects: Initialize Repo ASDLC Metadata -> Create Cross-Repository Contract Definition For This Project -> start feature.
   - Initialize Repo ASDLC Metadata: create `init_progress_definition.yaml` with project type, class membership, and deferred class metadata.
   - Define Project Stack Blueprints And Agent Guidelines For Active Classes: for type A only, approve stack blueprints and per-class agent guidelines with `node .overmind/overmind.js project init --path projects/<project-id>`. Overmind commits the stack baseline, then asks `Continue with common contract definition? [Y/n]`.
   - Create Cross-Repository Contract Definition For This Project: create project-level `common_contract_definition.md` with the same `node .overmind/overmind.js project init --path projects/<project-id>` command. If you answered no at the continuation prompt, rerun that command to resume directly at step 2.
   - Initialize and Enrich Business Requirements Structuring: start feature planning with `node .overmind/overmind.js run --path projects/<project-id>`.
   - `overmind run` (see p.5 below) refuses feature progression when an earlier project init step is incomplete and directs the operator to `node .overmind/overmind.js project init --path projects/<project-id>`. It directs deferred policy `B`/`C` class repos to repository binding and ready-unreconciled class repos to contract reconciliation with `node .overmind/overmind.js project reconcile --path projects/<project-id>`.

--- here we finished on project level and go to feature level ---

5. to create a feature end-to-end run orchestrator `node .overmind/overmind.js run --path projects/<project-id>` and it will guide you through the process, on some step you would need to save story or epic as a source within feature folder in .txt or .md file
6. when you are finished - please-please take a look at requirements_ears.md and implementation_plan.md yourself. It's the most critical part of future implementation and we don't have to rely on AI here completely. If you need to change or fix something - just run your usual agent, point it to the files and ask it to make changes.
   --- here we finished with feature planning, but who will work it out? ---
7. register new workers with `node .overmind/overmind.js worker register --path projects/<project-id>`, one run per worker with a strict class (backend|frontend|mobile|infrastructure).
8. now give worker uuid to the developer responsible for that worker so he can finish registration from his side
9. when `implementation_plan.md` is ready for a feature, run `node .overmind/overmind.js worker assign --feature-path projects/<project-id>/<feature-folder>` to fill `#### Assigned:` for each step based on class-matched active workers, dependency holds, or missing-worker markers

you can manually run TypeScript CLI commands for different steps after asdlc folder init, check

## Conceptual model

### Per-class transition lifecycle (D1)

`project_type_code` records how the project started (A = greenfield with blueprints; B/C = existing repo) and is **not read by feature-phase steps**. Classes transition independently from blueprint-backed to repo-backed on their own timeline. Each class's attachment state is tracked in `meta_info.class_repo_paths.<class>`:

- `state: "deferred"` — no repo attached. With `policy: "A"`, planning may proceed and skips this class for scan-dependent steps. With `policy: "B"` or `policy: "C"`, an existing repository is expected and feature work blocks until a path is bound.
- `state: "ready"` — repo is attached and scannable; planning scans this class. Recorded alongside `path` (absolute filesystem path) and `policy` (see below).

Class membership is managed by `node .overmind/overmind.js project create` and `node .overmind/overmind.js project add-class`. Both commands produce policy `A` deferred classes, which do not block feature work. Repository binding and contract reconciliation run through `node .overmind/overmind.js project reconcile --path <project-path>`. Reconcile can keep a deferred class as policy `A`, or convert it to policy `B`/`C`, bind a valid repo path, and transition it to `ready`. `overmind run` blocks deferred `B`/`C` classes with repo-binding guidance and blocks ready-unreconciled classes with contract-reconciliation guidance.

### Policy C — divergence semantics

**Policy `A`**: the repository will be generated later; the class remains deferred with an empty path.

**Policy `B`**: existing repository with partial context. Type B-specific planning distinctions are tracked for later enforcement.

**Policy `C`**: existing repository with code-first context. A layer that is materialized in the repo but diverges from the blueprint is still resolved from the repo — silently tagged `divergent_from_blueprint: §<n>` (the matching blueprint Layer Bindings block). Blueprint is consulted only when the layer is entirely absent from the repo. Choosing `C` is an informed governance declaration; the system honors it without second-guessing.

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

Coordinator commands enforce this gate: a ready class repo that is not on its default branch or has uncommitted changes is refused before scanning, with a clear `BLOCKED:` message directing the operator to merge or check out the default branch.

### Promise tier and concurrency (D7)

Planning is serial (assumed, one operator at a time) and execution is concurrent. A feature is a promise the moment its folder holds an `implementation_plan.md`; implemented steps surface via repo scan and the rest stay promises, with the per-row evidence chain sorting the source. There is no lifecycle state machine and no implementation-status analysis at planning time.

**Cross-feature `#### Depends on:` syntax:** entries without `/` are same-feature step IDs; entries containing `/` are cross-feature references with format `<feature-folder>/<step-id>` (example: `0003_customer_accounts/3.2`). The assignment step holds any step whose cross-feature dependency is not yet complete-and-merged, writing the exact assignment text `hold: depends on <feature-folder>/<step-id>`. Every re-run re-evaluates all holds.

A dead-but-undeleted feature folder keeps emitting promises and any dependent step stays held indefinitely; the operator's recourse is to delete the folder (there is no abandoned-feature concept — D7).

### First-attach contract reconciliation — stopgap (D6)

When a class first attaches (`node .overmind/overmind.js project reconcile --path <project-path>`), `common_contract_definition.md` was authored from blueprint intent and was never reality-checked. A one-time reconciliation diffs it against the as-built API; the operator resolves interactively. This is a **stopgap** that clears the blueprint-era backlog once per class attach; ongoing drift is the feedback loop's job (deferred).

## Most critical issues

- coordinator (overmind) can't distribute tasks for multiple workers (f.e. 2 backend)
- coordinator (overmind) unable to take worker output and redesign implementation plans from feedback
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

## Bundled CLI Input Contract

Project init requires:

- `--path <asdlc/projects/<project-id>>`

The feature workflow runs through the bundled CLI:

- `node .overmind/overmind.js project create`
- `node .overmind/overmind.js project add-class`
- `node .overmind/overmind.js project reconcile [--path <asdlc/projects/<project-id>>]`
- `node .overmind/overmind.js project init --path <asdlc/projects/<project-id>>`
- `node .overmind/overmind.js run [--path <asdlc/projects/<project-id>>] [--resume <step>]`
- `node .overmind/overmind.js worker register --path <asdlc/projects/<project-id>>`
- `node .overmind/overmind.js worker assign --feature-path <asdlc/projects/<project-id>/<feature-folder>>`

Worker assignment feature paths use:

- `--feature-path <asdlc/projects/<project-id>/<feature-folder>>`

Progress status is read-only and accepts either scope:

- `node .overmind/overmind.js status <asdlc/projects/<project-id>[/<feature-folder>]>`

`--feature-path` must:

- exist and be a directory
- be inside ASDLC `projects/`
- contain `feature_br_summary.md`

Project worker data lives in:

- `projects/<project-id>/workers.yaml`

## Notes

- The staged ASDLC workspace itself is just a normal folder and is not initialized as a git repository.
- `node .overmind/overmind.js project create` does not require git state for the staged ASDLC workspace.
- Each newly created ASDLC project folder under `projects/<project-id>/` is initialized as its own git repository with an initial commit containing `init_progress_definition.yaml`.
- Quality gates are TypeScript CLI validators exposed through `node .overmind/overmind.js gate ...`.
- Tests run through `npm test` and `npm run verify`.
- Task-to-BR runs through the installed `overmind-task-to-br` skill backed by `.overmind/overmind.js`, not a staged shell command. The CLI owns deterministic capture of `user_br_input.md` via `node .overmind/overmind.js capture task-to-br <feature-path> --source-file <path>` or `--jira <ticket>` before context/gate. Jira capture records the ticket marker; the skill/context step owns MCP fetch and persistence of fetched story text.
- BR clarification runs through the installed `overmind-br-clarification` skill backed by `node .overmind/overmind.js context br-clarification <feature-path>` and `node .overmind/overmind.js gate br-clarification <feature-path>`. EARS readiness is deterministic: `node .overmind/overmind.js readiness br-clarification <feature-path>`.
- BR-to-EARS runs through the installed `overmind-requirements-ears` skill backed by `node .overmind/overmind.js context requirements-ears <feature-path>` and `node .overmind/overmind.js gate requirements-ears <feature-path>`.
- EARS review runs through the installed `overmind-ears-review` skill backed by `node .overmind/overmind.js context ears-review <feature-path>` and `node .overmind/overmind.js gate ears-review <feature-path>`.
- ASDLC setup requires the built bundle at `packages/asdlc-coordinator/dist/overmind.js`; run `npm install`, `npm run build`, and then `npm run setup` from the repo root, or run `node /path/to/yasdef-overmind/packages/installer/dist/src/bin/overmind.js init` from any directory. Both commands prompt for the ASDLC workspace path.
- example of external_sources configuraqtion for knowledge base MCP

```
sources:
  - name: yasdef-knowledge-kb
    type: stack_knowledge_base
    description: Approved stack blueprints, architecture references, and project bootstrap conventions
```

## Runtime CLI And Skills

- `overmind init` / `npm run setup`
  Prompts for an ASDLC workspace path, then bootstraps a missing or empty workspace or updates an existing workspace containing `asdlc_metadata.yaml` through `packages/installer`: `.overmind/overmind.js`, packaged skills for `.codex` and `.claude`, runtime templates, setup defaults, `asdlc_metadata.yaml`, `projects/`, and generated `quickrun.md`.

- `overmind project create` (bundled CLI verb)
  `node .overmind/overmind.js project create` interactively creates a new project record + project folder, records project type and class membership, seeds deferred class rows, initializes `projects/<project-id>/` as a git repository, and creates the first commit.

- `overmind project add-class` (bundled CLI verb)
  `node .overmind/overmind.js project add-class` interactively adds a missing class or resets an existing class to deferred with an empty path and policy `A`.

- `overmind project reconcile` (bundled CLI verb)
  `node .overmind/overmind.js project reconcile [--path <asdlc/projects/<project-id>>]` records class policy, attaches selected policy `B`/`C` repositories, and runs the one-time common-contract reconciliation flow. With no `--path`, it auto-selects the only project or prompts for one when multiple projects exist.

- `overmind project init` (bundled CLI verb)
  `node .overmind/overmind.js project init --path <asdlc/projects/<project-id>>` runs project initialization through committed checkpoints. Type A projects run per-class `overmind-stack-blueprint` sessions followed by `overmind-agents-md` sessions, commit the stack baseline, and ask `Continue with common contract definition? [Y/n]`; yes continues in the same invocation, no exits successfully with step 2 pending. Every project type runs the `overmind-common-contract` session and the TypeScript common-contract gate before committing the initialization baseline.

- `packages/installer/_data/skills/overmind-agents-md/SKILL.md`
  Installed per-class type A project-init skill that creates or verifies `project_agents_md_claude_md_<class>.md` through `node .overmind/overmind.js context agents-md <project-path> --class <backend|frontend|mobile>` and `node .overmind/overmind.js gate agents-md <project-path>/project_agents_md_claude_md_<class>.md`.

- `overmind worker register` (bundled CLI verb)
  `node .overmind/overmind.js worker register --path <asdlc/projects/<project-id>>` interactively registers one worker class (`backend`, `frontend`, `mobile`, `infrastructure`) and appends an active worker record into `<project>/workers.yaml` using canonical `meta_info.project_id`.

- `overmind run` (bundled CLI verb)
  `node .overmind/overmind.js run [--path <asdlc/projects/<project-id>>] [--resume <step>]` discovers unfinished project feature folders first, asks whether to start a new feature or continue one of the unfinished features, keeps `projects/<project-id>/.overmind_feature_state.json` only as a last-selected cache, reads selected-feature progress through the in-process sequencing core, and orchestrates confirmed execution through Implementation Plan Semantic Review. `run` is the single feature-creation entrypoint: selecting "Start a new feature" dispatches catalog step `3` through the deterministic action registry, which seeds `feature_br_summary.md`, records the created feature, and continues into the phase loop. It refuses before feature work when project-level initialization, class-repo attach, or reconciliation is pending, naming the exact command that owns the boundary: `node .overmind/overmind.js project init --path <project-path>` for pending initialization, or `node .overmind/overmind.js project reconcile --path <project-path>` for pending class-repo attach or reconciliation.

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

- `overmind worker assign` (bundled CLI verb)
  `node .overmind/overmind.js worker assign --feature-path <asdlc/projects/<project-id>/<feature-folder>>` requires an assignment-ready `implementation_plan.md`, resolves active workers strictly by step repo class, asks for one class worker when multiple are available, and writes deterministic `#### Assigned:` values (worker UUID, no-active-worker marker, or dependency hold marker) on every step.
