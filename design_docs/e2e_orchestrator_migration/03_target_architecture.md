# E2E Orchestrator Migration — 3. Target Architecture

The cross-step sequencer promised in `design_docs/to_skills_migration/migration_to_skill_architecture_overview.md ## Decided` ("TS orchestrator / state machine in `asdlc-coordinator`, reused by a headless `overmind run` CLI and, later, embedded in the VS Code extension"). This document fixes its shape.

## Core principle: functional core, imperative shell

Everything that can be a pure function over `(definition, artifact tree, config)` is one, lives in `asdlc-coordinator`, and is what the VS Code extension imports. Side effects (fs writes, git, spawning agents, talking to the operator) sit behind ports; the CLI and the extension are two thin adapters over the same core.

```
packages/asdlc-coordinator/src/
  workspace/      NEW  runtime-root detection, project/feature discovery      (pure over fs reads)
  sequencing/     NEW  step catalog + next-step state machine + status view   (pure)
  config/         NEW  runner config load/validate (.setup/models.yaml)       (pure)
  runner/         NEW  prompt builder (pure) · AgentRunner port + codex
                       adapter · deterministic guards (snapshot/verify)
  orchestrator/   NEW  two use-cases sharing the same core: feature flow
                       (selection → phase loop; refuses on pending project-
                       level work) and project flow (attach → reconciliation
                       → commit unit); both emit typed PhaseOutcome and
                       depend only on ports
  interaction/    NEW  InteractionPort types (confirm / select / input)
  state/          NEW  per-project feature-state cache
  git/            NEW  repo-scoped git adapter: every call takes an explicit
                       repo root (runtime root for checkpoints, project
                       folder for the reconciliation unit — two distinct
                       worktrees, no ambient cwd); "not a git worktree" is
                       a typed result, not an error (callers differ: skip
                       vs pass-through). Class-repo git stays in repo/.
  repo/           EXT  + attach.ts (port of persist_class_repo_attach.sh)
  parse/          EXT  + projectTypeCode / classRepoPaths state in one read
  capture/        EXT  + scaffold-feature primitive
  context/ validate/ readiness/ sync/   EXISTING — consumed in-process
  cli/run.ts      EXT  + `run`, `status`, `scaffold`, `project reconcile` verbs
```

Consumers:

```
overmind CLI (.overmind/overmind.js)      VS Code extension (packages/vscode-extension)
  InteractionPort → TTY prompts             InteractionPort → webview forms
  AgentRunner    → spawn codex              AgentRunner    → VS Code terminal
  output         → stdout + exit codes      output         → dashboard state
            └──────── same orchestrator + sequencing + workspace core ────────┘
```

## Key contracts

**Step catalog.** One declarative `StepDefinition[]` is the single place a phase is described: `{ id, label, optional, perClass, resumeAliases, actions: Action[] }`. A step is an **ordered action sequence**, where an `Action` is either a **model session** `{ skillName, modelPhase, requiresSync?, readOnlyGuards, requiredOutputs, runIf? }` — `runIf` being a named predicate from a small closed set (e.g. `hasReadyClassRepo`), evaluated by the executor against workspace state so the catalog stays pure data — or a **deterministic action** — a named in-process coordinator function: a *check* (br-clarification readiness) or a *write primitive* (scaffold-feature, which collects operator input through the interaction port and returns the created feature path as a typed result). Most steps have exactly one action; the shapes the shell hard-coded become catalog entries: `3 = [deterministic(scaffold-feature)]`, `4.1 = [session(repo-br-scan, runIf: hasReadyClassRepo), session(task-to-br)]`, `4.2 = [session(br-clarification), check(br-clarification readiness)]`. This mirrors `init_progress_definition.yaml`, which declares 4.1 and 4.2 as single steps containing those behaviors — catalog ids stay definition ids. The executor iterates actions and never branches on step id; adding a pipeline step = adding a catalog entry (plus its skill/validators), not writing a launcher.

`readOnlyGuards` is a typed union, not a file list: **`fromContext`** (protected set = the context result's read-only inputs; steps 6, 7, 8, 8.1–8.4) or **named files with a mode** — `mustExistUnchanged` (byte-identical after the session; steps 5/5.1 on `feature_br_summary.md`) or `preserveExistence` (unchanged if present, absent must stay absent, never created/deleted/replaced). `requiredOutputs: []` is legal: a step may mutate existing artifacts in place with nothing new to assert, and the executor treats empty as "no assertion", not an error. The boundary example is 7.1: `{ readOnlyGuards: [external_sources.yaml: preserveExistence, init_progress_definition.yaml: preserveExistence], requiredOutputs: [] }` — statically named guards, the only step with the no-create mode, no fresh output.

**Sequencing state machine.** Primary result is `evaluate(workspace, project, feature?) → ProgressReport`: the typed evaluation of **every** declared step, project and feature scope — per step `{ stepId, name, scope: project|feature, optional, state: done | pending | blocked, perClass?, missingArtifacts[] }` plus report-level diagnostics. Replaces `init_progress_scanner.sh` completely — as a **new** scanner whose spec is `init_progress_definition.yaml` itself, not the old scanner's (imprecise) behavior; only the output contract is inherited (see Decisions). Everything else is a pure projection over the report:

- `nextStep() → NextStep { stepId, name, scope, perClassPending? }` — first non-done required step; what the orchestrator consumes (project scope covers init steps 1.x–2.x plus attach/reconciliation pending-work, so the feature flow can refuse with actionable "run X first" guidance).
- Checklist formatter + canonical `next step: <num> (<name>)` line — what `overmind status <path>` prints.
- The extension's `FeatureSummary` (`design_docs/overmind_vscode_extention/technical_requirements.md ## 7. Dashboard Data Contract`): `completedSteps`/`totalSteps` = counts over step states; `missingArtifacts` = union of per-step missing artifacts; `readiness` mapping: `ready` = all steps done, `in_progress` = pending steps and no blockers, `blocked` = pending project-scope prerequisite or unreadable inputs, `unknown` = definition parse failure.
- Phase-7 per-class pending/completed view.

This module **is** the extension's readiness model (`design_docs/overmind_vscode_extention/technical_requirements.md ## 3. Target Architecture`); the reuse claim is carried by `ProgressReport`, not by `NextStep`.

**Runner.** `executeStep(stepDef, bindings)` iterates the step's declared actions. For a model session action: evaluate `runIf` (skip with notice if false) → sync (in-process) → context (in-process, yields read-only inputs) → snapshot guards → build prompt → `AgentRunner.run()` → verify guards + required outputs. For a deterministic action: call the named coordinator function. Any action failure stops the step with a typed result. Session bindings cover the feature path, a single class (step 7), and a class *list* (the reconciliation session covers all pending classes at once); `AgentRunner` inherits stdio, so interactive sessions are the default — the shell's fd-forwarding dance was a bash artifact and has no TS equivalent. Gate ownership is unchanged: the model runs `overmind gate ...`; the orchestrator never invokes the gate verb (readiness/validator *functions* may be imported in-process per `design_docs/to_skills_migration/step_by_step_migration_for_particular_step.md ## 2. Ownership Rules`).

**Orchestrator flow-control.** Numeric rc protocol (0/10/20/30/40) becomes a `PhaseOutcome` union: `completed | skippedOptional | stoppedByOperator | finished | failed { resumeStep, diagnostics }`. The CLI maps outcomes to exit codes and prints restart guidance as `overmind run --path <p> --resume <step>`.

**Diagnostics.** One cross-cutting model; errors are values in the core, rendering belongs to the adapters:

- Shared `Diagnostic` type in `types/`: `{ severity: error | warning, source: <file path>, reason, stepId? }` — non-sensitive by construction (paths and reasons, never file content).
- **Core convention:** pure modules (`workspace/`, `sequencing/`, `config/`, `parse/`) never throw for *data* problems. Malformed YAML, missing or unreadable artifacts, and inconsistent definitions produce `diagnostics[]` in the typed result and degrade the affected item (`unknown` / `blocked` per the `ProgressReport` readiness mapping) instead of crashing the computation. Throwing is reserved for programmer errors.
- Carriers: `ProgressReport.diagnostics`, the config loader's result, `PhaseOutcome.failed`.
- **Adapters render, never invent:** the CLI formats the same values to stderr and exit codes; the extension routes them to its output channel and `DashboardModel.diagnostics`. One source, two renderers — this is what makes the extension's NFR "parse errors with file path and reason" and its "degrade to unknown, don't crash the dashboard" rule (`design_docs/overmind_vscode_extention/technical_requirements.md ## 7. Dashboard Data Contract` and `## 8. Readiness Rules`) come for free rather than requiring a fork.

**Runner config.** `.setup/models.md` keeps its pipe-table format (operator decision — zero workspace migration); the `config/` loader parses it into a typed, validated structure at load time: per-phase `{ command, model, args[] }`. `command` is validated against the registered agent adapters (only `codex` initially — preserving today's assertion as one rule instead of thirteen). This realizes the `models.md → typed runner config` decision from the overview doc: "typed" lives in the loader and schema, not in a new file format.

**D7 boundary preserved.** Repo-mutating sync runs in the orchestrator process (operator shell) before the model session; context builders stay read-only. Unchanged semantics, now in-process function calls.

## What the extension gets for free

Workspace detection (Requirement 1), project dashboard data (Requirement 2), feature readiness summaries, per-step action metadata (catalog + runner config), the scaffold/capture forms contract, and the interaction protocol. The extension contributes only VS Code bindings: activation, webview rendering, terminal-hosted `AgentRunner`, and port implementations.

### Supersession of the extension design docs

The extension design docs (`design_docs/overmind_vscode_extention/`, dated 2026-06-24) predate this migration and describe the extension as a launcher of `.commands/*.sh` scripts — exactly the scripts this migration deletes. **Where those docs conflict with this document, this document wins.** Their full revision is a Slice 5 deliverable (`04_migration_plan.md ## Slice 5 — Cleanup + extension enablement`); until it lands, read them through this mapping:

| Extension-doc concept (old) | Replacement in this architecture |
|---|---|
| "Run Scanner action" (`implementation_plan.md`); scanner freshness caveats | `overmind status` / in-process `sequencing/` — read-only compute, no terminal, never stale |
| "Create Feature" terminal action | `overmind scaffold feature` primitive; its future webview form is the capture contract, not a terminal wrapper |
| "Continue E2E" terminal action | `overmind run` hosted in a VS Code terminal via the terminal `AgentRunner` adapter (model sessions stay visible and interactive) |
| `requirements_ears.md` Requirement 7: "run existing scripts from the ASDLC `.commands/` folder", script allow-list, "script missing or not executable" blocking error | Same safety intent, new mechanism: allow-list of `overmind` CLI verbs; availability check on `.overmind/overmind.js` / bundled core |
| `requirements_ears.md` Requirement 9 verification: "mutation paths call ASDLC scripts" | Mutation paths call coordinator primitives (capture/scaffold/sync) or CLI verbs; ASDLC files remain the source of truth unchanged |
| "Script contract vs terminal mode" decision framework (`implementation_plan.md`) | Already answered: deterministic inputs → capture primitives + `InteractionPort` forms; model sessions → terminal-hosted `AgentRunner` |

## Engineering baseline

Prod-level toolchain, decided 2026-07-04 (operator-confirmed choices: ESLint + Prettier over Biome; no git hooks) and revised 2026-07-04 to **local agent-driven enforcement instead of remote CI**: the two agents that edit this repo — Claude (`CLAUDE.md`) and Codex (`AGENTS.md`) — run the full suite themselves before completing a change. Landed as `04_migration_plan.md ## Slice 0 — Toolchain baseline` so it also covers the already-migrated step code, and every later slice is verified against it.

- **Typechecking:** shared `tsconfig.base.json` stays `strict: true` and gains `noUncheckedIndexedAccess`, `noImplicitOverride`, `noFallthroughCasesInSwitch`, `verbatimModuleSyntax` — cheap while the codebase is young, painful to retrofit after five slices. Fast `npm run typecheck` (`tsc --noEmit`, test files included) per workspace + root aggregate, independent of the build.
- **Linting:** ESLint flat config with typescript-eslint's type-checked presets. Type-aware rules are the point — `no-floating-promises` and friends catch exactly the async/spawn/fs mistakes an orchestrator produces; this is why ESLint was chosen over Biome (which cannot do type-aware linting).
- **Formatting:** Prettier as the sole formatter (conflicting stylistic lint rules disabled) + `.editorconfig`.
- **Tests:** stay on Node's built-in runner (`node --test`) — no test-framework dependency. Coverage via the runner's native coverage, report-only at first; a threshold gate only once the orchestrator slices land.
- **Enforcement — local, agent-driven, no remote CI, no git hooks:** a single root `npm run verify` command runs, in order, typecheck → lint → format-check → build → test (TS workspaces **and** the surviving `tests/ai_scripts/*.sh` suites during the transition). Both `AGENTS.md` (Codex) and `CLAUDE.md` (Claude) mandate running `npm run verify` and confirming it green before treating any change as complete — the gate lives where the agents act, not in a push/PR pipeline. `engines` pins the Node floor. **No git hooks:** checkpoint commits (`git add -A`, tolerant of failure) and model-session commits must not pass through hook machinery that can change their behavior. Rationale for local-over-remote: immediate feedback (no push/wait), works offline, no CI plumbing for an agent-driven bash-and-TS project; residual risk (a non-compliant run isn't mechanically blocked) is accepted as the cost of the hook-free model, mitigated by the single-command design and the identical mandate in both agent files.
- **Zero-runtime-dependency rule:** `asdlc-coordinator`'s `dependencies` stays **empty** — it is what keeps the bundled `overmind.js` a single file with no `node_modules` at runtime. Dev-dependencies are unrestricted; adding a runtime dependency requires an explicit recorded decision.

## Decisions

Confirmed with the operator on 2026-07-03:

1. **Interactivity: parity via port.** Every current decision point (per-phase y/n, project/feature menus, phase-7 loop, reconciliation commit, repo attach) survives 1:1, routed through `InteractionPort`. Auto-advance profiles become configuration later, not a rewrite.
2. **Scanner: new implementation, definition-as-spec.** The current `init_progress_scanner.sh` is known-imprecise: it joins some steps together and omits others relative to `init_progress_definition.yaml`. The TS `sequencing/` module is therefore a **new** scanner, not a behavior-parity port: same output contract as the old one (rendered checklist + canonical `next step: <num> (<name>)` line), but step reporting must precisely reflect `init_progress_definition.yaml` — every declared step, no joining, no omissions, project and feature scope alike. Consequence: the e2e's `map_scanner_step_to_phase` remapping layer (legacy `4` → `5`, name-substring fallbacks) exists only to paper over that drift and disappears — catalog step ids equal definition step ids. Old shell scanner tests inform the output *format* only; step-reporting tests derive from the definition.
3. **Pre-flight is a separate project-level flow, not part of `overmind run`.** Repo attach + contract reconciliation + commit unit are project-level lifecycle operations that fire rarely (when class repo states change); they must not be joined into the per-feature flow. They become their own project-level command (working name `overmind project reconcile`), migrated within this plan as its own slice. The feature flow (`overmind run`) only **detects** pending project-level work — uniformly with the existing init-step prereq guard — and refuses with actionable guidance naming the command to run. The reconciliation session runs through the same **generic executor** (prompt builder + `AgentRunner` + guards) as a proper catalog entry — never a bespoke launcher; marker lifecycle and owned-paths verification live in the project-flow use case, at the same altitude as checkpoint commits in the feature flow.
4. **State file** becomes `<project>/.overmind_feature_state.json`; same single-value lifecycle and stale handling. Old `.env` file is ignored (a run simply re-asks feature selection once).
5. **Runner config keeps the `.setup/models.md` pipe-table format.** Zero migration for existing workspaces. The TS `config/` loader parses the same `phase | command | model | args...` rows into a typed, validated structure at load time (actionable errors replace mid-run awk failures); `command` is validated against registered agent adapters (only `codex` initially). The format stays; the awk goes.
6. **Scaffold is a primitive, not a skill — and just one of the steps.** `feature_br_scaffold.sh` is deterministic, so step 3 maps to `overmind scaffold feature` in `capture/` — matching the capture-primitives-for-future-webview-forms decision in the overview doc, and superseding the tentative `overmind-br-scaffold` skill row for step 3. In the catalog it is simply step 3's deterministic action (`3 = [deterministic(scaffold-feature)]`), executed by the generic executor like any other step — no dedicated migration slice, no special orchestrator handling; the CLI verb remains for standalone and extension-form use.
7. **New CLI verbs** `run`, `status`, `scaffold`, `project reconcile` extend the existing `capture|context|gate|sync|readiness` dispatch. `status` replaces the scanner's standalone command role.
8. **No long-lived back-compat**: same clean-break rule as the skills migration — migrated shell is deleted in the same slice that proves parity, not deprecated.
9. **Reconciliation status is a definition field, not a dotfile marker.** The shell tracks per-class reconciliation with `.contract_reconciled_<class>` marker files; the target records it as a per-class field on the existing lifecycle record — `class_repo_paths.<class>.contract_reconciled: true` in `init_progress_definition.yaml`. The class lifecycle (`state`, `path`, `policy`) already lives in that file, so this keeps the whole per-class state in one place instead of splitting it across dotfiles, lets the definition-as-spec scanner (decision 2) surface reconciliation natively, and shrinks the reconciliation commit unit (`02_responsibility_translation_map.md` row 20) to two stable owned paths — `init_progress_definition.yaml` + `common_contract_definition.md` — with no marker set to enumerate or roll back. **Deliberately simple, no transactional ceremony** (operator decision: this project does not need strong write-atomicity here): the project flow sets the flag(s) after the reconciliation session succeeds; a failed or partial run leaves them unset and the next run re-reconciles the still-pending classes, exactly as the marker retry did — reconciliation is idempotent. One correctness rule travels with the colocation: re-attaching a class (its `path` changes) clears `contract_reconciled` in the same edit, so a swapped repo is reconciled again — an invalidation the dotfile scheme had to remember to do out-of-band. `contract_reconciled` stays separate from `state`; `state` still means only "attached & scannable" and keeps gating steps 4.1/6/7 — it is **not** extended with a `reconciled` value.

## Non-goals

- No changes to skill bodies, gates, or artifact formats — the orchestrator consumes them as-is.
- No workflow-engine/queue/daemon; the orchestrator is a foreground process, artifacts remain the only durable state (plus the one-value feature cache).
- No multi-runner fan-out in v1 beyond the adapter seam (codex-only config rule stays until a second adapter is actually wanted).
- Worker registration/assignment and init-step (1.1/2.3) skill migrations stay separate work items from the overview doc.
