# Overmind TypeScript Quick Run

Use this for the npm/TypeScript packages and packaged Overmind skills.

## 1. Install Dependencies

Run this first after cloning the repo or after `node_modules/` was removed:

```bash
npm install
```

## 2. Build And Test

```bash
npm run build
npm test
```

`npm run build` creates ignored `dist/` output under `packages/*/`, including `packages/asdlc-coordinator/dist/overmind.js`.

## 3. Bootstrap Or Update ASDLC Workspace

From this repo root, after `npm install` and `npm run build`:

```text
npm run setup
```

Or run the built installer bin from any directory:

```text
node /path/to/yasdef-overmind/packages/installer/dist/src/bin/overmind.js init
```

The installer prompts:

```text
ASDLC workspace path:
```

Answer with the ASDLC workspace target path. A missing path or empty directory is bootstrapped; an existing workspace containing `asdlc_metadata.yaml` is updated; a non-empty non-workspace directory is refused without writes. The setup installs `packages/asdlc-coordinator/dist/overmind.js` into the selected ASDLC workspace as `.overmind/overmind.js`, plus packaged skills, runtime templates, setup defaults, `asdlc_metadata.yaml`, `projects/`, and generated `quickrun.md`.

- `.overmind/overmind.js`
- `.codex/skills/overmind-task-to-br/`
- `.claude/skills/overmind-task-to-br/`
- `.codex/skills/overmind-contract-delta/`
- `.claude/skills/overmind-contract-delta/`
- `.codex/skills/overmind-stack-blueprint/`
- `.claude/skills/overmind-stack-blueprint/`
- `.codex/skills/overmind-agents-md/`
- `.claude/skills/overmind-agents-md/`
- `.codex/skills/overmind-common-contract/`
- `.claude/skills/overmind-common-contract/`
- `.templates/init_progress_definition_TEMPLATE.yaml`
- `.templates/feature_br_summary_TEMPLATE.md`
- `.setup/models.md`
- `.setup/external_sources.yaml`
- `asdlc_metadata.yaml`
- `projects/`
- `quickrun.md`

## 4. Run Task-To-BR Helpers

From the installed project root:

```bash
node .overmind/overmind.js capture task-to-br <feature-path> --source-file <path-to-story.md-or.txt>
node .overmind/overmind.js capture task-to-br <feature-path> --jira <ticket>
node .overmind/overmind.js context task-to-br <feature-path>
node .overmind/overmind.js gate task-to-br <feature-path>
```

The skill owns the loop: capture `user_br_input.md` when missing, run context, update `feature_br_summary.md` and `missing_br_data.md`, run gate, repair on exit `1`, stop on exit `2`. Jira capture records `jira:<ticket>` first; context then tells the agent to fetch and persist the story text through a configured Jira MCP source.

## 5. Run Contract-Delta Helpers

From the installed ASDLC workspace root:

```bash
node .overmind/overmind.js sync contract-delta <feature-path>
node .overmind/overmind.js context contract-delta <feature-path>
node .overmind/overmind.js gate contract-delta <feature-path>
```

The feature orchestrator runs `sync` before loading `overmind-contract-delta`; the skill owns the context/write/gate/repair loop.

## 6. Create Projects, Manage Classes, And Reconcile

Project creation, class membership, repo attachment, and common-contract reconciliation use the bundled CLI. From the installed ASDLC workspace root, create a project with:

```bash
node .overmind/overmind.js project create
```

Creation asks for the project name, project type, and class list. Selected classes start as policy `A`: deferred with empty repo paths, intentionally repo-less, and allowed to start feature work. To add a missing class later, or reset a wrongly bound class back to that policy `A` state, run:

```bash
node .overmind/overmind.js project add-class
```

Project-level repo attachment and common-contract reconciliation are a separate command from the feature flow (`overmind run`):

```bash
node .overmind/overmind.js project reconcile [--path <project>]
```

With no `--path`, project selection mirrors `overmind run`: a single project auto-selects, multiple projects prompt with a finish choice, and finishing or a closed input exits zero without changes. The command:

- Prompts deferred classes for policy. Keeping `A` leaves the class deferred and non-blocking; choosing `B` or `C` asks for a local git repo path (blank keeps it deferred with the selected policy; one retry after an invalid path).
- Runs one `overmind-contract-reconciliation` session over every ready class whose `contract_reconciled` is not yet true, then sets that flag only on success.
- For git-backed projects, requires a clean project worktree before mutating, restricts the reconciliation unit to `init_progress_definition.yaml` and `common_contract_definition.md`, rolls back on unexpected changes, and offers a `Commit reconciliation results? [y/N]` prompt that commits exactly those two files with message `Update project reconciliation state`. Non-git projects reconcile without a commit prompt.

`overmind run` allows deferred policy `A` classes, refuses deferred policy `B`/`C` classes until repo paths are bound, and refuses ready-unreconciled classes until contract reconciliation finishes. `contract_reconciled: true` is the sole completion source; legacy `.contract_reconciled_<class>` markers are ignored.

Project init steps 1.1 and 2 run through the bundled CLI and TypeScript gates:

```bash
node .overmind/overmind.js project init --path projects/<project-id>
node .overmind/overmind.js gate stack-blueprint projects/<project-id>/project_stack_blueprint_backend.md
node .overmind/overmind.js context agents-md projects/<project-id> --class backend
node .overmind/overmind.js gate agents-md projects/<project-id>/project_agents_md_claude_md_backend.md
node .overmind/overmind.js gate common-contract projects/<project-id>
```

`project init` selects the next pending project init step. Type A projects run a stack-blueprint session and then an agents-md session for each active class before the common-contract session; type B/C projects advance directly to the common-contract session.
For type A projects, Overmind commits the step `1.1` stack baseline, prints `Continue with common contract definition? [Y/n]`, and continues into common contract definition on yes or blank input. Answering no pauses successfully; resume later with `node .overmind/overmind.js project init --path projects/<project-id>`.
Feature scaffolding refuses pending init or reconciliation checkpoints and prints the owning command (`project init` or `project reconcile`) before creating feature files.

## 7. Register And Assign Workers

From the installed ASDLC workspace root:

```bash
node .overmind/overmind.js worker register --path projects/<project-id>
node .overmind/overmind.js worker assign --feature-path projects/<project-id>/<feature-folder>
```

Registration writes `projects/<project-id>/workers.yaml` and reports the generated worker UUID. Assignment rewrites `#### Assigned:` lines in the feature `implementation_plan.md`.
