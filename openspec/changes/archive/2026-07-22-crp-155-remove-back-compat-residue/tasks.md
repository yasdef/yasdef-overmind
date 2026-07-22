## 1. Remove retired shell `.env` feature-state cache

- [x] 1.1 Delete the `LEGACY_FEATURE_STATE_FILE_NAME` export (and its doc comment) from `packages/asdlc-coordinator/src/state/feature-state.ts`; confirm `state/index.ts` needs no edit (wildcard re-export).
- [x] 1.2 In `packages/asdlc-coordinator/test/feature-state.test.ts`, remove the `LEGACY_FEATURE_STATE_FILE_NAME` import and delete the `"legacy env state is ignored, not migrated"` test scenario.
- [x] 1.3 Grep the repo for `LEGACY_FEATURE_STATE_FILE_NAME` to confirm no remaining source/test references (ignore `dist/` build output).

## 2. Remove `InstallResult.skillPath` compatibility field

- [x] 2.1 Remove the `skillPath` field from the `InstallResult` interface and its assignment (plus the now-unused `claudeTaskToBrSkillPath` local) in `packages/installer/src/init.ts`.
- [x] 2.2 Confirm `packages/installer/src/bin/overmind.ts` reports installed skills solely from `result.skillPaths` (already the case); make no output change.
- [x] 2.3 Remove the `assert.equal(result.skillPath, ...)` assertion from `packages/installer/test/init.test.ts`.
- [x] 2.4 Grep the repo for `skillPath` (word-boundary, not `skillPaths`) to confirm no remaining source/test references.

## 3. Verify

- [x] 3.1 Run `npm run typecheck`, `npm run lint`, `npm run format:check`, `npm run build`.
- [x] 3.2 Run `npm test` and `npm run verify`; confirm both green and `git diff --check` is clean.
