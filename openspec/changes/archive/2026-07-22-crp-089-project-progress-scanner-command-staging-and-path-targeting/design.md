## Context

`init_progress_scanner.sh` currently lives at `overmind/scripts/init_progress_scanner.sh` and is coupled to repository-global assumptions:
- definition path fixed to `overmind/init_progress_definition.yaml`
- output path fixed to `overmind/step_state.md`
- branch enforcement and commit flow tied to the source repository

ASDLC bootstrap already stages project-management commands into `/asdlc/.commands`, but it does not stage a scanner command. The requested change introduces project-local scanner usage from `/asdlc/projects/<project-id>` using that project folder’s `init_progress_definition.yaml`.

## Goals / Non-Goals

**Goals:**
- Make `overmind/scripts/project_mgmt/init_progress_scanner.sh` the canonical scanner script location.
- Stage scanner command into `/asdlc/.commands/` during first-machine ASDLC bootstrap.
- Support scanner invocation with project path argument under `/asdlc/projects/`.
- Evaluate progress from selected project’s `init_progress_definition.yaml` and return that project’s current state.
- Keep implementation shell-only and consistent with existing script style.

**Non-Goals:**
- Redesign checklist semantics, step schema, or requirement-condition grammar.
- Add non-interactive batch scanning over multiple project directories in one invocation.
- Introduce new runtime dependencies beyond existing shell tooling.

## Decisions

1. Move scanner source to `overmind/scripts/project_mgmt/init_progress_scanner.sh`.
Rationale: aligns ownership with other ASDLC command-management scripts and staging lifecycle.
Alternative considered: keep scanner under `overmind/scripts/` and only copy it during bootstrap. Rejected because ownership and staging logic diverge.

2. Use explicit project-path argument for staged scanner invocation.
Rationale: directly satisfies `/asdlc/projects/<project-id>` targeting and avoids hidden state selection.
Alternative considered: infer project from current working directory. Rejected because behavior becomes ambiguous and error-prone.

3. Scope scanner definition resolution to `<project-path>/init_progress_definition.yaml`.
Rationale: ensures per-project progress state is computed from the selected project definition rather than repository-global metadata.
Alternative considered: keep global definition and merge project overlays. Rejected as unnecessary complexity for this change.

4. Preserve existing checklist parsing/evaluation logic where possible.
Rationale: minimizes regression risk and keeps change focused on location/staging/path-scoping concerns.
Alternative considered: full scanner refactor. Rejected due high risk and no direct user value for this request.

## Risks / Trade-offs

- [Risk] Scanner path change requires immediate caller updates. → Mitigation: update docs/tests in the same change and enforce the new canonical invocation path.
- [Risk] Project path validation may reject legitimate inputs if normalization is too strict. → Mitigation: accept canonicalized absolute paths as long as they remain under `/asdlc/projects/`.
- [Risk] Existing tests are repo-root oriented and may miss project-scoped regressions. → Mitigation: extend scanner tests for per-project path selection and staging flow in `project_setup_asdlc_tests.sh`.

## Migration Plan

1. Relocate scanner implementation to `overmind/scripts/project_mgmt/init_progress_scanner.sh` and update internal constants/argument parsing for project-path mode.
2. Update `project_setup_first_init_machine.sh` to stage scanner into `/asdlc/.commands/` with executable permissions.
3. Update scanner tests to reference new canonical path and add project-path-based assertions.
4. Update ASDLC bootstrap tests to validate scanner command staging and runnable invocation contract.
5. Update `overmind/README.md` command examples for scanner usage with `/asdlc/projects/<project-id>` input.

Rollback strategy: restore scanner at previous path and remove staged scanner command from bootstrap flow.

## Open Questions

- Should project-scoped scans persist state to a project-local `step_state.md` file or remain stdout-only in staged usage?
