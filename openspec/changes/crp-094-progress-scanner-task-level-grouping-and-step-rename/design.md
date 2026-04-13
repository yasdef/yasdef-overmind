## Context

`overmind/scripts/project_mgmt/init_progress_scanner.sh` currently renders one flat checklist from `init_progress_definition.yaml` step order. The template already distinguishes project setup and feature work through `phase_name`, but that distinction is not visible in the emitted checklist. At the same time, Step 2 is named `Create Cross-Project Contract Inventory and Common Contracts Definition`, which overstates the scope and reads like a platform-wide task instead of a baseline contract-definition step for the current project.

This change affects the runtime scanner output, the canonical progress-definition template, and the checklist template/golden example used as formatting references. It must preserve the existing completion semantics, step ordering, and `next step` calculation while making the rendered checklist easier to scan.

## Goals / Non-Goals

**Goals:**
- Render steps `1` and `2` under a visible `PROJECT LEVEL TASKS` heading.
- Render steps `3` through `7` under a visible `FEATURE LEVEL TASKS <name-of-feature>` heading.
- Rename Step 2 in the canonical progress-definition template to `Create Cross-Repository Contract Definition For This Project`.
- Keep checklist order, artifact gating, short-circuit evaluation, and `next step` semantics unchanged.
- Make the section-heading output deterministic enough for docs, golden examples, and shell tests.

**Non-Goals:**
- Change step numbers or reorder steps.
- Introduce new CLI flags or scanner modes.
- Redesign artifact resolution, `required_if`, or `--feature_path` behavior.
- Add a new feature-metadata persistence flow outside the scanner/template surface.

## Decisions

1. Use the existing `phase_name` field in `init_progress_definition.yaml` as the source of project-level versus feature-level grouping.
Rationale: the template already classifies steps by phase, so scanner grouping can be added without inventing a separate grouping field.
Alternative considered: hard-code grouping by numeric ranges only. Rejected because `phase_name` is clearer and less brittle if step numbering evolves.

2. Rename Step 2 only in the canonical template and let scanner output inherit the new label from YAML.
Rationale: the scanner already treats `step_name` as source-of-truth, so changing the template keeps runtime behavior, docs, and generated project files aligned.
Alternative considered: remap only at render time. Rejected because it would split template truth from scanner truth.

3. Resolve `<name-of-feature>` for the feature-level heading from the active feature summary’s `feature_title` when available, with a deterministic fallback marker when not yet available.
Rationale: `feature_title` already exists in `feature_br_summary.md` document meta and is the most user-meaningful feature label in the current workflow.
Alternative considered: use the selected feature-path basename. Rejected because the default root basename (`product`) is not a meaningful feature name.

4. Keep the output shape simple: header, blank line, project-level section heading, grouped checklist lines, feature-level section heading, grouped checklist lines, blank line, `next step`.
Rationale: this makes the grouping visible without changing per-step checklist syntax or next-step parsing expectations.
Alternative considered: prefix each step label with `[PROJECT]` or `[FEATURE]`. Rejected because section headings are easier to scan and less noisy.

## Risks / Trade-offs

- [Risk] Feature heading naming can be unavailable before feature artifacts exist.
  Mitigation: define a deterministic fallback string so scanner output remains stable even before `feature_br_summary.md` is created or populated.

- [Risk] Additional section-heading lines can break tests or downstream consumers that assumed a flat checklist body.
  Mitigation: update template/golden example artifacts and shell tests together, while preserving unchanged checklist-line syntax and final `next step` line.

- [Risk] Existing project definitions generated from older templates may not include `phase_name`.
  Mitigation: keep design scoped to the canonical template and scanner behavior for current generated files; implementation can fail fast or use a bounded fallback only if necessary.

## Migration Plan

1. Update `overmind/templates/init_progress_definition_TEMPLATE.yaml` so Step 2 uses the new project-scoped contract-definition label and phase metadata remains explicit.
2. Extend `overmind/scripts/project_mgmt/init_progress_scanner.sh` to group rendered steps by phase, resolve the feature heading name from active feature metadata when available, and preserve current completion semantics.
3. Update `overmind/templates/step_state_TEMPLATE.md` and `overmind/golden_examples/step_state_GOLDEN_EXAMPLE.md` to reflect the grouped output contract.
4. Extend `tests/ai_scripts/init_progress_scanner_tests.sh` and any ASDLC staging tests that assert scanner output.
5. Update `overmind/README.md` so the scanner output examples and step naming match the new grouped format.

Rollback strategy: restore the flat checklist rendering and prior Step 2 label while leaving step ordering and completion semantics unchanged.

## Open Questions

- The feature heading fallback text should be finalized during implementation; a deterministic placeholder such as `<feature not initialized>` is acceptable if `feature_title` is unavailable.
