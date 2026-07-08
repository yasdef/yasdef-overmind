---
name: overmind-stack-blueprint
description: Generate a project_stack_blueprint_<class>.md artifact for an active type A project class.
---

# Overmind Stack Blueprint

Use this skill only for init step 1.1 stack-blueprint generation.

## Required Invocation

1. Run `node .overmind/overmind.js context stack-blueprint <project> --class <backend|frontend|mobile>`.
2. Read the full context output before writing.
3. Use only the target class, target artifact, read-only inputs, deterministic values, and gate command from that context.
4. Ask the operator only for stack-family approvals or overrides that cannot be derived deterministically.

## Runtime Bindings

- `project_root`, `progress_definition`, `target_class`, `target_blueprint`, `gate_command`, `cross_class_peer_trigger`, and `external_sources_status` come from the context command.
- Treat context paths as authoritative for this invocation.
- Use skill-relative assets from this skill's `assets/` directory.
- Do not hardcode source-repository `overmind/...` paths.

## Allowed Write Surface

- Write exactly one artifact: the `target_blueprint` path from context.
- Preserve `init_progress_definition.yaml`, `.setup/external_sources.yaml`, all peer blueprints, and every other project artifact.
- Do not create proposal transcripts, scratch files, helper outputs, or workflow markers.

## Assets

- Backend template: `assets/project_stack_blueprint_be_TEMPLATE.md`
- Backend golden example: `assets/project_stack_blueprint_be_GOLDEN_EXAMPLE.md`
- Frontend template: `assets/project_stack_blueprint_fe_TEMPLATE.md`
- Frontend golden example: `assets/project_stack_blueprint_fe_GOLDEN_EXAMPLE.md`
- Mobile template: `assets/project_stack_blueprint_mobile_TEMPLATE.md`
- Mobile golden example: `assets/project_stack_blueprint_mobile_GOLDEN_EXAMPLE.md`

## Purpose

- Create one approved declarative stack blueprint for one active backend, frontend, or mobile class in a type A project.
- Record stable structural conventions: planned repo identity, stack choices, layer folder conventions, component archetypes, and user-reachable patterns.
- The blueprint is durable planned evidence for later type A surface mapping. It is not a proposal transcript, repository scan substitute, implementation plan, feature plan, or API contract schema.

## Artifact Content Rules

- Use the class-specific template as the output structure contract.
- Use the class-specific golden example as the quality target.
- Preserve required headings, heading order, and key names from the template.
- Set class value to exactly `backend`, `frontend`, or `mobile`, matching `target_class`.
- Set `last_updated` in `YYYY-MM-DD` format.
- Record planned repo identity fields in Meta, tagged as planned when no repository exists yet.
- Record stack choices at framework/runtime level, including datastore, messaging, observability, deployment, and test stack where applicable.
- Record one Layer Binding block per standard surface-map layer for the target class.
- Each Layer Binding block carries `folder_paths`, `archetypes`, and `user_reachable_pattern`; backend Integration may also carry `topics_convention`.

## Proposal And Approval Rules

- Process only the target class in this skill session.
- If `external_sources_status` identifies an available stack knowledge base, use it for stack choices, layer folder conventions, and component archetypes. Tell the operator which source informed the proposal.
- Suggested knowledge-base search order: `<class> blueprint`, then `<class> architecture blueprint`, then relevant documents tagged with `<class>` or `architecture`.
- If the knowledge base is unavailable or does not yield a confident proposal, use bounded fallback proposals:
  - backend: default `java-spring-boot`, alternative `nodejs`
  - frontend: default `react`, alternative `angular`
  - mobile: default `native-android-ios`, alternative `flutter`
- Do not silently choose a default. Ask the operator to approve or override the baseline class conventions before writing.
- Do not write `project_stack_blueprint_<class>.md` until the operator explicitly approves that class's stack-family choice.
- Revisions to an existing blueprint require the same explicit approval as initial creation.
- Keep proposal source, fallback use, approval state, and conversation history in the chat only. Do not write them into the artifact.

## Cross-Class Transport/Contract Approach

- Use the context-provided `cross_class_peer_trigger` to determine whether `## 5. Cross-Class Transport/Contract Approach` applies.
- If `cross_class_peer_trigger: inactive`, omit the Cross-Class Transport/Contract Approach section entirely.
- If `cross_class_peer_trigger: active` and `target_class: backend`, include `## 5. Cross-Class Transport/Contract Approach`.
- Do not include the Cross-Class Transport/Contract Approach section in frontend or mobile blueprints.
- Prefer knowledge-base guidance for backend transport protocol and schema format when available.
- If the knowledge base is unavailable or inconclusive, infer from the approved backend stack choices where confident, for example Spring Boot to REST plus OpenAPI 3.1, or gRPC service framework to gRPC plus protobuf.
- If neither source yields a confident proposal, or the operator declines the proposal, write the literal `<to be defined during first feature implementation plan>` for both `transport_protocol` and `schema_format` with `user_approved: false`.
- Placeholder writes for this section do not require operator approval and do not block step 1.1.
- This section carries protocol and schema format only. Do not add endpoint definitions, per-feature contracts, request/response schemas, or source-of-truth governance.

## Prohibited Content

- Do not include workflow state, proposal metadata, fallback details, approval history, or conversation history.
- Do not include feature work, implementation slices, implementation-plan tasks, transport/user surface maps, or API contract schema governance.
- Do not expand the blueprint into a prescriptive implementation plan.
- Do not omit planned repo identity, package roots, folder conventions, layer bindings, or component archetypes.
- Do not redefine shared contract definitions; those belong in `common_contract_definition.md`.

## Gate Loop

1. Draft or repair only the `target_blueprint` artifact.
2. Run the exact `gate_command` from context after every write or repair.
3. If the gate exits `0`, stop and report completion.
4. If the gate exits `1`, read the gate output, repair only the reported missing or invalid content, and rerun the same gate command.
5. If the gate exits `2`, stop and report that validation cannot complete with the current runtime inputs.
6. If the blueprint cannot be approved or cannot pass the gate, stop and report that step 1.1 is incomplete.

## Final Response

If the gate passes for this class session, end with exactly:

`Project stack blueprint class session is finished for <target_class>. Nothing else to do now; press Ctrl-C so orchestrator can continue project init`
