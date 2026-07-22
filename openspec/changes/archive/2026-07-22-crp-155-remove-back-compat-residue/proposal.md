## Why

The e2e sh→TS migration (CRP-144–149) is otherwise clean, but two pieces of the
"recognize the old thing to keep compatibility" reflex leaked into the TypeScript.
Overmind has never been installed: there is no prior on-disk state and no prior
caller, so both pieces are dead ceremony. Removing them closes the migration with
zero back-compat residue.

## What Changes

- Delete the exported `LEGACY_FEATURE_STATE_FILE_NAME` constant
  (`.project_add_feature_e2e_state.env`) from `packages/asdlc-coordinator`. Ignoring
  unknown feature-state files is already the default — production `readFeatureState`
  only reads `.overmind_feature_state.json` and never references the constant — so the
  constant and its dedicated "legacy env state is ignored, not migrated" test scenario
  only mean something if old `.env` files exist to be ignored, and none do.
- Drop the `InstallResult.skillPath` compatibility field (the single Claude
  `overmind-task-to-br` path "retained from CRP-129") from `packages/installer`. The
  installer now fans out many skills through `skillPaths[]`; the singular field is an
  internal, never-shipped interface with no external caller.
- Derive the CLI install output from `skillPaths` only (already the case in
  `bin/overmind.ts`); drop the stale `skillPath` test assertion.

Out of scope (deliberately kept): the `technical-requirements.ts` section-6 "retired
loose-entry format" reject rule — that is a model-mistake guardrail, not deployment
back-compat.

## Capabilities

### New Capabilities
- `feature-state-cache`: reading and validating the per-project feature-state cache,
  including that unknown/foreign files (not the JSON cache) are simply absent, with no
  named legacy format recognized.
- `installer-install-result`: the installer's typed install result and CLI output
  surface, including that installed skills are reported solely from the fan-out
  `skillPaths` list.

### Modified Capabilities
<!-- No existing specs in openspec/specs/; nothing to modify. -->

## Impact

- `packages/asdlc-coordinator/src/state/feature-state.ts` — remove exported constant.
- `packages/asdlc-coordinator/test/feature-state.test.ts` — remove the legacy-env
  scenario and its import.
- `packages/installer/src/init.ts` — remove `InstallResult.skillPath` and its
  assignment.
- `packages/installer/test/init.test.ts` — remove the `skillPath` assertion.
- No runtime behavior change for fresh installs; `bin/overmind.ts` install output
  already reads `skillPaths`. `npm run verify` stays green.
