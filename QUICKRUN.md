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

## 3. Bootstrap Or Refresh ASDLC Workspace

From this repo root, after `npm install` and `npm run build`:

```bash
overmind/scripts/project_mgmt/project_setup_first_init_machine.sh
```

The setup stages `packages/asdlc-coordinator/dist/overmind.js` into the ASDLC workspace as `.overmind/overmind.js`, plus packaged skills into the supported runner skill directories. The current set includes `overmind-task-to-br`, `overmind-repo-br-scan`, `overmind-br-clarification`, `overmind-requirements-ears`, `overmind-ears-review`, and `overmind-contract-delta`.

- `.overmind/overmind.js`
- `.codex/skills/overmind-task-to-br/`
- `.claude/skills/overmind-task-to-br/`
- `.codex/skills/overmind-contract-delta/`
- `.claude/skills/overmind-contract-delta/`

## 4. Install Overmind Into A Runtime Project

From the target project root:

```bash
node /path/to/yasdef-overmind/packages/installer/dist/src/bin/overmind.js init
```

This creates:

- `.overmind/overmind.js`
- `.codex/skills/overmind-task-to-br/`
- `.claude/skills/overmind-task-to-br/`
- `.codex/skills/overmind-contract-delta/`
- `.claude/skills/overmind-contract-delta/`

## 5. Run Task-To-BR Helpers

From the installed project root:

```bash
node .overmind/overmind.js capture task-to-br <feature-path> --source-file <path-to-story.md-or.txt>
node .overmind/overmind.js capture task-to-br <feature-path> --jira <ticket>
node .overmind/overmind.js context task-to-br <feature-path>
node .overmind/overmind.js gate task-to-br <feature-path>
```

The skill owns the loop: capture `user_br_input.md` when missing, run context, update `feature_br_summary.md` and `missing_br_data.md`, run gate, repair on exit `1`, stop on exit `2`. Jira capture records `jira:<ticket>` first; context then tells the agent to fetch and persist the story text through a configured Jira MCP source.

## 6. Run Contract-Delta Helpers

From the installed ASDLC workspace root:

```bash
node .overmind/overmind.js sync contract-delta <feature-path>
node .overmind/overmind.js context contract-delta <feature-path>
node .overmind/overmind.js gate contract-delta <feature-path>
```

The transitional feature orchestrator runs `sync` before loading `overmind-contract-delta`; the skill owns the context/write/gate/repair loop.
