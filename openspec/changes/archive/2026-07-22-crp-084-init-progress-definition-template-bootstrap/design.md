## Context

CRP-084 moves bootstrap progress-definition ownership from a static tracked YAML file to a template-plus-initializer model. Today `overmind/init_progress_definition.yaml` is committed directly and `overmind/scripts/init_asdlc_in_this_repo.sh` assumes the file already exists before it can write `meta_info`.

The requested behavior is to treat the progress definition as a reusable template and let `init_asdlc_in_this_repo.sh` materialize the repo instance in `overmind/` while filling user-selected metadata (`project_type_code`, `project_type_label`, `project_classes`).

This is cross-cutting because it affects:
- bootstrap artifact ownership (`template` vs generated runtime file)
- initializer control flow in `init_asdlc_in_this_repo.sh`
- scanner/consumer compatibility assumptions for `overmind/init_progress_definition.yaml`
- test scaffolding and docs that currently assume the runtime YAML is pre-existing

## Goals / Non-Goals

**Goals:**
- Define one canonical template for init progress definition under `overmind/templates/`.
- Make `init_asdlc_in_this_repo.sh` create `overmind/init_progress_definition.yaml` from template when missing.
- Make `init_asdlc_in_this_repo.sh` fail fast when `overmind/init_progress_definition.yaml` already exists, with the canonical regeneration guidance message.
- Keep metadata prompting and persistence in one owning script (`init_asdlc_in_this_repo.sh`).
- Keep `init_progress_scanner.sh` and downstream consumers unchanged in file location (`overmind/init_progress_definition.yaml`).

**Non-Goals:**
- Redesign step semantics inside progress definition beyond metadata bootstrap wiring.
- Introduce new CLI flags/options for bootstrap scripts.
- Replace scanner input path or create a new runtime metadata file.
- Implement automatic inference of project type/classes from repository contents.

## Decisions

1. Add a dedicated YAML template file for progress definition under `overmind/templates/`.
Rationale: this separates reusable structure from repo-specific instance state and aligns with existing overmind template conventions.
Alternative considered: keep static YAML and patch only `meta_info` dynamically. Rejected because the user explicitly wants runtime file creation from template.

2. Let `init_asdlc_in_this_repo.sh` own materialization of `overmind/init_progress_definition.yaml`.
Rationale: one initializer should own both initial file creation and metadata persistence; this avoids split responsibility and bootstrap ordering ambiguity.
Alternative considered: create a separate script only for materialization. Rejected because it would add another required step with little value.

3. Materialize template only when runtime file is missing; fail fast when runtime file already exists.
Rationale: initializer ownership is explicitly "generate once" for repository bootstrap. Failing fast prevents silent drift or accidental mixed-regeneration workflows.
Alternative considered: reuse existing file on rerun. Rejected because requested behavior requires explicit cleanup before regeneration and a deterministic one-shot generation path.

4. Keep metadata writing logic centered on `meta_info` merge/update, not whole-file rewrite.
Rationale: minimizes risk of changing step definitions while still filling required user metadata.
Alternative considered: regenerate full file then reapply edits. Rejected as more complex and riskier for preserving local step-contract edits.

5. Keep scanner contract unchanged: it continues to read `overmind/init_progress_definition.yaml`.
Rationale: CRP-084 is a bootstrap ownership change, not a scanner contract redesign.
Alternative considered: scanner reading template directly with runtime overlays. Rejected due unnecessary complexity and higher migration risk.

## Risks / Trade-offs

- [Risk] Template and generated file can drift if manual edits bypass template updates.
  Mitigation: document ownership clearly and keep initializer deterministic; add tests that validate template-based bootstrap path.

- [Risk] Existing tests assume static YAML fixture setup and may fail unexpectedly.
  Mitigation: update script tests to explicitly cover both "file missing -> generated" and "file exists -> reused" paths.

- [Risk] File creation path could accidentally write malformed YAML and break scanner steps parsing.
  Mitigation: preserve template content as canonical source and keep metadata writes scoped to `meta_info`.

- [Risk] Existing repositories with already-present runtime YAML will be blocked from rerunning initializer until file is removed.
  Mitigation: provide explicit fail-fast message: `init_progress_definition.yaml already exists, remove it completely if you need re-generate it`.

## Migration Plan

1. Add `overmind/templates/init_progress_definition_TEMPLATE.yaml` with canonical step contract and empty/default `meta_info`.
2. Update `overmind/scripts/init_asdlc_in_this_repo.sh` to:
   - ensure template exists
   - materialize runtime YAML from template when runtime file is absent
   - fail fast with canonical message when runtime file already exists
   - prompt for user metadata and persist under `meta_info`
3. Keep existing metadata helper usage and adapt write path for newly generated runtime file only.
4. Update tests in `tests/ai_scripts/init_asdlc_in_this_repo_tests.sh` for generation path and existing-file fail-fast behavior.
5. Update scanner and related tests only where they assume static YAML pre-existence.
6. Update `overmind/README.md` bootstrap instructions to describe template-based generation and regeneration precondition.

Rollback strategy: revert template introduction and initializer materialization flow together, returning to static tracked runtime YAML behavior.

## Open Questions

- None.
