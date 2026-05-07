## Context

`project_add_feature_e2e.sh` is a long-running orchestrator that drives a multi-phase feature pipeline (steps 3–8.4). Optional phases (5.1, 7.1, 8.4) can modify feature artifacts in-place with no git checkpoint. If a user wants to roll back an optional phase or inspect state before it ran, there is currently no saved commit to revert to.

The ASDLC workspace is a standard git repository initialised by `project_setup_add_new_project.sh`. The orchestrator is the right place to insert checkpoints because it is the only code that knows the phase order.

## Goals / Non-Goals

**Goals:**
- Insert a git checkpoint commit at four phase boundaries: before 5.1, before 7.1, before 8.4, and after 8.4.
- Fail gracefully (warn and continue) when the workspace is not a git repository or when there is nothing to commit.

**Non-Goals:**
- Checkpoints at every phase boundary — only the boundaries adjacent to optional steps need them.
- Changing any individual feature script.
- Altering commit message policy for the initial project setup.

## Decisions

### Single reusable helper

Add `commit_feature_progress` to `project_add_feature_e2e.sh`. It takes a descriptive label (e.g., `"before step 5.1 (EARS review)"`), runs `git -C "$RUNTIME_ROOT" add -A` followed by `git -C "$RUNTIME_ROOT" commit -m "..."`, and prints a one-line status. No return-value protocol is needed — the function prints a warning and returns 0 on non-fatal conditions (nothing to commit, not a git repo).

Alternatives considered:
- **Inline git calls at each site** — noisier, harder to audit.
- **Separate script** — unnecessary overhead for four call sites in one file.

### Placement in the main loop

The four commits are placed in the `main()` phase loop, not inside `run_phase_by_index`. This keeps phase execution functions free of side effects and centralises checkpoint logic. A `case` or `if` on `${PHASE_IDS[$idx]}` identifies the right boundary:

| Trigger condition | Checkpoint label |
|---|---|
| After phase 5 (idx of 5.1 is about to run) | `before step 5.1 (EARS review)` |
| After phase 7 (idx of 7.1 is about to run) | `before step 7.1 (MCP enrichment)` |
| After phase 8.3 (idx of 8.4 is about to run) | `before step 8.4 (semantic review)` |
| After phase 8.4 succeeds or is skipped | `after step 8.4 (semantic review)` |

### Nothing-to-commit tolerance

`git commit` exits non-zero when there is nothing to commit. The helper checks the exit code and prints a notice rather than propagating the error.

## Risks / Trade-offs

- [git not available in PATH] → Commit is skipped with a warning; orchestrator continues normally.
- [Large feature diffs slow the commit] → Negligible in practice; feature folders contain only text files.
