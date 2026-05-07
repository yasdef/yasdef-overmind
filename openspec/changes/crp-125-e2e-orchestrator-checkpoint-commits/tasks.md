## 1. Add commit helper to e2e orchestrator

- [ ] 1.1 Add `commit_feature_progress` function to `overmind/scripts/project_mgmt/project_add_feature_e2e.sh` that stages all changes with `git -C "$RUNTIME_ROOT" add -A` and commits with a descriptive label; print a notice and return 0 on nothing-to-commit or non-repo conditions.

## 2. Insert checkpoint calls in main phase loop

- [ ] 2.1 Call `commit_feature_progress "before step 5.1 (EARS review)"` in the main phase loop immediately before phase 5.1 runs (after phase 5 succeeds).
- [ ] 2.2 Call `commit_feature_progress "before step 7.1 (MCP enrichment)"` in the main phase loop immediately before phase 7.1 runs (after phase 7 succeeds).
- [ ] 2.3 Call `commit_feature_progress "before step 8.4 (semantic review)"` in the main phase loop immediately before phase 8.4 runs (after phase 8.3 succeeds).
- [ ] 2.4 Call `commit_feature_progress "after step 8.4 (semantic review)"` in the main phase loop immediately after phase 8.4 completes (run or skipped).
