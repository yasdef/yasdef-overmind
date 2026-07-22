## Why

`overmind init` installs into whatever directory it is invoked from, and the root `npm run setup` script therefore always targets the `yasdef-overmind` source checkout itself — scattering `.overmind/`, `asdlc_metadata.yaml`, `projects/`, and runner skill directories into the source repo. The operator's intended model is the one the retired shell first-init machine had: the source repo is only ever the distribution source, and the ASDLC workspace lives at a destination the operator points at interactively during init. Unit D (`crp-154-installer-cutover`) dropped that operator-resolved destination along with the shell; this change restores it in TypeScript.

## What Changes

- **BREAKING**: `overmind init` no longer installs into the current working directory. The bin interactively asks the operator for the ASDLC workspace target path on stdin and installs there. The cwd-as-target behavior does not survive as a fallback — with no operator answer there is no install.
- The resolved target is branched deterministically:
  - Path does not exist, or exists as an empty directory → clean install (directory created if missing).
  - Directory contains `asdlc_metadata.yaml` → update, with the existing per-asset semantics unchanged (refresh `.overmind/overmind.js`, skills, `.templates/*`, `quickrun.md`; preserve `asdlc_metadata.yaml`, `.setup/models.md`, `.setup/external_sources.yaml`, `projects/`).
  - Non-empty directory without `asdlc_metadata.yaml` → blocking refusal (exit 2), no file written.
- `installProject(targetDir)` remains the deterministic, directly-testable core; the interactive prompt lives only in the bin adapter (`packages/installer/src/bin/overmind.ts`).
- Root `npm run setup` is kept and now goes through the prompting flow, so it can bootstrap or update any operator-chosen workspace and never implicitly targets the source repo.
- No new CLI flags or arguments; `overmind init` stays argumentless.
- `QUICKRUN.md` and `README.md` describe the single prompting flow; the "cd into the target and run the installer" instructions are removed.

## Capabilities

### New Capabilities

<!-- none -->

### Modified Capabilities

- `workspace-bootstrap`: `overmind init` gains operator-resolved target selection (interactive stdin prompt, no cwd fallback) and explicit target branching — clean install into missing/empty targets, per-asset update of existing workspaces identified by `asdlc_metadata.yaml`, blocking refusal for non-empty non-workspace targets. The `crp-154` "no update mode" wording is superseded: the previously implicit re-run semantics are now the named update branch; what stays excluded is the retired shell update ceremony (`ASDLC_PROJECTS_DIR_DEFAULT` rewrite, obsolete-command cleanup, `.commands`/`.helper`/`.rules`/`.golden_examples` staging).

## Impact

- `packages/installer/src/bin/overmind.ts` — reads the target path from stdin, resolves and branches on it, reports the install/update outcome.
- `packages/installer/src/init.ts` — `installProject(targetDir)` keeps its signature and per-asset semantics; target classification (empty / workspace / refuse) is added as deterministic exported logic so tests need no stdin.
- `packages/installer/test/` — bin prompt-flow tests (injected input/output) and target-classification tests; existing fresh-install tests keep passing against explicit target directories.
- Root `package.json` `setup` script unchanged in wording but changed in behavior (now prompts).
- `QUICKRUN.md`, `README.md` — single documented bootstrap flow.
- No coordinator runtime changes; `packages/asdlc-coordinator` `dependencies` stays empty.
