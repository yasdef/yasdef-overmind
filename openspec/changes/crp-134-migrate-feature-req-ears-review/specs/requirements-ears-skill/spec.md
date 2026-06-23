## ADDED Requirements

### Requirement: Feature e2e orchestrator preserves the read-only BR guard for the requirements-ears phase

CRP-133 migrated step 5 (BR→EARS) but dropped the former `feature_br_to_ears.sh` `ensure_feature_br_summary_unchanged` protection, leaving the phase 5 launcher (`run_requirements_ears_skill` in `project_add_feature_e2e.sh`) with only advisory allowed-write and `SKILL.md` text guarding the read-only `feature_br_summary.md`. This change SHALL retrofit the same deterministic guard onto that launcher: the phase 5 launcher SHALL snapshot `feature_br_summary.md` before launching the `overmind-requirements-ears` skill session and SHALL assert it is byte-unchanged after the session completes, failing the phase with an actionable error if it was modified. The retrofit SHALL be limited to this guard and SHALL NOT change step 5's skill, gate, or context behavior.

#### Scenario: requirements-ears phase fails on read-only BR mutation

- **WHEN** the phase 5 `overmind-requirements-ears` skill session completes but `feature_br_summary.md` differs from its pre-launch snapshot
- **THEN** the phase fails with an actionable error reporting that the read-only BR summary must not be modified, and does not report the phase as successful

#### Scenario: requirements-ears phase still passes when BR is untouched

- **WHEN** the phase 5 skill session completes and `feature_br_summary.md` matches its pre-launch snapshot
- **THEN** the read-only BR guard passes and the phase proceeds with its existing success behavior unchanged
