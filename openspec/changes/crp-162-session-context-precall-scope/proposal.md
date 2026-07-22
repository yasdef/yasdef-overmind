## Why

On the `e2e_migration` branch, step `4.1` (task-to-br) cannot complete through `overmind run` on a freshly scaffolded feature: the run fails with `task-to-br: Required file not found: <feature>/user_br_input.md`. This is a regression the TypeScript orchestrator introduced. The migrated `executeSessionAction` calls each skill's context builder before launching every session, and treats a non-zero context exit as a step failure. But `user_br_input.md` is created by the `overmind-task-to-br` skill itself, which owns a capture→context→gate loop and only invokes `context task-to-br` after it has captured a source. Because the orchestrator now runs that context builder before the skill can capture input, the deterministic "no input yet" error aborts the step before the session that would fix it ever starts — an unbreakable circular precondition on any new feature.

## What Changes

- Scope the session context pre-call to the actions that actually consume its result. `executeSessionAction` builds context before a session when the action declares a read-only guard that resolves its paths from context (`{ mode: "fromContext" }`), or when the action routes through a project-level class-list context builder (whose pre-call validates the class-to-repo bindings before launch). A session with neither — no from-context guard and no class-list builder, such as `task-to-br` — launches without the pre-call, even when its guards carry static catalog file lists.
- Restore the invariant the shell orchestrator held on `main`: it pre-ran `overmind context <skill>` for exactly the seven feature-scoped steps carrying a from-context guard (contract-delta, surface-map, technical-requirements, implementation-slices, prerequisite-gaps, implementation-plan, plan-semantic-review) and never for task-to-br, br-clarification, repo-br-scan, or stack-blueprint. The migration generalized the pre-call to all sessions and lost that distinction; this change re-establishes it.
- Preserve the existing failure behavior for from-context actions: when a from-context guard is present and its context builder exits non-zero, the step still fails as it does today.

The condition is a property of the action (`readOnlyGuards.some((guard) => guard.mode === "fromContext") || deps.classListContext?.[action.skillName] !== undefined`), not a step-id or skill-name branch, so no per-step special-casing is introduced.

## Capabilities

### New Capabilities

- `session-context-precall-scope`: the rule that the orchestrator builds a session action's deterministic context before launch only when a from-context read-only guard or a project-level class-list builder needs it, the preserved from-context failure behavior, and the resulting ability for a freshly scaffolded feature to reach and launch the task-to-br session.

### Modified Capabilities

<!-- None. openspec/specs/ contains no consolidated executor capability; this behavior is recorded as a new capability. -->

## Impact

- `packages/asdlc-coordinator/src/runner/execute-step.ts`: `executeSessionAction` gains a check that conditions the context pre-call; when neither a from-context guard nor a class-list builder is present it skips the builder and snapshots read-only guards against an empty from-context input list. No other function changes.
- `packages/asdlc-coordinator/test/`: add coverage for a no-from-context-guard session launching without invoking `deps.context` even when that builder would error, a from-context session still failing on a context error, and an orchestrator-level check that a freshly scaffolded feature reaching step `4.1` launches the task-to-br session rather than failing on a missing `user_br_input.md`.
- Not changed: `packages/asdlc-coordinator/src/context/task-to-br.ts` (its missing-input error is correct once the skill calls it), the `overmind-task-to-br` `SKILL.md` (already owns the capture loop and is identical to `main`), and the step `4.1` catalog entry.
