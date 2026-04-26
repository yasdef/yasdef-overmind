## Context

Project type `A` has no repository to scan, so later planning phases lack the structural facts that Step `7` normally derives from code: repo/service identity, layer paths, component archetypes, transport surfaces, and baseline user-reachable tokens. CRP-114 defines only the deterministic artifact contract for those facts. It does not create the project-init flow that asks the user to choose a stack or consumes the blueprint in Step `7`; those are separate follow-on changes.

Current Overmind artifacts already separate structure templates, operational rules, golden examples, and shell quality helpers. The stack blueprint contract should follow that pattern: templates define shape only, the rule defines allowed content and boundaries, golden examples demonstrate quality targets, and the helper performs structural validation only.

## Goals / Non-Goals

**Goals:**

- Define backend, frontend, and mobile stack blueprint templates.
- Keep blueprint content stable across features and scoped to project-level structural conventions.
- Keep blueprint content concise and update it when stable stack conventions change.
- Validate required metadata, stack categories, class-specific layers, and parseable baseline user-reachable tokens.
- Provide golden examples for valid backend, frontend, and mobile blueprints.
- Keep the quality helper deterministic and independent of model judgment.

**Non-Goals:**

- Add Step `1.1` or any project-init orchestration.
- Add MCP lookup, fallback stack proposal, or user-approval conversation handling.
- Record proposal-source or approval-state workflow metadata in the blueprint template contract.
- Teach Step `7` to consume blueprints as substitute surface-map evidence.
- Encode feature-specific surfaces, implementation slices, implementation plans, or API contract schemas in the blueprint.
- Require blueprints for project types `B` or `C`.

## Decisions

### Decision 1: Use one project-level artifact per active class

The contract defines `project_stack_blueprint_backend.md`, `project_stack_blueprint_frontend.md`, and `project_stack_blueprint_mobile.md` rather than one combined document.

This keeps each blueprint aligned with the existing per-class surface-map taxonomy and avoids requiring backend-specific fields in frontend/mobile documents. It also makes later Step `7` consumption simpler because each surface-map run can bind exactly one class blueprint.

### Decision 2: Templates carry structure only

Each template has exactly four normative sections: meta, stack choices, layer bindings, and baseline user-reachable inventory. Templates should contain headings, field names, and placeholders/comments only; they must not contain project-specific values, default stack recommendations, workflow state, or behavioral rules.

Concrete values belong in final project artifacts or golden examples. Behavioral constraints belong in `project_stack_blueprint_rule.md`, not in the templates. The blueprint rule must reject content that drifts into feature work, contract schema governance, slice planning, or plan sequencing.

### Decision 3: Templates contain artifact data only

The blueprint meta section includes durable artifact data only: class, repo/service identity, planned repo path, package/root metadata, and update date. It does not include workflow state such as proposal source or approval status.

CRP-115 owns the authoring flow that proposes stack choices, records user approval, and decides how to track approval/source evidence outside the template contract. CRP-114 only defines the final structural artifact shape.

### Decision 4: Layer bindings follow existing surface-map layer taxonomies

Backend layer blocks match the backend surface-map template. Frontend and mobile layer blocks match the frontend/mobile surface-map template, with mobile-specific native/device and local/offline blocks allowed only for mobile.

This avoids inventing a parallel architecture taxonomy and preserves compatibility with downstream surface-map generation.

### Decision 5: Baseline user-reachable inventory is token-based

The baseline inventory accepts concrete operator-invocable tokens or literal `none`. Valid examples include route paths, `METHOD /path` HTTP endpoints, CLI command names, scheduled job identifiers, mobile screen names, or deep links. Prose descriptions are invalid.

This keeps the blueprint compatible with downstream prerequisite-gap and surface-map tooling, which depends on machine-parseable `user_reachable_surface` values.

### Decision 6: The quality helper validates structure, not architectural taste

`check_project_stack_blueprint_quality.sh` should verify required fields, non-empty stack categories, expected layer sections, required per-layer keys, and token shape. It should not judge whether Java is better than Node.js, React is better than Angular, or one folder convention is better than another.

That keeps the helper deterministic and prevents the contract from silently becoming a stack-governance policy.

## Risks / Trade-offs

- **Risk: blueprint grows into an implementation plan** -> Mitigation: the rule explicitly forbids feature work, slice sequencing, and plan-level tasks.
- **Risk: helper over-validates technology choices** -> Mitigation: validate presence and structure only; do not encode preferred stacks in CRP-114.
- **Risk: baseline user-reachable inventory admits prose** -> Mitigation: require token-shaped entries or literal `none`; add tests for invalid prose.
- **Risk: mobile and frontend templates diverge unnecessarily** -> Mitigation: keep shared frontend/mobile taxonomy where appropriate and allow mobile-only blocks only for mobile artifacts.
- **Risk: workflow state leaks into the template contract** -> Mitigation: CRP-114 keeps proposal source and approval tracking out of templates, specs, and quality-helper requirements; CRP-115 owns authoring workflow state.
- **Risk: stack blueprint drifts after project setup** -> Mitigation: the blueprint rule states that stable stack convention changes require a blueprint update and `last_updated` revision.

## Migration Plan

No runtime migration is required. This change adds new templates, a new rule, golden examples, a new quality helper, and tests. Existing project types `B` and `C` are unaffected because this contract does not require stack blueprints for repo-backed projects.
