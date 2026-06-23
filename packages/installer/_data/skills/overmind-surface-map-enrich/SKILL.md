---
name: overmind-surface-map-enrich
description: Use when enriching surface-map placeholder fields using a configured knowledge-base MCP source (optional Step 7.1).
---

# Overmind Surface Map MCP Placeholder Enrichment

Use this skill to run the optional step 7.1 MCP placeholder enrichment for a feature folder. The enrichment inspects existing surface-map artifacts from Step 7 for literal `<to be defined during implementation>` placeholders, queries a configured knowledge-base MCP source for candidate values, presents confirmation to the operator, and patches confirmed values in place.

## Required Invocation

Run these commands from the installed project root:

1. Assemble deterministic context:

```bash
node .overmind/overmind.js context surface-map-enrich <feature-path>
```

2. Check the `no_op` field in the emitted context block first:
   - If `no_op: true`: read the reason, end the session immediately without querying any MCP source or modifying any file.

3. If not a no-op, write only the surface-map files listed under `## Surface Maps With Placeholders` in the context output.

4. Validate after every write or repair using the per-class gate command from the context output:

```bash
node .overmind/overmind.js gate surface-map <feature-path> --class <backend|frontend|mobile>
```

There is no separate `gate surface-map-enrich` command. Use `gate surface-map` with the `--class` argument.

Handle gate exit codes exactly:
- `0`: gate passed; after a passing gate, write `was_enriched_with_mcp: true` in the Document Meta section of that surface map.
- `1`: recoverable surface-map issue; read each `missing: ...` line, repair the surface map, and rerun the gate.
- `2`: runtime or validation failure; stop, report the blocker, and wait for operator instructions.

The model owns the context/write/gate/repair loop. Do not ask the operator for deterministic paths, required-input checks, allowed-write lists, or validation details that the context and gate commands provide.

Do not modify `external_sources.yaml`, rule files, model config, or any other input file.

If the quality gate cannot pass after confirmed edits were applied, end with this exact line:

```text
surface-map MCP placeholder enrichment cannot be completed with current inputs. Please provide instructions what to do, or adjust artifacts and rerun this phase
```

When the enrichment is finished (all confirmed edits applied and gates passed, or no enrichment was needed), end your final response with this exact last line:

```text
surface-map MCP placeholder enrichment phase is finished. Nothing else to do now; press Ctrl-C so orchestrator can start the next phase
```

## Inlined MCP Placeholder Enrichment Rule

### Purpose

Optional Step `7.1`: Inspect existing surface-map artifacts from Step `7` for literal `<to be defined during implementation>` placeholders and replace them with confirmed knowledge-base MCP guidance before Step `8`.

### Scope Constraints

- Edit only `<to be defined during implementation>` placeholder values in the target surface-map files listed in the context output.
- Do NOT rewrite non-placeholder content.
- Do NOT create new surface-map files.
- Do NOT create a new per-class enrichment status or audit artifact.
- Do NOT fold this step into Step `7` generation or into any Step `8`+ step.
- Do NOT modify `external_sources.yaml`, rule files, model config, or any other input file.
- After confirmed edits to a surface map and a passing quality gate, write `was_enriched_with_mcp: true` in the Document Meta section of that surface map.

### MCP Source Authority Boundaries

- Use only MCP sources configured in `.setup/external_sources.yaml` whose source name clearly identifies a knowledge base.
- A source name clearly identifies a knowledge base when it contains `knowledge`, `knowledge-base`, `knowledge_base`, or `kb` (case-insensitive).
- Do NOT use arbitrary MCP tools as surface-map authorities even if their `type` field contains knowledge-base wording.
- Verify that the selected MCP source is reachable before querying it.

### Enrichment Flow

1. Run `node .overmind/overmind.js context surface-map-enrich <feature-path>` and read the emitted context block.
2. Check `no_op: true` first. If present, report the reason and end the session immediately without modifying any file.
3. For each eligible knowledge-base MCP source name listed in the context, check reachability.
4. If no source is reachable: report that enrichment is not available and end the session without modifying any file.
5. For each surface map with placeholders, using the first reachable source:
   a. Query the source for candidate values for each placeholder field.
   b. Produce a concise replacement summary: field path, proposed value, source name, and evidence citation.
   c. Present the summary to the operator and wait for explicit confirmation.
   d. Apply only operator-confirmed replacements; leave all other content unchanged.
   e. After confirmed edits, run the per-class gate command from the context output.
   f. After confirmed edits and a passing gate, write `was_enriched_with_mcp: true` in the Document Meta section of that surface map.

### Confirmation Requirement

- Do NOT apply any replacement before the operator explicitly confirms.
- If the operator declines any or all replacements, leave the target fields as `<to be defined during implementation>`.
- If MCP returns no useful guidance, ambiguous guidance, or the confirmation is unclear, leave the placeholder unchanged.

### Non-Blocking Guarantee

- Step `7.1` must never block Step `8`.
- Leaving placeholders unchanged is a valid outcome when enrichment is unavailable, inconclusive, or declined.

### Quality Gate

- After confirmed edits to a backend surface map: run `node .overmind/overmind.js gate surface-map <feature-path> --class backend`.
- After confirmed edits to a frontend surface map: run `node .overmind/overmind.js gate surface-map <feature-path> --class frontend`.
- After confirmed edits to a mobile surface map: run `node .overmind/overmind.js gate surface-map <feature-path> --class mobile`.
- If the quality gate fails after edits, read the gate output, repair the surface map, and rerun the gate.

### Runtime Path Binding Rules

- Runtime bindings from `node .overmind/overmind.js context surface-map-enrich <feature-path>` are authoritative for each invocation.
- Use the emitted workspace root, feature path, surface map file paths, gate commands, and eligible KB source names exactly.
- Do not assume fixed source-repo paths or runner-specific skill install paths.
- Run the gate command after every write or repair.
