## Context

The current `createProject` primitive captures project name, one-or-more classes, one ready/deferred repository decision per class, and project type before it creates any files. Class membership therefore exists only as a creation-time decision. Later attachment is embedded in `project reconcile`, which combines repository mutation with contract reconciliation.

The persisted model already separates project-level origin from class-level repository state:

```yaml
meta_info:
  project_type_code: "A"
  project_classes:
    - backend
  class_repo_paths:
    backend:
      state: "ready"
      path: "/absolute/repo/path"
      policy: "C"
```

This change makes that separation explicit in the interaction model. `project_type_code` remains project metadata selected once during project creation. Each class receives its own `policy`, `state`, and `path` through a reusable class-management subprocess.

The existing `project init` command initializes project-level ASDLC artifacts and is not renamed or repurposed. In this design, "initialize project" means the base portion of `project create`, avoiding a collision with that command.

## Goals / Non-Goals

**Goals:**

- Allow a valid project record and project repository to be created with no classes.
- Make class/repository configuration reusable immediately after creation and through a separate command later.
- Persist class-level policy `A`, `B`, or `C` independently from project-level `project_type_code`.
- Give operators reversible navigation before mutation and explicit approval before replacing an existing class record.
- Give one subsystem ownership of class/repository metadata mutation.

**Non-Goals:**

- Multi-repository-per-class support; `project_classes` and `class_repo_paths` retain one record per supported class.
- New project-create or class-management CLI flags.
- Changing project name normalization, project folder naming, metadata registration, template steps, or initial git identity behavior.
- Defining new policy `B`/`C` divergence semantics beyond persisting the selected policy and existing downstream interpretation.
- Rewriting existing deployed project definitions.

## Decisions

### 1. Base creation completes before optional class management

`createProject` captures name and project-level type, writes a definition with `project_classes: []` and `class_repo_paths: {}`, appends the runtime metadata record, initializes the project git repository, and creates the existing initial commit. Only after that succeeds does the CLI ask whether to add classes.

On yes, the CLI invokes the same class-management primitive against the new project root. On no or closed input, the already-created base project remains a successful result. This keeps creation failure/rollback boundaries unchanged and prevents a later class prompt from undoing a valid project.

Alternative: delay all filesystem creation until the optional class loop finishes. Rejected because it keeps the two subprocesses coupled and makes "create without classes" a special abort path rather than a valid project state.

### 2. One reusable class-management state machine serves both entry points

The post-create handoff passes the known project root directly. The standalone `overmind project add-class-and-repo` command resolves the runtime root and reuses project discovery: current project when invoked from one, the only project when exactly one exists, or interactive project selection when several exist. The command accepts no path flag.

```text
already added: backend (repo deferred), frontend (repo ready)   <- info only
class menu
  1 add new class ─> choose class ─> choose A/B/C or escape
  2 all done              │                    │
                           │ escape             └─> class menu
                           └────────────────────────> class menu

policy A ───────────────────────────> proposed deferred + empty path
policy B/C ─> add repo now/later
                  later ────────────> proposed deferred + empty path
                  now ─> path check ─> proposed ready + canonical path
                             invalid ─> add repo now/later

new class ──────────────────────────> stage proposal ─> class menu
existing class ─> show old/new ─> confirm ─> stage or discard ─> class menu
all done ─> atomically persist staged changes ─> optional commit
```

Before the add-or-finish menu, the subprocess prints an informational summary of already-added classes and their repository state, for example `already added: backend (repo deferred), frontend (repo ready)`. The summary is display only; it is omitted when no class is configured yet.

The class picker itself lists all four supported classes on every pass with plain labels. Existing classes remain selectable so the replacement path stays reachable. The policy picker includes an explicit escape/back option because the line-oriented `InteractionPort` does not receive a portable physical Escape key event.

### 3. Policy determines the allowed state/path shape

The class record invariants are:

| Policy | Repository decision | Persisted state | Persisted path |
|---|---|---|---|
| `A` | not asked | `deferred` | empty |
| `B` | later | `deferred` | empty |
| `B` | valid path now | `ready` | canonical absolute path |
| `C` | later | `deferred` | empty |
| `C` | valid path now | `ready` | canonical absolute path |

Policy `A` is blueprint/deferred by construction and never prompts for a repository. Policy `B` or `C` records the selected policy even when repository attachment is deferred. This differs from `project_type_code`: changing a class never changes the project-level code or label.

### 4. Repository validation reuses the project-create contract

An add-now path must be non-blank, exist, be a directory, and contain at least one entry; it is then canonicalized to an absolute real path. A failed check emits the reason and returns to the add-now/add-later decision, allowing either retry or defer.

Alternative: require `.git`, as `project reconcile` attachment currently does. Rejected for this change because the requested class-management contract matches current project-create validation. Scan/readiness gates remain responsible for any stronger repository prerequisites they require.

### 5. Existing-class replacement is compare-and-confirm

The primitive builds the complete proposed `{ policy, state, path }` record before mutation. If the class exists and the proposal differs, it displays the current and proposed values and requires explicit yes/no confirmation. No, escape before confirmation, or closed input discards that proposal and returns/stops without changing that class. An identical proposal is reported as unchanged and does not prompt or write.

Accepted changes are staged in memory for the session. `all done` writes `project_classes` and `class_repo_paths` once through an atomic mutation, preserving unrelated `meta_info` fields and the complete `steps` block. Class keys and `project_classes` use canonical order. A policy, state, or path replacement clears `contract_reconciled` for that class because the evidence basis changed.

### 6. Class management and reconciliation have distinct ownership

`project add-class-and-repo` is the sole interactive writer of class membership, policy, state, and path. `project reconcile` stops prompting over deferred classes and only reconciles ready classes whose `contract_reconciled` flag is not true. Its guidance and tests are updated to describe reconciliation rather than attachment plus reconciliation.

This removes duplicate mutation paths. It also means an operator who chose later returns to `project add-class-and-repo`, selects the existing class, proposes the ready path, and confirms the replacement before reconciliation.

### 7. Class-management writes use the project repository transaction boundary

Before the first persisted mutation, a git-backed project must have a clean worktree. At `all done`, accepted changes are atomically written as one definition update. If the project is a git worktree and changes were written, the command offers one commit using a class-configuration commit message; declining retains the accepted definition change and reports that it remains uncommitted. Git inspection or commit failures are typed diagnostics and never claim a clean commit.

The post-create handoff starts from the clean initial project commit. This keeps project repository history distinct from runtime metadata and attached class repositories.

## Risks / Trade-offs

- [A newly created empty project cannot run class-dependent initialization] -> Readiness reports the missing class configuration and directs the operator to `overmind project add-class-and-repo`; creation itself remains valid.
- [Policy `A` expands the currently accepted class policy set from `B|C`] -> Update parsers, coherence validation, fixtures, and downstream policy unions together; enforce `A` only with deferred/empty state.
- [Removing attachment from reconcile changes an established operator path] -> Update reconcile guidance and pending-work messages to name the class-management command before reconciliation.
- [A declined class-management commit leaves a dirty project that blocks later managed mutations] -> Report the exact dirty state and require the operator to commit or revert before another transactional command.
- [Existing definitions may omit class policy] -> Keep them readable; require an explicit policy only when a class is newly added or replaced through this command.
- [The standalone command can target the wrong project in a multi-project workspace] -> Reuse explicit interactive project selection and print the selected project before the first class prompt.

## Migration Plan

1. Add the class-record model, validation, atomic mutation, and deterministic interaction primitive with focused tests.
2. Refactor project creation to emit empty class collections and add the optional post-create handoff.
3. Add `overmind project add-class-and-repo` with shared project discovery and project-repository transaction behavior.
4. Remove deferred attachment from reconcile and update all readiness/guidance paths to direct class changes to the new command.
5. Update parser/coherence consumers for policy `A`, docs, usage output, and package tests.
6. Run coordinator tests, root verification, strict OpenSpec validation, and `git diff --check`.

Rollback restores mandatory class capture inside `project create` and reconcile-owned attachment. Project definitions written by the new flow remain structurally readable; classless projects require class configuration before rollback-era creation assumptions can be satisfied.

## Open Questions

None blocking.
