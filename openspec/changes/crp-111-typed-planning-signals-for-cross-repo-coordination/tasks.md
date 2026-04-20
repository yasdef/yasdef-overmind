## 1. Replace the section 6 contract

- [x] 1.1 Update `overmind/rules/technical_requirements_rule.md` so section 6 allows zero or more typed `### Planning Signal:` blocks or the exact empty marker `- planning_signals: none`, limits supported `signal_type` to `cross_repo_contract_lock`, and states that signals are advisory metadata rather than execution steps.
- [x] 1.2 Update `overmind/templates/technical_requirements_TEMPLATE.md` to replace the old `constraint_*` / `prep_*` example with the typed planning-signal field set and the explicit empty-path marker.
- [x] 1.3 Update `overmind/golden_examples/technical_requirements_GOLDEN_EXAMPLE.md` so section 6 shows both required paths: one valid populated `cross_repo_contract_lock` block and one valid empty-path case.

## 2. Implement structural validation for planning signals

- [x] 2.1 Update `overmind/scripts/helper/check_feature_technical_requirements_quality.sh` to parse section 6 as typed planning-signal content, accept `- planning_signals: none`, require `signal_type: cross_repo_contract_lock` for populated blocks, and require unique `signal_id` values plus all required fields.
- [x] 2.2 Extend the helper so `owner_repo` and every `consumer_repos` entry must match the active project classes, and `source_evidence` must resolve to local `REQ-*`, `NFR-*`, or `comp/<component-slug>` tokens from the same artifact.
- [x] 2.3 Make the helper reject legacy section-6 `constraint_*` / `prep_*` entries after the typed contract is active, while still remaining policy-free about whether a planning signal was required.

## 3. Refresh automated coverage

- [x] 3.1 Update `tests/ai_scripts/check_feature_technical_requirements_quality_tests.sh` with passing coverage for one valid `cross_repo_contract_lock` block and for the explicit empty-marker case.
- [x] 3.2 Add failing coverage in `tests/ai_scripts/check_feature_technical_requirements_quality_tests.sh` for unsupported `signal_type`, duplicate `signal_id`, unresolved `source_evidence`, invalid repo ownership, and legacy loose section-6 content.
- [x] 3.3 Add regression coverage in the appropriate technical-requirements test suite proving section 6 may remain `- planning_signals: none` for a multi-repo feature and may remain `- planning_signals: none` even when surrounding feature context still implies contract-delta work, as long as no advisory planning signal is actually warranted.
- [x] 3.4 Update `tests/ai_scripts/init_feature_technical_requirements_tests.sh` fixtures and expectations so generated `technical_requirements.md` output uses typed planning-signal content or the explicit empty marker instead of `constraint_*` / `prep_*` lines.

## 4. Validate change readiness

- [x] 4.1 Run `bash tests/ai_scripts/check_feature_technical_requirements_quality_tests.sh` from the repository root.
- [x] 4.2 Run `bash tests/ai_scripts/init_feature_technical_requirements_tests.sh` from the repository root.
- [x] 4.3 Run `openspec status --change crp-111-typed-planning-signals-for-cross-repo-coordination` and confirm the change is apply-ready.
