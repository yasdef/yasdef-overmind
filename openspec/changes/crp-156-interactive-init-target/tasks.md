## 1. Target classification core

- [ ] 1.1 Add exported `classifyInstallTarget(path)` to `packages/installer` returning a typed result: `clean-install` (missing path or existing empty directory), `update` (directory containing `asdlc_metadata.yaml`), `refuse-not-empty` (non-empty directory without `asdlc_metadata.yaml`), `refuse-not-directory` (existing non-directory path). Filesystem inspection only; no writes.
- [ ] 1.2 Add exported target-path resolution: leading `~`/`~/` expands to `os.homedir()`, everything else resolves against the invoking cwd to an absolute path.
- [ ] 1.3 Unit-test classification and resolution directly (no stdin): missing path, empty dir, dir with only `asdlc_metadata.yaml`, populated workspace, non-empty non-workspace dir, file-as-target, `~` and relative inputs.

## 2. Bin prompt flow

- [ ] 2.1 Rework `packages/installer/src/bin/overmind.ts`: prompt "ASDLC workspace path:" on stdin via Node `readline`, resolve the answer, classify, then branch — clean install creates the directory (recursive) and runs `installProject`; update runs `installProject`; refusals print an error naming the resolved target and exit `2` with no write. Remove the `process.cwd()` target entirely — no fallback path in code.
- [ ] 2.2 Blank input or closed stdin: print that no target was selected, write nothing, exit `0`.
- [ ] 2.3 Report the outcome against the resolved absolute path: bootstrapped vs updated, plus the existing CLI/skills/templates/setup/quickrun summary from `InstallResult`.
- [ ] 2.4 Keep `overmind init` argumentless; any extra argument keeps failing with usage (no flag bypasses the prompt).

## 3. Bin tests

- [ ] 3.1 Add bin-level tests driving the compiled bin with piped stdin: answered path installs at that path (not at the child cwd), blank input exits `0` with no writes, non-empty non-workspace answer exits `2` with no writes, existing-workspace answer reports an update.
- [ ] 3.2 Update-branch integration test through the prompt flow: modified `.setup/models.md`, populated `asdlc_metadata.yaml`, `projects/` content, and a stale file inside an installed skill folder — after update the payload is refreshed, the stale file is gone, and operator-owned files are byte-identical.
- [ ] 3.3 Confirm existing `installProject` tests still pass unchanged against explicit target directories (core signature and per-asset semantics untouched).

## 4. Docs

- [ ] 4.1 Update `QUICKRUN.md`: collapse "Bootstrap ASDLC Workspace" and "Install Overmind Into A Runtime Project" into the single prompting flow (`npm run setup` from the checkout, or the installer bin from anywhere); remove the "cd into the target / from the target project root" instructions.
- [ ] 4.2 Update `README.md` install/bootstrap guidance to the same single flow.
- [ ] 4.3 Reflect the shipped behavior in `design_docs/e2e_orchestrator_migration/06_sh_remove_plan.md ## Target end state (from `03_target_architecture.md`)` installer paragraph only if it contradicts the prompting flow; otherwise leave design history untouched.

## 5. Verification

- [ ] 5.1 Run `npm run test --workspace overmind-installer`, then `npm run typecheck`, `npm run lint`, `npm run format:check`, `npm run build`, `npm test`.
- [ ] 5.2 Run `npm run verify` and `git diff --check`.
- [ ] 5.3 Manual smoke: `npm run setup` from the checkout, answer a temp path outside the checkout — workspace lands there, `git status` in the checkout stays clean; re-run with the same path — reports an update.
- [ ] 5.4 Assert `packages/asdlc-coordinator/package.json` still has `"dependencies": {}`.
- [ ] 5.5 Run strict OpenSpec validation for this change (`openspec validate crp-156-interactive-init-target --strict`).
