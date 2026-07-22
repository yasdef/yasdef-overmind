## Context

CRP-082 introduces one canonical repo-level source for project classification and project type so `overmind` initializers stop asking the same question repeatedly. Today, `init_br_scaffold.sh` always prompts for project type, while `init_repo_structure_summary.sh`, `init_project_tech_summary_be.sh`, and `init_contracts_inventory.sh` conditionally prompt when hint artifacts are missing or conflicting. That spreads ownership of the same decision across multiple scripts and makes reruns inconsistent.

The target source of truth is `overmind/init_progress_definition.yaml`, which already exists as the machine-readable bootstrap contract. Adding repo metadata there keeps initialization state in one file, but it means scanner parsing must tolerate a top-level metadata block without changing checklist behavior.

This change is cross-cutting because it affects:
- bootstrap YAML shape
- one new repo-level initializer script
- BR scaffold initialization
- three downstream technical-baseline initializers
- shell test coverage and README/process guidance

## Goals / Non-Goals

**Goals:**
- Add canonical repo metadata under `meta_info` in `overmind/init_progress_definition.yaml`.
- Introduce `overmind/scripts/init_asdlc_in_this_repo.sh` as the only script that asks for project type.
- Capture one-or-more project classes and normalize them deterministically.
- Update downstream init scripts to read canonical repo metadata instead of re-prompting.
- Keep failures explicit: if repo metadata is unavailable, tell the user to run the initializer.
- Preserve scanner/checklist behavior while tolerating the new top-level metadata block.

**Non-Goals:**
- Automatic inference of project type or project classes from repository contents.
- A new standalone metadata file outside `overmind/init_progress_definition.yaml`.
- Redesign of step order, scanner output format, or feature-level BR structure beyond direct project-type reuse.
- Broad refactoring of all `overmind` scripts into a new framework.

## Decisions

1. Store canonical repo metadata in `meta_info`, not a parallel file.
Rationale: `overmind/init_progress_definition.yaml` is already the machine-readable bootstrap contract. Extending it avoids introducing another config source that downstream scripts would have to discover and reconcile.
Alternative considered: add a separate `overmind/repo_meta.yaml`. Rejected because it duplicates initialization state and increases drift risk.

2. Normalize the requested "metaifo" area to `meta_info`.
Rationale: the intent is clearly a metadata section. `meta_info` is readable, consistent with existing naming style, and avoids baking a typo into a durable schema.
Alternative considered: use `metaifo` literally. Rejected because it weakens readability and would have to be explained everywhere.

3. Introduce a shared sourceable shell helper for repo metadata parsing and validation.
Rationale: at least five scripts need the same behaviors: project-type chooser mapping, metadata reads, validation, and fail-fast guidance. A shared helper keeps those rules consistent and reduces copy-paste drift.
Alternative considered: duplicate parsing logic into each script. Rejected because the repo already has substantial shell duplication and this change would worsen it.

4. Keep `init_asdlc_in_this_repo.sh` as the sole owner of project-type prompting.
Rationale: one script should own the human decision and persistence. All other consumers should either reuse the metadata or fail fast with guidance.
Alternative considered: keep conditional fallback prompts in downstream scripts. Rejected because it preserves the current inconsistency and undermines the repo-level source of truth.

5. Persist project classes as canonical YAML list values in stable order.
Rationale: the user wants one-or-more classes selected from `fe/be/mobile`. Persisting normalized values as `backend`, `frontend`, and `mobile` makes the metadata self-describing. Stable ordering keeps repeated runs deterministic.
Alternative considered: persist raw aliases like `be` and `fe`. Rejected because those are input shortcuts, not ideal durable metadata.

6. Continue writing project type into `feature_br_summary.md`, but source it from repo metadata.
Rationale: feature artifacts still need local traceability, and many downstream prompts already expect those fields in BR summary documents. Repo metadata becomes authoritative without removing useful feature-local copies.
Alternative considered: remove project type from BR summary entirely. Rejected because it would widen scope into multiple existing scripts and templates.

7. Make scanner compatibility explicit through tests, not parser redesign.
Rationale: the current scanner parser already keys off `steps:` and step entries. The safest implementation is to keep that behavior and add regression coverage proving `meta_info` does not break checklist evaluation.
Alternative considered: rewrite YAML parsing more broadly. Rejected because CRP-082 does not require broader scanner redesign.

## Risks / Trade-offs

- [Risk] Metadata write logic could accidentally corrupt `overmind/init_progress_definition.yaml`.
  Mitigation: limit writes to the `meta_info` block, use deterministic formatting, and add tests that verify step definitions remain intact.

- [Risk] Shared helper adoption may still leave one script using legacy prompt logic.
  Mitigation: update all known project-type consumer scripts in the same change and add targeted tests for each.

- [Risk] Project-class input handling may become ambiguous if multiple input forms are accepted.
  Mitigation: normalize supported aliases explicitly and persist only canonical values in stable order.

- [Risk] Downstream fail-fast behavior may surprise users accustomed to fallback prompts.
  Mitigation: error messages must explicitly name `overmind/scripts/init_asdlc_in_this_repo.sh` as the required prerequisite.

- [Risk] Scanner tests may miss regressions if only metadata-writing paths are covered.
  Mitigation: add scanner coverage that loads a definition file with `meta_info` present before `steps`.

## Migration Plan

1. Add `meta_info` to `overmind/init_progress_definition.yaml` with empty tracked defaults.
2. Add a shared helper for metadata read/write, chooser mapping, normalization, and fail-fast messaging.
3. Implement `overmind/scripts/init_asdlc_in_this_repo.sh` using the shared helper.
4. Update `init_br_scaffold.sh` to read canonical repo project type and label from `meta_info`.
5. Update `init_repo_structure_summary.sh`, `init_project_tech_summary_be.sh`, and `init_contracts_inventory.sh` to read canonical repo project type and remove interactive fallback prompts.
6. Add or update shell tests for initializer persistence, scaffold reuse, downstream fail-fast behavior, and scanner tolerance of top-level `meta_info`.
7. Update README/proposal-facing documentation where project-type prompting behavior changes.

Rollback strategy: revert the helper, initializer, YAML contract, and consumer-script changes together. Because the metadata stays in an existing file and feature artifacts keep their local fields, rollback does not require a data migration.

## Open Questions

- None. The intended metadata keys, owning initializer, and downstream fail-fast behavior are explicit enough to implement.
