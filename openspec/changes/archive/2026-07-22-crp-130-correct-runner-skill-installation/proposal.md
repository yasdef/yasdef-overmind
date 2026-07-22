## Why

CRP-129 added the `overmind-task-to-br` skill and the shared `.overmind/overmind.js` runtime CLI, but runtime ASDLC setup currently stages only the CLI and leaves Codex without `.codex/skills/overmind-task-to-br/`. Operators using Codex from a real ASDLC workspace therefore cannot invoke the migrated skill even though the CLI is present.

## What Changes

- Add correct runner skill installation for the packaged `overmind-task-to-br` skill while keeping `.overmind/overmind.js` as the single shared runtime CLI.
- Update the installer and ASDLC setup/update path so a generated ASDLC workspace receives the skill under Codex-compatible runner layout: `.codex/skills/overmind-task-to-br/`.
- Preserve the existing Claude install path `.claude/skills/overmind-task-to-br/`; do not move or duplicate the runtime CLI into runner-specific skill folders.
- Add tests proving fresh setup and update repair install both `.overmind/overmind.js` and runner skill files into the staged ASDLC workspace.
- Align quickrun/docs so setup guidance says `npm install`, `npm run build`, then setup stages the CLI plus runner skills.

## Capabilities

### New Capabilities
- `runner-skill-installation`: installation of packaged Overmind skills into supported runner skill directories in a runtime ASDLC workspace, with `.overmind/overmind.js` remaining the shared CLI used by those skills.

### Modified Capabilities
<!-- None — openspec/specs/ is empty; there are no existing main specs whose requirements change. -->

## Impact

- **Affected code:** `packages/installer/src/init.ts`, `packages/installer/test/init.test.ts`, `overmind/scripts/project_mgmt/project_setup_first_init_machine.sh`, and ASDLC setup tests under `tests/ai_scripts/`.
- **Affected runtime workspace:** generated ASDLC roots gain `.codex/skills/overmind-task-to-br/` and keep `.claude/skills/overmind-task-to-br/` plus `.overmind/overmind.js`.
- **Dependencies:** no new runtime dependency; still requires the built bundled CLI from `npm run build`.
- **Non-breaking:** existing `.overmind/overmind.js` path and commands remain unchanged.
