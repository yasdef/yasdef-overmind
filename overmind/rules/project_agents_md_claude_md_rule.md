# project_agents_md_claude_md Rule

## Purpose

`project_agents_md_claude_md_<class>.md` is the per-class handoff document used by a downstream coding agent to author the repository `AGENTS.md` and `CLAUDE.md`.

## Required Document Meta

The artifact must start with `## 1. Document Meta` and include:

- `artifact_kind: project_agents_md_claude_md`
- `class: backend|frontend|mobile`
- `project: <project id or name>`
- `source_blueprint: project_stack_blueprint_<class>.md`
- `last_updated: YYYY-MM-DD`

## Required Sections

Every artifact must include these top-level sections:

- `## 1. Document Meta`
- `## Stack Baseline`
- `## Target Project Shape`
- `## Layer Responsibilities`
- `## Mission`
- `## Non-Negotiable Engineering Rules`
- `## Coding Standards`
- `## Testing Standard`
- `## Linting and Quality Gates`
- `## Definition of Done`
- `## Decision Guidance for Agents`

## Blueprint-Derived Sections

- `## Stack Baseline` derives from `project_stack_blueprint_<class>.md ## 2. Stack Choices`.
- `## Target Project Shape` derives from `project_stack_blueprint_<class>.md ## 3. Layer Bindings` `folder_paths` values.
- `## Layer Responsibilities` includes one block per blueprint layer and restates that layer's `archetypes` and `user_reachable_pattern`.
- Blueprint-derived sections must not contradict the source blueprint.

## Engineering Guidance

- `## Mission` must rank code quality, maintainability, and testability ahead of delivery speed.
- `## Testing Standard` must state a recommended coverage floor.
- `## Linting and Quality Gates` must name local and CI checks.
- Guidance must be durable per-class engineering guidance.

## Frontend And Mobile Optional Sections

Frontend and mobile artifacts may include:

- `## Accessibility (a11y)`
- `## Internationalization (i18n)`
- `## UI Automation IDs`
- `## Applied Visual Style Contract`

These sections are operator-authored project decisions. Backend artifacts must not include these sections.

## Prohibited Content

Do not include workflow state, proposal metadata, knowledge-base source attribution, approval history, conversation transcript, feature-specific work, implementation slices, or API contract schema governance.
