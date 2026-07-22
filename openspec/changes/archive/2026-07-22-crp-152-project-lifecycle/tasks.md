## 1. Absorbed helpers into parse/workspace

- [x] 1.1 Add repo-path validation/resolution to `packages/asdlc-coordinator/src/workspace/` (non-empty existing directory → canonical absolute path), replacing `validate_repo_path`/`resolve_repo_path`, with unit tests for empty/nonexistent/not-a-directory/empty-directory rejection and canonical resolution.
- [x] 1.2 Reuse `parse/project-definition.ts` `escapeYamlDoubleQuoted` for all quoted-scalar escaping (no new copy); confirm the project-type label mapping (A/B/C → label) lives with the creation module in task 2.

## 2. Project-creation primitive

- [x] 2.1 Add `packages/asdlc-coordinator/src/capture/project.ts` with injected clock/UUID/interaction/temp-fixture ports (temp-fixture for the `mktemp`-style atomic metadata/definition writes) and a typed result (`diagnostics` + `changedPaths`); implement name normalization (lowercase, non-alphanumeric→`_`, trim underscores) with empty/symbol-only rejection, preserving the original name for metadata.
- [x] 2.2 Implement project-type selection (A/B/C by number or letter, with labels) and the ordered class-selection loop (`backend|frontend|mobile|infrastructure`, canonical order, no duplicates, ≥1 required) via `InteractionPort`.
- [x] 2.3 Implement per-class ready/deferred capture: ready path validated via the workspace resolver (task 1.1) with re-prompt on invalid, deferred recorded with empty path.
- [x] 2.4 Implement folder-name `<normalized-name>-<uuid>` computation, existing-folder abort, folder creation, template copy of `.templates/init_progress_definition_TEMPLATE.yaml`, and `meta_info` injection above the template `steps:` block (`project_id`, ordered `project_classes`, `project_type_code`, `project_type_label`, `class_repo_paths` state/path), preserving unrelated template content.
- [x] 2.5 Implement `asdlc_metadata.yaml` shape assertion (`meta:` present, `projects:` present and final), terminal-blank-line normalization (the sole permitted change to prior content), and a content-preserving append of the `- project/name/internal_folder/created_at` record via the temp-fixture atomic-write seam; fail without mutation on malformed metadata.

## 3. Project-creation git seam

- [x] 3.1 Extend `packages/asdlc-coordinator/src/git/` with an injected project init/first-commit surface (extend `ProjectGitPort` or add a sibling port): `git init`, ensure identity with local fallback (`Overmind ASDLC`/`overmind-asdlc@local.invalid`) only when unset, stage the definition, and initial commit `Initialize ASDLC project workspace`.
- [x] 3.2 Wire the git seam into `capture/project.ts` after folder/definition creation; keep project git scope distinct from runtime-root/class-repo scopes.

## 4. Creation primitive tests

- [x] 4.1 Add `packages/asdlc-coordinator/test/capture/project.test.ts` covering: name slugification + empty/symbol-only rejection; type resolution + rejection; class ordering/dedup/≥1; ready-path validation re-prompt + deferred capture; template `meta_info`-above-`steps` injection with escaping; metadata shape assertion, trailing-blank normalization, byte-preservation, and malformed-metadata no-mutation; existing-folder abort.
- [x] 4.2 Test the git seam against the injected port: fresh init + fallback identity + initial commit, and configured-identity preservation; assert the typed result reports the project folder/definition and `asdlc_metadata.yaml` in `changedPaths` on success and a diagnostic (no partial success) on each failure.

## 5. CLI wiring

- [x] 5.1 Add a `create` subverb to the `project` branch in `packages/asdlc-coordinator/src/cli/run.ts` (`runProjectCreate`, no required options — prompts), rendering the typed result ("Created ASDLC project folder: …", "Updated ASDLC metadata: …") and correct exit codes; wire clock/UUID/git seams through `CliAdapterOverrides`; update the top-level usage string to include `project create`.
- [x] 5.2 Fold the reconciliation-intent guidance + confirm-before-reconcile (from `project_setup_update_project.sh`) into `runProjectReconcile` on the interactive path, treating decline/EOF as a clean abort (exit 0) and leaving `project_type_code` untouched.
- [x] 5.3 Add/extend CLI tests for `project create` (interactive success, argument/usage errors, EOF clean-stop) and for the reconcile guidance/confirm (guidance shown, decline aborts cleanly, `--path`/single-project paths still work).

## 6. Shell removal and docs

- [x] 6.1 Delete `overmind/scripts/project_mgmt/project_setup_add_new_project.sh`, `overmind/scripts/project_mgmt/project_setup_update_project.sh`, and `overmind/scripts/common_libs/project_setup_common.sh`.
- [x] 6.2 Delete `tests/ai_scripts/project_setup_update_project_tests.sh` and remove the `.commands`/`common_libs` staging for the three deleted scripts from `overmind/scripts/project_mgmt/project_setup_first_init_machine.sh`.
- [x] 6.3 Do **not** modify `tests/ai_scripts/project_setup_asdlc_tests.sh` (owned by Unit D). Grep the tree to confirm the only remaining references to the three deleted scripts are the Unit-D-owned suite/staging, and record the coordinated-landing dependency (see design Risks).
  - Active production/docs grep leaves only the Unit-D-owned `tests/ai_scripts/project_setup_asdlc_tests.sh` references; full-suite shell verification is coordinated with Unit D.
- [x] 6.4 Update `overmind/README.md`, `QUICKRUN.md`, and generated quick-run guidance to name `overmind project create` and `overmind project reconcile` instead of the shell commands.

## 7. Verification

- [ ] 7.1 Run the new package tests, then `npm run typecheck`, `npm run lint`, `npm run format:check`, `npm run build`, `npm test`.
- [ ] 7.2 Run `npm run verify` and `git diff --check`. Confirm no dangling references to the three deleted scripts remain except in the Unit-D-owned `project_setup_asdlc_tests.sh`/its staging; coordinate landing with Unit D (do not fix that suite here).
- [x] 7.3 Assert `packages/asdlc-coordinator/package.json` still has `"dependencies": {}` (no runtime dependency introduced).
- [x] 7.4 Run strict OpenSpec validation for this change (`openspec validate crp-152-project-lifecycle --strict`).
