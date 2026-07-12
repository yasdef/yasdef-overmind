## Context

Today two commands write `class_repo_paths`. `project create` captures a ready-or-deferred repository decision per class before the project exists, and `project reconcile` prompts every deferred class to attach a repository, writing `state: "ready"`, the canonical path, and a hardcoded `policy: "C"`. Creation is therefore the only place class membership can be declared, and reconcile is the only place a repository can be bound — but only for a class that creation already declared and left deferred.

The persisted model is:

```yaml
meta_info:
  project_type_code: "A"
  project_classes:
    - backend
  class_repo_paths:
    backend:
      state: "deferred"
      path: ""
      policy: "A"
```

This change keeps repository binding exactly where it already lives and instead removes it from creation, so that one command owns each decision:

| Decision | Owner |
|---|---|
| project identity, project type | `project create` |
| class membership (which classes exist) | `project create`, `project add-class` |
| class policy, repository path, `ready` | `project reconcile` |

## Goals / Non-Goals

**Goals:**

- Make project creation total: it cannot fail on a repository path, because it never asks for one.
- Give class membership a command that works at any point in a project's life, not only at creation.
- Give a mis-bound class a way back to deferred so reconcile can rebind it.
- Keep exactly one implementation that writes class policy, repository path, and `ready` state.

**Non-Goals:**

- Multiple repositories per class; one record per supported class is retained.
- Changing project name normalization, folder naming, metadata registration, template seeding, or initial git identity behavior.
- Removing or repurposing the project-level `project_type_code`.
- Defining downstream `A`/`B`/`C` interpretation beyond persisting the selected policy.

## Decisions

### 1. Creation declares classes; it never touches repositories

`project create` asks for the project name, the project type, and which of `backend`, `frontend`, `mobile`, `infrastructure` the project has. Each selected class is written in canonical order as:

```yaml
backend:
  state: "deferred"
  path: ""
  policy: "A"
```

Selecting no class is valid and produces empty class collections. Creation then prints that `overmind project reconcile` binds repositories.

Alternative: keep the ready-or-deferred question in creation. Rejected because it forces every repository decision into the moment of creation, adds a validation/retry loop to a command that otherwise cannot fail on operator input, and duplicates the binding logic reconcile already owns.

### 2. Seeded `policy: "A"` is a default, not a claim

A class with no repository has nothing to classify, so the seeded policy is a placeholder that reconcile overwrites when the operator states what the repository actually is. `A` is used as that placeholder because a class row is written with a concrete policy value rather than an absent field.

Nothing in the coordinator reads `policy` today; it is write-only metadata whose only constraint is coherence validation. That makes the placeholder free now. **The first consumer that branches on per-class policy must not treat a deferred `A` as "greenfield, generate this repository"** — a deferred `A` means the operator has not stated the policy yet. Only a policy recorded through reconcile is an operator statement.

### 3. Reconcile asks the policy before the path

Reconcile keeps prompting every deferred class in definition order. The prompt gains a first question:

```text
deferred class
  policy? ─ A ──> keep deferred, empty path, record policy A
            B/C ─> repository path? ─ blank ─> keep deferred, record policy B/C
                                    │ valid ─> ready + canonical path + policy B/C
                                    └ invalid ─> one retry, then keep deferred
            blank/EOF ─> class unchanged
```

Policy `A` means the repository does not exist yet, so there is nothing to ask for and nothing to validate. Policy `B` or `C` means an existing repository, so the existing path validation and single-retry rule apply unchanged.

The list of prompted classes stays "every deferred class", not "every class without a policy". A deferred class is by definition unbound, so asking about it on the next run is correct; blank already means "still not yet".

### 4. Membership changes only ever produce a deferred class

`project add-class` offers two actions:

- **add a class** that is not in `project_classes` — inserts the row in canonical order as deferred, empty path, policy `A`.
- **change a class** that is in `project_classes` — resets that row to deferred, empty path, policy `A`, and clears `contract_reconciled`.

Both actions land a class in exactly the state creation produces, and reconcile binds it on the next run. The command never asks for a repository path, never asks for a policy, and never writes `ready`.

Alternative: let "change a class" take a new repository path directly. Rejected — that reintroduces a second implementation of policy/path/ready writing next to reconcile's, which is the coupling this change exists to remove.

### 5. Membership writes use the project repository transaction boundary

`project add-class` resolves the runtime root and reuses existing project discovery: the current project when invoked from one, the only project when exactly one exists, interactive selection otherwise. It accepts no arguments and no path flag, and prints the selected project before the first prompt.

Before its write, a git-backed project must have a clean worktree. The command mutates one class per invocation as a single definition update, then offers one commit; declining retains the accepted uncommitted change and reports that state. Git inspection or commit failures are typed diagnostics and never claim a clean commit.

### 6. Policy coherence widens to `A|B|C`

`validateClassRecordCoherence` currently accepts a missing policy and rejects any policy other than `B` or `C`. Both halves are wrong under this change: creation, `add-class`, and reconcile all write a policy, so every class row carries one. The rule becomes: `policy` is required and is one of `A|B|C`; `A` is valid only alongside `deferred` state and an empty path; `ready` requires a non-empty canonical path; `deferred` requires an empty path.

The missing-policy tolerance existed only for rows written by the old creation flow, which recorded state and path without a policy. Those rows are not produced by any writer after this change, so the tolerance is dropped rather than retained.

## Risks / Trade-offs

- [A deferred `A` is indistinguishable from an operator-stated `A`] -> Accepted; policy has no consumer today. Decision 2 records the constraint the first consumer must honor.
- [An operator who already has all repositories now runs two commands instead of one] -> Accepted; creation gains totality and the binding path is the same one used for every later repository.
- [A class reset to deferred loses its reconciliation evidence] -> Intended: `contract_reconciled` is cleared because the repository binding it was based on is gone.
- [A declined `add-class` commit leaves a dirty project that blocks later managed mutations] -> Report the exact dirty state and require the operator to commit or revert before another transactional command.

## Migration Plan

1. Widen policy coherence to `A|B|C` and thread the selected policy through `applyClassAttachment` and `attachClassRepo`.
2. Add the policy prompt to the reconcile deferred-class loop, keeping policy `A` path-free.
3. Remove repository capture from `project create`, allow an empty class selection, and seed selected classes as deferred/`A`.
4. Add the membership mutation and the `project add-class` command with project discovery and the project-repository transaction boundary.
5. Update docs, usage output, and package tests.
6. Run coordinator tests, root verification, strict OpenSpec validation, and `git diff --check`.

Overmind has no installed base and no prior on-disk project definitions, so each step replaces the previous behavior outright: no compatibility shim, no dual-shape parsing, and no fixtures for definitions written by the old flow.

## Open Questions

None blocking.
