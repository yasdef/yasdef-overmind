## Context

`overmind/scripts/project_mgmt/init_progress_scanner.sh` currently resolves one selected feature path, renders checklist state for that feature context, and persists the rendered payload to one shared project-root `step_state.md`. That contract was acceptable while projects effectively had one active feature, but it becomes misleading once a project contains multiple feature folders because the persisted file no longer identifies which feature it represents and is overwritten by the last scan.

The change needs to preserve the current scanner CLI (`--path <feature-folder>`), keep project-root persistence, and avoid changing checklist semantics. It also needs to keep machine-consumable stdout behavior intact for orchestrator parsing while making persisted files unambiguous across multiple features in the same project.

## Goals / Non-Goals

**Goals:**
- Replace the single shared project-root `step_state.md` persistence target with a deterministic feature-specific filename derived from the selected feature folder.
- Keep one scan result scoped to one selected feature: same checklist body, same canonical final `next step` line, same stdout payload.
- Keep project-level storage so operators can still discover scan artifacts from the project root without entering feature folders.
- Update orchestrator, docs, and tests to resolve the new persisted filename contract consistently.

**Non-Goals:**
- Changing scanner invocation, checklist ordering, step completion semantics, or feature discovery behavior.
- Aggregating multiple feature statuses into one combined project report.
- Adding new CLI flags or extra persisted metadata files.
- Renaming feature folders or introducing dependence on `feature_id` values inside feature artifacts.

## Decisions

### Decision: Persist scanner output to `step_state_<feature-folder>.md` at project root
For a scan invoked with `--path <project>/<feature-folder>`, the persisted artifact will be written to `<project>/step_state_<feature-folder>.md`.

Rationale: the scanner already knows the exact feature folder chosen at invocation time, and that folder name is available before any feature-specific metadata file is parsed. This keeps the filename stable for the life of the folder and avoids coupling persistence to `feature_id` initialization timing or later content edits.

Alternatives considered:
- Keep one shared `step_state.md`: rejected because it silently overwrites status for other features in the same project.
- Persist inside the feature folder: rejected because the user explicitly chose project-root storage.
- Use `feature_id` in the filename: rejected because early steps can run before a stable `feature_id` is guaranteed, and the scanner’s authoritative input is the selected folder path anyway.

### Decision: Derive the filename from the feature folder basename only
The filename suffix will use the selected feature folder basename, not the entire relative feature path.

Rationale: current project layout treats direct child feature folders under the project root as the canonical feature unit, so basename-derived filenames stay readable and short while matching operator expectations.

Alternatives considered:
- Encode the full relative feature path: rejected as unnecessary noise for the current layout and harder to read in project root listings.
- Maintain a lookup file from feature path to persisted state filename: rejected because it adds state without solving a real problem.

### Decision: Keep stdout parity and checklist semantics unchanged
The scanner will continue to print the exact rendered payload it writes, and the payload itself will remain scoped to the selected feature plus project-level tasks.

Rationale: orchestrator parsing already depends on the canonical final `next step` line from stdout. Changing output shape would broaden the blast radius beyond the filename fix.

Alternatives considered:
- Add the persisted filename into stdout: rejected because stdout currently doubles as machine-consumable checklist output and should remain stable.
- Emit a multi-feature summary from one scan: rejected because one invocation still has one selected feature context.

### Decision: Consumers resolve persisted files from selected feature context
Any script or documentation that references scanner persistence will be updated to describe or compute the feature-specific filename from the selected feature folder.

Rationale: this keeps the contract coherent end-to-end and avoids hidden assumptions about a shared `step_state.md`.

Alternatives considered:
- Keep writing both the old and new filenames during a transition period: rejected because dual-write would preserve ambiguity and invites stale reads from the legacy path.

## Risks / Trade-offs

- [Risk] Existing tooling may still read `<project>/step_state.md`. -> Mitigation: mark the contract as breaking in proposal/specs and update docs/tests/orchestrator references in the same implementation change.
- [Risk] Future nested feature-folder layouts could make basename-only filenames collide. -> Mitigation: current project structure uses one feature folder level under the project root; if nested features become valid later, revisit the filename derivation rule in a separate change.
- [Risk] Old shared `step_state.md` files may remain in existing runtime projects and confuse operators. -> Mitigation: implementation should stop writing the legacy file and docs should describe the new filename pattern clearly; cleanup of stale historical files can be handled opportunistically, not as part of this contract change.

## Migration Plan

1. Update scanner output path computation to derive `step_state_<feature-folder>.md` from the selected feature folder basename.
2. Replace any script logic, docs, and tests that assume `<project>/step_state.md`.
3. Preserve stdout output and requirement semantics unchanged apart from the persisted filename.
4. Validate the change with focused scanner/orchestrator tests and `openspec status`.
5. Rollback strategy: restore the shared `step_state.md` output path and revert dependent references.

## Open Questions

- None.
