## Why

The current technical-requirements phase can detect cross-repo contract pressure, but it cannot carry that coordination intent forward in a compact typed form. As a result, later phases either ignore the need entirely or reconstruct it loosely from prose, which makes cross-repo coordination inconsistent and hard to review.

## What Changes

- Replace the current section 6 loose `constraint_*` / `prep_*` pattern in `technical_requirements.md` with zero-or-more typed `planning_signal` blocks plus one explicit empty-path marker when no signal is needed.
- Introduce one initial signal type, `cross_repo_contract_lock`, with a strict schema that captures `signal_id`, `signal_type`, `owner_repo`, `consumer_repos`, `required_artifact`, `must_precede`, `output_requirements`, and `source_evidence`.
- Keep planning signals narrowly scoped as advisory metadata only: they make cross-repo coordination intent visible, preserve that intent for downstream consumers, and keep the reasoning reviewable without turning section 6 into implementation steps.
- Make the non-goals explicit in the contract: a signal is not mandatory just because a feature spans multiple repos, is not mandatory just because `feature_contract_delta.md` says `delta_needed: true`, must not become a hidden plan step, and must not regress back into loose `prep_*` prose once typed blocks exist.
- Update the technical-requirements rule, template, and golden example so section 6 shows both supported paths: one valid populated `planning_signal` block and one valid empty-path case.
- Update the technical-requirements quality helper to validate only structure and evidence integrity for section 6: unique signal ids, required fields present, `source_evidence` tokens resolve, repo ownership values are valid for the active project classes, and the empty-path marker is accepted without failure.
- Add targeted tests for the valid signal path, the empty-path case, invalid evidence tokens, duplicate signal ids, and invalid repo ownership.

## Capabilities

### New Capabilities

- `overmind-technical-requirements-planning-signals`: The technical-requirements artifact SHALL support optional typed `planning_signal` blocks in section 6 so cross-repo coordination intent can be expressed in a structured, reviewable, and non-mandatory form.

### Modified Capabilities

- `overmind-feature-technical-requirements`: The feature technical-requirements workflow SHALL treat section 6 as optional advisory metadata, SHALL support an explicit empty-path marker when no signal is needed, and SHALL validate typed planning signals structurally without forcing downstream planning actions.

## Impact

- Affected rule/template/example artifacts:
  - `overmind/rules/technical_requirements_rule.md`
  - `overmind/templates/technical_requirements_TEMPLATE.md`
  - `overmind/golden_examples/technical_requirements_GOLDEN_EXAMPLE.md`
- Affected scripts/helpers:
  - `overmind/scripts/helper/check_feature_technical_requirements_quality.sh`
- Affected tests:
  - `tests/ai_scripts/check_feature_technical_requirements_quality_tests.sh`
  - `tests/ai_scripts/init_feature_technical_requirements_tests.sh`
- Process impact:
  - Step 7 technical requirements can preserve cross-repo coordination intent in a typed form without forcing section 6 to be populated for every multi-repo feature.
  - Downstream artifacts gain a reviewable advisory signal surface, but they do not gain an automatic requirement to create coordination slices or plan steps solely because a signal exists.
