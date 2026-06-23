## Context

CRP-129 introduced the TypeScript `overmind` CLI bundle and the `overmind-task-to-br` skill, but it left two installation paths with different behavior. `project_setup_first_init_machine.sh` stages only `.overmind/overmind.js` into a runtime ASDLC workspace. The TypeScript installer copies the skill only to `.claude/skills/overmind-task-to-br/`. A real Codex-oriented ASDLC workspace can therefore contain `.overmind/overmind.js` and `.codex/config.toml`, but no `.codex/skills/overmind-task-to-br/`.

The migration architecture expects skills to be available to the active runner while all deterministic mechanics stay in the shared CLI. This change closes that provisioning gap for the supported local runners without changing the runtime CLI path.

## Goals / Non-Goals

**Goals:**
- Install the packaged `overmind-task-to-br` skill into Codex and Claude runner skill directories in generated ASDLC workspaces.
- Keep `.overmind/overmind.js` as the only staged runtime CLI bundle; skills continue to call `node .overmind/overmind.js capture|context|gate ...`.
- Make both installation paths consistent: TypeScript `overmind init` and legacy ASDLC `project_setup_first_init_machine.sh` setup/update both provision the same skill payload.
- Add tests covering fresh setup and update repair for the runner skill directories.

**Non-Goals:**
- Do not change `overmind-task-to-br` behavior, prompt contents, asset-relative path contract, or CLI commands.
- Do not add a second CLI under `.codex/skills`, `.claude/skills`, or any runner-specific folder.
- Do not implement `.github/skills` or `.agents/skills` fan-out until those runner layouts are validated in this repo.
- Do not migrate `project_setup_first_init_machine.sh` itself to TypeScript in this change.

## Decisions

- **Codex and Claude are the supported runner targets for this change.** Codex is required because the real ASDLC workspace is Codex-driven and already has `.codex/config.toml`; Claude remains supported because CRP-129 installed the pilot skill there. GitHub and generic agents stay deferred to avoid creating untested runner directories.
- **Copy the canonical skill source into each runner directory.** The source remains `packages/installer/_data/skills/overmind-task-to-br/`. Installation copies the complete folder, including `SKILL.md` and `assets/`, to `.codex/skills/overmind-task-to-br/` and `.claude/skills/overmind-task-to-br/`.
- **Keep shared mechanics outside runner skill folders.** `.overmind/overmind.js` remains the single runtime CLI location. This avoids per-runner drift and preserves the CRP-129 context output that intentionally avoids hardcoded runner install paths.
- **Legacy setup directly stages the skill payload.** Until setup is migrated to TypeScript, `project_setup_first_init_machine.sh` should copy the skill source itself instead of invoking `npm` or the TypeScript installer. It already requires a built CLI bundle; it should also require the packaged skill source.
- **Update mode repairs packaged skill files.** The skill is package-owned, so setup/update and installer runs may overwrite the installed skill folder from canonical source. Runtime project artifacts under `projects/` are not touched.

## Risks / Trade-offs

- **Runner-specific format drift** → Keep the target set to known local runner layouts only: `.codex/skills` and `.claude/skills`.
- **Overwriting local edits inside installed skill folders** → Treat installed skills as generated package payload; operators should edit canonical source in this repo, not generated ASDLC copies.
- **Setup script remains bash while installer is TypeScript** → Keep the bash staging logic narrow and file-copy only; no npm/build work is added to runtime setup.
- **Docs can imply broader fan-out than implemented** → Update quickrun/readme wording to say CRP-130 supports Codex and Claude, while broader runner fan-out is still future work.

## Migration Plan

1. Update the TypeScript installer to install the skill to both `.codex/skills/overmind-task-to-br/` and `.claude/skills/overmind-task-to-br/`, and expose both installed paths in its result.
2. Update installer tests to assert both runner skill folders contain `SKILL.md` and assets while `.overmind/overmind.js` stays unchanged.
3. Add skill-source staging to `project_setup_first_init_machine.sh` for fresh setup and update mode.
4. Extend ASDLC setup tests to cover fresh installation, update repair of missing skill directories, and missing skill source failure.
5. Update docs/quickrun to explain that setup stages `.overmind/overmind.js` plus Codex/Claude skill folders.
6. Run `npm test`, focused setup shell tests, `git diff --check`, and OpenSpec validation.

Rollback: revert this change. Existing CRP-129 behavior remains: `.overmind/overmind.js` staged by setup and `.claude/skills` installed only through the TypeScript installer.

## Open Questions

None. `.github/skills` and `.agents/skills` remain deferred until their expected local layouts are validated.
