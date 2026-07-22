## Context

This CRP records the agreed design from the June 2026 coordinator-evolution review targeting complex enterprise backend+frontend+mobile projects. It is the consolidated recap of that review and the requirements baseline for the planned overmind shell+md → Python+skills port (the yasdef worker has already completed the same migration). Decisions below describe target behavior; implementation lands inside the port, not as shell-era patches.

Three structural limitations of the current pipeline drive this CRP:

- Project type `A`/`B`/`C` is a single project-level label fixed at init. A greenfield (`A`) project whose backend repo materializes after feature 1 has no clean path into repo-backed planning, and classes materialize at different times, so no single label ever fits.
- Blueprint fallback evidence (CRP-117) is type-`A`-only transitional machinery, but repos materialize blueprints incrementally — a repo-backed class still needs blueprint evidence for layers no feature has touched yet.
- Concurrency exists de facto (`project_add_feature_e2e.sh` allows starting a new feature while others are unfinished) but is undesigned: each feature plans as if alone, so concurrent features can duplicate work, claim conflicting contract shapes, and collide on surfaces invisibly.

## Goals / Non-Goals

**Goals:**

- Per-class blueprint→repo transition, operator-prompted at feature start.
- A permanent, demand-driven, per-layer evidence resolution chain replacing project-type gating.
- `B`/`C` redefined as divergence policies with enforceable semantics (`C` in phase 1, `B` in phase 2).
- Concurrency-aware planning: merged truth vs promised truth, with committed feature plans as an evidence tier.
- Deterministic execution gating for cross-feature dependencies at the assignment step.

**Non-Goals (explicitly deferred, on the record):**

- Multi-repo / multi-worker per class. The class = repo = worker 1:1:1 assumption stays; phase 1 carries only a data-model hedge (list-shaped `class_repo_paths`). Open ripple questions for the future CRP: per-repo blueprints; whether the plan's `#### Repo:` field names a class or a repo (worker handoff contract).
- The feedback loop (orchestrator consuming worker output and re-planning — README known issue). Separate upcoming design discussion. Event vocabulary already accumulated for it: `contract_drift`, `already_satisfied`, divergence tags, cross-feature promise invalidation, dormant-promise liveness.
- Deciding whether `B` remains a project type or becomes a per-class config flag — parked until operators have lived with policy `C` divergence tags.
- Acceptance/verification loop, Jira ingestion, artifact versioning.

## Decisions

### D1 — Project type `A` is init-time bookkeeping; classes transition independently

Each class transitions blueprint-backed → repo-backed on its own timeline. At feature start, the e2e flow prompts the operator directly for every deferred class: enter a valid repo path to attach it (reusing `project_setup_update_project.sh` attach logic), defaulting the class policy to `C`, or leave it blank to keep the class deferred. A blueprint is authored at init and cannot know where the operator will later clone the repo on their machine, so the repo path is never recorded in the blueprint and there is no auto-detection — the operator-provided path is the sole attach source. The prompt carries a one-line policy explanation ("repo becomes authoritative; blueprint consulted only for subsystems absent from the repo") so the choice is informed — and the operator's informed choice is the ratification; no additional review ceremony. `project_type_code` is demoted to a historical record of how the project started; feature steps stop reading it.

> Correction (see tasks.md §17a): the original D1 keyed the trigger off a blueprint-authored local repo path that the e2e flow probed for a scannable git repo. That field is removed — a blueprint never knows the operator's machine layout — and replaced by the direct per-class prompt above. No fallback, no backward compatibility; policy stays `C` (Option A).

### D2 — Scan-dependent steps gate per class, never per project type

Steps `4.1` (Scan repo and apply task-to-BR update), `6` (Define Feature Contract Delta), and `7` (Analyze Repos And Prepare Repo Execution Context) iterate active classes and gate on `class_repo_paths[<class>].state`, not `project_type_code`. A per-class `policy` field is recorded at attach time. The list-shaping hedge for the deferred multi-repo evolution is itself deferred to the Python port (see D9): reshaping `class_repo_paths` in the current plain-shell stack would force list-parsing into every consumer for no phase 1 behavioral gain.

### D3 — Evidence resolution is per-layer, demand-driven, and permanent

The resolution chain per surface-map row / per need:

```
repo scan (merged truth) → in-flight feature promises → blueprint → placeholder
```

- **Demand-driven:** the chain runs only when a feature's requirements create a need. "Absent" means "this need is not satisfied," never an inventory claim about the repo. The system's knowledge universe is requirements + blueprints + code (+ committed plans, per D7); hidden knowledge enters only through new requirements — by design, not as a limitation.
- **Permanent:** attaching a repo never retires the blueprint. A repo materializes the blueprint layer by layer; unmaterialized layers keep resolving from blueprint (`(planned)` tags) for the life of the project. One source per row, every source tagged.
- Blueprint evidence citations carry the blueprint's `last_updated` date, so the operator sees the age of recorded intent at the moment it is consumed (plan review), with no proactive staleness ceremony.

### D4 — The worker is the second line of defense

The orchestrator plans shallow on purpose; the worker's design phase dives deep. The rare planning miss (e.g., a previously delivered capability the scan overlooked) is caught by the worker, which needs a formal step outcome `already_satisfied` (records why; closes the step without work). Cross-repo change, coordinated with the yasdef worker project. No absence-confirmation prompts at planning time.

### D5 — `B` and `C` are divergence policies, not code-origin labels

- **Policy `C` (phase 1):** the repo is law. A layer that is materialized-but-divergent from the blueprint resolves from the repo silently, with a passive `divergent_from_blueprint: §<n>` tag on the row (nearly free — the scanner already holds the blueprint bindings for the layer). Blueprint is consulted only on complete absence. Choosing `C` is an informed governance declaration — including "our blueprints are wrong by policy" cases (e.g., regulated environments); the system honors it without second-guessing.
- **Policy `B` (phase 2):** divergence may become an operator question, built on the step `8.4` (Implementation Plan Semantic Review) interaction pattern, with bounded asking criteria (structural divergences in Stack Choices or Layer Bindings only — never style). Resolution is always one of exactly two states: edit the blueprint to match reality, or schedule an alignment step. The blueprint is the only memory — no waiver registry, no third state. An accepted divergence disappears from the next scan because the blueprint was edited; a scheduled alignment keeps being detected until the repo actually changes, which is honest. Phase 2 also adds retroactive blueprint authoring for born-`B` projects (without a blueprint, `B` has nothing to diverge from — which is why the `B`/`C` distinction was unenforceable until now).

### D6 — One-time contract reconciliation at first attach (stopgap)

When a class first attaches, `common_contract_definition.md` was authored from blueprint intent and was never reality-checked. A one-time reconciliation diffs it against the as-built API; the operator resolves. Explicitly documented as a stopgap that clears the blueprint-era backlog only — ongoing drift is the feedback loop's job (deferred).

### D7 — Concurrency: serial planning, concurrent execution; merged truth vs promised truth

Phase 1 separates two concurrencies the de-facto behavior conflated. **Planning is serial** (assumed, not enforced): the single operator drives `project_add_feature_e2e.sh` one feature at a time, so at most one feature is mid-planning at any moment. **Execution is concurrent**: features that are already planned are implemented by workers in parallel, and a later feature's plan may depend on an earlier feature's not-yet-merged steps. Removing concurrent *planning* removes mutual blindness — the feature being planned already sees every sibling's plan; concurrent *execution* is what the promise tier and the assignment gate still serve. A circular cross-feature dependency is impossible by construction: an earlier feature could not depend on a later one that did not yet exist when it was planned.

- **Merged truth:** before any planning repo scan (`4.1` Scan repo and apply task-to-BR update, `6` Define Feature Contract Delta, `7` Analyze Repos And Prepare Repo Execution Context, or `8.2` Prerequisite Gap Trace), Overmind synchronizes the attached local repo's default branch from its configured upstream using `git pull --rebase`, then scans that updated local default branch. Worker branches and uncommitted edits are invisible to planning; their content is represented by promises instead. A repo that is not on its default branch, has uncommitted changes, lacks an upstream for the default branch, or fails pull/rebase is blocked and not scanned. Accepted work counts only after it is present on the upstream default branch and the attached local repo has synchronized it.
- **Promised truth:** a sibling feature plan forms a new evidence tier between repo scan and blueprint, tagged `(in-flight <feature-folder>)`. Features are referenced by folder name throughout; the system has no separate feature-ID scheme.
- **A feature is a promise iff its folder holds an `implementation_plan.md` — nothing more.** Because planning is serial, every sibling that is not the current feature has, by construction, already finished planning, so its plan is a stable commitment; there is no readiness predicate to re-check, no lifecycle state machine, and no implementation-status analysis at planning time. "A function is either in the code or in a plan": implemented steps surface via repo scan (merged truth), unimplemented steps stay promises, and the per-row chain sorts it. A fully-merged sibling is harmless to read as a promise — repo scan already wins per row — so completeness is not tested either.
- **No collision-at-commit subsystem.** Serial planning means the feature being planned sees every sibling promise during normal planning, so overlaps surface at the step that owns them: step `7` (Analyze Repos And Prepare Repo Execution Context) binds sibling plans and tags overlapping rows `(in-flight <feature-folder>)`, step `6` (Define Feature Contract Delta) reads sibling deltas and reports endpoint overlaps, and step `8.4` (Implementation Plan Semantic Review) reads the sibling-tagged surface map and raises overlaps as product-fit findings. There is no separate commit-moment detector and no separate collision prompt. Nothing here hard-gates.
- **Consumption:** step `8.2` (Prerequisite Gap Trace) gains category `scheduled_in_feature <feature-folder>/<step-id>`; the plan template's `#### Depends on:` learns cross-feature syntax — an entry containing `/` is `<feature-folder>/<step-id>` (example: `0003_customer_accounts/3.2`).
- **Execution gate = assignment.** `feature_assing_workers.sh` refuses to assign a step whose cross-feature dependency is not complete-and-merged, writing a deterministic hold marker instead (same pattern as existing class-scoped error messages). Completion is read from the dependency's step block: the block exists and every checklist box in it is `- [x]`. This per-step completion check is execution-time bookkeeping, not the planning-time implementation analysis dropped above. Every assignment run re-validates, so a hold flips to an assignment once the dependency completes.
- **Dead features are the operator's responsibility.** There is no `abandoned` concept and no abandonment marker. A feature folder that is dead but not deleted keeps emitting promises, and a dependent step stays held indefinitely; the operator's recourse is to delete the dead folder. Accepted cost for phase-1 simplicity.
- **Liveness is out of scope:** staleness warnings and automatic re-planning belong to the feedback loop.
- Serial-with-no-siblings is the degenerate case: with zero sibling plans the chain collapses to repo → blueprint → placeholder. The design is strictly additive.

### D8 — Phasing

**Phase 1:** per-class transition (D1, D2, D6), permanent evidence chain with policy-`C` tagging (D3, D5-C), concurrency-aware planning and gating (D7), worker `already_satisfied` coordination (D4). **Phase 2:** policy `B` interactive divergence review + retroactive blueprint authoring (D5-B).

### D9 — Execution decision: phase 1 lands in the current shell stack; the port inherits it

This CRP was originally drafted as the requirements baseline for the planned Python+skills port. By operator decision (June 2026), phase 1 executes now against the current shell/md stack; `tasks.md` is written shell-era concrete accordingly. The Python port inherits this behavior and this design record as its baseline. Data-model changes that are cheap in Python but expensive in plain shell — list-shaped `class_repo_paths`, richer feature-lifecycle storage than the marker-file convention — are deferred to the port.

### D10 — First-attach contract reconciliation is class-scoped and runs after the attach loop (follow-up)

**Problem.** As first implemented, D6 (One-time contract reconciliation at first attach) diffed the whole `common_contract_definition.md` against whichever single repo had just attached, with no per-class scope and no notion of "promised." On a real backend+frontend project this produced two bad effects: (1) reconciliation fired *inside* the per-class attach prompt loop, immediately after the backend attach, so the operator never got to attach the frontend before the model started challenging the contract; and (2) because the full contract (backend + frontend surface) was diffed against only the backend repo, every frontend-owned surface read as "no evidence it exists" and was proposed for removal — even though an unattached class is *promised*, not absent. Effect (2) contradicts D3 (Evidence resolution is per-layer, demand-driven, and permanent): absence means "this need is not satisfied," never an inventory claim about a repo.

**Fix.** (A) Reconciliation no longer runs inside the attach prompt loop. The existing post-loop sweep over ready-without-marker classes runs it once, after the operator has attached every repo they intend to attach this feature-start. (B) The reconciliation prompt is scoped per producing class: it reconciles only contract surface produced or owned by an attached (ready) class against that class's repo, and treats surface produced or owned by a still-deferred (promised) class as out of scope — never flagged, removed, or challenged, because a deferred class has no attached repo yet and its absence is not drift. Both the attached classes and the deferred classes are passed into the prompt as explicit in-scope / out-of-scope context. Attribution is read from the contract itself (`producer_repositories` / `consumer_repositories` per contract, repository→class per source block).

**Refinement (item-1 review).** The first cut left the reconciliation command class-agnostic — invoked once per markerless class but reconciling *all* ready repos each time, so a two-class attach ran it twice and each run reprocessed already-reconciled classes (a one-time-per-class violation). Resolved by making the command genuinely class-scoped: `project_contract_reconciliation.sh` now takes a repeatable `--class` argument, the sweep collects all newly-attached (markerless) ready classes and runs **one session scoped to exactly those classes** (already-reconciled and deferred classes become out-of-scope context, never reprocessed), and a per-class marker is written for each only after that single session succeeds. Each target class remains explicit in prompt context even when multiple classes share one monorepo path. Each contract row is judged against its producer/`source_of_truth` repo; a consumer-side mismatch whose source of truth is out of scope is recorded as `planning_implication: reconcile consumer drift` rather than rewriting `canonical_shape`, and a contract is never removed because a participant has not attached.

**Refinement (quality gate).** The contract quality gate (`.helper/check_common_contract_definition_quality.sh`) is **model-owned**, matching `init_common_contract_definition.sh` and the model-invoked-helper convention: the model runs the gate command, treats a content failure (exit 1) as authoritative fix instructions and repairs until exit 0, stops and reports on a helper failure (exit 2), and ends with a defined "cannot pass" line if it cannot. The orchestrator does not execute the gate. The template/golden example are deliberately not added to the prompt: reconciliation edits an already-gated baseline (authored and gated once by `init_common_contract_definition.sh`), so the gate alone guards structural integrity of the edits.

**Refinement (commit is operator-gated).** Step 2 validates that only initialization-baseline paths changed, then commits `init_progress_definition.yaml`, applicable `project_stack_blueprint_<class>.md` files, and `common_contract_definition.md`, so first attachment begins from a clean project repository; unexpected paths stop before that commit. Before the first repo-attachment or reconciliation mutation, the e2e orchestrator requires that clean baseline. After a successful reconciliation session, it validates that only the reconciliation unit changed: `init_progress_definition.yaml`, `common_contract_definition.md`, and the markers for classes reconciled in that session. Unexpected paths stop the flow and remove the new completion markers before any commit. Otherwise it prompts `Commit reconciliation results? [y/N]` and commits only on explicit yes, then verifies the full project worktree is clean. It does not prompt or commit when no reconciliation ran. A declined commit leaves the unit uncommitted and stops the e2e flow before feature work begins. The model still owns the helper quality gate; the orchestrator neither executes that helper nor parses model output.
