## Context

Project type `A` has no repository to scan. The initial project setup moment is intentionally shallow: the user chooses project type and active classes, and may optionally provide stack guidance. The user should not be forced to answer concrete architecture questions that are unknowable at this point.

The previous blueprint concept tried to capture repo-scan-equivalent structural evidence too early: planned repo paths, package roots, folder paths, archetypes, layer bindings, and baseline user-reachable tokens. That creates false precision unless the model invents details.

CRP-114 now defines only the early artifact that is appropriate for this stage: one approved high-level stack family choice per active class. CRP-115 owns how that choice is proposed from MCP/knowledge-base guidance or fallback model proposals and how user approval is collected.

## Goals / Non-Goals

**Goals:**

- Define backend, frontend, and mobile stack-family blueprint templates.
- Keep blueprint content limited to class identity, update date, and approved high-level stack-family choice.
- Validate only structural completeness for that minimal contract.
- Provide golden examples for valid backend, frontend, and mobile stack-family choices.
- Keep the quality helper deterministic and independent of model judgment.

**Non-Goals:**

- Add Step `1.1` or any project-init orchestration.
- Add MCP lookup, fallback stack proposal, or user-approval conversation handling.
- Require known constraints, baseline surfaces, path convention strategy, folder paths, package roots, layer bindings, or component archetypes.
- Teach Step `7` to consume this artifact as substitute surface-map evidence.
- Encode feature-specific surfaces, implementation slices, implementation plans, or API contract schemas in the blueprint.
- Require blueprints for project types `B` or `C`.

## Decisions

### Decision 1: Keep one artifact per active class

The contract keeps the names `project_stack_blueprint_backend.md`, `project_stack_blueprint_frontend.md`, and `project_stack_blueprint_mobile.md`.

The artifact is class-scoped because each active class may receive guidance from a different source or require a different fallback proposal.

### Decision 2: Record stack family, not structural evidence

The final artifact records an approved high-level stack family only. Examples:

- backend: `java-spring-boot`, `nodejs`
- frontend: `react`, `angular`
- mobile: `native-android-ios`, `flutter`

The artifact must not require or include concrete folder paths, package roots, component archetypes, user-reachable routes, screens, jobs, or API endpoint inventory.

### Decision 3: Approval/source handling belongs to CRP-115

CRP-114 templates do not include MCP/source metadata, proposal alternatives, approval state, or conversation history. CRP-115 owns the authoring flow that gets a proposal from configured guidance or fallback model defaults and asks the user to approve one option or override it.

The final artifact is the durable outcome, not the workflow transcript.

### Decision 4: The quality helper validates honesty, not architecture

`check_project_stack_blueprint_quality.sh` should verify required sections, class value, date shape, and populated stack-family choice. It should not judge stack quality, require a specific default, or infer missing details.

### Decision 5: This artifact is not enough for Step `7`

The stack-family blueprint may inform later planning context, but it is not repo-scan-equivalent evidence. Step `7` still needs a separate future mechanism before type `A` can produce surface maps without inventing folder paths or user-reachable surfaces.

## Risks / Trade-offs

- **Risk: artifact becomes too vague to help Step `7`** -> Accepted. This early artifact should not solve Step `7`; it prevents false precision at project birth.
- **Risk: helper over-validates technology choices** -> Mitigation: validate presence and class shape only.
- **Risk: defaults become silent choices** -> Mitigation: CRP-115 requires explicit user approval before writing final artifacts.
- **Risk: workflow state leaks into templates** -> Mitigation: keep source and approval tracking in the authoring flow, not in CRP-114 templates.

## Migration Plan

No runtime migration is required. This change adds minimal templates, a rule, golden examples, a quality helper, and tests. Existing project types `B` and `C` are unaffected because this contract does not require stack-family blueprints for repo-backed projects.
