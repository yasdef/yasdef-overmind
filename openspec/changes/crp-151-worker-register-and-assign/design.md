## Context

The worker lifecycle is the last operator surface still implemented as pre-TypeScript shell. Three scripts own it:

- `project_register_worker.sh` — prompts for a class, generates a unique UUID, and appends an entry to `workers.yaml`.
- `feature_assing_workers.sh` — parses plan repo classes, filters active workers, resolves one per class (auto or prompt), evaluates cross-feature dependency holds, and rewrites `#### Assigned:` lines in `implementation_plan.md`. It shells out to the readiness helper first.
- `check_implementation_plan_readiness.sh` — a plan-shape precondition (≥1 `### Step`, each step exactly one supported `#### Repo:`).

This is Unit A of `design_docs/e2e_orchestrator_migration/06_sh_remove_plan.md`. Per that plan's framing, Overmind has never been installed, so these scripts are behavior *reference*, not a deployed contract: the artifact contracts of record are `workers.yaml` shape, `implementation_plan.md` step/repo/assigned structure, and the operator interaction flow. The already-migrated coordinator (`cli/run.ts` dispatch, `InteractionPort`, the injected-clock pattern in `capture/scaffold-feature.ts`) is the baseline this change extends and reuses. `packages/asdlc-coordinator` runtime `dependencies` are empty and stay empty.

Note on git: the plan's "Deterministic primitives" paragraph groups project creation with the worker primitives and mentions injected git ports. That git seam belongs to project *creation* (Unit B: `git init` + initial commit). Neither worker shell (`project_register_worker.sh`, `feature_assing_workers.sh`) performs any git operation, and no artifact contract requires a commit on register/assign — so Unit A wires no git port (see Decision 3).

## Goals / Non-Goals

**Goals:**

- Move worker registration and assignment into deterministic coordinator modules under `src/workers/`, plus an assignment-time `validate/worker-assignment.ts`.
- Add `overmind worker register --path <project>` and `overmind worker assign --feature-path <feature>` to the existing dispatch, with injected interaction/clock/UUID/git ports for deterministic tests.
- Preserve the artifact contracts: registry shape/identity, class validation, UUID uniqueness, active-worker filtering, single/multi selection, missing-worker markers, dependency holds, and byte-preservation of unrelated content.
- Delete the three shell files and their three test suites in this change; remove their command staging; leave `npm run verify` green.

**Non-Goals:**

- Project creation/reconcile (Unit B), init steps (Unit C), installer cutover (Unit D), back-compat residue (Unit E).
- Porting the shell test suites scenario-for-scenario; TypeScript tests specify correct behavior against the contracts, consulting the shell suites only for genuine edge cases.
- Any new flags/options beyond the two verbs and their existing `--path`/`--feature-path` arguments.
- A repository-wide zero-shell assertion — that lands with Unit D; this change only removes its own three scripts.
- Modifying `tests/ai_scripts/project_setup_asdlc_tests.sh` (unit D) or `tests/ai_scripts/project_setup_update_project_tests.sh` (unit B). Those suites also stage/assert the deleted scripts, but they belong to other units and are left to them.

## Decisions

### 1. New `src/workers/` module directory, not folded into `capture/`

Registration and assignment are their own concern (worker registry + plan assignment) distinct from feature/project capture. A dedicated `workers/registry.ts` and `workers/assignment.ts` keeps the seam clear and mirrors the existing per-concern layout (`capture/`, `validate/`, `repo/`). *Alternative:* placing them in `capture/` — rejected; capture is about scaffolding new artifacts, not mutating the worker registry and plan.

### 2. Line-oriented parse/mutate, not a YAML/Markdown AST

The shell operates on lines and the contracts are line-shaped (`- uuid:` blocks in `workers.yaml`, `### Step` / `#### Repo:` / `#### Assigned:` in the plan). To preserve unrelated content byte-for-byte and avoid a runtime dependency, the modules parse and mutate line-oriented text (matching the existing `validate/*` and `capture/scaffold-feature.ts` approach) rather than round-tripping through a YAML/Markdown library. *Alternative:* adding a YAML parser dependency — rejected; it would reformat unrelated content and breaks the empty-`dependencies` invariant.

### 3. Injected clock, UUID, and interaction ports

Registration needs a timestamp (`registered_at`) and a unique UUID; both are injected (a `WorkerClock { now(): string | number }` and a `UuidGenerator { next(): string }`, following `ScaffoldClock`) so tests are deterministic. Class selection and multi-worker selection go through the existing `InteractionPort` (`select`/`input`), reusing its EOF-as-clean-stop semantics. **No git port is wired:** neither shell commits, and register/assign leave committing to the operator/other flows — adding a commit would be unrequested behavior beyond the contracts. The CLI wires the TTY/real adapters; `CliAdapterOverrides` gains the clock/UUID seams tests need (interaction is already present). *Alternative:* reading the system clock / `crypto.randomUUID` directly inside the module — rejected; non-deterministic and untestable. *Alternative:* auto-committing the mutation — rejected; no shell or contract does so.

Each primitive returns a typed result object carrying `diagnostics` and `changedPaths` (plus the resolved UUID / per-class assignments), and the CLI derives its stdout/stderr and exit code from that result — never by scraping printed text — matching `runProjectReconcile` and the plan's deterministic-primitive invariant.

### 4. `validate/worker-assignment.ts` stays separate from the implementation-plan gate

The readiness check is a narrow assignment-time precondition (steps exist; each has exactly one supported repo), not the full `validate/implementation-plan.ts` quality gate. Keeping it separate matches the plan's explicit instruction and avoids coupling assignment to the heavier gate. Assignment calls it internally and it is available for reuse; it does not become a new `overmind gate` verb unless later required.

### 5. Assignment resolves classes from the plan, selection is per class

Distinct repo classes come from the plan's `#### Repo:` lines (backend/frontend/mobile). For each class: zero active workers → missing-worker marker + non-success exit; one → auto-select; many → `InteractionPort.select`. Cross-feature `#### Depends on:` entries are resolved against the sibling `implementation_plan.md` (dependency step present, ≥1 checklist item, all checked); an incomplete dependency writes a `hold: depends on <feature>/<step>` marker. Markers are written into the plan and the command exits non-success, matching the shell's "rewrite-and-report" behavior rather than aborting mid-write.

### 6. CLI dispatch: `worker` command with `register` / `assign` subverbs

`runCli` gains a `worker` branch paralleling the existing `project` branch: `worker register` → `runWorkerRegister(--path)`, `worker assign` → `runWorkerAssign(--feature-path)`. The top-level usage string is updated to include `worker register|assign`. CLI adapters collect args and render typed results; the modules own parsing, mutation, and validation, and the CLI does no output scraping — consistent with `runProjectReconcile`.

## Risks / Trade-offs

- **Line-oriented mutation misses an odd YAML/Markdown shape the shell tolerated** → port the shell's exact matchers (inline-empty `workers: []` normalization, quoted/unquoted scalars, evidence-block insertion point) and add fixture-based byte-preservation tests over untouched blocks.
- **UUID/clock injection surface leaks into the CLI type** → keep the seams on a small deps object with production defaults, exposed through `CliAdapterOverrides` only for tests, as `scaffold-feature.ts` already does.
- **Deleting the readiness helper before assignment reuses it** → `feature_assing_workers.sh` currently execs the helper; the TypeScript assignment calls `validate/worker-assignment.ts` directly, so all three scripts are removed together in one change with no dangling reference.
- **Staging references left dangling** → remove the `.commands`/`common_libs` staging for all three scripts in `project_setup_first_init_machine.sh` in the same change and grep for residual references before verify.
- **Coordinated landing with units B and D (breaks the "any order" assumption for this pair)** → `project_setup_update_project_tests.sh` (unit B) and `project_setup_asdlc_tests.sh` (unit D) copy/stage the three deleted scripts, so deleting them turns those two suites red. Per scope decision, unit A does not edit them; instead unit A is sequenced to land together with (or after minimal prep in) units B and D that drop those stale references. Unit A remains independent of B/C for its own TypeScript and its three dedicated suites; only these two cross-unit suites impose the ordering.

## Migration Plan

1. Add `workers/registry.ts`, `workers/assignment.ts`, `validate/worker-assignment.ts` with injected ports and package tests specifying the contracts above.
2. Wire `overmind worker register|assign` into `cli/run.ts` dispatch and `CliAdapterOverrides`; update the usage string.
3. Delete the three shell files and their three `tests/ai_scripts/` suites; remove their staging from `project_setup_first_init_machine.sh`.
4. Update `overmind/README.md`, `QUICKRUN.md`, and generated quick-run guidance to the new verbs.
5. Run package tests, then `npm run typecheck|lint|format:check|build|test|verify`, `git diff --check`, and strict OpenSpec validation.

Rollback restores the three shell files, their suites, their staging, and the prior docs; no persisted state migrates because nothing was ever installed.

## Open Questions

- None blocking. Registration currently prints a hand-off message with the new UUID; the TypeScript verb preserves that message text so operator guidance stays stable.
