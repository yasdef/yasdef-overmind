## 1. Installer-owned support-asset payload

- [x] 1.1 Add `packages/installer/_data/templates/` with `init_progress_definition_TEMPLATE.yaml` and `feature_br_summary_TEMPLATE.md` copied byte-for-byte from `overmind/templates/`; add `packages/installer/_data/setup/` with `models.md` and `external_sources.yaml` copied from `overmind/setup/`.
- [x] 1.2 Declare the runtime-template manifest (`init_progress_definition_TEMPLATE.yaml`, `feature_br_summary_TEMPLATE.md`) and setup manifest (`models.md`, `external_sources.yaml`) as constants in `packages/installer/src/init.ts`; do not stage any other `overmind/templates` file (each ships inside a packaged skill's `assets/`).

## 2. Extend `installProject` to a full fresh-workspace bootstrap

- [x] 2.1 Add required-source validation for the new payload in `installProject` (`packages/installer/src/init.ts`): fail fast with a clear, source-naming error if any runtime template or setup default is missing, before writing any workspace file; keep the existing CLI + packaged-skill validation.
- [x] 2.2 Install the runtime templates into the workspace `.templates/` directory (byte-for-byte from the payload) so `capture/project.ts` and `capture/scaffold-feature.ts` resolve their defaults.
- [x] 2.3 Install the setup defaults into `.setup/` with preserve-if-exists semantics for `models.md` and `external_sources.yaml` (never clobber operator configuration).
- [x] 2.4 Write the `asdlc_metadata.yaml` `meta:`/`projects:` scaffold only when absent (preserve a populated registry) and ensure the `projects/` directory exists.
- [x] 2.5 Generate `quickrun.md` in TypeScript (no heredoc) from the installer's skill manifest and the shipped `node .overmind/overmind.js` verb set; emit no `.sh` command. Do **not** create `.commands/`, `.helper/`, `.rules/`, or `.golden_examples/`, inject no `ASDLC_PROJECTS_DIR_DEFAULT`, and run no obsolete-command cleanup.
- [x] 2.6 Extend `InstallResult` with the installed runtime-template paths, installed setup-default paths, and the generated `quickrun.md` path (keep the existing `skillPath`/`skillPaths`; `skillPath` removal is Unit E / CRP-155).

## 3. Install bin output

- [x] 3.1 Update `packages/installer/src/bin/overmind.ts` to render a workspace-bootstrap summary from the extended `InstallResult` (CLI, skills, templates, setup defaults, quick-run) with TypeScript/npm commands only and no `.sh` reference.

## 4. Fresh-bootstrap installer tests

- [x] 4.1 Test full fresh install: executable `.overmind/overmind.js`, skill fan-out across `.codex`/`.claude` (byte-for-byte), `.templates/` runtime templates, `.setup/` defaults, `asdlc_metadata.yaml` scaffold, `projects/` directory, and generated `quickrun.md` all present.
- [x] 4.2 Test the installed CLI executes (spawn `node .overmind/overmind.js` with a harmless verb) and that runtime templates land at the paths `capture/project.ts` and `capture/scaffold-feature.ts` read.
- [x] 4.3 Test preserve-if-exists: a re-run over a modified `.setup/models.md`/`external_sources.yaml` and a populated `asdlc_metadata.yaml` leaves those untouched while refreshing package-owned CLI/skills/templates; assert no `.commands/`/`.helper/`/`.rules/`/`.golden_examples/` is created and no `ASDLC_PROJECTS_DIR_DEFAULT` injection occurs.
- [x] 4.4 Test required-source validation fails cleanly (non-zero, source-naming error, no partial workspace) when a runtime template or setup default is missing from the payload.
- [x] 4.5 Test generated `quickrun.md` names the expected `node .overmind/overmind.js` verbs and contains no `.sh` token; assert the install-bin output is likewise shell-free.

## 5. End-state zero-shell assertion

- [x] 5.1 Add an installer-package test asserting the repository-wide zero-shell end state: in a Git checkout `git ls-files '*.sh'` yields nothing, a Node-based first-party scan of `packages`, `overmind`, and `tests` with `node_modules` and `dist` pruned yields no `.sh`, and the packaged payload under `packages/installer/_data/` contains no `.sh`. No allow-list of permitted shell files.

## 6. Root wiring and shell removal

- [x] 6.1 Root `package.json`: add a `setup` script invoking the installer bin (`node packages/installer/dist/src/bin/overmind.js init`) as the source-repo bootstrap entry.
- [x] 6.2 Root `package.json`: remove `test:shell` and rewire `test` to run `test:ts` only, so `verify` composes typecheck + lint + format:check + build + TypeScript tests with no shell suite.
- [x] 6.3 Delete `overmind/scripts/project_mgmt/project_setup_first_init_machine.sh` and `tests/ai_scripts/project_setup_asdlc_tests.sh`; remove the now-empty `tests/ai_scripts/` directory.

## 7. Docs

- [x] 7.1 Update `README.md` and `QUICKRUN.md`: replace `overmind/scripts/project_mgmt/project_setup_first_init_machine.sh` bootstrap steps and the first-init-machine script description with the installer-based setup (`npm run setup` / `overmind init`); leave no active `.sh` invocation and no `.rules`/`.templates`/`.golden_examples`/`.helper` staging language.
- [x] 7.2 Update `AGENTS.md`: replace the `bash tests/ai_scripts/*.sh` test-command list and shell-test-location guidance with the TypeScript/npm commands (`npm test` / `npm run verify` and package-scoped tests); remove the `.sh`-scripts working rule if it no longer applies.

## 8. Verification

- [x] 8.1 Run the installer package tests (`npm run test --workspace overmind-installer` or `npm run test:ts`).
- [x] 8.2 Run `npm run typecheck`, `npm run lint`, `npm run format:check`, `npm run build`, `npm test`, `npm run verify` — all green; then `git diff --check`.
- [x] 8.3 Run the plan's end-state checks: `git ls-files '*.sh'` inside the checkout and the Node-based first-party scan of `packages`, `overmind`, and `tests` with `node_modules` and `dist` pruned — both must be empty.
- [x] 8.4 Confirm `packages/asdlc-coordinator/package.json` still has `"dependencies": {}` (no runtime dependency introduced).
- [x] 8.5 Grep the tree to confirm no residual active reference to `project_setup_first_init_machine.sh`, `project_setup_asdlc_tests.sh`, `tests/ai_scripts`, or `test:shell` outside historical design/OpenSpec artifacts.
- [x] 8.6 Run strict OpenSpec validation (`openspec validate crp-154-installer-cutover --strict`).
