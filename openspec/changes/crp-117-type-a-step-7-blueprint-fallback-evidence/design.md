## Context

Project type `A` starts without a scannable repository, but CRP-114 and CRP-115 now provide one approved `project_stack_blueprint_<class>.md` per active backend, frontend, or mobile class. Step `7` still exits before model invocation for type `A`, so feature planning cannot produce `project_surface_struct_resp_map_<class>.md` for new projects even when blueprint evidence exists.

Step `7` must become the only consumer that converts type `A` blueprint conventions into feature-scoped surface maps. Repo evidence remains stronger than blueprint evidence for each row or field whenever a class repo path is ready and scannable, including later type `A` projects that materialize a partial repository.

## Goals / Non-Goals

**Goals:**

- Allow Step `7` to run for project type `A` when the active target class has an approved stack blueprint.
- Prefer real repository evidence over blueprint evidence for each row or field whenever repo scan resolves it.
- Use blueprint layer bindings as planned structural evidence when repo scan does not resolve a type `A` row or field.
- Require each generated surface-map row to resolve evidence in this order: repo evidence, blueprint evidence, then literal `<to be defined during implementation>`.
- Preserve existing type `B` and `C` repo-backed behavior.
- Keep downstream Steps `8`, `8.1`, `8.2`, and `8.3` consuming surface maps only.

**Non-Goals:**

- Change the CRP-114 stack blueprint artifact contract.
- Change the Step `1.1` approval flow.
- Make blueprints API contract schemas or common contract definitions.
- Make type `B` or `C` consume stack blueprints.
- Add new script CLI flags.
- Implement type `A` support in Steps `8`, `8.1`, `8.2`, or `8.3` beyond their existing surface-map inputs.

## Decisions

### Decision 1: Replace the type A hard stop with a target selection path

`feature_repo_surface_and_exec_context.sh` should stop calling the current type `A` failure path before target selection. Instead, it should build candidate target classes from active backend/frontend/mobile classes.

For each type `A` target class, the script checks whether a ready repo path is present and scannable. If yes, that path is selected as repo evidence, and the matching `projects/<project-id>/project_stack_blueprint_<class>.md` may also be bound as planned fallback evidence for rows or fields that repo scan does not resolve. If no ready repo path exists, the script requires the matching blueprint before model invocation.

Alternative considered: keep type `A` blocked until MCP extraction is added. That keeps the pipeline blocked even though the project now has approved structural blueprint evidence.

### Decision 2: Treat blueprint evidence as planned structural evidence only

For type `A`, the prompt should bind the approved stack blueprint as read-only planned structural evidence when it is needed as the primary evidence source or as fallback for unresolved rows in a partial repo. The prompt should not call it repository scan evidence and should not authorize direct blueprint reads in later steps.

Alternative considered: copy blueprint content directly into the generated surface map without model interpretation. That would bypass feature-scoped filtering from `requirements_ears.md` and `feature_contract_delta.md`.

### Decision 3: Preserve repo-first precedence

If a type `A` class has a ready repo path that resolves to a directory, Step `7` should use the same repository scan evidence path used by type `B` and `C`. The blueprint remains available only as fallback for rows or fields not resolved by repo evidence.

Alternative considered: always prefer blueprints for type `A`. That would ignore stronger real code evidence after the repository is created.

### Decision 4: Make row-level fallback explicit in rules and prompt

The rule and prompt should require model output to explain whether each relevant section `3` layer block and section `4` touched surface block is grounded in repo evidence, blueprint evidence, or the placeholder. When neither repo nor blueprint evidence can identify a concrete path/component/token for a row, the model must use the literal `<to be defined during implementation>` instead of inventing a name.

Alternative considered: use `none` for unknown planned rows. `none` already means no applicable value; it should not mean "unknown but expected during implementation."

### Decision 5: Keep downstream boundary at generated surface maps

Steps `8`, `8.1`, `8.2`, and `8.3` continue to consume `project_surface_struct_resp_map_<class>.md` as their execution-context input. They should not be changed to read `project_stack_blueprint_<class>.md` directly.

## Risks / Trade-offs

- **Risk: planned blueprint paths are mistaken for existing code** -> Mitigation: rule and prompt text must label blueprint citations as planned structural evidence for type `A`.
- **Risk: model invents concrete class names where neither repo nor blueprint says them** -> Mitigation: require literal `<to be defined during implementation>` for unresolved row fields.
- **Risk: type B/C behavior regresses** -> Mitigation: branch type `A` logic explicitly and keep existing ready-repo collection and prompt shape for type `B` and `C`.
- **Risk: type A mixed evidence becomes confusing** -> Mitigation: bind one target class per invocation and state that repo evidence wins per row or field, with blueprint used only as planned fallback for unresolved rows or fields.
- **Risk: init progress wording overstates repository scan** -> Mitigation: update Step `7` completion conditions to describe repo evidence, blueprint evidence, and placeholder fallback precisely.

## Migration Plan

No persisted data migration is required. Existing type `A` projects must already have Step `1.1` blueprints from CRP-115 before Step `7` can use blueprint fallback. Existing type `B` and `C` projects continue through the current repo-backed path.
