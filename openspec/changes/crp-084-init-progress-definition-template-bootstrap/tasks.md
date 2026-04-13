## 1. Add template-based progress definition source

- [x] 1.1 Create `overmind/templates/init_progress_definition_TEMPLATE.yaml` with canonical `meta_info` defaults and current ordered `steps` contract.
- [x] 1.2 Ensure template content is scanner-compatible without requiring runtime post-processing for step semantics.
- [x] 1.3 Update documentation/comments that currently treat `overmind/init_progress_definition.yaml` as static tracked source.

## 2. Implement runtime materialization in ASDLC initializer

- [x] 2.1 Update `overmind/scripts/init_asdlc_in_this_repo.sh` to create `overmind/init_progress_definition.yaml` from template when runtime file is missing.
- [x] 2.2 Add fail-fast behavior when runtime YAML already exists and print exactly: `init_progress_definition.yaml already exists, remove it completely if you need re-generate it`.
- [x] 2.3 Keep metadata prompt and persistence flow unchanged in ownership, writing selected values into `meta_info`.

## 3. Preserve deterministic metadata persistence and scanner compatibility

- [x] 3.1 Ensure metadata write logic remains deterministic for identical user selections on template-generated files.
- [x] 3.2 Verify scanner and consumer scripts continue reading `overmind/init_progress_definition.yaml` unchanged.
- [x] 3.3 Add fail-fast handling for missing template source with explicit actionable error messaging.

## 4. Extend and update regression test coverage

- [x] 4.1 Update `tests/ai_scripts/init_asdlc_in_this_repo_tests.sh` to cover file-missing template materialization path.
- [x] 4.2 Add test coverage proving existing runtime YAML triggers non-zero fail-fast with the exact canonical message.
- [x] 4.3 Update scanner-related tests where fixture setup assumes only static progress-definition source semantics.

## 5. Validate and document

- [x] 5.1 Update `overmind/README.md` bootstrap instructions to describe template-based creation through `init_asdlc_in_this_repo.sh`.
- [x] 5.2 Run targeted shell tests from repo root for ASDLC initializer and scanner flows.
- [x] 5.3 Confirm `openspec status --change crp-084-init-progress-definition-template-bootstrap` reports apply-ready completion.
