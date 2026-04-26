## Context

CRP-114 defines the minimal stack-family blueprint artifact contract: templates, rule boundaries, golden examples, and structural quality validation. CRP-115 adds the project-init orchestration that creates those blueprints for project type `A`.

Project type `A` has no repository to scan. Step `1` only captures project type and active classes, plus optional stack guidance source metadata. Step `1.1` must turn that sparse starting point into one approved high-level stack-family choice per active class. It must not force the user or model to invent repo paths, package roots, layer bindings, archetypes, baseline user-reachable surfaces, or path strategies.

The key separation is:

- CRP-114 owns the minimal final stack-family blueprint artifact shape.
- CRP-115 owns how the user and model decide the stack family, how optional guidance sources are consulted, how approval is obtained, and when Step `2` is allowed to proceed.

## Goals / Non-Goals

**Goals:**

- Add Step `1.1` for type `A` projects only.
- Record optional per-class stack guidance sources during project setup.
- Generate one approved stack-family blueprint per active class before Step `2`.
- Use configured MCP/knowledge-base guidance when available.
- Use bounded model fallback proposals when guidance is absent or unavailable.
- Require explicit user approval before final blueprint files are written.
- Keep proposal-source and approval tracking in the authoring flow, not in CRP-114 templates.
- Run the CRP-114 quality helper before Step `1.1` is complete.
- Make Step `2` depend on approved stack-family blueprints for type `A` and treat them as read-only project context.

**Non-Goals:**

- Change the CRP-114 stack-family blueprint artifact contract.
- Add Step `7` blueprint consumption.
- Create repo-scan-equivalent structural evidence.
- Require MCP availability for type `A`.
- Require blueprints for project types `B` or `C`.
- Put known constraints, baseline surfaces, path convention strategy, folder paths, package roots, layer bindings, component archetypes, or API contract schemas into stack-family blueprints.
- Add new script CLI flags.

## Decisions

### Decision 1: Add Step `1.1` instead of expanding Step `1`

Step `1` already owns project metadata bootstrap. Step `1.1` is a separate init step that consumes that metadata and produces approved high-level stack-family blueprints for type `A`.

This keeps project setup metadata capture separate from model-assisted stack-family selection and makes the Step `2` dependency explicit.

### Decision 2: Store optional guidance source metadata in project setup

Step `1` will support optional per-class metadata such as `stack_guidance_sources[backend]`, `stack_guidance_sources[frontend]`, and `stack_guidance_sources[mobile]`. The metadata is optional; absence is valid and triggers fallback proposals in Step `1.1`.

The source value is a pointer to startup-configured guidance, such as an MCP-backed source name or another documented knowledge source. CRP-115 does not make any particular MCP mandatory.

### Decision 3: Process active classes independently

The authoring command processes each active class separately. It creates exactly one final stack-family blueprint per active class for type `A`. For project types `B` and `C`, the command no-ops because repo scan remains their source of truth.

Independent class processing allows a backend blueprint to use configured guidance while a frontend blueprint falls back to the bounded menu in the same project.

### Decision 4: Extract or propose only high-level stack families

When guidance is configured and available, the authoring flow extracts high-level stack-family options from that guidance and summarizes them for user approval.

When no guidance source exists or the configured source is unavailable, the model presents a small fallback menu for user discussion and approval:

- backend: Java/Spring Boot default, Node.js alternative,
- frontend: React default, Angular alternative,
- mobile: native Android Kotlin and iOS Swift default, Flutter/Dart alternative.

The flow must not ask for or generate detailed repository structure during this step.

### Decision 5: Final blueprint write requires explicit approval

The command must not write final `project_stack_blueprint_<class>.md` artifacts until the user approves one stack-family option or provides an override. Approval/source tracking belongs to the Step `1.1` authoring flow and logs/output, not to CRP-114 template fields.

This prevents silent default stack selection while keeping the durable artifact minimal.

### Decision 6: Step `2` consumes stack-family blueprints as read-only context

For type `A`, `common_contract_definition.md` is created only after all active-class stack-family blueprints exist and pass quality validation. Step `2` may use the approved stack family as project context, but it must not treat the blueprint as API contract schemas or as Step `7` structural evidence.

Contract schema governance remains owned by `common_contract_definition.md`.

## Risks / Trade-offs

- **Risk: fallback defaults become silent choices** -> Mitigation: require explicit approval before writing final blueprint artifacts.
- **Risk: MCP unavailability blocks type `A` projects** -> Mitigation: absence or failure of guidance source falls back to bounded proposals.
- **Risk: Step `1.1` invents structural evidence** -> Mitigation: CRP-114 artifact contract forbids paths, layers, archetypes, and baseline surfaces.
- **Risk: Step `2` treats stack family as contract definition** -> Mitigation: update Step `2` conditions and rule text to use blueprints as read-only context only.
- **Risk: type `A` still cannot produce Step `7` surface maps** -> Accepted. That remains a separate future change; this CRP does not solve surface-map evidence.

## Migration Plan

No data migration is required. Existing projects of type `B` and `C` remain unaffected. Type `A` projects created after this change must complete Step `1.1` before Step `2`; any existing type `A` project in progress will need the per-class stack-family blueprints generated once using the new Step `1.1` flow.
