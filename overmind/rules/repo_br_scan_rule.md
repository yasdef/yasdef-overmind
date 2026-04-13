Repo scan enrichment rules for the runtime target BR artifact (`<TARGET_BR_ARTIFACT>`)

Read this file fully before scanning the repository.

Purpose
- Enrich `<TARGET_BR_ARTIFACT>` for existing-project repositories using only repository-proven business evidence.
- This repo-scan phase is only a baseline existing-system business-context pass.
- Determine what business capability the repository already implements, which actors/use cases it already serves, and which gaps or contradictions exist in the current BR summary.
- Do not turn this pass into future-feature discovery, feature design, or feature specification.

Non-negotiable rules
1. No guessing. Use only facts proven by allowed repository evidence.
2. If a value cannot be proven, leave the existing value as-is or keep `[UNFILLED]`.
3. Preserve existing section order, headings, keys, and field names.
4. Do not add, remove, or rename sections, headings, keys, or numbered FR/BR line-item identifiers.
5. The only allowed structural addition is `- **CONTRADICTORY FACT N:** ...` inside the relevant existing subsection.
6. Never silently overwrite a contradicted filled value.
7. Do not treat this rule file, the target summary file, templates, or golden examples as business evidence. They are instruction/structure inputs only.
8. Fill only `## 1. Document Meta` fields `last_updated`, `source_type` and `## 13. Existing-System Context`: all existing fields, the rest of blocks/fields in it must be leaved `[UNFILLED]`.

Allowed evidence scope
- Scan only business-related code, tests, contracts, schemas, migrations, and product-facing docs.
- Favor evidence that proves business behavior, actors, business rules, domain data, scope boundaries, failures, integrations, and existing-system gaps.

Excluded by default
- Do not scan these locations as business evidence unless the user explicitly asks for them:
  - `/ai/**`
  - `/overmind/**`
  - hidden directories and hidden project areas such as `/.idea/**`, `/.openspec/**`, `/.git/**`, and other `/.*/**`
- Exception: you must read this rule file and the target `<TARGET_BR_ARTIFACT>`, but do not cite them as proof of business behavior.
- Ignore framework noise, build tooling, editor config, dependency/vendor folders, and generated artifacts unless they directly prove a business rule or business data shape.

What counts as business evidence
- Domain entities, aggregates, value objects, and business-facing data models.
- Application services, use-case handlers, workflows, orchestrators, and policy/decision logic.
- Business-facing endpoints, commands, events, queue handlers, and integration contracts.
- Tests that prove business scenarios, acceptance flows, validations, or business constraints.
- Product docs outside excluded folders when they describe business intent or domain terminology.
- Do not rely on package names, folder names, or framework labels alone without behavioral evidence.

How to understand the repository first
1. Identify the dominant business capability implemented by this repository.
2. Derive that from repeated domain terms, business workflows, entity names, API/resource names, data models, and business-oriented tests.
3. Describe the repository in business terms, not framework terms.
4. If the repository is mostly platform/infrastructure and no stronger business meaning is provable, state only what is provable and leave unsupported business-intent fields unfilled.
5. If multiple capabilities exist, prioritize the dominant one and avoid merging unrelated capabilities into one invented feature narrative.

How to update the runtime BR target artifact
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

Strict Section-13 format contract (mandatory)
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

Runtime path bindings
- The caller provides runtime path bindings in the prompt context (feature root, target artifact, helper command).
- Use those runtime bindings as authoritative for this invocation.
- Do not replace runtime bindings with fixed `overmind/product/...` assumptions.

Evidence discipline by section
- `last_updated` must be `YYYY-MM-DD`.
- In `## 1. Document Meta`, add `Repository scan` to `source_type` but don't delete or replace other sources.
- If a field contains multiple proved items, keep them concise in one bullet line using a readable delimiter such as commas or semicolons.

Contradiction handling
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

Practical scan strategy
1. Start from business-significant entry points.
2. Follow domain models, use-case services, validators, repositories, endpoints, contracts, and business-oriented tests.
3. Collect only evidence that explains business meaning, actors, rules, scope, data expectations, integrations, failures, and existing-system gaps.
4. Ignore AI/process artifacts and hidden project areas unless explicitly requested.

Final quality bar
- Every filled statement must be traceable to concrete repository evidence.
- Unsupported fields remain `[UNFILLED]`.
- Contradictions are explicit, not buried.
- The summary should help a human understand what business capability this repository implements, what is already present, what is missing, and what existing claims are contradicted by the codebase.

Business Context Completeness Gate
- This gate is mandatory before repo-scan phase can be treated as complete.
- After each update pass of `<TARGET_BR_ARTIFACT>`, run:
  - `<REPO_SCAN_GATE_HELPER_COMMAND>`
- Gate pass condition:
  - script exits `0` and reports business-context completeness
- Gate fail condition:
  - script exits non-zero with missing/unfilled details
- On gate failure:
  - inspect the missing/unfilled fields reported by the script
  - correct the document only with repository-supported facts
  - ask user `1 proceed` or `2 finish` before attempting another pass
  If user reply `2 finish` OR if this Gate passes - report repo-scan phase complet
