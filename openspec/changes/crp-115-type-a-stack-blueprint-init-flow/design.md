## Context

CRP-114 defines the deterministic stack blueprint artifact contract: templates, rule boundaries, golden examples, and structural quality validation. CRP-115 adds the project-init orchestration that creates those blueprints for project type `A`.

Project type `A` has no repository to scan, so the pipeline needs a project-level source of planned structural facts before Step `2` and later feature phases can proceed. The flow must happen after Step `1` records project type/classes and before Step `2` creates `common_contract_definition.md`.

The key separation is:

- CRP-114 owns the final blueprint artifact shape.
- CRP-115 owns how the user and model decide the stack, how optional guidance sources are consulted, how approval is obtained, and when Step `2` is allowed to proceed.

## Goals / Non-Goals

**Goals:**

- Add Step `1.1` for type `A` projects only.
- Record optional per-class stack guidance sources during project setup.
- Generate one approved blueprint per active class before Step `2`.
- Use configured guidance when available and bounded fallback proposals when guidance is absent.
- Require explicit user approval before final blueprint files are written.
- Keep proposal-source and approval tracking in the authoring flow, not in CRP-114 templates.
- Run the CRP-114 quality helper before Step `1.1` is complete.
- Make Step `2` depend on approved blueprints for type `A` and treat them as read-only project context.

**Non-Goals:**

- Change the CRP-114 blueprint artifact contract.
- Add Step `7` blueprint consumption.
- Require MCP availability for type `A`.
- Require blueprints for project types `B` or `C`.
- Put API contract schema definitions into stack blueprints.
- Add new script CLI flags.

## Decisions

### Decision 1: Add Step `1.1` instead of expanding Step `1`

Step `1` already owns project metadata bootstrap. Step `1.1` is a separate init step that consumes that metadata and produces project-level stack blueprints for type `A`.

This keeps project setup metadata capture separate from model-assisted stack authoring and makes the Step `2` dependency explicit.

### Decision 2: Store optional guidance source metadata in project setup

Step `1` will support optional per-class metadata such as `stack_guidance_sources[backend]`, `stack_guidance_sources[frontend]`, and `stack_guidance_sources[mobile]`. The metadata is optional; absence is valid and triggers fallback proposals in Step `1.1`.

The source value is a pointer to startup-configured guidance, such as an MCP-backed source name or another documented source. CRP-115 does not make any particular MCP mandatory.

### Decision 3: Process active classes independently

The authoring command processes each active class separately. It creates exactly one final blueprint per active class for type `A`. For project types `B` and `C`, the command no-ops because repo scan remains their source of truth.

Independent class processing allows a backend blueprint to use configured guidance while a frontend blueprint falls back to the bounded menu in the same project.

### Decision 4: Use bounded fallback proposals when guidance is absent

When no stack guidance source exists or the configured source is unavailable, the model presents a small fallback menu for user discussion and approval:

- backend: Java/Spring Boot default, Node.js alternative,
- frontend: React default, Angular alternative,
- mobile: native Android Kotlin and iOS Swift default, Flutter/Dart alternative.

The defaults are proposals only. The flow must allow the user to approve, reject, or override them before any final blueprint is written.

### Decision 5: Final blueprint write requires explicit approval

The command must not write final `project_stack_blueprint_<class>.md` artifacts until the user approves stack choices and baseline class conventions. Approval/source tracking belongs to the Step `1.1` authoring flow and logs/output, not to CRP-114 template fields.

This preserves the template responsibility rule while still preventing silent default stack selection.

### Decision 6: Step `2` consumes blueprints as read-only project context

For type `A`, `common_contract_definition.md` is created only after all active-class stack blueprints exist and pass quality validation. Step `2` may use the blueprints for planned repo/service/class context, but it must not treat them as API contract schemas.

Contract schema governance remains owned by `common_contract_definition.md`.

## Risks / Trade-offs

- **Risk: fallback defaults become silent choices** -> Mitigation: require explicit approval before writing final blueprint artifacts.
- **Risk: MCP unavailability blocks type `A` projects** -> Mitigation: absence or failure of guidance source falls back to bounded proposals.
- **Risk: Step `1.1` duplicates CRP-114 validation logic** -> Mitigation: reuse `check_project_stack_blueprint_quality.sh` from CRP-114.
- **Risk: approval/source state leaks into templates** -> Mitigation: keep workflow state in authoring flow output/logging and exclude it from CRP-114 templates and quality-helper requirements.
- **Risk: Step `2` treats blueprint stack details as contract definitions** -> Mitigation: update Step `2` conditions and rule text to use blueprints as read-only project context only.

## Migration Plan

No data migration is required. Existing projects of type `B` and `C` remain unaffected. Type `A` projects created after this change must complete Step `1.1` before Step `2`; any existing type `A` project in progress will need the per-class blueprints generated once using the new Step `1.1` flow.
