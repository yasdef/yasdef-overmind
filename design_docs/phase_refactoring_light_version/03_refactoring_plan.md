# Phase Refactoring: Refactoring Plan

**Status: placeholder — not started, not committed.** To be written after the pending decisions in `02_phase_redesign_and_target_architecture.md` section `## 8. Pending Decisions and Deferred Topics` are confirmed.

Rough phase sketch (subject to change):

- **Phase 0 — settle decisions.** Decide the business-visible-gap exception path (the open sliver of the two-case prerequisite model), living-inventory bootstrap approach, F4 grounding artifact template shape.
- **Phase 1 — specify.** Target step definitions (YAML as canonical source), artifact templates, and gate specs (plan readiness checks, pass-B structural diff, interrogation coverage).
- **Phase 2 — implement in the TS port.** Land as skills + `asdlc-coordinator` gates per `design_docs/to_skills_migration/`; do not patch the shell+md pipeline.
- **Phase 3 — validate.** Parallel-run one feature on an experimental project against the old pipeline; compare plan quality and gate behavior.
- **Phase 4 — cut over.** Retire old feature-phase steps/templates; update `overmind/README.md` and the sequence diagram (generated/derived from YAML).
