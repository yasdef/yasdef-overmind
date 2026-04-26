# Project Stack Blueprint Rule

## Purpose
- A project stack blueprint records the approved structural conventions for one active project class during early type A initialization.
- Blueprints are durable outcomes, not proposal transcripts or repository scan substitutes.
- For type A Step 7, the blueprint is the declarative substitute evidence used to derive a per-class surface map without scanning a repository.
- This rule also guides Step `1.1` authoring: produce one approved declarative stack blueprint per active backend/frontend/mobile class using configured guidance when available; otherwise use bounded fallback proposals.

## Artifact Content
- Include the three required sections from the template: Meta, Stack Choices, and Layer Bindings.
- Use `backend`, `frontend`, or `mobile` as the class value.
- Record `last_updated` in `YYYY-MM-DD` format.
- Record planned repo identity fields in Meta, tagged as planned where no repository exists yet.
- Record stack choices at framework/runtime level, including datastore, messaging, observability, deployment, and test stack where applicable.
- Record one Layer Binding block per standard surface-map layer for the class.
- Each Layer Binding block carries `folder_paths`, `archetypes`, and `user_reachable_pattern`; backend Integration may also carry `topics_convention`.

## Authoritative Inputs
- Read `init_progress_definition.yaml` for:
  - `meta_info.project_type_code`
  - `meta_info.project_classes`
- Check `.setup/external_sources.yaml` for an entry with `type: stack_knowledge_base`; if present, its `name` is the MCP server to query for stack guidance.
- Use the class-specific template and golden example only for final artifact shape and quality target.

## Proposal Rules
- Process each active class independently.
- If `.setup/external_sources.yaml` contains a `stack_knowledge_base` source and that MCP server is available, extract stack choices, layer folder conventions, and component archetypes from it; tell the user which source informed the proposal.
- If the file is absent, contains no `stack_knowledge_base` entry, or the MCP server is unavailable, use these fallback stack-family proposals, then ask the user to approve or override baseline class conventions:
  - backend: default `java-spring-boot`, alternative `nodejs`
  - frontend: default `react`, alternative `angular`
  - mobile: default `native-android-ios`, alternative `flutter`
- Allow the user to override a proposed stack family before final approval.
- Do not silently choose a default.

## Approval And Write Rules
- Do not write `project_stack_blueprint_<class>.md` until the user explicitly approves that class's stack-family choice.
- Revisions to existing blueprints require the same explicit approval as initial creation.
- Keep proposal source, fallback use, approval state, and conversation history in command output only.
- Final blueprint files must contain only the fields defined in Artifact Content above.

## Prohibited Content
- Do not include workflow state, proposal source metadata, approval state, fallback proposal details, or conversation history.
- Do not include feature work, implementation slices, implementation-plan tasks, transport/user surface maps, or API contract schema governance.
- Shared contract definitions remain owned by `common_contract_definition.md`.
- Do not expand the blueprint into a prescriptive implementation plan.
- Planned repo identity, package roots, folder conventions, layer bindings, and component archetypes are required; do not omit them.

## Completion Gate
- After writing each final blueprint, run:
  - `<PROJECT_STACK_BLUEPRINT_GATE_HELPER_COMMAND>`
- If the helper reports quality errors, revise the final blueprint and rerun the helper until it exits `0`.
- If a required blueprint cannot be approved or cannot pass the helper, stop and report that Step `1.1` is incomplete.
