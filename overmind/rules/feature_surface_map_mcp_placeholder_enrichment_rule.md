# MCP Placeholder Enrichment Rule

Read this file fully before making any edits.

## Purpose

Optional Step `7.1`: Inspect existing surface-map artifacts from Step `7` for literal `<to be defined during implementation>` placeholders and replace them with confirmed knowledge-base MCP guidance before Step `8`.

## Scope Constraints

- Edit only `<to be defined during implementation>` placeholder values in the target surface-map files listed in the prompt.
- Do NOT rewrite non-placeholder content.
- Do NOT create new surface-map files.
- Do NOT create a new per-class enrichment status or audit artifact.
- Do NOT fold this step into Step `7` generation or into any Step `8`+ step.
- Do NOT modify `external_sources.yaml`, rule files, model config, or any other input file.

## MCP Source Authority Boundaries

- Use only MCP sources configured in `.setup/external_sources.yaml` whose source name clearly identifies a knowledge base.
- A source name clearly identifies a knowledge base when it contains `knowledge`, `knowledge-base`, `knowledge_base`, or `kb` (case-insensitive).
- Do NOT use arbitrary MCP tools as surface-map authorities even if their `type` field contains knowledge-base wording.
- Verify that the selected MCP source is reachable before querying it.

## Enrichment Flow

1. Read all surface maps listed in the prompt and identify placeholder fields.
2. For each eligible knowledge-base MCP source name provided in the prompt, check reachability.
3. If no source is reachable: report that enrichment is not available and exit without modifying any file.
4. For each surface map with placeholders, using the first reachable source:
   a. Query the source for candidate values for each placeholder field.
   b. Produce a concise replacement summary: field path, proposed value, source name, and evidence citation.
   c. Present the summary to the user and wait for explicit confirmation.
   d. Apply only user-confirmed replacements; leave all other content unchanged.
   e. After confirmed edits, run the quality gate command specified in the prompt for that class.
   f. After confirmed edits and a passing quality gate, the script sets `was_enriched_with_mcp: true` in that surface map's Document Meta automatically — no manual action required.

## Confirmation Requirement

- Do NOT apply any replacement before the user explicitly confirms.
- If the user declines any or all replacements, leave the target fields as `<to be defined during implementation>`.
- If MCP returns no useful guidance, ambiguous guidance, or the confirmation is unclear, leave the placeholder unchanged.

## Non-Blocking Guarantee

- Step `7.1` must never block Step `8`.
- Leaving placeholders unchanged is a valid outcome when enrichment is unavailable, inconclusive, or declined.

## Quality Gate

- After confirmed edits to a backend surface map: run the backend quality gate command provided in the prompt.
- After confirmed edits to a frontend or mobile surface map: run the frontend/mobile quality gate command provided in the prompt.
- If the quality gate fails after edits, report the failure and do not suppress the error.
