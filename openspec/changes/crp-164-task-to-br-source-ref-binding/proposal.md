## Why

The pre-migration task-to-BR output bound both the durable `user_br_input.md` capture record and its underlying story source into `feature_br_summary.md` `## 1. Document Meta -> source_refs`; the migrated skill commonly records only the underlying file or ticket. Because the TypeScript task-to-BR gate does not validate this field, the missing capture link passes silently and weakens source traceability for every downstream artifact.

## What Changes

- Define the complete captured-source binding for task-to-BR as the feature's `user_br_input.md` path plus the `epic_story_source_file` locator recorded inside that artifact, for both local-file and Jira capture.
- Emit those required source references in deterministic task-to-BR context so the skill does not have to infer them.
- Require the task-to-BR skill to merge every required captured source into `feature_br_summary.md` `## 1. Document Meta -> source_refs` while preserving additional valid references.
- Extend the TypeScript task-to-BR gate to report recoverable exit `1` diagnostics for an unfilled `source_refs` field or any missing required captured-source reference.
- Update the packaged task-to-BR example and regression coverage so freshly installed Codex and Claude skills demonstrate and enforce the restored binding.
- Keep CRP-162's capture→context→gate ordering unchanged: source references are derived only after capture has produced `user_br_input.md`.

## Capabilities

### New Capabilities

- `task-to-br-source-ref-binding`: deterministic binding and validation of the durable captured-input artifact and its underlying local or Jira source in the BR summary.

### Modified Capabilities

<!-- None. openspec/specs/ contains no consolidated task-to-BR capability. -->

## Impact

- `packages/asdlc-coordinator/src/context/task-to-br.ts` and task-to-BR parsing utilities: derive and expose the required reference set from captured input.
- `packages/asdlc-coordinator/src/validate/task-to-br.ts`: validate `source_refs` by set inclusion and preserve stable exit-code behavior.
- `packages/installer/_data/skills/overmind-task-to-br/SKILL.md` and its golden example: make the binding operational and visible in deployed skill installations; the existing template field remains structural.
- Coordinator and installer tests: cover local-file and Jira references, missing-reference repair diagnostics, path normalization, preservation of extra references, and installed assets.
- Existing feature summaries that omit `user_br_input.md` from `source_refs` receive a recoverable gate failure and must be repaired or rerun before the task-to-BR gate passes.
