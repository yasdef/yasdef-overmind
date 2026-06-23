---
name: overmind-requirements-ears
description: Use when converting a readiness-approved feature_br_summary.md into atomic EARS requirements in requirements_ears.md.
---

# Overmind Requirements EARS

Use this skill to convert a feature folder's readiness-approved business requirements summary into deterministic, testable EARS requirements.

## Required Invocation

Run these commands from the installed project root:

1. Assemble deterministic context:

```bash
node .overmind/overmind.js context requirements-ears <feature-path>
```

2. Read the emitted context block and write only:
- `<feature-path>/requirements_ears.md`

3. Validate after every write or repair:

```bash
node .overmind/overmind.js gate requirements-ears <feature-path>
```

Handle gate exit codes exactly:
- `0`: gate passed; finish.
- `1`: recoverable EARS artifact issue; read each `missing: ...` line, repair only `requirements_ears.md`, and rerun the gate.
- `2`: runtime or validation failure; stop, report the blocker, and wait for operator instructions.

The model owns the context/write/gate/repair loop. Do not ask the operator for deterministic paths, readiness state, or validation details that the context and gate commands provide.

If gate compliance is not feasible with the current BR input and the rules below, stop finalization, briefly explain the blocker, and end with this exact line:

```text
based on provided reasons, EARS gate cannot pass with current BR input. Please provide instructions what to do, or adjust requirements and rerun this phase
```

When the gate passes, end your final response with this exact last line:

```text
BR->requirement-EARS phase is finished. Nothing else to do now; press Ctrl-C so orchestrator can start the next phase
```

## Assets

Asset paths are relative to this loaded skill directory. Do not resolve them through a hardcoded agent install path such as `.codex/skills/...` or `.claude/skills/...`; use the copy exposed by the current supported CLI.

- `assets/reqirements_ears_TEMPLATE.md`
- `assets/reqirements_ears_GOLDEN_EXAMPLE.md`

## Inlined BR to Atomic EARS Conversion Rule

### Purpose

- Convert readiness-approved structured BR content into deterministic, atomic EARS requirements.
- Preserve the existing EARS output shape already used by this repository.
- Keep model-facing conversion behavior in this skill, not in shell or TypeScript launcher prompts.

### Authoritative Inputs and Outputs

- Read-only business source for this run: `feature_br_summary.md`, resolved by the context command.
- Output target for this run: `requirements_ears.md`, resolved by the context command.
- Do not edit `feature_br_summary.md` during this stage.
- Do not create or modify unrelated artifacts.
- The allowed write list is exactly `requirements_ears.md`.

### Output Format Baseline

- Use `assets/reqirements_ears_TEMPLATE.md` as the structural template.
- Use `assets/reqirements_ears_GOLDEN_EXAMPLE.md` as the style and block-shape reference.
- Keep standard sections and block format:
  - `## Requirements` with `### Requirement <N> — <Title>` blocks.
  - `## Non-Functional Requirements` with `### NFR <N> — <Title>` blocks when NFR facts exist.
  - Each block must include `**User Story:**`, `**Acceptance Criteria (EARS):**`, and `**Verification:**`.
- Do not introduce a parallel schema, metadata-only schema, or alternate top-level structure.

### Source-of-Truth and Inference Rules

- Use only facts present in `feature_br_summary.md`.
- If a minimal inference is necessary for grammatical completeness, mark it inline with `[Inference]`.
- Keep inferred content conservative and directly bounded by nearby BR facts.
- If facts are missing or ambiguous, do not invent behavior.
- Prefer narrower requirements; if narrowing still leaves uncertainty, add:
  - `Unresolved gap: <fact missing from BR summary>.`
- Do not start a new user-question loop in this stage.

### Extraction Map From Structured BR

Extract conversion ingredients from these BR areas before drafting blocks:

- Actor: `## 4. Actors and Consumers` primary and secondary actors.
- Trigger/event: `## 6. Functional Requirements`, `## 7. Business Rules and Decision Logic`, `## 10. Failure Cases and Edge Cases`.
- Preconditions/state: `## 8. Permissions and Access Constraints`, `## 9. State and Data Expectations`.
- Expected behavior: `## 6. Functional Requirements`.
- Rejection behavior: `## 10. Failure Cases and Edge Cases`, plus constraint-driven rejects from `## 8. Permissions and Access Constraints`.
- State/data effects and persistence: `## 9. State and Data Expectations`.
- Side effects and integration effects: `## 11. Integration and Dependency Context`.
- NFR constraints: `## 12. Non-Functional Requirements`.
- Scope boundaries/non-goals: `## 5. Scope Definition` and `## 2.3 Explicitly stated in source`.

### Atomic Splitting Rules

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

### Allowed EARS Patterns

Each acceptance bullet must use exactly one allowed pattern:

- `THE <System Name> SHALL <capability>.`
- `WHEN <event>, THE <System Name> SHALL <response>.`
- `IF <condition>, THEN THE <System Name> SHALL <response>.`
- `WHILE <state>, THE <System Name> SHALL <response>.`
- `WHERE <feature/constraint>, THE <System Name> SHALL <response>.`
- `WHEN <event> AND WHILE <state>, THE <System Name> SHALL <response>.`

The gate matches these patterns case-insensitively. Do not use free-form imperative bullets outside these patterns.

### Prohibited Content in EARS Statements

- Implementation design or architecture decisions.
- File paths, module names, class names, endpoint wiring, or roadmap/planning text.
- Shell/process instructions, helper behavior, or quality-loop mechanics.

### Deterministic Ordering and Numbering

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

### Runtime Path Binding Rules

- Runtime bindings from `node .overmind/overmind.js context requirements-ears <feature-path>` are authoritative for each invocation.
- Use the emitted workspace root, feature path, read-only BR source, target EARS artifact, asset paths, allowed-write list, and gate command exactly.
- Do not assume fixed source-repo paths or runner-specific skill install paths.
- Run the gate command after every write or repair.

### Completion Gate

- Before finalizing, run `node .overmind/overmind.js gate requirements-ears <feature-path>` against the current `requirements_ears.md`.
- Gate pass condition:
  - command exits `0`.
- Gate recoverable condition:
  - command exits `1` and returns one or more `missing: quality gate failed: ...` lines.
- Runtime failure condition:
  - command exits `2`.
- On gate exit `1`, evaluate whether the gate can realistically pass with current BR facts and allowed inferences. If pass is feasible, revise `requirements_ears.md` and rerun the gate. If pass is not feasible, stop finalization with the infeasibility line from `Required Invocation`.

### Minimal Traceability

- If needed, include short trace hints compatible with the current template, for example:
  - `Source refs: FR-2, BR-1, rejection_cases`
- Keep traceability lightweight; do not redefine template structure.

### Linked Artifact Propagation From BR Section 16

#### Document-Level Registry

- Read `## 16. Linked Artifacts` from `feature_br_summary.md`.
- If the list contains at least one entry, emit a `## Linked Artifacts` section at the end of `requirements_ears.md`, after `## Non-Functional Requirements` or the last section before any authoring notes, copying all entries verbatim with their id, title, type, and locator fields.
- If `## 16. Linked Artifacts` in the BR is empty, omit the `## Linked Artifacts` section from the EARS output entirely.

#### Per-Requirement Association

- For each `### Requirement` block, apply semantic judgment to identify which `LAR-NNN` entries from BR section 16 are relevant to the behavior described in that requirement.
- When one or more `LAR-NNN` ids are relevant, add a `**Linked Artifacts:**` field after `**Verification:**` listing those ids as bullet points, one per line, consistent with the bold-label style used by `**User Story:**` and `**Verification:**`.
- When no artifacts are relevant to a requirement, omit the `**Linked Artifacts:**` field for that block entirely.

#### Registry Integrity

- Every `LAR-NNN` id referenced in any `**Linked Artifacts:**` field must have a matching entry in the document-level `## Linked Artifacts` registry.
- Do not introduce `LAR-NNN` ids that are not present in BR section 16.
