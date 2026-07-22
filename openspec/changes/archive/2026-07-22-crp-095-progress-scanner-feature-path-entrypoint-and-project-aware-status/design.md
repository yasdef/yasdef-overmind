## Context

`overmind/scripts/project_mgmt/init_progress_scanner.sh` currently requires a project folder positional argument and supports scanner-local `--feature_path` only as an additional override for feature-scoped artifacts. That contract no longer matches the intended user entrypoint: users think in terms of a concrete feature folder, but still need one checklist that includes both project-level setup status and the selected feature's progress.

The change is cross-cutting because it touches staged command usage, scanner path validation, feature-root resolution, tests, and documentation. It must keep the current grouped checklist semantics, project-level artifact checks, and deterministic `step_state.md` output while replacing the scanner CLI contract.

## Goals / Non-Goals

**Goals:**
- Replace scanner invocation `<project-path> [--feature_path <path>]` with required `--path <path/to/feature>`.
- Infer the owning ASDLC project root from the selected feature folder instead of requiring a separate project argument.
- Keep project-level checklist evaluation anchored at the inferred project root.
- Treat the selected feature folder as the active feature root for feature heading resolution and product-root checklist targets.
- Keep `step_state.md` persisted at project scope and keep stdout output identical to the persisted content.
- Update staged quickrun text, README usage, and shell tests to the new CLI.

**Non-Goals:**
- Change checklist YAML schema, step ordering, or completion semantics.
- Change other product-artifact scripts that still legitimately use optional `--feature_path`.
- Add implicit feature auto-selection when `--path` is omitted.
- Introduce persisted scanner state or hidden feature-selection configuration.

## Decisions

1. Use a required `--path` flag for scanner entry, matching the staged-command style already used by `init_common_contract_definition.sh`.
Rationale: this keeps staged command UX explicit and consistent, while removing the awkward split between project selection and feature override.
Alternative considered: keep positional project path and rename `--feature_path`. Rejected because it still forces the user to pass two scope selectors for one scan.

2. Interpret `--path` as a concrete feature-folder path inside `asdlc/projects/<project-id>/...`, not as a repo-relative override string.
Rationale: the user request is feature-folder-oriented (`feature-1` level), and a filesystem path lets the scanner validate that the folder belongs to one specific ASDLC project before scanning.
Alternative considered: treat `--path` as a project-relative alias for `--feature_path`. Rejected because it keeps project inference ambiguous and preserves the old two-input mental model.

3. Infer project root by canonicalizing the selected feature path and walking upward to the nearest ancestor that contains `init_progress_definition.yaml`, while requiring that ancestor to remain under `asdlc/projects/`.
Rationale: this supports feature folders nested below the project root without hard-coding one folder depth.
Alternative considered: assume the immediate parent of the feature folder is always the project root. Rejected because it is brittle if feature folders are nested or grouped.

4. Keep logical product-root checklist targets mapped to the selected feature folder for the duration of that invocation.
Rationale: existing YAML definitions and feature-heading lookup already assume a logical feature root. Rebinding that logical root to the selected folder avoids rewriting project definitions per feature.
Alternative considered: require each project definition to be rewritten with absolute feature-folder paths. Rejected because it adds configuration churn with no user value.

5. Keep project-scoped inputs and outputs rooted at the inferred project folder.
Rationale: `init_progress_definition.yaml`, project-level artifacts, and `step_state.md` remain project contracts even when the user launches the scan from feature scope.
Alternative considered: write a separate feature-local status file. Rejected because the requested behavior is one combined checklist, not parallel project and feature status artifacts.

6. Remove scanner behavior from the generic optional `--feature_path` contract while preserving that contract for the remaining product-artifact scripts.
Rationale: scanner will no longer expose the same CLI semantics as those scripts, so the spec surface should stop pretending they share one flag contract.
Alternative considered: keep scanner listed under the old contract for compatibility wording only. Rejected because it would leave the main specs internally inconsistent.

## Risks / Trade-offs

- [Risk] Existing staged scanner callers will break immediately after the CLI change. -> Mitigation: update README, quickrun output, and shell tests in the same implementation change, and fail fast with explicit `--path` guidance.
- [Risk] Project-root inference could select the wrong ancestor if path validation is loose. -> Mitigation: require the resolved project ancestor to live under `asdlc/projects/` and to contain `init_progress_definition.yaml`.
- [Risk] Older projects may still assume feature artifacts live only under `overmind/product`. -> Mitigation: keep logical product-root semantics in the scanner and map them to the selected feature folder at runtime instead of forcing template migration.
- [Risk] A selected feature folder may not yet contain `feature_br_summary.md` or other feature artifacts. -> Mitigation: preserve deterministic fallback heading and incomplete-step behavior for missing feature artifacts.

## Migration Plan

1. Update scanner argument parsing to require `--path <feature-folder>` and remove support for positional project path and scanner-local `--feature_path`.
2. Add path validation and project-root inference for feature folders under `asdlc/projects/`, including clear failures for missing/invalid paths and project-root-only input.
3. Refactor scanner feature-root resolution so product-root checklist entries and feature heading metadata resolve from the selected feature folder, while project-level artifacts continue to resolve from the inferred project root.
4. Update staged quickrun text in `project_setup_first_init_machine.sh`, README guidance, and scanner-focused shell tests.
5. Validate `openspec status` for the change once design, specs, and tasks are complete.

Rollback strategy: restore positional project-path plus optional `--feature_path` parsing and revert docs/tests to the prior staged invocation contract.

## Open Questions

- None. The remaining implementation work is mechanical once the feature-path validation and project-root inference rules above are accepted.
