## Context

`project_setup_add_new_project.sh` creates a project record and seeded folder. This change adds guided project class selection and class-scoped repository path capture during creation time. The behavior includes two interactive loops: class selection until explicit completion, then per-class repo-path readiness and capture.

This change extends the per-project definition contract in `projects/<project_id>/init_progress_definition.yaml` while keeping `asdlc/asdlc_metadata.yaml` minimal. It needs deterministic, shell-only input handling with validation safeguards for path collection.

## Goals / Non-Goals

**Goals:**
- Add numbered class-selection loop: `1 backend`, `2 frontend`, `3 mobile`, `4 infrastructure`, `5 done`.
- Keep prompting until user selects `5`; after each valid add, show already selected classes.
- Remove already-selected class options from subsequent prompts (eventually only option `5` remains).
- After class loop, ask per selected class if user is ready to add local repo path now (`1 yes`, `2 later`).
- If `yes`, prompt for path and validate it exists and is non-empty.
- Persist class list and class-level repo path state in project definition metadata (`meta_info.project_classes`, `meta_info.class_repo_paths`).

**Non-Goals:**
- Verify repository type or contents beyond existence/non-empty path checks.
- Add CLI flags/options or non-interactive bulk modes.
- Refactor unrelated update-project or downstream pipeline scripts.

## Decisions

1. Keep two explicit interactive loops in add-project script.
Rationale: matches requested conversational flow and makes class completion intentional via option `5`.
Alternative considered: single free-form comma input. Rejected because it removes guided incremental confirmation.

2. Normalize class values to canonical labels: `backend`, `frontend`, `mobile`, `infrastructure`.
Rationale: deterministic metadata and stable downstream branching.
Alternative considered: storing numeric selections. Rejected due poor readability and coupling to prompt numbering.

3. Persist class-level repo path capture as structured object in project definition metadata.
Rationale: supports explicit ready/later outcome and optional path values per selected class.
Alternative considered: flat list of paths only. Rejected because it cannot represent “add later” state clearly.

4. Validate paths using shell checks only (`-e`, `-d`, `ls -A`).
Rationale: portable and aligned with no extra dependency requirement.
Alternative considered: language-specific filesystem tooling. Rejected to preserve shell-only constraint.

## Risks / Trade-offs

- [Risk] Interactive loops can become noisy if invalid input repeats.
  Mitigation: keep concise validation errors and reprint available choices each retry.

- [Risk] Path validation criteria may reject acceptable repos (for example symlink edge cases).
  Mitigation: accept existing directories and fail only on missing or empty directory paths.

- [Risk] Additional metadata fields in project definitions may impact strict consumers of template structure.
  Mitigation: preserve existing keys and append additive fields (`project_id`, `class_repo_paths`).

## Migration Plan

1. Extend add-project script prompt flow for class-selection loop with running summary and shrinking menu.
2. Add per-class repo-path readiness loop and path validation branch.
3. Write selected classes and class-path capture data into `projects/<project_id>/init_progress_definition.yaml`; keep `asdlc_metadata.yaml` project record minimal.
4. Update helper tests for loop behavior, duplicate handling, repo-path capture, and invalid path retries.
5. Update README add-project section with the new interaction contract.

Rollback strategy: revert add-project script and tests to pre-loop behavior while retaining existing project record creation.

## Open Questions

- None.
