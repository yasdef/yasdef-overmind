## Why

After Step `7` can fall back from repo evidence to type `A` blueprint evidence, some touched surfaces may still have no confirmed repo or blueprint source and therefore land in explicit `<to be defined during implementation>` placeholders. Those placeholders should remain valid Step `7` output, but operators need an optional follow-up pass that can replace them with confirmed knowledge-base MCP guidance before Step `8` when such guidance is available and approved.

## What Changes

- Add optional Step `7.1` after Step `7` and before Step `8` for MCP knowledge-base placeholder enrichment.
- Keep Step `7` responsible for writing explicit `<to be defined during implementation>` placeholders first; Step `7.1` must not be folded into Step `7` generation.
- Make Step `7.1` non-blocking: Step `8` may proceed when Step `7` is complete, whether Step `7.1` is skipped, no-ops, fails to find useful MCP data, or the user rejects proposed replacements.
- Run Step `7.1` separately for each existing `project_surface_struct_resp_map_<class>.md` artifact.
- For each class map, first detect placeholder fields eligible for replacement, then check for a configured MCP source in `overmind/setup/external_sources.yaml`.
- Require the configured external source name to clearly reveal that the MCP source is a knowledge base, so Step `7.1` does not treat arbitrary external MCP tools as surface-shape authorities.
- Check MCP reachability only after placeholders are found and a knowledge-base-named source is configured.
- Ask the MCP source for candidate replacements only when both placeholders and a reachable knowledge-base source exist.
- Create a short user-facing summary showing what would be replaced with what, including the MCP source/evidence, and ask for user confirmation before editing.
- Update the relevant surface-map file in place only for user-confirmed replacements, then rerun the existing surface-map quality helper for that changed artifact.
- Leave placeholders untouched when there are no placeholder candidates, no configured knowledge-base MCP, MCP is unreachable, MCP returns no useful confirmation, MCP returns ambiguous guidance, or the user declines replacement.
- Do not require a new per-class enrichment status/audit artifact.

## Capabilities

### New Capabilities

- `overmind-optional-step-7-1-mcp-placeholder-enrichment`: Optional Step `7.1` SHALL inspect existing Step `7` surface maps, query a configured knowledge-base MCP only for eligible placeholder fields, summarize proposed replacements for user confirmation, and apply only confirmed replacements in place.
- `overmind-step-7-1-nonblocking-placeholder-enrichment`: Optional Step `7.1` SHALL NOT block Step `8`; placeholders remain valid when enrichment is skipped, unavailable, inconclusive, or rejected.
- `overmind-step-7-1-knowledgebase-source-selection`: Optional Step `7.1` SHALL use only MCP sources configured in `overmind/setup/external_sources.yaml` whose source name clearly identifies the source as a knowledge base.

### Modified Capabilities

(none - no main specs exist yet for these requirements)

## Impact

- Depends on `crp-117-type-a-step-7-blueprint-fallback-evidence` so placeholder enrichment is applied after repo and blueprint fallback have both failed.
- Affected workflow definition:
  - `overmind/templates/init_progress_definition_TEMPLATE.yaml`
  - `overmind/init_progress_definition_sequence_diagram.md`
- Affected Step `7` assets:
  - `overmind/rules/feature_repo_surface_and_exec_context_rule.md`
  - `overmind/golden_examples/project_surface_struct_resp_map_be_GOLDEN_EXAMPLE.md`
  - `overmind/golden_examples/project_surface_struct_resp_map_fe_GOLDEN_EXAMPLE.md`
- New optional Step `7.1` assets:
  - `overmind/scripts/feature_surface_map_mcp_placeholder_enrichment.sh`
  - `overmind/rules/feature_surface_map_mcp_placeholder_enrichment_rule.md`
- Affected external-source configuration:
  - `overmind/setup/external_sources.yaml`
- Possible affected metadata or prompt context:
  - existing optional guidance source metadata from project init, if reused for Step `7`
  - Step `7.1` model prompt bindings for configured knowledgebase sources
- Affected tests:
  - `tests/ai_scripts/feature_surface_map_mcp_placeholder_enrichment_tests.sh`
  - related init progress scanner tests for optional Step `7.1` routing/non-blocking behavior
