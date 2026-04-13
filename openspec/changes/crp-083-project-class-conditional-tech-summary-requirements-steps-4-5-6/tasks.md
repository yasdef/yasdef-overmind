## 1. Extend step contract schema for conditional requirements

- [x] 1.1 Update `overmind/init_progress_definition.yaml` Step 4, Step 5, and Step 6 tech-summary entries to use `required_if.meta_info.project_classes.any_of` guards.
- [x] 1.2 Keep unguarded requirements unchanged and verify schema remains backward-compatible for existing entries.
- [x] 1.3 Add schema-level validation behavior for malformed `required_if` structures.

## 2. Implement shared conditional-evaluation logic

- [x] 2.1 Add or extend shared helper logic so `required_if` evaluation is implemented once and reused by all requirement consumers.
- [x] 2.2 Implement deterministic `any_of` evaluation against `meta_info.project_classes`.
- [x] 2.3 Implement fail-fast error messages when `required_if` is malformed or unsupported.

## 3. Apply conditional evaluation to Step 4 scanner completion

- [x] 3.1 Update `overmind/scripts/init_progress_scanner.sh` parser to read optional `required_if` fields on `finished_only_if_artefacts_present` entries.
- [x] 3.2 Update scanner completion logic so guarded artifact entries are mandatory only when their condition matches.
- [x] 3.3 Preserve existing behavior for unguarded entries, artifact groups, and sequential short-circuit gating.

## 4. Apply conditional evaluation to Step 5/6 input-required checks

- [x] 4.1 Identify and update the script path(s) that enforce `input_required` readiness for Steps 5 and 6.
- [x] 4.2 Apply the same shared `required_if` semantics used by scanner evaluation.
- [x] 4.3 Ensure Step 5/6 do not fail solely on missing tech summaries when `project_classes` is empty.

## 5. Add regression coverage and validate

- [x] 5.1 Extend `tests/ai_scripts/init_progress_scanner_tests.sh` with backend-only, frontend/mobile-only, fullstack, and empty-class scenarios for Step 4.
- [x] 5.2 Add or update tests for Step 5/6 input-required evaluation under the same class permutations.
- [x] 5.3 Run targeted test suites from repository root and confirm no regressions for unguarded requirements.
