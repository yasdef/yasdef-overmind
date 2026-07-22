## ADDED Requirements

### Requirement: Shared Diagnostic type

The system SHALL define a single shared `Diagnostic` type in `types/` with the authoritative shape `{ severity: error | warning, source: <file path>, reason, stepId? }` (`03_target_architecture.md ## Diagnostics`; `02_responsibility_translation_map.md` row 23), non-sensitive by construction (paths and reasons only, never file content), as the one cross-cutting model for data problems across the pure core. This type SHALL land in this slice (retrofit is invasive) and SHALL be the carrier used by `ProgressReport.diagnostics`. Deterministic classification that a projection must branch on (e.g. definition-parse failure driving `unknown` readiness) SHALL be carried as a typed field on `ProgressReport` (see the `progress-sequencing` capability), NOT by overloading the `Diagnostic` shape — keeping this type identical to the authoritative design contract.

#### Scenario: Diagnostic carries path, reason, and severity

- **WHEN** a core module produces a diagnostic for a malformed input
- **THEN** the diagnostic has a `severity`, a `source` path, and a `reason`, carries no file content, and adds no fields beyond the authoritative shape

#### Scenario: Optional stepId association

- **WHEN** a diagnostic originates from evaluating a specific declared step
- **THEN** the diagnostic may carry that `stepId` so adapters can associate it with the step

### Requirement: Errors-as-values convention for pure modules

The pure modules (`workspace/`, `sequencing/`, `parse/`) SHALL NOT throw for **data** problems — malformed YAML, missing or unreadable artifacts, and inconsistent definitions SHALL produce `diagnostics[]` in the typed result and degrade the affected item (`blocked` step state, or `unknown` readiness per the `ProgressReport` readiness mapping) instead of crashing the computation. Throwing SHALL be reserved for programmer errors. An acceptance test SHALL prove that malformed or missing definition inputs yield a `ProgressReport` with degraded step states and populated `diagnostics[]` — no throw.

#### Scenario: Malformed definition yields diagnostics, not a throw

- **WHEN** `evaluate` runs against a project whose `init_progress_definition.yaml` is malformed
- **THEN** it returns a `ProgressReport` with degraded step states and at least one error-severity diagnostic naming the file and reason, and does not throw

#### Scenario: Missing artifact degrades the step, not the run

- **WHEN** a declared required artifact for a step is absent or unreadable
- **THEN** the step is reported not-done with the artifact listed in `missingArtifacts` (and a diagnostic when the file is unreadable), and evaluation of remaining steps continues without throwing

### Requirement: Adapters render diagnostics, never invent them

Adapters (the CLI in this slice; the extension later) SHALL render the diagnostic values produced by the core and SHALL NOT invent diagnostics of their own for core data problems. The CLI SHALL format diagnostics to stderr and map them to exit codes; the same values SHALL later be routable to the extension's output channel unchanged.

#### Scenario: CLI renders core diagnostics to stderr

- **WHEN** `overmind status` evaluates a project that produced error-severity diagnostics
- **THEN** the CLI writes those diagnostics' path and reason to stderr and exits non-zero, without adding diagnostics the core did not produce
