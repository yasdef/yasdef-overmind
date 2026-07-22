## 1. Split current project setup flow into dispatcher + helpers

- [x] 1.1 Create helper script files for option `1`, option `2`, and option `3` under `overmind/scripts/` with clear ownership comments/purpose.
- [x] 1.2 Move the current `overmind/scripts/project_mgmt/project_setup_asdlc.sh` implementation logic into helper script #2 (`add new project`) without behavior changes.
- [x] 1.3 Replace `overmind/scripts/project_mgmt/project_setup_asdlc.sh` body with dispatcher-only flow that prints the required startup prompt and options.

## 2. Implement deterministic routing and input validation

- [x] 2.1 Parse one numeric user selection and map `1`/`2`/`3` to the matching helper script path.
- [x] 2.2 Enforce fail-fast invalid-selection behavior (non-zero exit and valid-options guidance).
- [x] 2.3 Ensure dispatcher executes exactly one helper and returns the helper's exit code unchanged.

## 3. Preserve option-2 metadata initialization contract

- [x] 3.1 Confirm helper #2 preserves current metadata init semantics (required files, branch checks, prompts, YAML write, and commit behavior).
- [x] 3.2 Keep existing output/error contracts consumed by downstream scripts and tests (including missing/invalid metadata guidance).
- [x] 3.3 Add placeholder behavior contract for helpers #1 and #3 until their full logic is provided in a follow-up change.

## 4. Update tests and documentation

- [x] 4.1 Update `tests/ai_scripts/project_setup_asdlc_tests.sh` for dispatcher prompt/options and option-2 execution path.
- [x] 4.2 Add routing tests for valid options and invalid selection fail-fast behavior.
- [x] 4.3 Update `overmind/README.md` to describe `project_setup_asdlc.sh` as dispatcher and document helper split.

## 5. Validate apply readiness

- [x] 5.1 Run targeted script tests from repository root for project setup dispatcher and impacted downstream flows.
- [x] 5.2 Run `openspec status --change crp-085-project-setup-asdlc-dispatcher` and verify apply-required artifacts are complete.
