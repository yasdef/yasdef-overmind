## Why

`overmind project create` couples project identity with repository binding: it asks for a repository path per class before the project exists, so the operator must have every repository decided at creation time. Meanwhile class membership is a creation-only decision — a project that grows a class later has no command to declare it, and a class bound to the wrong repository has no command to unbind it.

## What Changes

- **BREAKING**: `overmind project create` captures project name, project-level `project_type_code`, and the class list only. Every selected class is written as `state: "deferred"`, `path: ""`, `policy: "A"`, and creation reports that `overmind project reconcile` binds repositories. Selecting no class is valid.
- **BREAKING**: `overmind project create` no longer asks for repository paths and no longer validates them.
- Add `overmind project add-class`, an interactive argumentless command with exactly two actions: add a class that is not in the project, or change an existing class by resetting it to deferred. Both actions produce the same undeclared-repository row (`deferred`, empty path, policy `A`), and a reset clears that class's `contract_reconciled` value.
- `overmind project reconcile` remains the sole writer of class policy, repository path, and `state: "ready"`. Before asking for a repository path it SHALL ask which policy the class has: `A` (repository will be generated), `B` (existing repository, partial context), or `C` (existing repository, code-first).
- Policy `A` at the reconcile prompt keeps the class deferred without asking for a path. Policy `B` or `C` asks for a path under the existing validation and retry rules; a supplied valid path records the selected policy with `state: "ready"`.
- **BREAKING**: `attachClassRepo` stops hardcoding `policy: "C"` and records the policy the operator selected. Class-record coherence widens from `B|C` to `A|B|C`, with policy `A` valid only while the class is deferred with an empty path.

## Capabilities

### New Capabilities

- `project-class-membership`: declare a class that is not yet in a project, or reset an existing class to deferred so reconcile can rebind it.

### Modified Capabilities

- `project-creation`: creation captures identity, project type, and class membership; it does not capture or validate repository paths.
- `project-update`: reconcile captures class policy before a repository path and is no longer the only project-update verb.

## Impact

- `packages/asdlc-coordinator/src/capture/project.ts` — remove repository-path capture, allow an empty class selection, and seed each selected class as deferred with policy `A`.
- `packages/asdlc-coordinator/src/capture/project-class.ts` (new) — the add/reset membership primitive and its typed result.
- `packages/asdlc-coordinator/src/parse/project-definition.ts` — accept a policy argument in `applyClassAttachment` instead of hardcoding `C`, and add the membership mutation that inserts or resets a class row.
- `packages/asdlc-coordinator/src/repo/attach.ts` — thread the selected policy through `attachClassRepo` and widen `validateClassRecordCoherence` to `A|B|C`.
- `packages/asdlc-coordinator/src/orchestrator/run-project-reconciliation-flow.ts` — ask for the class policy before the repository path and keep policy-`A` classes deferred without a path prompt.
- `packages/asdlc-coordinator/src/cli/run.ts` — add the `project add-class` verb with existing project discovery.
- Coordinator tests, `README.md`, and `QUICKRUN.md` — cover creation without repository prompts, the policy prompt in reconcile, and both membership actions.
