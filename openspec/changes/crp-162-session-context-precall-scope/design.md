## Context

The migrated orchestrator runs each catalog step through `executeStep`, which dispatches session actions to `executeSessionAction` in `packages/asdlc-coordinator/src/runner/execute-step.ts`. For every session action, that function currently:

1. Evaluates the `runIf` predicate (skip if false).
2. Runs the sync function when `requiresSync` is set (fail on non-zero).
3. **Builds deterministic context** via `deps.context[action.skillName]` (fail on non-zero exit).
4. Resolves the runner model/phase config.
5. Builds the session prompt via `deps.buildSessionPrompt(action, bindings)`.
6. Validates and snapshots read-only guards, then launches the model session.

The context result from step 3 is consumed in exactly one place: `resolveContextReadOnlyInputs(contextResult, bindings)` (execute-step.ts:288), whose output feeds `validateReadOnlyGuardsBeforeSession` and `snapshotReadOnlyGuards`. Those only act on guards declared as `{ mode: "fromContext" }`; guards of mode `mustExistUnchanged` / `preserveExistence` carry static file lists from the catalog and never read the context result. Critically, `buildSessionPrompt` does **not** take the context result — the model prompt is assembled from `bindings` and a per-skill recipe, independent of the deterministic context builder.

So for any session action with no `fromContext` guard, step 3 does work whose output nothing reads. `task-to-br` (step-catalog.ts:105) is exactly that: `session("task-to-br", "task_to_br", ["feature_br_summary.md"])` with no `readOnlyGuards`. Yet its context builder, `context/task-to-br.ts`, hard-errors when `user_br_input.md` is absent — and that file is produced by the `overmind-task-to-br` skill's own capture step, which runs only inside the session that step 3 is blocking. The result is a circular precondition: on a fresh feature, step `4.1` can never launch the session that would create the input its own pre-flight context demands.

On `main` this class of bug could not occur because there was no generic pre-call. The shell orchestrator (`overmind/scripts/project_mgmt/project_add_feature_e2e.sh`) invoked `overmind context <skill>` for precisely the seven feature-scoped steps that snapshot a from-context guard — contract-delta, surface-map, technical-requirements, implementation-slices, prerequisite-gaps, implementation-plan, plan-semantic-review — and never for task-to-br, br-clarification, repo-br-scan, or stack-blueprint. Those seven are exactly the catalog entries tagged with `contextGuard`. The TypeScript migration folded the pre-call into `executeSessionAction` for all sessions and, in doing so, dropped the guard-driven selectivity that made it safe.

## Goals / Non-Goals

**Goals:**

- Let a freshly scaffolded feature reach step `4.1` and launch the task-to-br session, so the skill can run its own capture→context→gate loop.
- Restore `main`'s invariant: build a session's deterministic context before launch only when a from-context read-only guard consumes it, extended to project-level class-list sessions whose builder validates the class-to-repo bindings before launch.
- Keep the existing behavior for from-context sessions unchanged, including failing the step when their context builder exits non-zero.
- Express the condition as an action property, not a step-id or skill-name branch.

**Non-Goals:**

- Changing `context/task-to-br.ts`. Its missing-input error is correct: by the time the skill calls `context task-to-br`, the input must exist.
- Changing the `overmind-task-to-br` `SKILL.md`, which already owns the capture loop and is byte-identical to `main`.
- Changing the step `4.1` catalog entry or any other catalog entry.
- Adding CLI flags, reordering the other steps in `executeSessionAction`, or altering how the prompt is built.

## Decisions

**Gate the pre-call on `readOnlyGuards.some((guard) => guard.mode === "fromContext")`.** This is the exact set the shell orchestrator pre-called context for, so it reproduces `main`'s behavior without enumeration. When the check is false, skip the `deps.context` invocation entirely and snapshot read-only guards against an empty from-context input list — safe because a no-from-context action has no context-derived paths to resolve, and static-file guards resolve from the catalog. When true, the current path runs unchanged: build context, fail on non-zero, resolve, validate, snapshot.

_Alternatives considered._ (a) Special-case `task-to-br` by skill name — rejected: it fixes one symptom, leaves br-clarification/repo-br-scan/stack-blueprint carrying the same dead pre-call, and reintroduces the per-step branching the target architecture forbids. (b) Make `context/task-to-br.ts` tolerate a missing `user_br_input.md` — rejected: it papers over the ordering inversion, weakens a builder that is correctly strict when the skill calls it in-loop, and still leaves every other no-guard session doing wasted work. (c) Drop the pre-call for all sessions and let each skill run its own context — rejected: the seven from-context steps genuinely need the snapshot resolved before the session for read-only guard enforcement; removing it would lose that protection.

**Keep the guard-mode check local to `executeSessionAction`.** The `Action` type and `ReadOnlyGuard` discriminated union already carry `mode`, so the predicate is a one-line inspection of data the function already holds. No new field, no catalog change, no type change.

**Also pre-call for project-level class-list sessions (D4).** The `contract-reconciliation` step routes through a `classListContext` builder but declares a `mustExistUnchanged` guard, not `fromContext`, so a fromContext-only gate would skip its pre-call. Unlike the feature-scoped skills, that builder's pre-call is not dead work: it validates the pending class-to-repo bindings and fails the step before launch on an invalid or unmapped class. The gate therefore also treats "a class-list context builder is registered for the skill" as needing context: `deps.classListContext?.[action.skillName] !== undefined`. This is still an action-data property, not a skill-name branch, and `common-contract` (the other class-list session) already carries a fromContext guard, so only reconciliation depends on this arm.

## Risks / Trade-offs

**A future session action that reads context indirectly (not through a from-context guard) would silently skip the pre-call.** → Today nothing reads the context result except from-context guard resolution — `buildSessionPrompt` is independent of it — so the guard-mode check is a faithful proxy for "needs context." If a later change makes the prompt or another consumer depend on the context result, that change must add the dependency deliberately and revisit this gate; the coupling is small and localized to one function.

**The seven from-context steps must still behave exactly as before.** → The change is purely additive around the existing branch: the true-branch path is the current code unchanged. Regression coverage for a from-context session failing on a context error locks this in.
