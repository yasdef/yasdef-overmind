## Context

Project type `A` has no repository to scan. Gap 5 requires one declarative per-class blueprint that records stable, user-approved conventions before Step 7 can later produce surface-map evidence without inventing repository facts.

CRP-114 defines the artifact contract only. CRP-115 owns how the blueprint is proposed from MCP/knowledge-base guidance or fallback model proposals and how user approval is collected.

## Goals / Non-Goals

**Goals:**

- Define backend, frontend, and mobile project stack blueprint templates.
- Capture Meta, Stack Choices, and Layer Bindings.
- Validate only structural completeness for that Gap 5 contract.
- Provide golden examples for valid backend, frontend, and mobile blueprints.
- Keep the quality helper deterministic and independent of model judgment.

**Non-Goals:**

- Add Step `1.1` or any project-init orchestration.
- Add MCP lookup, fallback stack proposal, or user-approval conversation handling.
- Teach Step `7` to consume this artifact as substitute surface-map evidence.
- Encode feature-specific surfaces, implementation slices, implementation plans, or API contract schemas in the blueprint.
- Require blueprints for project types `B` or `C`.

## Decisions

### Decision 1: Keep one artifact per active class

The contract keeps the names `project_stack_blueprint_backend.md`, `project_stack_blueprint_frontend.md`, and `project_stack_blueprint_mobile.md`.

The artifact is class-scoped because each active class may receive guidance from a different source or require a different fallback proposal.

### Decision 2: Record stable blueprint structure, not feature work

The final artifact records approved stack choices, planned repo identity, package roots, class-specific layer bindings, and component archetypes. It must not include feature-specific surfaces, implementation slices, implementation plans, or API contract schemas.

### Decision 3: Approval/source handling belongs to CRP-115

CRP-114 templates do not include MCP/source metadata, proposal alternatives, approval state, or conversation history. CRP-115 owns the authoring flow that gets a proposal from configured guidance or fallback model defaults and asks the user to approve one option or override it.

The final artifact is the durable outcome, not the workflow transcript.

### Decision 4: The quality helper validates honesty, not architecture

`check_project_stack_blueprint_quality.sh` should verify required sections, class value, date shape, stack choice fields, layer binding fields, and baseline token shape. It should not judge stack quality, require a specific default, or infer missing details.

### Decision 5: Step `7` consumption is separate

The blueprint supplies Gap 5 substitute evidence, but Step `7` wiring remains a separate Gap 6 change.

## Risks / Trade-offs

- **Risk: artifact becomes too prescriptive** -> Mitigation: keep it to stable project-level conventions and keep feature work in feature artifacts.
- **Risk: helper over-validates technology choices** -> Mitigation: validate presence and class shape only.
- **Risk: defaults become silent choices** -> Mitigation: CRP-115 requires explicit user approval before writing final artifacts.
- **Risk: workflow state leaks into templates** -> Mitigation: keep source and approval tracking in the authoring flow, not in CRP-114 templates.

## Migration Plan

No runtime migration is required. This change adds Gap 5 templates, a rule, golden examples, a quality helper, and tests. Existing project types `B` and `C` are unaffected because this contract does not require stack blueprints for repo-backed projects.
