## 1. Canonical captured-source derivation and context

- [x] 1.1 Add one shared TypeScript derivation utility used by task-to-BR context and validation that returns the workspace-relative `user_br_input.md` path followed by the trimmed `epic_story_source_file` value, removes duplicates in first-seen order, and identifies an unfilled original-source field
- [x] 1.2 Update `packages/asdlc-coordinator/src/context/task-to-br.ts` to emit the canonical required source references as an explicit semicolon-delimited context binding after capture, preserving CRP-162's capture→context→gate ordering and the existing CLI surface

## 2. Task-to-BR skill contract and runtime documentation

- [x] 2.1 Update `packages/installer/_data/skills/overmind-task-to-br/SKILL.md` so `feature_br_summary.md` `## 1. Document Meta -> source_refs` merges every context-required captured source, uses capture-record-first canonical output, and preserves additional populated references
- [x] 2.2 Update `packages/installer/_data/skills/overmind-task-to-br/assets/feature_br_summary_GOLDEN_EXAMPLE.md` from the bare `source_refs: JIRA-AUTH-241` value to exactly `source_refs: projects/auth-platform/self-service-password-reset/user_br_input.md; jira:JIRA-AUTH-241`, leaving the existing template responsible only for field structure
- [x] 2.3 Add a concise task-to-BR source-binding contract to `overmind/README.md`, naming the capture record and `epic_story_source_file` locator required in `source_refs`

## 3. Deterministic task-to-BR gate

- [x] 3.1 Update `packages/asdlc-coordinator/src/validate/task-to-br.ts` to read `source_refs` only from `feature_br_summary.md` `## 1. Document Meta`, parse exact semicolon-delimited elements, and require every canonical captured-source reference while allowing alternate order and additional populated references
- [x] 3.2 Preserve recoverable exit `1` when `user_br_input.md` is missing and name the file so capture can be rerun; also return exit `1` diagnostics for an absent/unfilled `source_refs` field, an absent/unfilled `user_br_input.md -> epic_story_source_file`, and each exact missing required reference, while retaining exit `2` for a missing target BR summary or validator runtime failure and exit `1` for a missing `missing_br_data.md`

## 4. Regression and deployability tests

- [x] 4.1 Extend task-to-BR context and capture tests for local-file and Jira inputs, canonical workspace-relative paths, capture-record-first ordering, deduplication, and the explicit required-reference binding after capture
- [x] 4.2 Extend task-to-BR validator tests and fixtures for a complete binding, a missing `user_br_input.md` file returning exit `1`, each missing reference independently, missing/unfilled fields, substring-only mismatch, alternate order, and preservation of an additional reference
- [x] 4.3 Extend installer tests to prove fresh and update installs place the updated task-to-BR skill and golden example in both `.codex/skills/overmind-task-to-br` and `.claude/skills/overmind-task-to-br`
- [x] 4.4 Add a temporary-workspace task-to-BR smoke case that begins without `user_br_input.md`, captures a local source before context derivation, obtains context, repairs `source_refs`, and passes the gate without introducing a pre-session context dependency

## 5. Verification

- [x] 5.1 Run `npm run test --workspace asdlc-coordinator`, `npm run test --workspace overmind-installer`, `npm test`, and `npm run verify` from the repository root and fix regressions
