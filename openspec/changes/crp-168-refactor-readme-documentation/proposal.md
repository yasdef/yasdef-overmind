## Why

The repository documentation mixes product onboarding, operator guidance, internal design history, command reference, and isolated phase mechanics at inconsistent levels of detail. This makes the complete Overmind lifecycle difficult to understand and causes each CRP to append more duplicated or overly specific README content.

## What Changes

- Refactor root `README.md` into a concise repository and product entry point covering purpose, maturity, installation, the happy path, major concepts, human checkpoints, current limitations, and contributor commands.
- Refactor `overmind/README.md` into the durable operator guide for the complete workspace, project, feature-planning, and worker-handoff lifecycle at a consistent level of detail.
- Give every workflow stage a uniform operator-facing description of purpose, public command, important input or prerequisite, output, decision point, and recovery behavior where applicable.
- Document the shared gate exit-code and resume model once instead of repeating phase-specific repair internals.
- Remove duplicated command inventories, release-history prose, design-decision shorthand, literal artifact-field algorithms, validator mappings, and CRP-specific implementation details from the READMEs; retain or link those details in their owning rules, skills, executable contracts, process map, or generated runtime guide.
- Clarify navigation among root `README.md`, `overmind/README.md`, generated `quickrun.md`, the canonical process map, and normative rules so future documentation changes have one clear destination.
- Reword the process diagram's source-of-truth claim so it is the canonical end-to-end process map while `*_rule.md` files remain authoritative for operational and quality rules.

## Capabilities

### New Capabilities

- `readme-information-architecture`: Defines the audience, content boundaries, workflow coverage, detail level, navigation, and drift-prevention expectations for Overmind's repository and operator READMEs.

### Modified Capabilities

<!-- None. openspec/specs/ contains no consolidated documentation capability. -->

## Impact

- Root `README.md`: substantial restructuring and deduplication of product, setup, conceptual-model, CLI, notes, limitations, and release-history content.
- `overmind/README.md`: replacement of uneven phase-specific prose with a complete operator-facing lifecycle, command summary, checkpoints, outputs, recovery model, and documentation map.
- `overmind/init_progress_definition_sequence_diagram.md`: terminology adjustment and links consistent with its role as the canonical process map.
- Existing `*_rule.md` files, packaged skills, coordinator contracts, and generated `quickrun.md` remain the owners of exact mechanics; they are referenced rather than copied unless a stale cross-document statement must be corrected.
- No runtime behavior, CLI command, flag, artifact schema, validator, dependency, or deployment asset changes.
