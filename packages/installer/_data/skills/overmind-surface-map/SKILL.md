---
name: overmind-surface-map
description: Use when defining a per-class project_surface_struct_resp_map_<class>.md from EARS requirements, feature contract delta, and the class repository or stack blueprint.
---

# Overmind Surface Map

Use this skill for step 7 to define the repository surface and execution-context map for one project class (`backend`, `frontend`, or `mobile`). The orchestrator selects the class and passes it as `--class <class>`; this skill is single-class and never prompts for the class.

## Required Invocation

Run these commands from the installed ASDLC workspace root. `<class>` is the class the orchestrator selected (`backend`, `frontend`, or `mobile`).

1. Assemble deterministic context for the class:

```bash
node .overmind/overmind.js context surface-map <feature-path> --class <class>
```

2. Read the emitted context block: the per-class binding (track label, template/golden assets, target artifact), the scan scope (a ready repository path, or a policy A blueprint fallback when no repo is ready), the read-only inputs, and the exact gate command. Write only the bound target `<feature-path>/project_surface_struct_resp_map_<class>.md`.

3. Validate after every write or repair:

```bash
node .overmind/overmind.js gate surface-map <feature-path> --class <class>
```

Handle gate exit codes exactly:

- `0`: gate passed; finish.
- `1`: recoverable artifact issue; read every `missing: quality gate failed: ...` line, repair only the bound surface map file, and rerun the gate.
- `2`: validation cannot complete; stop, report the blocker, and wait for operator instructions without further edits.

The model owns the context/write/gate/repair loop. Ask the operator only for missing human decisions; do not ask for the class, paths, repo state, or validation details supplied by context and gate.

If gate compliance is not feasible with the current repository/blueprint evidence, briefly explain the blocker and end with this exact line (with `<track>` set to the context `track_label`):

```text
repo surface and execution context <track> gate cannot pass with current repository evidence. Please provide instructions what to do, or adjust requirements and rerun this phase
```

When the gate passes, end the final response with this exact last line (with `<track>` set to the context `track_label`):

```text
Repo surface and execution context <track> phase is finished. Nothing else to do now; press Ctrl-C so orchestrator can start the next phase
```

## Assets

Asset paths are relative to this loaded skill directory. Use the asset the context block names for the bound class; do not hardcode `.codex/skills/...`, `.claude/skills/...`, or source-repository paths.

- `assets/project_surface_struct_resp_map_be_TEMPLATE.md`, `assets/project_surface_struct_resp_map_be_GOLDEN_EXAMPLE.md` (backend)
- `assets/project_surface_struct_resp_map_fe_TEMPLATE.md`, `assets/project_surface_struct_resp_map_fe_GOLDEN_EXAMPLE.md` (frontend and mobile)

## Inlined Repo Surface And Execution Context Rule

### Purpose

- Convert feature requirements plus feature contract delta into a repository surface map for the bound track.
- Describe two things only: key parts of the target repository and their general responsibilities, and repository surfaces touched by the current feature for the target track.
- Produce deterministic output for the bound `project_surface_struct_resp_map_<class>.md`.

### Track Binding

- The context block bindings are authoritative for: target track name (`track_label`), applicable project classes, repository paths to scan (scan scope), target template and golden example, the `project_classes` value to write in artifact meta, and the gate command + completion wording.
- Do not infer another track; the context already binds one via `--class`.

### Ownership Boundaries

- Owns: repository-level structure summary for the bound track, and feature-scoped surface mapping for the bound track.
- Must not own: another track's execution context, business requirements decomposition, contract governance redesign, or broad risk analysis outside repository structure and touched surfaces.

### Authoritative Inputs And Outputs

- Read project type and class applicability from the context block.
- Read these read-only input artifacts (named in the context `read_only_input` manifest): `init_progress_definition.yaml`, `requirements_ears.md`, `feature_contract_delta.md`, plus, when present, the class `project_stack_blueprint_<class>.md` and any committed sibling `implementation_plan.md`.
- Use only repository paths listed as scan scope. Update only the bound `project_surface_struct_resp_map_<class>.md`. Never modify any read-only input.

### Evidence Resolution Chain

- Resolve each row in `Key Parts of Repo and Their Responsibilities` and each row in the class surfaces section per the permanent chain: repo scan → in-flight feature promises → blueprint (`(planned)` tag) → literal `<to be defined during implementation>`.
- The chain runs only for surfaces this feature's requirements touch; "absent" means this feature's need is not satisfied, never an inventory claim about the repo.
- Repo scan evidence is available only when the context binds a ready repository path for the class; repo scan rows cite the concrete repository path.
- In-flight feature promise evidence is available only when committed sibling plans are bound. Rows resolved from a sibling plan must carry the tag `(in-flight <feature-folder>)` and evidence must cite `<feature-folder>/implementation_plan.md step <step-id>`.
- Blueprint evidence is available when `class_repo_paths.<class>` has `state: deferred` with `policy: A` and an approved `project_stack_blueprint_<class>.md` exists; blueprint-derived values are planned structural evidence only, tagged `(planned)`, never presented as repository-proven code evidence, and citations append the blueprint `Meta` block `last_updated` exactly: `project_stack_blueprint_<class>.md §<n> (last_updated: <YYYY-MM-DD>)`. An existing blueprint remains fallback evidence for unmaterialized layers after its class repository becomes ready.
- For policy `C`, when a materialized repo layer diverges from `project_stack_blueprint_<class>.md ## 3. Layer Bindings`, resolve from repo evidence and add at most one optional passive bullet in that layer block, exactly `- divergent_from_blueprint: §<n>`. This field is optional, never required, never prompts, never blocks.
- One source per row; do not mix repo, promise, blueprint, and placeholder sources in the same row. Every non-repo source must be tagged.
- For `user_reachable_surface`, use an explicit union of applicable concrete tokens from `feature_contract_delta.md` plus concrete tokens from the row's selected tier; use `none` only when no applicable entry exists, never `<to be defined during implementation>` for this field.
- For every applicable surface row, `evidence` must combine the selected chain-tier citation with `feature_contract_delta.md <item id>`. Prose-only evidence is invalid.

### Output Format Baseline

- Use the bound template as the structure contract and the bound golden example as the style contract. Preserve heading order and key names from the template.
- Keep `Key Parts of Repo and Their Responsibilities` general to repository/codebase layer responsibilities. Keep the class surfaces section focused only on surfaces touched by the current feature.

### Transport vs User-Reachable Split

- Every layer and surface row records two explicit subfields:
  - `transport_layer`: internal callable code present in the repository (API clients, services, hooks, repositories, helpers). Use `none` when no transport-layer code exists for this block.
  - `user_reachable_surface`: operator-invocable entry points an operator can invoke without writing code. Use `none` when none exists.
- A single conflated line mixing both forms is invalid; the gate rejects a block missing either subfield.
- User-reachable taxonomy: **frontend** = a mounted route/page/top-level screen (e.g., `/checkout/summary`); **mobile** = a registered screen or deep link (e.g., `checkout://risk-screen`); **backend** = an operator-reachable HTTP endpoint, CLI command, scheduled job, or admin tool (internal-only services/repositories/helpers do NOT qualify).
- Each `user_reachable_surface` entry is a concrete navigable token (route path, full HTTP method+path, CLI command, job id) — not prose. Transport-layer presence does NOT imply user-reachable presence; do not list internal services/clients/helpers there. Use the literal `none` when empty; a blank or omitted subfield is invalid.

### Evidence Rules

- Use only repository-proven evidence, the declared feature input artifacts, and context-bound non-repo evidence from the permanent chain.
- Do not invent layers, module boundaries, or touched surfaces without evidence from repo, bound sibling plans, or blueprint. Keep scope narrow to this feature delta. Explain each layer/surface concisely. Do not duplicate details that belong in other artifacts.

### Runtime Path Binding Rules

- Treat the context block runtime bindings as authoritative for this invocation. Resolve outputs under the runtime feature root. Do not hardcode `overmind/product/...` or runner-specific installation paths.

### Quality Criteria and Completion Gate

- Draft the bound target before invoking the gate. Run `node .overmind/overmind.js gate surface-map <feature-path> --class <class>` after every write or repair.
- On exit `1`, repair exactly the reported structural failures and rerun the gate. On exit `2`, make no further edits and wait for operator instructions. Finalize only after exit `0`.
