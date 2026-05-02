# Project Stack Blueprint Rule

## Purpose
- A project stack blueprint records the approved structural conventions for one active project class during early type A initialization.
- Blueprints are durable outcomes, not proposal transcripts or repository scan substitutes.
- For type A Step 7, the blueprint is the declarative substitute evidence used to derive a per-class surface map without scanning a repository.
- This rule also guides Step `1.1` authoring: produce one approved declarative stack blueprint per active backend/frontend/mobile class using configured guidance when available; otherwise use bounded fallback proposals.

## Artifact Content
- Include the three required sections from the template: Meta, Stack Choices, and Layer Bindings.
- Backend blueprints additionally include §5 Cross-Class Transport/Contract Approach when the backend has an in-project peer class (another backend, frontend, or mobile). Either populate concretely with `user_approved: true`, or use the literal `<to be defined during first feature implementation plan>` for both fields with `user_approved: false`. See `## §5 Cross-Class Transport/Contract Approach Derivation` below for how §5 values are derived and approved.
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
- Suggested order for querying the selected MCP source. For each active class:
    - first search for `<class> blueprint`
    - if the results are empty or not clearly relevant, search for `<class> architecture blueprint`
    - if the results are still empty or not clearly relevant, list documents with tags that include `<class>` or `architecture` and inspect the most relevant candidates for the active class
- If the file is absent, contains no `stack_knowledge_base` entry, or the MCP server is unavailable, use these fallback stack-family proposals, then ask the user to approve or override baseline class conventions:
  - backend: default `java-spring-boot`, alternative `nodejs`
  - frontend: default `react`, alternative `angular`
  - mobile: default `native-android-ios`, alternative `flutter`
- Allow the user to override a proposed stack family before final approval.
- Do not silently choose a default.

## §5 Cross-Class Transport/Contract Approach Derivation
- Determine whether §5 applies by running the runtime-bound cross-class peer trigger helper (see prompt context). It exits 0 and prints `cross_class_peer_trigger: active` when §5 applies, or `cross_class_peer_trigger: inactive` when §5 is a no-op for this project. Skip §5 entirely on `inactive`.
- When active, §5 derivation follows the same Proposal Rules and Approval And Write Rules above, with these §5-specific extras:
  - The fallback when the `stack_knowledge_base` source is absent, unavailable, or yields no confident proposal is §5-specific stack inference from the approved §2 stack choices on the same backend blueprint (for example: Spring Boot → REST + OpenAPI 3.1; gRPC service framework → gRPC + protobuf), not the §2/§3/§4 stack-family fallback menu.
  - When neither MCP nor §5-specific stack inference yields a confident proposal, or the user declines a confident proposal, write the literal `<to be defined during first feature implementation plan>` for both `transport_protocol` and `schema_format` with `user_approved: false`. Placeholder writes do not require user approval. Do not retry the declined source.
- The structural §5 contract enforced by the project stack blueprint quality helper is unchanged by this derivation.

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
- Do not place §5 in frontend or mobile blueprints; backend is the sole holder.
- Do not let §5 carry per-endpoint contract content; it carries protocol and schema format only.

## Completion Gate
- After writing each final blueprint, run:
  - `<PROJECT_STACK_BLUEPRINT_GATE_HELPER_COMMAND>`
- If the helper reports quality errors, revise the final blueprint and rerun the helper until it exits `0`.
- If a required blueprint cannot be approved or cannot pass the helper, stop and report that Step `1.1` is incomplete.
