# Init Progress Definition — Data Model

Reference for the `init_progress_definition.yaml` schema. See `init_progress_definition_sequence_diagram.md` for the step flow.

## `meta_info.class_repo_paths`

Maps each active class (`backend`, `frontend`, `mobile`, `infrastructure`) to its repo attachment record. Shape per class:

```yaml
class_repo_paths:
  <class>:
    state: "ready" | "deferred"
    path: "<abs path>" | ""
    policy: "A" | "B" | "C"
```

### Fields

**`state`**
- `"ready"` — repo is attached and scannable. Scan-dependent steps (4.1, 6, 7) include this class.
- `"deferred"` — no repo attached. With policy `"A"`, this is intentional and does not block feature work. With policy `"B"` or `"C"`, an existing repo still needs to be bound before feature work. Scan-dependent steps skip deferred classes; evidence resolves from committed sibling promises, blueprint (`(planned)`), or placeholder instead.

**`path`**
Absolute filesystem path to the git repository when `state` is `"ready"`, otherwise an empty string. All planning scans read the **committed default branch** of ready repos only — never the working tree.

**`policy`**
Class policy recorded by `overmind project reconcile`.
- `"A"` — repository will be generated later; the class stays deferred with an empty path.
- `"B"` — existing repository with partial context.
- `"C"` — existing repository with code-first context. A layer materialized in the repo but diverging from the blueprint resolves from the repo, tagged `divergent_from_blueprint: §<n>`. Blueprint is consulted only for layers entirely absent from the repo.

### Lifecycle

Classes start `"deferred"` with `path: ""` and `policy: "A"`, which means feature work can start without repo evidence for that class. `node .overmind/overmind.js project add-class` adds a missing class or resets an existing class back to that deferred shape. `node .overmind/overmind.js project reconcile --path <project-path>` can keep a deferred class as policy `A`, or convert it to policy `B`/`C`, bind a valid operator-provided repo path, and reconcile ready classes; `node .overmind/overmind.js run` blocks deferred `B`/`C` classes and ready-unreconciled classes with separate guidance.

`project_type_code` records how the project started and is not read by feature-phase steps.
