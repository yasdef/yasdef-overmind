# Structured BR to Atomic EARS Conversion Rule

Read this file fully before generating output.

## Purpose
- Convert readiness-approved structured BR content into deterministic, atomic EARS requirements.
- Keep conversion behavior in this rule artifact, not in shell logic.
- Preserve the existing EARS output shape already used by this repository.

## Authoritative Inputs and Outputs
- Read-only business source for this run: `<BR_SUMMARY_SOURCE_ARTIFACT>` (resolved from `<feature_path>/feature_br_summary.md`).
- Output target for this run: `<EARS_TARGET_ARTIFACT>` (resolved from `<feature_path>/requirements_ears.md`).
- Do not edit `<BR_SUMMARY_SOURCE_ARTIFACT>` during this stage.
- Do not create or modify unrelated artifacts.

## Output Format Baseline (Mandatory)
- Use `.templates/reqirements_ears_TEMPLATE.md` as the structural template.
- Use `.golden_examples/reqirements_ears_GOLDEN_EXAMPLE.md` as the style and block-shape reference.
- Keep standard sections and block format:
  - `## Requirements` with `### Requirement <N> — <Title>` blocks.
  - `## Non-Functional Requirements` with `### NFR <N> — <Title>` blocks when NFR facts exist.
  - Each block must include `**User Story:**`, `**Acceptance Criteria (EARS):**`, and `**Verification:**`.
- Do not introduce a parallel schema, metadata-only schema, or alternate top-level structure.

## Source-of-Truth and Inference Rules
- Use only facts present in `<BR_SUMMARY_SOURCE_ARTIFACT>`.
- If a minimal inference is necessary for grammatical completeness, mark it inline with `[Inference]`.
- Keep inferred content conservative and directly bounded by nearby BR facts.
- If facts are missing or ambiguous, do not invent behavior.
- Prefer narrower requirements; if narrowing still leaves uncertainty, add:
  - `Unresolved gap: <fact missing from BR summary>.`
- Do not start a new user-question loop in this stage.

## Extraction Map From Structured BR
Extract conversion ingredients from these BR areas before drafting blocks:
- Actor: `## 4. Actors and Consumers` (primary and secondary actors).
- Trigger/event: `## 6. Functional Requirements`, `## 7. Business Rules and Decision Logic`, `## 10. Failure Cases and Edge Cases`.
- Preconditions/state: `## 8. Permissions and Access Constraints`, `## 9. State and Data Expectations`.
- Expected behavior (success path): `## 6. Functional Requirements`.
- Rejection behavior (failure path): `## 10. Failure Cases and Edge Cases`, plus constraint-driven rejects from `## 8`.
- State/data effects and persistence: `## 9. State and Data Expectations`.
- Side effects and integration effects: `## 11. Integration and Dependency Context`.
- NFR constraints: `## 12. Non-Functional Requirements`.
- Scope boundaries/non-goals: `## 5. Scope Definition` and `## 2.3 Explicitly stated in source`.

## Atomic Splitting Rules
- One independent obligation per EARS bullet.
- Split a single BR item into multiple blocks or bullets when it mixes independent obligations across:
  - success behavior
  - rejection behavior
  - permission/access rules
  - state or persistence effects
  - side effects/integration effects
  - non-functional constraints
- Functional obligations belong in `Requirement` blocks; quality constraints belong in `NFR` blocks.
- Keep each bullet independently testable without requiring hidden assumptions.

## Allowed EARS Patterns
- Each acceptance bullet must use exactly one preferred pattern:
  - `WHEN <event>, THE <System> SHALL <response>.`
  - `IF <condition>, THEN THE <System> SHALL <response>.`
  - `WHILE <state>, THE <System> SHALL <response>.`
  - `WHERE <feature/constraint>, THE <System> SHALL <response>.`
- Combined form is allowed only when state and event are both required:
  - `WHEN <event> AND WHILE <state>, THE <System> SHALL <response>.`
- Do not use free-form imperative bullets outside these patterns.

## Prohibited Content in EARS Statements
- Implementation design or architecture decisions.
- File paths, module names, class names, endpoint wiring, or roadmap/planning text.
- Shell/process instructions, helper behavior, or quality-loop mechanics.

## Deterministic Ordering and Numbering
- Preserve stable ordering by processing BR source sections in document order.
- Within each source item, emit obligations in this order:
  - success
  - rejection
  - permission/access
  - state/persistence
  - side effects/integrations
  - NFR constraints
- Number `Requirement` blocks sequentially from `1` in emission order.
- Number `NFR` blocks sequentially from `1` in emission order.
- Re-runs with materially unchanged BR input must keep the same block order and numbering.

## Runtime Path Binding Rules
- Runtime bindings provided by the caller are authoritative for each invocation.
- Treat `<feature_path>` as the root for resolving `<BR_SUMMARY_SOURCE_ARTIFACT>` and `<EARS_TARGET_ARTIFACT>`.
- Do not assume fixed repository-local paths for feature artifacts.

## Completion Gate
- Before finalizing, run the runtime-provided EARS quality gate command against `<EARS_TARGET_ARTIFACT>` (for example `.helper/check_requirements_ears_quality.sh <EARS_TARGET_ARTIFACT>`).
- Gate pass condition:
  - command exits `0`.
- Gate fail condition:
  - command exits non-zero and returns one or more quality errors.
- On gate failure:
  - evaluate whether the gate can realistically pass with current BR facts and allowed inferences.
  - if pass is feasible, revise the EARS output and rerun the gate command.
  - if pass is not feasible with current BR input, stop finalization and send a short explanation followed by this exact line:
    `based on provided reasons, EARS gate cannot pass with current BR input. Please provide instructions what to do, or adjust requirements and rerun this phase`

## Minimal Traceability (Optional, Limited)
- If needed, include short trace hints compatible with the current template, for example:
  - `Source refs: FR-2, BR-1, rejection_cases`
- Keep traceability lightweight; do not redefine template structure.

## Linked Artifact Propagation (from BR Section 16)

### Document-Level Registry
- Read `## 16. Linked Artifacts` from `<BR_SUMMARY_SOURCE_ARTIFACT>`.
- If the list contains at least one entry, emit a `## Linked Artifacts` section at the end of `<EARS_TARGET_ARTIFACT>` (after `## Non-Functional Requirements` or the last section before any authoring notes), copying all entries verbatim with their id, title, type, and locator fields.
- If `## 16. Linked Artifacts` in the BR is empty (no entries), omit the `## Linked Artifacts` section from the EARS output entirely.

### Per-Requirement Association
- For each `### Requirement` block, apply semantic judgment to identify which LAR-NNN entries from BR section 16 are relevant to the behavior described in that requirement.
- When one or more LAR IDs are judged relevant, add a `**Linked Artifacts:**` field after `**Verification:**` listing those LAR IDs as bullet points (one per line), consistent with the bold-label style used by `**User Story:**` and `**Verification:**`.
- When no artifacts are relevant to a particular requirement, omit the `**Linked Artifacts:**` field for that block entirely.

### Registry Integrity
- Every LAR-NNN ID referenced in any `**Linked Artifacts:**` field must have a matching entry in the document-level `## Linked Artifacts` registry.
- Do not introduce LAR IDs that are not present in BR section 16.
