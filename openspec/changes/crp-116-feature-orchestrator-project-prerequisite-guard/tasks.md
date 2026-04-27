## 1. Implement scanner prerequisite guard

- [x] 1.1 Add a first-supported-step constant for `project_add_feature_e2e.sh`, set to Step `3`.
- [x] 1.2 Add a dotted numeric step-id comparison helper that correctly treats `1.1` and `2` as earlier than `3`, and handles multi-segment values such as `2.10` predictably.
- [x] 1.3 Add a project-prerequisite failure helper that prints the scanner-reported step id/name, explains that project init is incomplete, and exits nonzero.
- [x] 1.4 Include specific command guidance for Step `1.1` using `.commands/init_project_stack_blueprints.sh --path <project-path>`.
- [x] 1.5 Include specific command guidance for Step `2` using `.commands/init_common_contract_definition.sh --path <project-path>`.
- [x] 1.6 Wire the guard after `run_scanner_and_get_next_step` and before `map_scanner_step_to_phase`, preserving current handling for `next step: none`.

## 2. Preserve supported feature routing

- [x] 2.1 Confirm scanner results for Step `3` and later continue through existing phase mapping without prerequisite failure output.
- [x] 2.2 Confirm unknown scanner steps that are not earlier than Step `3` still use the existing unmapped-step error path.
- [x] 2.3 Keep scanner invocation, saved feature path handling, resume parsing, and downstream `--feature_path` command calls unchanged.

## 3. Add regression coverage

- [x] 3.1 Add a `project_add_feature_e2e.sh` test where scanner returns Step `1.1` and assert nonzero exit plus stack-blueprint command guidance.
- [x] 3.2 Add a `project_add_feature_e2e.sh` test where scanner returns Step `2` and assert nonzero exit plus common-contract command guidance.
- [x] 3.3 Add or update coverage proving scanner Step `3` or later still follows existing orchestration behavior.
- [x] 3.4 Add coverage for a future earlier dotted step without a known command hint and assert generic project-prerequisite guidance.

## 4. Verify

- [x] 4.1 Run `bash tests/ai_scripts/project_add_feature_e2e_tests.sh`.
- [x] 4.2 Run `openspec status --change crp-116` and confirm the change is apply-ready.
