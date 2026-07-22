## Context

This change closes the e2e sh→TS migration (CRP-144–149) with zero back-compat residue.
Two vestiges of the "recognize the old thing to stay compatible" reflex remain in the
already-migrated TypeScript, per
`design_docs/e2e_orchestrator_migration/06_sh_remove_plan.md ### Unit E / CRP-155`. Under
the fresh-install lens — Overmind has never been installed, so no prior on-disk state and
no prior caller exist — both are dead ceremony.

Current state:

- `packages/asdlc-coordinator/src/state/feature-state.ts` exports
  `LEGACY_FEATURE_STATE_FILE_NAME` (`.project_add_feature_e2e_state.env`) "recognized only
  to be ignored". Production `readFeatureState` reads only `FEATURE_STATE_FILE_NAME`
  (`.overmind_feature_state.json`) and never references the legacy constant; ignoring is
  already the default. `state/index.ts` re-exports the whole module, and
  `test/feature-state.test.ts` has a `"legacy env state is ignored, not migrated"`
  scenario that imports and writes the legacy file.
- `packages/installer/src/init.ts` keeps a singular `InstallResult.skillPath` (the Claude
  `overmind-task-to-br` path) "retained from CRP-129" alongside the fan-out `skillPaths[]`.
  `bin/overmind.ts` already reports installed skills from `skillPaths`; only
  `test/init.test.ts` still asserts on `skillPath`.

This is a cross-package cleanup with a spec-level behavioral contract (install output and
feature-state recognition), which is why it carries specs and this short design note.

## Goals / Non-Goals

**Goals:**
- Remove `LEGACY_FEATURE_STATE_FILE_NAME` and its dedicated test scenario.
- Remove `InstallResult.skillPath` and its assignment; keep CLI output derived from
  `skillPaths`; drop the stale test assertion.
- Keep `npm run verify` green with no runtime behavior change for fresh installs.

**Non-Goals:**
- No change to the JSON feature-state cache behavior or its other tests.
- No change to `bin/overmind.ts` output (it already uses `skillPaths`).
- Keep the `technical-requirements.ts` section-6 "retired loose-entry format" reject rule —
  it is a model-mistake guardrail, not deployment back-compat, and is out of scope.

## Decisions

- **Delete rather than deprecate the legacy constant.** No caller references it and no
  `.env` files exist to ignore, so a soft-deprecation adds surface for nothing. The
  `state/index.ts` wildcard re-export needs no edit — removing the export from
  `feature-state.ts` removes it from the module surface. Alternative (keep as `@deprecated`)
  rejected: it preserves exactly the residue this unit removes.
- **Drop `skillPath` outright rather than alias it to `skillPaths[0]`.** The field is an
  internal, never-shipped interface; aliasing keeps the vestige alive. The CLI already
  fans out from `skillPaths`, so no output changes. Alternative (retain for one release)
  rejected: nothing was ever shipped, so there is no release to be compatible with.
- **Update tests by deletion, not rewrite.** The legacy-env scenario and the `skillPath`
  assertion assert the residue itself; the remaining feature-state and install-result tests
  fully cover the kept behavior.

## Risks / Trade-offs

- [A hidden consumer imports `LEGACY_FEATURE_STATE_FILE_NAME` or reads `skillPath`] →
  Repo-wide grep before deleting confirmed the only references are the two test files and
  the definitions themselves; `npm run verify` (typecheck + build + tests) catches any
  missed reference.
- [Loss of the "legacy is ignored" regression guard] → Low risk: the generic "missing
  cache is reported as missing" behavior is retained and covered; there is no legacy format
  left to regress against.

## Migration Plan

No deployment/rollback concerns — nothing is installed and no interface was shipped. The
change is a source + test edit verified by `npm run verify`. Rollback is a straight git
revert if needed.
