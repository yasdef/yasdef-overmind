## Context

This CRP records the agreed design from the June 2026 coordinator-evolution review targeting complex enterprise backend+frontend+mobile projects. It is the consolidated recap of that review and the requirements baseline for the planned overmind shell+md → Python+skills port (the yasdef worker has already completed the same migration). Decisions below describe target behavior; implementation lands inside the port, not as shell-era patches.

Three structural limitations of the current pipeline drive this CRP:

- Project type `A`/`B`/`C` is a single project-level label fixed at init. A greenfield (`A`) project whose backend repo materializes after feature 1 has no clean path into repo-backed planning, and classes materialize at different times, so no single label ever fits.
- Blueprint fallback evidence (CRP-117) is type-`A`-only transitional machinery, but repos materialize blueprints incrementally — a repo-backed class still needs blueprint evidence for layers no feature has touched yet.
- Concurrency exists de facto (`project_add_feature_e2e.sh` allows starting a new feature while others are unfinished) but is undesigned: each feature plans as if alone, so concurrent features can duplicate work, claim conflicting contract shapes, and collide on surfaces invisibly.

## Goals / Non-Goals

**Goals:**

- Per-class blueprint→repo transition, detected at feature start, operator-confirmed.
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

Each class transitions blueprint-backed → repo-backed on its own timeline. At feature start, the e2e flow checks every deferred class: if the blueprint's `planned_repo_path` now holds a scannable git repository, it prompts the operator to attach it (reusing `project_setup_update_project.sh` attach logic), defaulting the class policy to `C`. The prompt carries a one-line policy explanation ("repo becomes authoritative; blueprint consulted only for subsystems absent from the repo") so the choice is informed — and the operator's informed choice is the ratification; no additional review ceremony. `project_type_code` is demoted to a historical record of how the project started; feature steps stop reading it.

### D2 — Scan-dependent steps gate per class, never per project type

Steps `4.1` (repo scan for BR), `6` (contract delta), and `7` (surface maps) iterate active classes and gate on `class_repo_paths[<class>].state`, not `project_type_code`. A per-class `policy` field is recorded at attach time. The list-shaping hedge for the deferred multi-repo evolution is itself deferred to the Python port (see D9): reshaping `class_repo_paths` in the current plain-shell stack would force list-parsing into every consumer for no phase 1 behavioral gain.

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
- **Policy `B` (phase 2):** divergence may become an operator question, built on the step `8.4` semantic-review interaction pattern, with bounded asking criteria (structural divergences in §2 stack choices / §3 archetypes only — never style). Resolution is always one of exactly two states: edit the blueprint to match reality, or schedule an alignment step. The blueprint is the only memory — no waiver registry, no third state. An accepted divergence disappears from the next scan because the blueprint was edited; a scheduled alignment keeps being detected until the repo actually changes, which is honest. Phase 2 also adds retroactive blueprint authoring for born-`B` projects (without a blueprint, `B` has nothing to diverge from — which is why the `B`/`C` distinction was unenforceable until now).

### D6 — One-time contract reconciliation at first attach (stopgap)

When a class first attaches, `common_contract_definition.md` was authored from blueprint intent and was never reality-checked. A one-time reconciliation diffs it against the as-built API; the operator resolves. Explicitly documented as a stopgap that clears the blueprint-era backlog only — ongoing drift is the feedback loop's job (deferred).

### D7 — Concurrency: merged truth vs promised truth

- **Merged truth:** all repo scans (`4.1`, `7`, `8.2`) read the default branch only. Worker branches are invisible to planning; their content is represented by promises instead. Implied discipline: accepted work merges to default before it counts.
- **Promised truth:** committed feature plans form a new evidence tier between repo scan and blueprint, tagged `(in-flight <feature-folder>)`. Features are referenced by folder name throughout; the system has no separate feature-ID scheme.
- **Promise eligibility is all-or-nothing: planning fully finished.** A feature emits promises if and only if its `implementation_plan.md` passes the same readiness predicate `feature_assing_workers.sh` already enforces. Mid-planning artifacts are working material, not commitments; the finished plan is the system's one commitment artifact. Zero implemented steps is irrelevant to eligibility.
- **Feature lifecycle:** `planning` (emits nothing, reads committed siblings' promises) → `committed` (emits promises) → `implementing` (mixed truth: merged steps surface via repo scan, the rest stay promises — the chain sorts it per row) → `complete` / `abandoned` (emits nothing; `abandoned` is an explicit operator marker).
- **Consumption:** step `8.2` gains category `scheduled_in_feature <feature-folder>/<step-id>`; the plan template's `#### Depends on:` learns cross-feature syntax — an entry containing `/` is `<feature-folder>/<step-id>` (example: `0003_customer_accounts/3.2`).
- **Execution gate = assignment.** `feature_assing_workers.sh` refuses to assign a step whose cross-feature dependency is not complete-and-merged, writing a deterministic hold marker instead (same pattern as existing class-scoped error messages). Every assignment run re-validates — this also catches dangling citations of abandoned features at the last orchestrator touch before execution.
- **Collision detection at the commit moment.** The all-or-nothing rule makes two simultaneously-planning features mutually blind; therefore the collision check runs when a plan passes its readiness gate and becomes a promise — checked against all existing promises plus merged truth. First committer passes clean; the second sees conflicts exactly when its plan becomes binding. Surface overlaps (`concurrently_touched_by: <feature-folder>`) are product judgment → step `8.4` findings; same-endpoint contract conflicts are cheap to flag early → immediate e2e prompt. Never hard gates.
- **Liveness is out of scope:** a committed-but-dormant feature emits promises indefinitely; phase 1 visibility is the hold marker naming its blocker at assignment time. Staleness warnings and automatic re-planning belong to the feedback loop.
- Serial operation is the degenerate case: with zero in-flight features the chain collapses to repo → blueprint → placeholder. The design is strictly additive.

### D8 — Phasing

**Phase 1:** per-class transition (D1, D2, D6), permanent evidence chain with policy-`C` tagging (D3, D5-C), concurrency-aware planning and gating (D7), worker `already_satisfied` coordination (D4). **Phase 2:** policy `B` interactive divergence review + retroactive blueprint authoring (D5-B).

### D9 — Execution decision: phase 1 lands in the current shell stack; the port inherits it

This CRP was originally drafted as the requirements baseline for the planned Python+skills port. By operator decision (June 2026), phase 1 executes now against the current shell/md stack; `tasks.md` is written shell-era concrete accordingly. The Python port inherits this behavior and this design record as its baseline. Data-model changes that are cheap in Python but expensive in plain shell — list-shaped `class_repo_paths`, richer feature-lifecycle storage than the marker-file convention — are deferred to the port.
