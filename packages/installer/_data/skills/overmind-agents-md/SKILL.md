---
name: overmind-agents-md
description: Generate or verify project_agents_md_claude_md_<class>.md for an active type A project class.
---

# Overmind Agents-MD

Use this skill only for the project agent-guidelines artifact bound by:

```bash
node .overmind/overmind.js context agents-md <project> --class <backend|frontend|mobile>
```

## Required First Step

Run the context command before reading or writing the artifact. Use the returned bindings as authoritative:

- `workspace_root`
- `project_root`
- `target_class`
- `target_agents_md`
- `gate_command`
- `agents_md_template_asset`
- `agents_md_golden_example_asset`
- `external_sources_status`
- `agents_md_status`
- every `read_only_input`
- the single path under `Allowed Write Surface`

## Allowed Write Surface

Write exactly the bound `target_agents_md` file and nothing else. Treat these inputs as read-only:

- `init_progress_definition.yaml`
- `project_stack_blueprint_<class>.md`
- `.setup/external_sources.yaml` when present
- peer `project_agents_md_claude_md_<class>.md` artifacts
- every other project artifact

## Present Artifact Rule

When `agents_md_status: present`, run the bound `gate_command` first.

- If the gate exits `0`, leave the artifact byte-unchanged and report completion.
- If the gate exits `1`, repair only the reported problems and rerun the same gate.
- If the operator asks to revise a gate-passing artifact, obtain explicit approval before writing.

## Content Rules

- Follow the class template asset for structure.
- Use the class golden example as a quality target, not as a rule.
- Derive `Stack Baseline`, `Target Project Shape`, and `Layer Responsibilities` from the read-only source blueprint.
- Include the required document meta header:
  - `artifact_kind: project_agents_md_claude_md`
  - `class: <target_class>`
  - `project: <project id or name>`
  - `source_blueprint: project_stack_blueprint_<target_class>.md`
  - `last_updated: YYYY-MM-DD`
- Include durable engineering guidance for mission, non-negotiable rules, coding standards, testing, linting/quality gates, definition of done, and decision guidance.
- Make `## Mission` rank code quality, maintainability, and testability ahead of delivery speed.
- Name both the local and CI checks in `## Linting and Quality Gates`, and state a percentage coverage floor in `## Testing Standard`.
- For frontend and mobile, include optional accessibility, internationalization, UI automation ID, and visual style sections only when the operator supplies those decisions or approves proposed bounded guidance.
- Do not include workflow state, proposal metadata, source attribution, approval history, conversation transcript, feature work, implementation slices, or API contract governance.

## Source Chain

Build the proposed guidance in this order:

1. Use the configured stack knowledge base when `external_sources_status` identifies one and it yields confident guidance. Tell the operator which source informed the proposal.
2. Use bounded fallback guidance aligned with the approved blueprint when the knowledge base is unavailable or inconclusive.
3. Ask for explicit operator approval or overrides before writing the initial artifact.

Do not silently adopt defaults.

## Gate Loop

After every write, run the exact `gate_command` from context.

- Exit `0`: report the class session complete.
- Exit `1`: read the reported problems, repair only those problems, and rerun the same gate.
- Exit `2`: stop and report that validation cannot complete.

The coordinator binds the command; you own the loop.

## Final Response

When complete, say exactly:

`Project agent guidelines class session is finished for <target_class>. Nothing else to do now; press Ctrl-C so orchestrator can continue project init`
