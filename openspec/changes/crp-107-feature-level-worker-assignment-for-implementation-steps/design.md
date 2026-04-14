## Context

Overmind currently creates a shared `implementation_plan.md` with optional `#### Assigned:` lines, but assignment is intentionally deferred and done manually after Step `8.2`. The project already stores registered workers in `<project-path>/workers.yaml`, including `uuid`, `class`, and `status`, yet no feature-level script consumes that registry to bind plan steps to workers.

This change adds a dedicated feature-level assignment command while keeping current workflow boundaries intact: planning still happens in `feature_implementation_plan.sh`, and assignment happens afterward against a completed plan. The implementation must remain shell-only, preserve existing plan content, and avoid adding unrelated CLI flags.

## Goals / Non-Goals

**Goals:**
- Add a feature-level runtime command `feature_assing_workers.sh` with `--feature_path <asdlc/projects/<project-id>/<feature-folder>>`.
- Enforce implementation-plan readiness before assignment starts.
- Resolve worker eligibility strictly by exact class match between step `#### Repo:` and `workers.yaml` worker `class`.
- Require deterministic class-level selection when multiple active workers exist in one class.
- Ensure every step ends with `#### Assigned:` containing either a selected worker UUID or a deterministic error message.
- Keep updates non-destructive by preserving step ordering and checklist content while only changing/adding assignment lines.

**Non-Goals:**
- Changing implementation-plan generation logic in Step `8.2`.
- Adding worker load balancing, per-step custom worker selection, or multi-worker distribution within one class.
- Introducing worker lifecycle edits (register/update/delete) in this command.
- Supporting repo classes not represented by implementation-plan `#### Repo:` entries.

## Decisions

### Decision: Assignment command is feature-path scoped and project-derived
The script will accept only `--feature_path` and resolve the project directory as `dirname(<feature-path>)`. It will read workers from `<project-path>/workers.yaml` and update only `<feature-path>/implementation_plan.md`.

Rationale: this matches existing staged feature commands and keeps write scope deterministic.

Alternatives considered:
- Accept project path + feature id separately: rejected to avoid extra CLI surface.
- Read workers from global registry only: rejected because project-level `workers.yaml` is the authoritative runtime source.

### Decision: Readiness gate requires a parseable implementation plan
Assignment starts only if `implementation_plan.md` exists and includes at least one valid step block with `### Step ...` plus `#### Repo:`. Missing or malformed plan content causes a non-zero exit with a clear readiness error.

Rationale: assignment should run only after planning output is materially present and consumable.

Alternatives considered:
- Gate solely on scanner step state: rejected because assignment needs the actual plan structure anyway.
- Attempt best-effort assignment on partial plan: rejected because output would be ambiguous and non-deterministic.

### Decision: Worker availability is class-strict and status-filtered
A worker is eligible only when `status: active` and `class` exactly equals the step repo class (`backend`, `frontend`, `mobile`). No cross-class fallback is allowed.

Rationale: the user requirement is strict class matching; cross-class fallback would hide staffing gaps.

Alternatives considered:
- Allow fallback to any active worker: rejected because it violates class constraints.
- Include `postponed` workers: rejected because postponed workers are not currently available.

### Decision: Selection is one class-wide choice per run
For each class present in the plan:
- 0 eligible workers: record deterministic assignment error text for all steps in that class.
- 1 eligible worker: assign that UUID to all steps in that class automatically.
- >1 eligible workers: prompt once for that class and apply the chosen UUID to all steps in that class.

Rationale: assignment should be predictable and low-friction while preserving explicit operator control in ambiguous cases.

Alternatives considered:
- Prompt for each step: rejected as noisy and inconsistent.
- Auto-pick first UUID when multiple exist: rejected because the user explicitly requested interactive choice.

### Decision: Rewrite only `#### Assigned:` lines in-place
The command will parse the plan step-by-step, update existing `#### Assigned:` lines or insert them after `#### Evidence:` when missing, and keep all other content unchanged.

Rationale: minimal mutation reduces regression risk for downstream plan quality checks and human review.

Alternatives considered:
- Regenerate the whole plan document: rejected as too destructive.
- Store assignments in a separate sidecar file: rejected because required result is in plan `#### Assigned:` lines.

## Risks / Trade-offs

- [Risk] Shell parsing can be brittle if plan format drifts from template contracts. -> Mitigation: fail fast on malformed step blocks and add regression tests for parse edge cases.
- [Risk] Class-level single selection cannot split work between multiple same-class workers. -> Mitigation: document that this command intentionally assigns one worker per class per run.
- [Risk] Persisting error text in `#### Assigned:` may be mistaken for final staffing state. -> Mitigation: use deterministic `ERROR:`-prefixed messages and print summary guidance in command output.
- [Risk] Existing plans with unusual `#### Assigned:` placement may not be normalized consistently. -> Mitigation: enforce one canonical assignment line per step and cover migration behavior in tests.

## Migration Plan

1. Add `overmind/scripts/feature_assing_workers.sh` with feature-path validation, readiness checks, workers loading, class-level selection, and deterministic plan rewrite.
2. Stage the new command into ASDLC workspaces via `project_setup_first_init_machine.sh` bootstrap/update sync and quickrun guidance.
3. Update `overmind/README.md` with command usage and assignment behavior contract.
4. Add shell regression coverage under `tests/ai_scripts/` for readiness failures, no-worker class errors, multi-worker prompts, and final `#### Assigned:` plan output.
5. Verify OpenSpec change status reports apply-ready once design/specs/tasks are complete.

Rollback strategy: remove the new assignment command and staging/docs references; previously written `#### Assigned:` lines remain as regular plan content for manual cleanup.

## Open Questions

- Should assignment runs with one-or-more class errors exit non-zero after updating the file, or exit zero with warning-only status? This change currently keeps the behavior open for implementation decision, while requiring deterministic per-step error output either way.
