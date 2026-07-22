## Context

The Overmind Step-2 contract already exists in two places: the init sequence diagram and the progress-definition template both expect `common_contract_definition.md`. The repository, however, only has adjacent backend/frontend contract inventory assets and no exact phase scaffold for producing the shared baseline artifact from ASDLC project metadata.

This change introduces a new project-scoped init phase that differs from the current feature-root phases:
- it operates on an ASDLC project folder under `asdlc/projects/<project-id>`,
- it must be targeted explicitly with `--path`,
- it is staged-runtime only and must be invoked from `asdlc/.commands/init_common_contract_definition.sh`,
- repo-path invocation must fail with exact guidance string `init asdlc repo first, run this script only from asldc/.commands`,
- it reads repository inputs from `<project>/init_progress_definition.yaml`,
- and it writes its output back into that same project folder as `common_contract_definition.md`.

The user also explicitly requested that implementation of this phase use the local `overmind-new-pipeline-step` skill so the repository keeps one consistent scaffold pattern across script, rule, helper, models setup, template, golden example, docs, and tests.

## Goals / Non-Goals

**Goals:**
- Add a deterministic Step-2 bootstrap phase for `common_contract_definition.md`.
- Require explicit project-folder targeting via `--path <asdlc/projects/<project-id>>`.
- Enforce staged runtime for this phase (repo-path invocation must fail fast).
- Keep repo-path fail-fast message stable as `init asdlc repo first, run this script only from asldc/.commands`.
- Load repository inputs from `meta_info.class_repo_paths` in the selected project's `init_progress_definition.yaml`.
- Run the configured `common_contract_definition` model phase from staged `asdlc/.setup/models.md` (sourced from `overmind/setup/models.md`) and persist the artifact into the selected project folder.
- Add the full Overmind phase scaffold: rule, helper, template, golden example, README entry, and tests.
- Make the implementation workflow itself explicitly follow `overmind-new-pipeline-step`.

**Non-Goals:**
- Introduce implicit project discovery or a default project-folder selection mechanism.
- Redesign Step 2 into a feature-scoped `--feature_path` flow.
- Implement MCP-only fallback for projects that do not provide repository paths.
- Create `feature_contract_delta.md` or modify later feature-phase artifacts in this change.

## Decisions

1. Require `--path` and reject omitted project selection.
Rationale: ASDLC can hold multiple projects under `asdlc/projects/`, so implicit selection would be ambiguous and error-prone. The user explicitly requested `--path`, which makes the invocation stateless and deterministic.
Alternative considered: infer the latest or only project folder. Rejected because it hides selection logic and risks writing into the wrong ASDLC project.

2. Enforce strict project-root path validation for `--path`.
Rationale: the requested contract is project-level only. Accepting `asdlc/projects/` or nested subfolders would make ownership ambiguous and can place outputs in unintended paths.
Alternative considered: auto-normalize parent/subfolder input into nearest project root. Rejected because that introduces implicit path rewriting and weakens deterministic targeting.

3. Treat `<project>/init_progress_definition.yaml` as the sole source of repository inputs.
Rationale: project metadata already persists active classes and `class_repo_paths`. Reusing that file keeps the phase contract local to the chosen ASDLC project and avoids extra prompting or duplicate configuration.
Alternative considered: accept raw repo paths as direct CLI arguments. Rejected because it would duplicate project metadata and broaden CLI surface unnecessarily.

4. Limit this phase to repository-path-driven analysis.
Rationale: the user request is explicit that the model must analyze repo paths defined in project metadata. Keeping this change repo-driven avoids mixing the future MCP branch into the first scaffold version.
Alternative considered: add dual behavior for project type A with MCP guidance now. Rejected because it expands scope and introduces a second evidence source before the repo-driven path is stabilized.

5. Keep all runtime writes scoped to the selected project folder.
Rationale: Step 2 output is project-level ASDLC state, not repository-level `overmind/product` state. Writing only `<project>/common_contract_definition.md` prevents cross-project collisions and matches the scanner template contract.
Alternative considered: write into repository `overmind/product/`. Rejected because the source of truth for this phase is the ASDLC project workspace.

6. Encode scaffold alignment as an explicit implementation rule.
Rationale: the repository already has a dedicated skill for adding Overmind pipeline phases. Making its use explicit in this change reduces drift between init script, rule, helper, models setup, templates, docs, and tests.
Alternative considered: leave skill usage implicit. Rejected because the user explicitly requested the reminder and this change spans the exact scaffold surface that the skill is meant to govern.

7. Keep staged command runtime self-sufficient.
Rationale: deployable phases must not depend on source-repo runtime paths once staged into ASDLC.
Alternative considered: dual-mode runtime (repo path + staged path). Rejected for this phase to avoid ambiguity and force deterministic ASDLC-local execution.

## Risks / Trade-offs

- [Risk] Requiring `--path` makes the new entrypoint less convenient than feature-root scripts.
  Mitigation: document the contract clearly in `overmind/README.md` and keep path validation/error messages precise.

- [Risk] Some ASDLC project records may have deferred or missing `class_repo_paths`.
  Mitigation: fail fast with an actionable error when the selected project lacks usable repository paths for analysis.

- [Risk] Repo-driven scope leaves project type A unsupported for this phase.
  Mitigation: make that limitation explicit in docs/tests and keep the scaffold narrow until repository-path flow is proven.

- [Risk] The new phase could drift from the repository’s standard phase pattern.
  Mitigation: explicitly require the `overmind-new-pipeline-step` skill during implementation and cover all scaffold pieces in tasks/tests.

- [Risk] Staged command could drift from staged support-asset availability (`.rules`, `.helper`, `.setup`).
  Mitigation: include first-init-machine staging and update-mode repair/sync requirements in this change surface and tests.

## Migration Plan

1. Add the new artifact contract files:
   - `overmind/templates/common_contract_definition_TEMPLATE.md`
   - `overmind/golden_examples/common_contract_definition_GOLDEN_EXAMPLE.md`
2. Add the runtime scaffold:
   - `overmind/rules/common_contract_definition_rule.md`
   - `overmind/scripts/helper/check_common_contract_definition_quality.sh`
   - `overmind/scripts/init_common_contract_definition.sh`
3. Add `common_contract_definition` to `overmind/setup/models.md`.
4. Update `project_setup_first_init_machine.sh` to stage `init_common_contract_definition.sh` into `.commands` and include `.setup/models.md` in staged support assets.
5. Update `overmind/README.md` with staged-only invocation and `--path` usage.
6. Add tests in `tests/ai_scripts/` for:
   - required `--path`,
   - repo-path fail-fast with exact message `init asdlc repo first, run this script only from asldc/.commands`,
   - strict project-folder validation under `asdlc/projects/` (reject parent `projects/` and reject subfolders),
   - staged-command-only invocation behavior,
   - required root-level `init_progress_definition.yaml` plus metadata/repo-path loading from that file,
   - artifact generation at `<project>/common_contract_definition.md`,
   - helper pass/fail behavior.

Rollback strategy: remove the new phase artifacts and model row, and leave Step 2 as an acknowledged gap until a new scaffold change is prepared.

## Open Questions

- None.
