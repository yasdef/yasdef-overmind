## Context

CRP-117 makes Step `7` capable of generating surface maps from repo evidence, type `A` stack blueprint evidence, and finally the literal `<to be defined during implementation>` placeholder when neither source can confirm a field. Those placeholders are valid Step `7` output and allow planning to proceed without invented structure.

Some projects may also have a configured MCP-backed knowledge base that can confirm planned surface details after Step `7` has made unresolved fields explicit. CRP-118 adds optional Step `7.1` as a separate enrichment pass so operators can replace specific placeholders with confirmed knowledge-base guidance before Step `8`, without making knowledge-base availability mandatory.

## Goals / Non-Goals

**Goals:**

- Add optional Step `7.1` after Step `7` and before Step `8`.
- Inspect existing `project_surface_struct_resp_map_<class>.md` artifacts for literal `<to be defined during implementation>` placeholders.
- Query a configured knowledge-base MCP only after eligible placeholders are found.
- Require the external source name to clearly identify a knowledge base before it can be used as surface-shape authority.
- Summarize candidate replacements with source/evidence and require user confirmation before editing.
- Edit only the relevant surface-map file in place for confirmed replacements.
- Rerun the existing backend or frontend/mobile surface-map quality helper after an edit.
- Keep Step `7.1` non-blocking for Step `8`.

**Non-Goals:**

- Fold placeholder enrichment into Step `7` generation.
- Make Step `7.1` required for feature planning.
- Create a new per-class status, audit, or enrichment artifact.
- Treat arbitrary MCP sources as authoritative for surface shape.
- Replace placeholders without user confirmation.
- Rewrite non-placeholder surface-map content.
- Change Steps `8`, `8.1`, `8.2`, or `8.3` to read MCP sources directly.

## Decisions

### Decision 1: Keep Step 7.1 as a separate optional phase

The workflow should add Step `7.1` between Step `7` and Step `8` with `optional: true`. Step `7` remains responsible for producing explicit unresolved placeholders first; Step `7.1` only works from existing surface maps.

Alternative considered: enrich during Step `7`. That would hide the repo -> blueprint -> placeholder fallback boundary and make MCP availability part of core surface-map generation.

### Decision 2: Use one script for all classes and run it per existing map

Add `feature_surface_map_mcp_placeholder_enrichment.sh` as the optional command. It should locate existing backend, frontend, and mobile surface-map artifacts under the feature path and process each present artifact independently.

The command should choose the backend quality helper for backend maps and the frontend/mobile quality helper for frontend or mobile maps.

Alternative considered: create separate backend and frontend/mobile enrichment commands. That would duplicate the placeholder detection, source selection, user confirmation, and in-place update flow.

### Decision 3: Detect placeholders before touching external sources

The script should first scan each existing surface map for the exact literal `<to be defined during implementation>`. If a map has no placeholders, it no-ops for that class and does not check MCP reachability.

Alternative considered: always check MCP availability at startup. That would create noise and possible failures even when there is nothing to enrich.

### Decision 4: Select only knowledge-base-named MCP sources

Step `7.1` should read `.setup/external_sources.yaml` from the staged ASDLC workspace and accept only configured MCP source names that clearly indicate knowledge-base authority, such as names containing `knowledge`, `knowledge-base`, `knowledge_base`, or `kb`. The source must still be reachable before querying.

Alternative considered: rely only on `type` metadata. Existing examples include `stack_knowledge_base`, but the requirement specifically needs the source name to be self-identifying so arbitrary MCP tools are not treated as surface authorities by accident.

### Decision 5: Let the model propose replacements, then require explicit user approval

When eligible placeholders and a reachable knowledge-base MCP source both exist, the command should invoke the configured model with the enrichment rule, the target surface map, the placeholder inventory, and the selected source binding. The model should produce a concise replacement proposal for the operator. The script or model flow must not apply edits until the user confirms the proposed replacements.

Alternative considered: automatically apply any MCP result. That would make external guidance silently authoritative and risks replacing placeholders with ambiguous or overly broad suggestions.

### Decision 6: Edit in place and rely on existing quality helpers

Confirmed replacements should update the existing `project_surface_struct_resp_map_<class>.md` file only. After edits, the command should run the existing surface-map quality helper for that class and leave the file unchanged if the proposal is rejected or inconclusive.

Alternative considered: write a separate enrichment artifact or audit file. The proposal explicitly excludes a new per-class enrichment status/audit artifact, and downstream steps already consume the surface maps.

## Risks / Trade-offs

- **Risk: optional enrichment becomes a hidden required step** -> Mitigation: mark Step `7.1` optional and ensure scanner/orchestrator behavior lets Step `8` proceed when it is incomplete or skipped.
- **Risk: non-authoritative MCP source is used** -> Mitigation: require configured source name to reveal knowledge-base intent and verify reachability only after placeholders exist.
- **Risk: model replaces too much content** -> Mitigation: rule and prompt restrict edits to confirmed placeholder replacements in the selected surface map.
- **Risk: ambiguous MCP output creates false certainty** -> Mitigation: leave placeholders untouched when guidance is absent, ambiguous, inconclusive, or rejected by the user.
- **Risk: quality gate fails after replacement** -> Mitigation: rerun the existing class-specific quality helper after confirmed edits and report failure with stable exit behavior.

## Migration Plan

No persisted data migration is required. Existing surface maps with placeholders remain valid. Deployed ASDLC workspaces need the new Step `7.1` script, rule, setup assets, and progress-definition updates staged through the existing project setup/update mechanism.
