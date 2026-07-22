## Context

Project creation and project update are the last operator surfaces in the project-lifecycle group still implemented as pre-TypeScript shell. Three scripts own them:

- `project_setup_add_new_project.sh` — prompts for project name (normalizes to a slug), an ordered class selection, per-class ready/deferred repo capture, and project type (`A`/`B`/`C`); generates an epoch-ms UUID and a UTC `created_at`; creates `projects/<slug>-<uuid>/`, copies `init_progress_definition_TEMPLATE.yaml`, injects a `meta_info` block above the template `steps:` block, `git init`s the project folder with a local-identity fallback and an initial commit, and appends a project record to `asdlc_metadata.yaml` (asserting `meta`/`projects` shape first).
- `project_setup_update_project.sh` — discovers projects, prompts the operator to pick one, prints the reconciliation-intent guidance (attach + one-time contract reconciliation + optional commit), confirms, and then delegates to `node .overmind/overmind.js project reconcile --path <project_dir>`. Its only real work today is selection + guidance + hand-off.
- `project_setup_common.sh` — shared helpers: `project_type_label_for_code` (A/B/C → label), `escape_yaml_double_quoted_value`, `validate_repo_path`, `resolve_repo_path`.

This is Unit B of `design_docs/e2e_orchestrator_migration/06_sh_remove_plan.md`. Per that plan's framing, Overmind has never been installed, so these scripts are behavior *reference*, not a deployed contract: the artifact contracts of record are the `asdlc_metadata.yaml` record shape, the `init_progress_definition.yaml` `meta_info`/`steps` structure, the `init_progress_definition_TEMPLATE.yaml` template, and the operator interaction flow. The already-migrated coordinator is the baseline this change extends and reuses: `cli/run.ts` dispatch (including the existing `overmind project reconcile` and its project-selection block), `InteractionPort`, the injected-clock pattern in `capture/scaffold-feature.ts`, `parse/project-definition.ts` (which already exports `escapeYamlDoubleQuoted`, `readProjectDefinitionMetadata`, `applyClassAttachment`, and a `ProjectGitPort`/`RepoGitProjectAdapter`), and `workspace/` discovery/resolution. `packages/asdlc-coordinator` runtime `dependencies` are empty and stay empty.

Note on git: unlike the worker primitives (Unit A), project *creation* genuinely performs git work — `git init`, an identity fallback, staging the definition, and an initial commit — so this change wires a project-creation git seam (see Decision 4).

## Goals / Non-Goals

**Goals:**

- Move project creation into a deterministic coordinator primitive (`capture/project.ts`) invoked through `overmind project create`, with injected clock/UUID/interaction/temp-fixture/git ports for deterministic tests.
- Preserve the artifact contracts: project ID/name normalization, type selection, ordered class selection, ready/deferred repo capture, canonical path validation, `asdlc_metadata.yaml` append (with shape assertion + trailing-blank normalization), definition-template population with the `meta_info` block, project-folder creation, project `git init` with local-identity fallback, and the initial commit.
- Make `overmind project reconcile` the sole update path, folding the still-useful project-selection and reconciliation-intent guidance from the update wrapper into the reconcile CLI flow.
- Absorb the reusable `project_setup_common.sh` helpers into `capture/project.ts`, `parse/`, and `workspace/` where they architecturally belong, reusing the existing `escapeYamlDoubleQuoted`.
- Delete the three shell files and the update shell suite in this change; remove their command staging; leave `npm run verify` green.

**Non-Goals:**

- Worker lifecycle (Unit A / CRP-151), init steps 1.1 and 2 (Unit C), installer cutover and the repository-wide zero-shell assertion (Unit D), and back-compat residue (Unit E).
- Porting `project_setup_update_project_tests.sh` scenario-for-scenario; TypeScript tests specify correct behavior against the contracts, consulting the shell suite only for genuine edge cases.
- Any new flags/options beyond `overmind project create` and the existing `overmind project reconcile --path`. `project create` reads its inputs interactively, matching the shell.
- Manipulating the legacy project-level `project_type_code` during reconcile (the wrapper deliberately does not, to keep the reconcile clean-worktree/commit unit intact); `project create` still records it because the definition contract carries it.
- Modifying `tests/ai_scripts/project_setup_asdlc_tests.sh` (owned by Unit D), which also stages these scripts.

## Decisions

### 1. `capture/project.ts` for creation, reusing `parse/`/`workspace/` for absorbed helpers

Project creation is an artifact-capture concern (create the project folder, definition, metadata record) and belongs alongside `capture/scaffold-feature.ts`, so the primitive lives in `capture/project.ts`. The `project_setup_common.sh` helpers are split by where they architecturally belong rather than dumped into one file: YAML escaping reuses the existing `parse/project-definition.ts` `escapeYamlDoubleQuoted` (no new copy); repo-path validation/resolution (non-empty existing directory → canonical absolute path) lands in `workspace/` next to the other path resolution; and project-type labels (A/B/C → label) live with the creation primitive that consumes them. *Alternative:* a standalone `capture/project-setup-common.ts` mirroring the shell file — rejected; it would duplicate `escapeYamlDoubleQuoted` and split path logic away from `workspace/`.

### 2. Line-oriented parse/mutate, not a YAML AST

The contracts are line-shaped: the metadata record is a fixed four-line block appended under `projects:`, and the definition `meta_info` block is injected above the template `steps:` block. To preserve unrelated content and avoid a runtime dependency, creation composes and mutates line-oriented text (matching the shell and the existing `parse/`/`capture/` approach), including the shell's metadata-shape assertion (`meta:` and `projects:` present, `projects:` the final top-level section) and trailing-blank-line normalization before the append. *Alternative:* a YAML library — rejected; it reformats unrelated content and breaks the empty-`dependencies` invariant.

### 3. Injected clock, UUID, interaction, and temp-fixture ports

Creation needs a UUID (the shell uses epoch-ms as the project's unique suffix) and a UTC `created_at`; both are injected (a clock returning the ISO/UTC timestamp and a UUID/id generator, following `ScaffoldClock`) so tests are deterministic and folder names are stable. Name normalization, class selection loop, per-class ready/deferred capture, repo-path entry, and type selection all go through the existing `InteractionPort` (`select`/`input`), reusing its EOF-as-clean-stop semantics. The shell's `mktemp`-based atomic writes (temp file → `mv`) for the metadata append and the definition population are preserved as an injected temp-fixture port so tests control temp-file placement deterministically. The primitive returns a typed result carrying `diagnostics` and `changedPaths` (the created folder/definition and the mutated `asdlc_metadata.yaml`), and the CLI derives its stdout/stderr and exit code from that result — never by scraping printed text — matching `runProjectReconcile` and `registerWorker`. *Alternative:* reading the system clock / `crypto.randomUUID` / `Date.now()` directly inside the module — rejected; non-deterministic and untestable.

### 4. A project-creation git seam (init + identity fallback + initial commit)

Project creation is the one lifecycle primitive that legitimately commits: `git init -q`, ensure `user.name`/`user.email` (falling back to the local `Overmind ASDLC`/`overmind-asdlc@local.invalid` identity only when unset), stage the definition file, and create the initial `Initialize ASDLC project workspace` commit. This is exposed as an injected git port so tests run without touching a real repo. The existing `ProjectGitPort`/`RepoGitProjectAdapter` in `git/index.ts` is reconcile-shaped (worktree status, changed paths, commit); this change adds the small init/first-commit surface it lacks (extending that port or adding a sibling `ProjectInitGitPort`), keeping project/runtime-root/class-repo git scopes distinct per the architecture invariants. *Alternative:* running git directly in the primitive — rejected; non-deterministic and untestable, and inconsistent with the injected-adapter pattern used everywhere else.

### 5. `overmind project reconcile` becomes the sole update path; wrapper guidance folded in

`runProjectReconcile` already performs project discovery, single-project auto-select, and interactive selection — the wrapper's selection logic is redundant with it. The only wrapper behavior worth keeping is the reconciliation-intent guidance (this runs the full attach + one-time contract reconciliation + optional commit, not just a repo attach) and its confirm-before-delegating prompt. That guidance/confirmation is folded into `runProjectReconcile` (emitted before the reconciliation session, gated by an interaction confirm that respects EOF-as-clean-stop), after which the wrapper adds nothing and is deleted. The reconcile flow continues to leave the legacy `project_type_code` untouched. *Alternative:* keeping a thin `project update` alias verb — rejected; the plan makes reconcile the sole update path and adding an alias is unrequested surface.

### 6. CLI dispatch: `project create` alongside `project reconcile`

`runCli`'s existing `project` branch gains a `create` subverb (`project create` → `runProjectCreate`, no required options — it prompts) next to `reconcile`; unknown `project` subverbs keep returning the usage error. The top-level usage string is updated to include `project create`. CLI adapters collect args and render typed results; the primitive owns parsing, mutation, and validation, and the CLI does no output scraping — consistent with `runProjectReconcile` and `runWorker`.

## Risks / Trade-offs

- **Line-oriented metadata/definition mutation misses an odd shape the shell tolerated** → port the shell's exact matchers (metadata `meta:`/`projects:` shape assertion, `projects:`-final check, trailing-blank normalization, `meta_info` injection above `steps:`) and add fixture-based byte-preservation tests over untouched blocks of `asdlc_metadata.yaml` and the definition template.
- **UUID/clock injection surface leaks into the CLI type** → keep the seams on a small deps object with production defaults, exposed through `CliAdapterOverrides` (reuse the existing `clock`/`uuid` seams; add a git/temp seam only as needed), as `scaffold-feature.ts` and `registerWorker` already do.
- **Git identity fallback clobbers a configured identity** → only set `user.name`/`user.email` when unset (mirroring `ensure_project_git_identity`), and cover both "already configured" and "fallback" paths in tests against the injected git port.
- **Reconcile guidance/confirm changes the reconcile UX for callers that used it directly** → the guidance is emitted and the confirm gates only the interactive path; `--path`-driven and single-project runs keep working, and EOF during the confirm is a clean stop (exit 0), matching the wrapper's default-No-on-EOF behavior.
- **Coordinated landing with Units A and D** → `project_setup_update_project_tests.sh` (this unit) and `project_setup_asdlc_tests.sh` (Unit D) both stage/assert the scripts touched across units. This change deletes only its own three scripts and the update suite, and removes their staging from `project_setup_first_init_machine.sh`; the Unit-D-owned `project_setup_asdlc_tests.sh` is left to Unit D. Grep for residual references before verify and record the coordinated-landing dependency.

## Migration Plan

1. Add `capture/project.ts` with the creation primitive and injected clock/UUID/interaction/git(/temp) ports; absorb repo-path validation/resolution into `workspace/` and type labels into the creation module, reusing `parse/project-definition.ts` `escapeYamlDoubleQuoted`; extend `git/` with the project init/first-commit seam. Add package tests specifying the contracts above.
2. Wire `overmind project create` into `cli/run.ts`'s `project` branch and `CliAdapterOverrides`; update the usage string.
3. Fold the project-selection reconciliation-intent guidance + confirm from `project_setup_update_project.sh` into `runProjectReconcile`; add/extend its CLI tests.
4. Delete `project_setup_add_new_project.sh`, `project_setup_update_project.sh`, `project_setup_common.sh`, and `tests/ai_scripts/project_setup_update_project_tests.sh`; remove their `.commands`/`common_libs` staging from `project_setup_first_init_machine.sh` (leaving Unit-D-owned staging alone).
5. Update `overmind/README.md`, `QUICKRUN.md`, and generated quick-run guidance to the project verbs.
6. Run package tests, then `npm run typecheck|lint|format:check|build|test|verify`, `git diff --check`, and strict OpenSpec validation.

Rollback restores the three shell files, the update suite, their staging, and the prior docs; no persisted state migrates because nothing was ever installed.

## Open Questions

- None blocking. `project create` preserves the shell's operator-facing messages ("Created ASDLC project folder: …", "Updated ASDLC metadata: …") and the folder-name scheme `<normalized-name>-<uuid>` so operator guidance and on-disk layout stay stable.
