## 1. Responsibility inventory (blocks implementation)

- [x] 1.1 Build the responsibility inventory for the touched rows of `02_responsibility_translation_map.md` (rows 5 [executor], 6, 7, 8, 10 [reuse, extended], 11, 14 [partial]); confirm every behavior has a named TS owner in this slice — any unowned behavior blocks the slice
- [x] 1.2 Audit the 13 `build_*_prompt` heredocs + `run_*_skill` launchers in `overmind/scripts/project_mgmt/project_add_feature_e2e.sh`: record per phase the skill name, the `Use`/`Load` verb, the runtime-binding lines, the exact `node <cli> capture|context|sync|gate <skill> <feature> [--class]` command lines, whether a pre-session sync and/or context runs, the `readOnlyGuards` mode, and the `requiredOutputs` — this is the parity fixture for §5–§7

## 2. config/ — typed runner-config loader (`runner-config`)

- [x] 2.1 Implement `loadRunnerConfig(modelsPath)` in `packages/asdlc-coordinator/src/config/` parsing the unchanged `.setup/models.md` pipe-table into typed per-phase `{ command, model, args[] }`, matching the awk row semantics (skip `#` comments, ignore `< 3`-field rows, trim fields, first case-insensitive phase match wins)
- [x] 2.2 Validate `command` against the registered agent adapters (only `codex` initially) — one rule replacing the 13 scattered `MODEL_CMD == codex` assertions
- [x] 2.3 Surface load problems as `Diagnostic` values at phase-resolution time (missing file, requested phase unresolvable — absent or present only as a skipped short/malformed row, non-`codex` command) with `source = .setup/models.md` and actionable `reason`; short/malformed rows are skipped during parsing and produce no standalone diagnostic; never throw for data problems
- [x] 2.4 Export from a `config/index.ts` barrel and add to the package `index.ts`
- [x] 2.5 Tests: well-formed read → typed config; comments/short rows ignored during parsing; non-`codex` command rejected; missing file, absent phase, and phase present only as a short row all degrade with diagnostics (no throw)

## 3. context/ extension — typed readOnlyInputs (unblocks the fromContext guard)

- [x] 3.1 Additively extend `ContextResult` (`types/`) with an optional structured `readOnlyInputs: string[]`, leaving `text` and its `- read_only_input:` lines byte-unchanged
- [x] 3.2 Populate `readOnlyInputs` in the `fromContext` builders (contract-delta, surface-map, technical-requirements, implementation-slices, prerequisite-gaps, implementation-plan, plan-semantic-review, surface-map-enrich) from the same list the text lines render
- [x] 3.3 Tests: for a representative `fromContext` builder, `readOnlyInputs` equals the set the `- read_only_input:` text lines render, and the existing `.text` output is unchanged (standalone `context` CLI verb unaffected)

## 4. runner/ — prompt builder (`session-prompt-builder`)

- [x] 4.1 Implement the single pure `buildSessionPrompt(sessionAction, bindings)` in `runner/`, deriving per-phase differences from the session action data (`skillName`, `modelPhase`, `requiresSync`) and bindings (runtime root, feature path, overmind CLI path, resolved artifact paths, target class) — no per-step branches
- [x] 4.2 Emit the three-part shape (skill reference line, `Runtime bindings:` block, `Required flow:` block with the exact CLI command lines) and omit skill-owned final-response lines, exactly as the heredocs did
- [x] 4.3 Tests: prompt-content parity across all 13 pipeline phases (skill name, runtime-binding lines, exact CLI command lines incl. `--class` where applicable, no final-response lines), asserted against the §1.2 heredoc audit

## 5. runner/ — guards (`session-guards`)

- [x] 5.1 Implement `runner/guards.ts` with snapshot/verify driven by the catalog `ReadOnlyGuard` union: `fromContext` (protected set = context `readOnlyInputs`, byte-identical after), `mustExistUnchanged` (exists-before + byte-identical-after), `preserveExistence` (unchanged-if-present, absent-stays-absent, never create/delete/replace); violations as `Diagnostic` values naming path + mode
- [x] 5.2 Implement `requiredOutputs` existence assertion after a successful session, with empty-list-is-legal semantics (asserts nothing, not an error)
- [x] 5.3 Tests — all three modes: `fromContext` modified-file violation; `mustExistUnchanged` altered-file violation; `preserveExistence` present-unchanged pass / present-modified fail / absent-stays-absent pass / absent-created fail
- [x] 5.4 Tests — `requiredOutputs`: missing required output reported; empty `requiredOutputs` (the 7.1 shape) asserts nothing

## 6. runner/ — AgentRunner port + codex adapter (`agent-runner`)

- [x] 6.1 Define the `AgentRunner` port (`run(spec) → { exitCode }`, spec = `{ command, model, args[], prompt, cwd }`) in `runner/`
- [x] 6.2 Implement `CodexAgentRunner` spawning `codex -m <model> <args...> <prompt>` from the runtime root with inherited stdio via `node:child_process` (no runtime dependency), returning the child exit code
- [x] 6.3 Provide a stub `AgentRunner` for tests (records spec, returns a chosen exit code)
- [x] 6.4 Tests: codex argv + cwd + inherited stdio match the shell `cmd=(codex -m … ) ; cd runtime_root` invocation; non-zero child exit returned without throwing

## 7. runner/ — generic executor (`step-executor`)

- [x] 7.1 Implement `executeStep(stepDef, bindings, deps)` iterating `stepDef.actions` in order, branching only on action `kind` (never step id); inject `deps` (`AgentRunner`, runner-config loader, in-process `sync`/`context`/`readiness` functions); return a typed `StepResult` with diagnostics; any action failure stops the step
- [x] 7.2 Session action order: `runIf` (skip-with-notice when false) → `requiresSync` sync (before session, D7) → context (read-only, yields `readOnlyInputs`) → load model config for `modelPhase` → snapshot guards → build prompt → `AgentRunner.run()` → verify guards + assert required outputs; guards verified regardless of agent exit code; executor never runs `overmind gate`
- [x] 7.3 Deterministic action dispatch: `check`/`write` call named in-process coordinator functions (4.2 `check` → `br-clarification` readiness); unknown action name → `Diagnostic`, not throw; scaffold-feature `write` covered with a stub (real primitive is Slice 3)
- [x] 7.4 Session bindings scope to feature path + single class (step 7); design the contract so the Slice 4 class-list binding is an extension, not a fork
- [x] 7.5 Tests (over the stub agent): multi-action ordering (4.1); action failure stops the step; `runIf` false skips as success; sync-before-session + `fromContext` snapshot/verify; guards verified even on non-zero agent exit; `check` invokes readiness; unknown deterministic action degrades; per-class step binds a single class and resolves `project_surface_struct_resp_map_<class>.md`

## 8. interaction/ — port + TTY adapter (`interaction-port`)

- [x] 8.1 Define `InteractionPort` in `interaction/` with typed `confirm(message) → boolean`, `select(message, options) → choice`, `input(message) → string` request shapes
- [x] 8.2 Implement the TTY adapter over stdin/stdout preserving today's `read -r` prompt wording and y/n semantics
- [x] 8.3 Tests: typed request/result shapes; TTY `confirm` resolves a boolean with preserved semantics; confirm the port is defined but not wired into any orchestrator loop this slice

## 9. Verify

- [x] 9.1 Run `npm run verify` (typecheck → lint → format-check → build → test across TS workspaces + surviving `tests/ai_scripts/*.sh`, unchanged this slice); resolve all failures
- [x] 9.2 Confirm `asdlc-coordinator`'s runtime `dependencies` list is still empty (codex spawned via `node:child_process`; no library added)
- [x] 9.3 Confirm no shell edits and no deletions were made (the e2e keeps its launchers and `.setup/models.md` reads until Slice 3)
- [x] 9.4 Confirm the Slice 2 rows of `02_responsibility_translation_map.md` (5 executor, 6, 7, 8, 10 extended, 11, 14 partial) are demonstrably owned by the named TS modules with tests
