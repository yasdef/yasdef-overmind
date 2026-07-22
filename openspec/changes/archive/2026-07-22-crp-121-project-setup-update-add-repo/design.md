## Context

`project_setup_add_new_project.sh` already encapsulates the canonical rules for
how a repo path is collected, validated, and persisted into
`projects/<project_id>/init_progress_definition.yaml` (see `validate_repo_path`,
`resolve_repo_path`, `prompt_repo_path_for_class`, `collect_repo_path_states`,
and `inject_project_bootstrap_into_definition`). The persisted shape per class
is:

```yaml
meta_info:
  project_id: "..."
  project_classes: [backend, frontend, ...]
  project_type_code: "A" | "B" | "C"
  project_type_label: "..."
  class_repo_paths:
    backend:
      state: "deferred"   # or "ready"
      path: ""             # set when state == "ready"
```

Project records are appended to a top-level `asdlc_metadata.yaml` (with `meta:`
and `projects:` keys) by `append_project_record`. The update flow operates
strictly on already-bootstrapped projects, so it must read the existing project
list from there and edit a single `projects/<project_id>/init_progress_definition.yaml`
file in place.

The current `project_setup_update_project.sh` is a 7-line stub. Dispatcher
option 3 (the entry point that calls this script) is unchanged.

## Goals / Non-Goals

**Goals:**

- Provide a single, idempotent interactive entry point to attach a repo to a
  `deferred` class on an existing project, with the same path validation rules
  as the new-project flow.
- Persist the change as a minimal, targeted edit of
  `projects/<project_id>/init_progress_definition.yaml` that does not disturb
  unrelated content (steps block, comments, formatting).
- After a successful attach, when the project is type `A` and every class is
  now `ready`, give the operator a single chance to reclassify the project to
  `B` or `C`, with a finish-without-changing option that is the safe default.

**Non-Goals:**

- Removing repos, editing an existing `ready` repo path in place, batch-attach
  across multiple classes, attaching repos to classes that are not present in
  `meta_info.project_classes`.
- Any change to the dispatcher menu, to `project_setup_add_new_project.sh`
  observable behavior, or to the `init_progress_definition.yaml` schema.
- Triggering downstream re-runs of stack-blueprint, contract, or surface-map
  steps when `project_type_code` flips. The re-run policy stays a separate
  concern owned by other scripts.
- Locking or concurrency control for the YAML file.

## Decisions

### D1. Extract only the helpers shared between the two related scripts into `overmind/scripts/common_libs/`

Create a new shared library file
`overmind/scripts/common_libs/project_setup_common.sh` containing exactly the
helpers needed by both `project_setup_add_new_project.sh` and the rewritten
`project_setup_update_project.sh`:

- `validate_repo_path`
- `resolve_repo_path`
- `project_type_label_for_code`
- `escape_yaml_double_quoted_value`

Both scripts then `source` this file. Bodies are the existing implementations
copied verbatim — no behavior changes, no signature changes, no renaming.

**Why over alternatives:**

- *Inline-copying the helpers into the update script*: rejected because it
  would duplicate ~30 LOC of validation and escaping logic that is genuinely
  shared between the two scripts.
- *Sourcing the add-new script directly*: rejected because the add-new script
  has top-level execution flow (calls `main` at the bottom).
- *A broader `_project_setup_lib.sh` covering more helpers*: explicitly out of
  scope. Only helpers actually used by the update flow move; nothing else in
  the add-new script is touched. The dedicated `common_libs/` folder
  separates "code shared between user-facing scripts" from rule files that
  guide the model.

The add-new script keeps its current behavior; the only change there is
deleting the four extracted function bodies and adding a `source` line near
the top.

### D2. Project selection input source

List projects from `meta_info.project_id` entries discovered by scanning
`projects/*/init_progress_definition.yaml` rather than from
`asdlc_metadata.yaml`. Reason: the per-project YAML is the source of truth this
script edits, so listing what we can actually act on avoids drift if the two
files disagree. Present a numbered prompt with the project id and
`project_type_code`; `q` quits with exit 0 and no mutation.

### D3. Class selection only offers `deferred` classes

After picking a project, parse its `class_repo_paths` and list only entries
whose `state` is `deferred`. Classes already `ready` are not listed. If no
class is `deferred`, print a clear "nothing to add" message and exit 0 without
prompting further. Quit (`q`) still works.

**Why:** the requirement is "add repo" not "edit repo." Reattaching to an
already-`ready` class would require a confirmation flow and a path-overwrite
contract that the proposal does not cover. Keeping the surface narrow.

### D4. Path entry uses the same loop as the new-project flow

Reuse the same prompt-validate-resolve loop as `prompt_repo_path_for_class`,
with one addition: an explicit quit token (`q`) at the input prompt exits with
exit 0 and no mutation. Empty input is rejected (existing behavior). On
validation failure, re-prompt (existing behavior). The quit token must be
checked *before* `validate_repo_path` so that `q` is never treated as a path.

### D5. YAML write strategy: targeted in-place edit, not full regenerate

Use a small `awk` block keyed on the indentation pattern emitted by
`inject_project_bootstrap_into_definition` (4-space indent for class name,
6-space indent for `state:`/`path:`). The edit:

1. Locates `class_repo_paths:`.
2. Within its block, locates the chosen class line (`    <class>:`).
3. Updates `state: "deferred"` → `state: "ready"` and `path: ""` →
   `path: "<resolved>"` (with `escape_yaml_double_quoted_value`).
4. Writes via temp-file + `mv`, mirroring how the add-new script writes.

For the type-A reclassification, the same approach updates the two scalar
lines `project_type_code:` and `project_type_label:` at indent 2. No YAML
parser dependency; matches what `assert_metadata_shape` already assumes about
the file format.

**Why over alternatives:** introducing `yq` was rejected because the project
ships pure shell only (per CLAUDE.md "use plain shell implementations only").
Regenerating the file would require parsing and re-emitting the full `steps:`
block — high blast radius for a one-field change.

### D6. Type-A reclassification trigger and shape

Triggered only when, **after** the successful attach, every entry in
`class_repo_paths` has `state: "ready"` AND `project_type_code` is `A`.
Compute "all ready" by reading the file we just wrote, not the in-memory state
before the write — this avoids drift if the file has diverged.

Prompt shape:

```
All class repos are now ready. Project type is currently A (New project).
Reclassify?
1. B - Existing project with partial context
2. C - Existing project with code-first context
3. Keep type A and finish
```

Selecting `1` or `2` writes both `project_type_code` and `project_type_label`
(reuse `project_type_label_for_code`). Selecting `3` (also the default on
empty input) leaves the file untouched and exits 0. Invalid input re-prompts.

### D7. Quit semantics

`q` (case-insensitive) at the project prompt, class prompt, or path prompt
exits with code 0 and no file mutation. The reclassification prompt's
"keep / finish" is option 3 because at that point we have already written a
successful attach and the script must exit successfully. Quit at that prompt
is therefore semantically the same as option 3.

## Risks / Trade-offs

- **YAML format brittleness** → the targeted `awk` edit assumes the exact
  indentation produced by the add-new script. **Mitigation:** add a guard
  early in the update flow that asserts the expected `class_repo_paths:` block
  and `state: "deferred"` line exist for the chosen class; abort with a clear
  error if not, so a manually-edited file fails loudly instead of being
  silently mis-edited.
- **Stale project type after reclassification** → flipping `A`→`B`/`C` does
  not retroactively delete `project_stack_blueprint_<class>.md` or rerun
  contract/surface steps. **Mitigation:** call this out in the success
  message ("Project type changed to B. Existing type-A artifacts under
  /product remain in place; rerun init steps as needed.") and document in the
  spec scenarios so downstream scripts/tests don't assume a clean reset.
- **Race with another update** → no locking. **Mitigation:** out of scope;
  matches the add-new flow's posture. Document in spec.
- **`q` collisions** → an operator with a directory literally named `q`
  cannot attach it via this flow (would have to use `./q` instead).
  **Mitigation:** treat as acceptable — the quit token is documented and the
  workaround is trivial.

## Migration Plan

Not applicable. No schema change; no existing data migration. Rollback is
`git revert` of the change. The new shared library
`_project_setup_lib.sh` is purely additive; if it fails to source, both the
new and the existing add-new scripts fail at startup with a clear error
rather than running on partial helpers.

## Open Questions

- Should the success message proactively suggest re-running specific init
  scripts after a type-A→B/C flip? Deferred to the spec phase; the design
  treats it as informational text only.
- Should the script support being invoked non-interactively (env-var driven)
  for tests? Current decision: no. Tests will drive the existing prompts via
  `printf` heredocs as the existing test suites do.
