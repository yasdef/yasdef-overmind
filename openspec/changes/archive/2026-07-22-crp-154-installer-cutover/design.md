## Context

Two shell files remain after Units A/B/C landed:

- `overmind/scripts/project_mgmt/project_setup_first_init_machine.sh` (835 lines) — the ASDLC workspace deployment boundary. Interactively resolves a parent directory, then in bootstrap **or** update mode stages: `.overmind/overmind.js` (from `packages/asdlc-coordinator/dist/overmind.js`), every packaged skill into `.codex/skills/` and `.claude/skills/`, `.rules`/`.templates`/`.golden_examples`/`.helper`/`.setup` support assets, `.commands` (with an injected `ASDLC_PROJECTS_DIR_DEFAULT` rewrite and obsolete-command cleanup), the `asdlc_metadata.yaml` scaffold, the `projects/` and `.commands` directories, and a heredoc `quickrun.md`.
- `tests/ai_scripts/project_setup_asdlc_tests.sh` (1751 lines) — its shell suite, iterated by the root `test:shell` script.

This is Unit D of `design_docs/e2e_orchestrator_migration/06_sh_remove_plan.md`. The already-migrated `packages/installer` is the baseline this change extends: it already installs `.overmind/overmind.js` (via `getBundledOvermindPath()`), validates and byte-copies all 16 packaged skills into `.codex`/`.claude`, and refreshes stale skill folders. `capture/project.ts` already reads `.templates/init_progress_definition_TEMPLATE.yaml` and `capture/scaffold-feature.ts` reads `.templates/feature_br_summary_TEMPLATE.md` at runtime; the runner and context builders read `.setup/models.md` and `.setup/external_sources.yaml`. No coordinator runtime code references `.rules`, `.golden_examples`, `.helper`, or `.commands` — those staged trees only fed the retired shell-driven model sessions, whose assets now live inside the packaged skills.

Overmind has never been installed. There is no deployed workspace to upgrade, so the first-init machine is behavior *reference* and a fresh-install boundary only. The contracts of record are the runtime file paths the coordinator reads (`.templates/…`, `.setup/…`, `.overmind/overmind.js`, `<runner>/skills/…`) and the artifact templates, not the shell's staging ceremony.

## Goals / Non-Goals

**Goals:**

- Make `packages/installer` the complete fresh-workspace deployment boundary. `overmind init` installs the runtime CLI, the packaged-skill fan-out, the runtime templates deterministic creation needs (`.templates/init_progress_definition_TEMPLATE.yaml`, `.templates/feature_br_summary_TEMPLATE.md`), the `.setup` defaults (`models.md`, `external_sources.yaml`, preserve-if-exists), the `asdlc_metadata.yaml` scaffold, the `projects/` directory, and a TypeScript-generated `quickrun.md`.
- Preserve the still-applicable deployment invariants: required-source validation before any write, executable CLI installation, byte-for-byte skill installation, and preserve-if-exists for setup defaults. Drop everything that only existed for a redeploy: update mode, the `ASDLC_PROJECTS_DIR_DEFAULT` rewrite, obsolete-command cleanup, and `.commands`/`.helper`/`.rules`/`.golden_examples` staging.
- Own the support-asset payload inside the installer package (`packages/installer/_data/templates/`, `packages/installer/_data/setup/`) mirroring the existing `_data/skills/`, so the installer is self-contained and its "exact support-asset manifest" is versioned in one place.
- Add a source-repo setup invocation to root `package.json`; delete the two shell files; remove the `test:shell` script and rewire `test`; remove the empty `tests/ai_scripts/`; update `README.md`, `QUICKRUN.md`, and `AGENTS.md` to TypeScript/npm only.
- Add one end-state zero-shell assertion over versioned files and the packaged payload, and land `npm run verify` green with the full repository at zero shell.

**Non-Goals:**

- Worker lifecycle (Unit A / CRP-151), project create + reconcile (Unit B / CRP-152), and project-init steps 1.1/2 (Unit C / CRP-153) — all landed.
- Removing `InstallResult.skillPath` and the singular "Installed skill to …" CLI line — that back-compat residue is Unit E / CRP-155. This change adds new result fields and the workspace-summary output around it but does not delete the `skillPath` field.
- Any new runner beyond `.codex`/`.claude`, any new CLI flag/option beyond the existing `overmind init`, and any change to `.setup/models.md`'s pipe-table format.
- Re-authoring skill assets or templates; this change moves/copies the existing template + setup sources into the installer payload without editing their content.
- Porting the 1751-line shell suite scenario-for-scenario; the installer's TypeScript tests specify correct fresh-install behavior against the runtime path contracts, consulting the shell suite only for genuine edge cases.

## Decisions

### 1. Installer owns a `_data/` support-asset payload; runtime manifest is only what the coordinator reads

The installer already owns `_data/skills/`. This change adds `_data/templates/` and `_data/setup/` under the same package, sourced from `overmind/templates` and `overmind/setup`. The **runtime template manifest** is exactly the two files the coordinator reads at runtime — `init_progress_definition_TEMPLATE.yaml` (`capture/project.ts`) and `feature_br_summary_TEMPLATE.md` (`capture/scaffold-feature.ts`) — not the full `overmind/templates` set, because every other template now ships inside a packaged skill's `assets/`. The **setup manifest** is `models.md` + `external_sources.yaml`. *Alternative:* stage from `overmind/templates`/`overmind/setup` at install time (as the shell did) — rejected; the installer is a publishable package that must be self-contained and must not reach outside its own tree, and the "exact support-asset manifest under installer ownership" belongs versioned in `_data/`.

### 2. Drop the `.rules`/`.golden_examples`/`.helper`/`.commands` staging entirely

No coordinator runtime code reads these trees; they existed only to feed the shell's model sessions, whose rule prose and golden examples now live inside the packaged skills. A fresh workspace therefore needs none of them. *Alternative:* keep staging them "for safety" — rejected; it would reintroduce dead payload and re-open the staging inventory the plan is closing. Architecture invariant 5 (skills carry prose + assets; parsing/mutation/gates are TypeScript) makes the skill the single home for that content.

### 3. Fresh-install boundary only — no update mode, no `ASDLC_PROJECTS_DIR` rewrite, no obsolete cleanup

Because nothing was ever deployed, there is no prior workspace to reconcile. `installProject` performs an idempotent fresh install: it always (re)writes package-owned payload (CLI, skills, templates) and preserves operator-owned setup defaults and the `asdlc_metadata.yaml` registry if present. The shell's update mode, the `ASDLC_PROJECTS_DIR_DEFAULT` awk-injection into staged commands, and `OBSOLETE_STAGED_COMMAND_FILES` cleanup are all deleted — there are no staged shell commands to rewrite or clean. *Alternative:* port update mode for future re-runs — rejected as unrequested surface; re-running `overmind init` on an existing workspace already refreshes package-owned payload and preserves operator files, which covers the only real reinstall case.

### 4. `asdlc_metadata.yaml` scaffold and `projects/` creation move into `installProject`, preserve-if-exists

Bootstrap must leave a workspace `overmind project create` can immediately append to: an `asdlc_metadata.yaml` with the `meta:`/`projects:` scaffold and a `projects/` directory. `installProject` writes the scaffold only when absent (never clobbering a registry that already lists projects) and ensures `projects/` exists. This mirrors the shell's `write_metadata_scaffold`/`create_bootstrap_directories` without the `.commands` directory. *Alternative:* let `overmind project create` create the registry lazily — rejected; the plan makes the installer the deployment boundary that produces a ready-to-use workspace, and `capture/project.ts` expects the registry path to exist.

### 5. `quickrun.md` is generated in TypeScript from the shipped verb set

The heredoc `write_quickrun_guide` becomes a TypeScript generator that emits the same operator guidance keyed to the current `node .overmind/overmind.js` verbs (project create/reconcile/init, worker register/assign, run, scaffold, status, context/gate flows) and the staged runner skill directories. No `.sh` command appears. Generating (not copying) keeps guidance close to the installer's own manifest so the two cannot drift. *Alternative:* ship a static `quickrun.md` asset in `_data/` — rejected; the guide names the exact installed skill set and workspace paths the installer controls, so generating from that manifest avoids a second source of truth. (Invariant 3: runtime mutation/content generation lives in typed installer code, not shell.)

### 6. `InstallResult` grows workspace-summary fields; the bin renders from them

`installProject` returns the CLI path, installed skill paths, installed runtime-template paths, installed setup-default paths, and the generated `quickrun.md` path. `bin/overmind.ts` renders a workspace-bootstrap summary from those fields instead of the single "Installed skill to …" line. The legacy singular `skillPath` field stays (Unit E removes it), so this change is additive to the result shape and does not disturb Unit E's separately-scoped deletion. *Alternative:* fold the Unit E cleanup in here — rejected; the plan scopes `skillPath` removal to Unit E to keep each change's diff and acceptance crisp.

### 7. Root `package.json`: add `setup`, remove `test:shell`, rewire `test`

Add a `setup` script invoking the installer bin (`node packages/installer/dist/src/bin/overmind.js init`) as the source-repo bootstrap entry. Delete `test:shell` and its `test:ts && test:shell` composition so `test` runs `test:ts` only; `verify` (typecheck + lint + format:check + build + test) then runs green with no shell suite. This is the step that flips the whole repository to zero-shell-runnable. *Alternative:* keep `test:shell` as an empty no-op — rejected; the plan removes the wiring, and an empty glob loop is dead code.

### 8. One end-state zero-shell assertion in the installer package

A single installer-package test asserts the repository end state: `git ls-files '*.sh'` yields nothing, `find packages overmind tests -type f -name '*.sh'` yields nothing, and the packaged payload under `packages/installer/_data/` contains no `.sh`. This replaces the transitional inventory guard — there is no allow-list of permitted shell files anymore, just the invariant that none exist. Placing it in the installer package keeps it in the TypeScript suite that `verify` runs. *Alternative:* a standalone shell/CI check — rejected; a `.sh` guard-of-shell would violate the very end state, and the assertion belongs in the suite that gates every build.

## Risks / Trade-offs

- **The runtime template manifest is under-inclusive and a runtime read fails** → derive the manifest from the actual coordinator reads (grep of `.templates/` usage yields exactly `init_progress_definition_TEMPLATE.yaml` and `feature_br_summary_TEMPLATE.md`), add required-source validation for each, and add a bootstrap test that both files exist at their runtime paths and that `overmind project create`/`scaffold feature` resolve their defaults against the installed workspace.
- **Dropping `.rules`/`.golden_examples` breaks a model session that still reads a staged path** → confirmed by grep that no coordinator runtime code and no packaged SKILL.md references a workspace `.rules`/`.golden_examples` path (skills reference their own `assets/`); cover a full init/feature dry-run in the installer/coordinator tests to catch a stray staged-path assumption.
- **Setup-default clobber destroys operator config on re-run** → preserve-if-exists for `.setup/models.md` and `.setup/external_sources.yaml` and for `asdlc_metadata.yaml`; add a test that a re-run over a modified `.setup/models.md` and a populated `asdlc_metadata.yaml` leaves both untouched while refreshing package-owned CLI/skills/templates.
- **Generated `quickrun.md` drifts from the shipped verbs** → generate it from the installer's own skill manifest and the current verb set, and assert in a test that it contains no `.sh` token and names the expected `node .overmind/overmind.js` verbs.
- **`test:shell` removal hides a scenario the shell suite uniquely covered** → before deleting `project_setup_asdlc_tests.sh`, port its genuinely load-bearing fresh-install assertions (skill fan-out, CLI executes, required-source failure, preserve-if-exists) into the installer TypeScript tests; the update-mode and staged-command scenarios are intentionally dropped with the behavior they covered.
- **Zero-shell assertion is order-sensitive with the file deletions** → make the assertion a plain filesystem/git scan run in the installer suite so it fails loudly if any deletion is missed, and run the two `git ls-files`/`find` commands from the plan's Verification section as the final manual gate.

## Migration Plan

1. Add the installer-owned payload: copy `overmind/templates/{init_progress_definition_TEMPLATE.yaml,feature_br_summary_TEMPLATE.md}` into `packages/installer/_data/templates/` and `overmind/setup/{models.md,external_sources.yaml}` into `packages/installer/_data/setup/`.
2. Extend `installProject` (`packages/installer/src/init.ts`): install runtime templates into `.templates/`, setup defaults into `.setup/` (preserve-if-exists), write the `asdlc_metadata.yaml` scaffold (preserve-if-exists) and create `projects/`, and generate `quickrun.md` in TypeScript. Add required-source validation for the new template/setup payload. Extend `InstallResult` with the new installed paths (keep `skillPath`).
3. Update `packages/installer/src/bin/overmind.ts` to render a workspace-bootstrap summary from the extended result.
4. Write fresh-bootstrap installer tests: skill fan-out, CLI executes, runtime templates + setup defaults at expected paths, preserve-if-exists, generated guidance is shell-free and names the TypeScript verbs, required-source validation fails cleanly, and re-run idempotency.
5. Add the end-state zero-shell assertion test in the installer package.
6. Root `package.json`: add `setup`, remove `test:shell`, rewire `test` to `test:ts`.
7. Delete `overmind/scripts/project_mgmt/project_setup_first_init_machine.sh` and `tests/ai_scripts/project_setup_asdlc_tests.sh`; remove the now-empty `tests/ai_scripts/` directory.
8. Update `README.md`, `QUICKRUN.md`, and `AGENTS.md` to TypeScript/npm bootstrap and test commands only; grep the tree for residual references to the deleted scripts and to `tests/ai_scripts`/`test:shell`.
9. Verify: installer package tests, then `npm run typecheck|lint|format:check|build|test|verify`, `git diff --check`, and the two zero-shell commands (`git ls-files '*.sh'`, `find packages overmind tests -type f -name '*.sh'`) both empty. Confirm `packages/asdlc-coordinator` runtime `dependencies` stay `{}`.

Rollback restores the two shell files, the `test:shell` wiring, and the prior docs; no persisted state migrates because nothing was ever installed.

## Open Questions

- None blocking. The runtime template manifest is fixed by the coordinator's actual `.templates/` reads; the setup manifest matches the shell's `STAGED_SETUP_FILES`. The exact `quickrun.md` wording is generated from the installer's skill manifest and the shipped verb set during implementation, matching the guidance already in `README.md`/`QUICKRUN.md`.
