---
name: overmind-repo-br-scan
description: Use when enriching feature_br_summary.md ## 1. Document Meta and ## 13. Existing-System Context from ready project class repositories for the repo-br-scan step.
---

# Overmind Repo BR Scan

Use this skill to enrich a feature folder's `feature_br_summary.md` with existing-system business context discovered from ready project class repositories.

## Required Invocation

Capture is not applicable for this step: the input is the pre-existing `feature_br_summary.md` plus the ready repositories.

Run these commands from the installed project root:

1. Assemble deterministic context:

```bash
node .overmind/overmind.js context repo-br-scan <feature-path>
```

2. If the context reports a no-op (no ready repositories), finish without editing any artifact.

3. If context exits with a `BLOCKED: ... (D7)` message, the repository is not in the expected state (wrong branch, dirty tree, or no upstream). Stop, report the exact message, and wait for user instructions — the orchestrator syncs repositories before this session starts, so a D7 here means a precondition that sync cannot fix (e.g., wrong branch).

4. Otherwise, read the emitted context block and update ONLY:
   - `feature_br_summary.md` — restricted to the allowed write surface below

5. Validate after every write or repair:

```bash
node .overmind/overmind.js gate repo-br-scan <feature-path>
```

Handle gate exit codes exactly:
- `0`: gate passed; finish.
- `1`: recoverable content issue; read each `missing: ...` line, repair the artifacts, and rerun the gate.
- `2`: runtime or validation failure; stop, report that validation cannot complete, and wait for user instructions.

The model owns the context/generate/gate/repair loop. Do not rely on a separate shell orchestrator to run this step.

When the gate passes, end your final response with this exact last line:

```text
Repo scan phase to enrich BR is finished. Nothing else to do now; press Ctrl-C so orchestrator can start the next phase
```

## Allowed Write Surface

You may ONLY edit these parts of `feature_br_summary.md`:
- `## 1. Document Meta`: fields `last_updated` and `source_type` only
- `## 13. Existing-System Context`: all existing fields

Everything else in `feature_br_summary.md` and all other files are **read-only** for this step. Do not create, delete, or modify any other file.

## Assets

Asset paths are relative to this loaded skill directory. Do not resolve them through a hardcoded agent install path such as `.claude/skills/...`; use the copy exposed by the current supported CLI.

- `assets/feature_br_summary_TEMPLATE.md`
- `assets/feature_br_summary_GOLDEN_EXAMPLE.md`

## Runtime Path Bindings

Runtime path bindings come from the `context repo-br-scan` output for the current invocation. Treat those runtime bindings as authoritative for the workspace root, feature path, artifact paths, asset paths, and gate command. Do not replace runtime bindings with fixed `overmind/product/...` assumptions.

## Inlined Repo-BR-Scan Rule

### Scope

- Enrich `feature_br_summary.md` for existing-project repositories using only repository-proven business evidence.
- This repo-scan phase is only a baseline existing-system business-context pass.
- Determine what business capability the repository already implements, which actors/use cases it already serves, and which gaps or contradictions exist in the current BR summary.
- Do not turn this pass into future-feature discovery, feature design, or feature specification.

### Non-negotiable rules

1. No guessing. Use only facts proven by allowed repository evidence.
2. If a value cannot be proven, leave the existing value as-is or keep `[UNFILLED]`.
3. Preserve existing section order, headings, keys, and field names.
4. Do not add, remove, or rename sections, headings, keys, or numbered FR/BR line-item identifiers.
5. The only allowed structural addition is `- **CONTRADICTORY FACT N:** ...` inside the relevant existing subsection.
6. Never silently overwrite a contradicted filled value.
7. Do not treat this rule file, the target summary file, templates, or golden examples as business evidence. They are instruction/structure inputs only.
8. Fill only `## 1. Document Meta` fields `last_updated`, `source_type` and `## 13. Existing-System Context`: all existing fields, the rest of blocks/fields in it must be left `[UNFILLED]`.

### Allowed evidence scope

- Scan only business-related code, tests, contracts, schemas, migrations, and product-facing docs.
- Favor evidence that proves business behavior, actors, business rules, domain data, scope boundaries, failures, integrations, and existing-system gaps.

### Excluded by default

- Do not scan these locations as business evidence unless the user explicitly asks for them:
  - `/ai/**`
  - `/overmind/**`
  - hidden directories and hidden project areas such as `/.idea/**`, `/.openspec/**`, `/.git/**`, and other `/.*/**`
- Exception: you must read this rule file and the target `feature_br_summary.md`, but do not cite them as proof of business behavior.
- Ignore framework noise, build tooling, editor config, dependency/vendor folders, and generated artifacts unless they directly prove a business rule or business data shape.

### What counts as business evidence

- Domain entities, aggregates, value objects, and business-facing data models.
- Application services, use-case handlers, workflows, orchestrators, and policy/decision logic.
- Business-facing endpoints, commands, events, queue handlers, and integration contracts.
- Tests that prove business scenarios, acceptance flows, validations, or business constraints.
- Product docs outside excluded folders when they describe business intent or domain terminology.
- Do not rely on package names, folder names, or framework labels alone without behavioral evidence.

### How to understand the repository first

1. Identify the dominant business capability implemented by this repository.
2. Derive that from repeated domain terms, business workflows, entity names, API/resource names, data models, and business-oriented tests.
3. Describe the repository in business terms, not framework terms.
4. If the repository is mostly platform/infrastructure and no stronger business meaning is provable, state only what is provable and leave unsupported business-intent fields unfilled.
5. If multiple capabilities exist, prioritize the dominant one and avoid merging unrelated capabilities into one invented feature narrative.

### How to update the runtime BR target artifact

1. Read the current file fully before editing.
2. Identify which fields are empty, which are already supported, and which are contradicted by repository evidence.
3. Fill only gaps that describe the current repository's existing business context and are directly supported by evidence.
4. Prefer concise business-readable wording over implementation detail.
5. Treat repo scan as repository baseline enrichment, not feature-definition enrichment.
6. Repo-scan phase can edit only this surface:
   - In `## 1. Document Meta`: `last_updated`, `source_type`
   - In `## 13. Existing-System Context`: all existing fields
8. In `## 13. Existing-System Context`, keep one complete block of items per one repository in scope.
9. In each repository block under `## 13. Existing-System Context`, prefer filling the repository-level business-context fields first, especially:
   - `repository_business_domain`
   - `repository_primary_capability`
   - `repository_supported_business_flows`
   - `repository_supported_user_roles`
10. Use those `## 13` repository-level fields for statements such as what business domain each repository serves, what it mainly does, which business flows it supports, and which user/admin/operator roles already exist in the current system.
11. If business intent is not provable but technical behavior is, prefer filling actors, permissions, state/data expectations, integrations, failures, and existing-system context while leaving future-feature fields unfilled.

### Strict Section-13 format contract (mandatory)

- Build `## 13. Existing-System Context` as repeated repository blocks only; never collapse multiple repositories into one shared/global list.
- Repository block count must match the number of repositories provided by runtime context for this run.
- For each repository block, keep this exact shape and key names:
  - `### 13.N Repository: <repo_id_or_class>`
  - `- repository_id_or_class: <value>`
  - `- repository_path: <value>`
  - `- repository_business_domain: <value>`
  - `- repository_primary_capability: <value>`
  - `- repository_supported_business_flows: <value>`
  - `- repository_supported_user_roles: <value>`
  - `- already_implemented_behavior: <value>`
  - `- partially_implemented_behavior: <value>`
  - `- known_gaps: <value>`
  - `- known_workarounds: <value>`
  - `- legacy_constraints: <value>`
  - `- refactor_signals: <value>`
  - `- prerequisite_missing_parts: <value>`
- Keep block numbering contiguous: `13.1`, `13.2`, `13.3`, ...
- If evidence is missing for a field inside a repository block, keep `[UNFILLED]` for that field; do not delete the field.

### Evidence discipline by section

- `last_updated` must be `YYYY-MM-DD`.
- In `## 1. Document Meta`, add `Repository scan` to `source_type` but don't delete or replace other sources.
- If a field contains multiple proved items, keep them concise in one bullet line using a readable delimiter such as commas or semicolons.

### Contradiction handling

- When an existing filled value is disproved and the corrected value is clearly provable:
  - replace the value with the proved fact
  - add `- **CONTRADICTORY FACT N:** <previous claim> ; repository evidence shows <proved fact>. Source: <repo-relative paths>` in the same subsection
- When an existing filled value is only partially supported:
  - keep the strongest proved portion in the value if it can be separated cleanly
  - add a contradiction note for the unsupported or incorrect portion
- When an existing filled value is contradicted but the exact correction is not fully provable:
  - keep the current value
  - add a contradiction note explaining what part is not supported and cite evidence
- Place contradiction notes immediately below the affected field when practical; otherwise place them at the end of the same subsection.
- Number contradiction notes sequentially within the same subsection.

### Practical scan strategy

1. Start from business-significant entry points.
2. Follow domain models, use-case services, validators, repositories, endpoints, contracts, and business-oriented tests.
3. Collect only evidence that explains business meaning, actors, rules, scope, data expectations, integrations, failures, and existing-system gaps.
4. Ignore AI/process artifacts and hidden project areas unless explicitly requested.

### Final quality bar

- Every filled statement must be traceable to concrete repository evidence.
- Unsupported fields remain `[UNFILLED]`.
- Contradictions are explicit, not buried.
- The summary should help a human understand what business capability this repository implements, what is already present, what is missing, and what existing claims are contradicted by the codebase.

### Business Context Completeness Gate

- This gate is mandatory before repo-scan phase can be treated as complete.
- After each update pass of `feature_br_summary.md`, run:
  - `node .overmind/overmind.js gate repo-br-scan <feature-path>`
- Gate pass condition:
  - script exits `0` and reports business-context completeness
- Gate fail condition:
  - script exits non-zero with missing/unfilled details
- On gate failure (exit `1`):
  - read each `missing: ...` line reported by the script
  - repair the artifact using only repository-supported facts
  - rerun the gate; repeat until it passes
- On exit `2`: stop and wait for user instructions; do not report the step complete
