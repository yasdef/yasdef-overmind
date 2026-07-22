## Why

Two shell files remain in the repository: `overmind/scripts/project_mgmt/project_setup_first_init_machine.sh` (the ASDLC workspace deployment boundary) and `tests/ai_scripts/project_setup_asdlc_tests.sh` (its 1751-line shell suite). Units A/B/C already moved worker lifecycle, project lifecycle, and project-init steps 1.1/2 into TypeScript; only the deployment boundary and the shell test harness are left. This is Unit D of `design_docs/e2e_orchestrator_migration/06_sh_remove_plan.md`: make `packages/installer` the fresh-workspace deployment boundary, delete the last two shell files and the whole shell test wiring, and land the repository-wide zero-shell end state. Overmind has never been installed, so the first-init machine is behavior *reference* and a fresh install boundary only — no upgrade path, no deployed-shell cleanup, no historical staging inventory to preserve.

## What Changes

- Extend `packages/installer` from skill-only installation to complete fresh ASDLC workspace bootstrap. `overmind init` installs, in one deterministic pass: the runtime CLI `.overmind/overmind.js`, every packaged skill for every supported runner (`.codex`/`.claude`), the runtime templates deterministic creation needs (`.templates/init_progress_definition_TEMPLATE.yaml`, `.templates/feature_br_summary_TEMPLATE.md`), the setup defaults (`.setup/models.md`, `.setup/external_sources.yaml`), the `asdlc_metadata.yaml` registry scaffold, the `projects/` directory, and generated `quickrun.md` operator guidance. All support assets are copied from an installer-owned payload under `packages/installer/_data/`; guidance is generated in TypeScript with no shell heredocs.
- Preserve the deployment-boundary invariants that still apply to a fresh install: required-source validation before any write (fail fast if a packaged skill, runtime template, or setup default is missing), executable CLI installation, byte-for-byte skill installation, and preserve-if-exists semantics for `.setup/models.md` and `.setup/external_sources.yaml`. Because nothing was ever deployed, drop all upgrade/update-mode behavior, the injected `ASDLC_PROJECTS_DIR_DEFAULT` command rewrite, obsolete-staged-command cleanup, and the `.commands`/`.helper`/`common_libs`/`.rules`/`.golden_examples` staging that only existed to serve shell-driven model sessions.
- Write fresh-bootstrap installer tests: skill fan-out across runners, CLI executes, runtime templates and setup defaults land at their expected paths with preserve-if-exists behavior, generated guidance names only TypeScript/npm commands, and required-source validation fails cleanly on a missing payload.
- Add a source-repo setup invocation to root `package.json` so the workspace is bootstrapped through the installer (`node packages/installer/dist/src/bin/overmind.js init`) instead of the shell script; update `README.md`, `QUICKRUN.md`, and `AGENTS.md` to TypeScript/npm commands only (no `.sh` invocation, no `bash tests/ai_scripts/...` command list).
- Delete `overmind/scripts/project_mgmt/project_setup_first_init_machine.sh` and `tests/ai_scripts/project_setup_asdlc_tests.sh`; remove all remaining shell staging code, the `test:shell` script and its `test` composition in root `package.json`, and the now-empty `tests/ai_scripts/` directory.
- Add a single end-state zero-shell assertion (an installer-package test) over versioned files and packaged assets, asserting `git ls-files '*.sh'` and the packaged installer payload contain no `.sh` file. This replaces the transitional inventory guard entirely — there is no longer a set of "allowed" shell files to track.

## Capabilities

### New Capabilities

- `workspace-bootstrap`: `overmind init` bootstraps a complete fresh ASDLC workspace from an installer-owned payload — runtime CLI, packaged-skill fan-out across supported runners, runtime templates for deterministic creation, `.setup` defaults with preserve-if-exists, `asdlc_metadata.yaml` scaffold, `projects/` directory, and generated `quickrun.md` — with required-source validation and no upgrade/update-mode surface.
- `zero-shell-closure`: the repository reaches and asserts a zero-shell end state — the last two shell files and all shell test wiring (`test:shell`, `tests/ai_scripts/`) are removed, root `package.json` bootstraps through the installer, docs carry no active shell invocation, and a single versioned-files-and-packaged-assets assertion guarantees no `.sh` file remains.

### Modified Capabilities

<!-- None. The installer's prior skill-only behavior and the first-init machine's staging live only in code and shell, not in any archived OpenSpec main spec. Both concerns are captured as new capabilities in this change. -->

## Impact

- Extends `packages/installer/src/init.ts`: `installProject` gains runtime-template, setup-default, metadata-scaffold, `projects/` and generated-`quickrun.md` installation plus required-source validation for the new payload; `InstallResult` grows the installed template/setup/guidance paths. Removes no existing skill fan-out. (The `InstallResult.skillPath` compatibility field is left to Unit E / CRP-155.)
- Adds an installer-owned support-asset payload under `packages/installer/_data/` (`_data/templates/`, `_data/setup/`) sourced from `overmind/templates` and `overmind/setup`; updates `packages/installer/src/bin/overmind.ts` install output to report the bootstrapped workspace.
- Adds fresh-bootstrap and zero-shell tests under `packages/installer/test/`.
- Root `package.json`: adds a `setup` script invoking the installer; removes `test:shell` and rewires `test` to `test:ts` only.
- Deletes `overmind/scripts/project_mgmt/project_setup_first_init_machine.sh` and `tests/ai_scripts/project_setup_asdlc_tests.sh`; removes the now-empty `tests/ai_scripts/` directory. After this change `git ls-files '*.sh'` and `find packages overmind tests -type f -name '*.sh'` are both empty.
- Updates `README.md`, `QUICKRUN.md`, and `AGENTS.md` to TypeScript/npm bootstrap and test commands only. `packages/asdlc-coordinator` runtime `dependencies` stay `{}`.
