## Context

`crp-097` and `crp-098` give implementation steps deterministic functional and technical evidence links and reject plans that omit unresolved technical work. Both gates trust the upstream artifacts as the source of "what currently exists." That trust is misplaced today: Step `7` surface maps and Step `8` `technical_requirements.md` use a single free-text `current_state` per concern, and that single line silently mixes two very different forms of "exists":

- transport-layer presence (a hook, a client, a service that other code can call), and
- user-reachable presence (a route, page, screen, CLI command, scheduled job an operator can invoke directly).

When transport-layer presence alone is reported as `current_state`, the downstream pipeline cannot tell whether the user can actually reach the behavior. This change splits the recording so `crp-109` can build a hard prerequisite-gap gate on top of a trustworthy ground truth.

## Goals / Non-Goals

**Goals:**
- Force every surface-map block and every technical-requirements `current_state` to record transport-layer presence and user-reachable-surface presence as separate subfields.
- Define what counts as user-reachable per project class so the helper can validate the split deterministically.
- Reject single-line conflated `current_state` entries.
- Keep the change additive at field level: existing block structure is preserved; only the `current_state` payload shape changes.

**Non-Goals:**
- Do not introduce a new top-level artifact; reuse the existing surface-map and technical-requirements files.
- Do not alter Section numbering or block ordering in the surface-map templates.
- Do not enforce any prerequisite-gap reasoning in this change; that work belongs to `crp-109`.
- Do not redefine what `gap/TECH_REQ-<n>` or `comp/<component-slug>` tokens mean; `crp-098` semantics are unchanged.

## Decisions

1. Split is mandatory on both surface-map blocks and technical-requirements `current_state`
Rationale: surface map is the upstream evidence and technical requirements is what later steps consume. Splitting only one end would let conflation re-enter at the boundary. Both ends must enforce the same shape.
Alternative considered: split only at technical-requirements layer. Rejected because the surface-map writer is the one who actually inspects the repo; making that writer commit to the split removes ambiguity at the source.

2. `none` is an explicit marker for an empty side
Rationale: shell-readable presence requires a concrete token. An empty subfield is indistinguishable from a forgotten subfield, so the helper would either over-fail or under-fail. `none` is unambiguous and readable.
Alternative considered: omit the subfield when empty. Rejected because the helper would have to distinguish "intentionally absent" from "writer forgot."

3. User-reachable definition is project-class-specific
Rationale: "user-reachable" is meaningful but not universal. The rule defines the term per class so the writer and helper agree:
- frontend: a mounted route, page, or top-level screen that an operator can navigate to.
- mobile: a registered screen or deep link an operator can land on.
- backend: an operator-reachable endpoint, CLI command, scheduled job, or admin tool — not internal-only services or repositories.
Alternative considered: a single project-agnostic definition. Rejected because backend "user-reachable" differs structurally from frontend "user-reachable" and a single definition would either confuse writers or under-constrain backend evidence.

4. Conflation rejection is at helper level, not template level
Rationale: the template encodes the shape but cannot stop a writer from collapsing both subfields into one prose blob. The helper enforces the split as a hard gate so the contract holds even when the template is bypassed.
Alternative considered: rely on template structure alone. Rejected because writers reformat blocks freely and the contract must hold against the artifact, not the seed.

## Risks / Trade-offs

- [Risk] Split increases verbosity in surface-map and technical-requirements artifacts.
  Mitigation: keep both subfields on adjacent lines and allow `none` markers; net length growth is small per block.

- [Risk] Writers may use different verbal forms for "user-reachable" across project classes.
  Mitigation: rule defines class-specific user-reachable taxonomy and helper validates token form per class.

- [Risk] Pre-existing surface-map and technical-requirements artifacts will not pass the new helper without rewrite.
  Mitigation: regenerate both artifacts when the rule is applied to a feature; the helper failure message identifies the missing subfield to make the rewrite mechanical.

- [Risk] The split may invite over-categorization for blocks where transport and user-reachable are the same surface (e.g., a CLI command that is both the entry point and the only callable code path).
  Mitigation: rule explicitly allows the same path to appear in both subfields when they are genuinely the same surface.

## Migration Plan

1. Update the contracts:
   - `overmind/rules/feature_repo_surface_and_exec_context_rule.md`
   - `overmind/rules/technical_requirements_rule.md`
2. Update templates and golden examples:
   - `overmind/templates/project_surface_struct_resp_map_fe_TEMPLATE.md`
   - `overmind/templates/project_surface_struct_resp_map_be_TEMPLATE.md`
   - `overmind/templates/technical_requirements_TEMPLATE.md`
   - matching `overmind/golden_examples/...`
3. Teach generators to emit the split:
   - `overmind/scripts/feature_repo_surface_and_exec_context.sh`
   - `overmind/scripts/feature_technical_requirements.sh`
4. Add helper enforcement:
   - `overmind/scripts/helper/check_repo_surface_and_exec_context_quality.sh`
   - `overmind/scripts/helper/check_technical_requirements_quality.sh`
5. Add and update tests under `tests/ai_scripts/`.

Rollback strategy: revert templates and helpers together; existing rule conditions and `crp-097` / `crp-098` semantics remain intact.

## Open Questions

- None. The remaining design question — whether the split lives only at `current_state` or also at upstream surface-map blocks — is resolved in favor of both ends to prevent boundary regressions.
