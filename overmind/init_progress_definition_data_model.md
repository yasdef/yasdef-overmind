# Init Progress Definition — Data Model

Reference for the `init_progress_definition.yaml` schema. See `init_progress_definition_sequence_diagram.md` for the step flow.

## `meta_info.class_repo_paths`

Maps each active class (`backend`, `frontend`, `mobile`) to its repo attachment record. Shape per class:

```yaml
class_repo_paths:
  <class>:
    state: "ready" | "deferred"
    path: "<abs path>"   # present when state is "ready"
    policy: "C"          # recorded at attach time
```

### Fields

**`state`**
- `"ready"` — repo is attached and scannable. Scan-dependent steps (4.1, 6, 7) include this class.
- `"deferred"` — no repo attached yet. Scan-dependent steps skip this class; evidence resolves from committed sibling promises, blueprint (`(planned)`), or placeholder instead.

**`path`**
Absolute filesystem path to the git repository. Present when `state` is `"ready"`. All planning scans read the **committed default branch** of this repo only — never the working tree.

**`policy`**
Divergence policy recorded at attach time.
- `"C"` (phase 1 default) — the repo is authoritative. A layer materialized in the repo but diverging from the blueprint resolves from the repo, tagged `divergent_from_blueprint: §<n>`. Blueprint is consulted only for layers entirely absent from the repo.
- `"B"` (phase 2, not yet enforced) — structural divergences trigger an interactive operator question at step `8.4`.

### Lifecycle

Classes start `"deferred"` (blueprint-backed) and transition to `"ready"` (repo-backed) independently. At feature start, `project_add_feature_e2e.sh` checks every deferred class: if the blueprint's `planned_repo_path` holds a scannable git repository, it prompts the operator to attach it and records `policy: "C"`.

`project_type_code` records how the project started and is not read by feature-phase steps.
