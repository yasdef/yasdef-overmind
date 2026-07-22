## ADDED Requirements

### Requirement: ears-review launcher read-only guard runs on every exit path

The `project_add_feature_e2e.sh` phase 5.1 launcher (`run_ears_review_skill`) SHALL evaluate its deterministic `feature_br_summary.md` immutability comparison on **every** exit path — including when the model session exits non-zero — and SHALL do so before the launcher returns the model's exit code. When `feature_br_summary.md` drifted from its pre-launch snapshot, phase 5.1 SHALL fail with the read-only-corruption error even if the model session also exited non-zero, so a model that both corrupts the read-only BR summary and fails cannot bypass the guard. This closes a gap in the shipped launcher, which returned the model's non-zero exit code before reaching the comparison. The fix SHALL be limited to the guard ordering; the skill, gate, context, prompt content, and final-response lines for step 5.1 SHALL be unchanged.

#### Scenario: BR mutation is caught even when the model exits non-zero

- **WHEN** the phase 5.1 skill session mutates `feature_br_summary.md` **and** the model exits non-zero
- **THEN** the launcher evaluates the BR immutability comparison before returning, and phase 5.1 fails with the read-only-corruption error rather than silently propagating the model exit code and leaving the corrupted BR summary

#### Scenario: Untouched BR with a model failure still propagates the model failure

- **WHEN** the phase 5.1 skill session exits non-zero but `feature_br_summary.md` is byte-unchanged from its snapshot
- **THEN** phase 5.1 fails with the model's exit code (normal restartable failure), with no spurious read-only-corruption error

#### Scenario: Successful run preserves the existing guard behavior

- **WHEN** the phase 5.1 skill session exits zero
- **THEN** the launcher still asserts the model produced `requirements_ears_review.md` and that `feature_br_summary.md` is byte-unchanged, exactly as before
