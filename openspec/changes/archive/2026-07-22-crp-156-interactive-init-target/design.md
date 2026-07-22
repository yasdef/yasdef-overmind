## Context

`packages/installer/src/bin/overmind.ts` runs `installProject(process.cwd())`: the target is whatever directory the bin is invoked from, and the root `npm run setup` script (whose cwd npm pins to the repo root) can therefore only install into the `yasdef-overmind` source checkout. The retired shell first-init machine (`project_setup_first_init_machine.sh`, deleted in `crp-154-installer-cutover`) instead resolved the destination interactively from the operator, keeping the source repo purely a distribution source. The operator has confirmed that model is the required one: the source checkout is never a runtime workspace, the target is asked interactively, an empty target is a clean install, an existing workspace is an update, and the cwd-as-target behavior must not survive as a fallback.

`installProject(targetDir)` itself is already target-parameterized, idempotent, and carries the wanted per-asset update semantics (refresh CLI/skills/templates/quickrun; preserve `asdlc_metadata.yaml`, `.setup` defaults, `projects/`). What is missing is target resolution, target classification, and the safety refusal for non-workspace directories.

## Goals / Non-Goals

**Goals:**

- `overmind init` asks the operator for the ASDLC workspace path on stdin and installs there; no cwd fallback, no flag bypass.
- Deterministic target classification: missing/empty → clean install, `asdlc_metadata.yaml` present → update, non-empty without it (or not a directory) → exit `2` refusal with no write.
- Keep `installProject(targetDir)` and its per-asset semantics unchanged; keep it directly testable without stdin.
- `npm run setup` remains the documented source-repo entry point and now prompts, so it can never implicitly pollute the checkout.

**Non-Goals:**

- No new CLI flags or arguments (`overmind init` stays argumentless; repo rule).
- No change to what the install pass writes, to skill fan-out, payload validation, or preserve-if-exists semantics.
- No restoration of retired shell update ceremony (`ASDLC_PROJECTS_DIR_DEFAULT` rewrite, obsolete-command cleanup, `.commands`/`.helper`/`.rules`/`.golden_examples` staging).
- No coordinator changes; `packages/asdlc-coordinator` runtime `dependencies` stays empty.

## Decisions

1. **Prompt lives in the bin adapter; core stays deterministic.** `bin/overmind.ts` gains a small stdin/stdout prompt (Node `readline`, no dependency) and calls exported pure logic plus `installProject(resolvedTarget)`. Alternative — threading an `InteractionPort` into `installProject` — was rejected: the coordinator's port abstraction lives in another package, the installer has exactly one question to ask, and keeping `installProject(targetDir)` signature-stable preserves every existing test.
2. **Target classification is an exported pure function.** `classifyInstallTarget(path)` (in `init.ts` or a sibling module) returns a typed result (`clean-install | update | refuse-not-empty | refuse-not-directory`) from filesystem inspection only, so branch behavior is unit-tested without stdin and the bin merely maps the result to messages and exit codes. `asdlc_metadata.yaml` presence is the workspace marker — the same file the coordinator's `workspace/` detection keys on.
3. **Path resolution: `~` expansion plus `path.resolve`.** A leading `~`/`~/` expands to `os.homedir()`; anything else resolves against the invoking cwd. Operators will type `~/asdlc`; raw `path.resolve` alone would silently create a `./~/asdlc` folder. No other expansion (no env vars, no globs).
4. **Blank or closed stdin is a zero-write cancel, exit `0`.** Consistent with the existing interaction convention (`overmind project reconcile` closed-input exits zero without changes). Refusal of a non-empty non-workspace target is the error case and exits `2`, matching the blocking-failure code convention.
5. **"Empty directory" means no entries at all.** No allow-list for `.DS_Store` and friends — the refusal message tells the operator what to do, and special-casing junk files invites silent installs into wrong directories.
6. **Update is the existing re-run pass, now named.** No new update code path: the update branch simply runs `installProject` against the classified workspace. The spec names the per-asset refresh/preserve behavior so it becomes contract instead of accident; `crp-154`'s "no update mode" requirement wording is superseded accordingly (what stays excluded is the shell ceremony, which was the substance of that exclusion).

## Risks / Trade-offs

- [Prompting breaks non-interactive invocation (CI, scripted installs)] → Accepted deliberately: the operator explicitly rejected any non-prompting fallback. Closed stdin cancels cleanly with exit `0` and no writes, so accidental non-interactive runs are harmless. A flag/argument can be added later only on explicit request.
- [Installer tests must not hang on stdin] → All branch logic is exported and tested directly; bin-level tests drive the prompt with injected/piped input and never inherit the test runner's stdin.
- [Operator typos create workspaces at unintended paths] → The prompt echoes the resolved absolute path in the outcome report; a mistyped path yields either a fresh directory (visible, removable) or a refusal — never writes into an existing non-workspace directory.
- [`quickrun.md` regeneration on update overwrites operator edits] → Existing behavior kept intentionally: `quickrun.md` is generated guidance, package-owned by contract.

## Migration Plan

Single change, no deployment surface: land bin + classification + tests, update `QUICKRUN.md`/`README.md` to the prompting flow (drop "cd into the target" instructions), leave `npm run setup` wiring as is. Rollback is reverting the change.

## Open Questions

None — target model, update semantics, no-fallback, and no-new-flags were operator-confirmed on 2026-07-11.
