## Context

The pipeline currently supports two slice kinds implicitly: feature-delivery slices and supporting-only slices (auth, API, contract, state). Neither category covers a third case: work whose sole purpose is to freeze a shared cross-repo contract artifact before parallel downstream implementation can safely proceed.

Gap 2 (technical requirements planning signals) introduces typed `cross_repo_contract_lock` blocks in section 6. Without a corresponding mechanism in slices and the plan, those signals remain informative but inert — the planner has no structured way to emit contract-coordination work even when the evidence justifies it.

The opposite failure mode has already been established as worse: a mandatory regime where every signal forces a coordination slice, every coordination slice forces a plan step, and every consumer repo is wired behind it. That regime was discarded in the previous attempt. This design installs only the optional half.

Current files in scope:
- `overmind/rules/implementation_slices_rule.md`
- `overmind/rules/implementation_plan_rule.md`
- `overmind/templates/implementation_slices_TEMPLATE.md`
- `overmind/scripts/helper/check_implementation_slices_quality.sh`
- `overmind/scripts/helper/check_implementation_plan_quality.sh`
- `tests/ai_scripts/check_implementation_slices_quality_tests.sh`
- `tests/ai_scripts/check_implementation_plan_quality_tests.sh`

## Goals / Non-Goals

**Goals:**
- Allow the slices artifact to express optional coordination slices alongside feature-delivery slices.
- Allow the plan to lift a coordination slice into a plan step only when downstream work is genuinely blocked.
- Keep coordination slice and step absence a valid quality outcome.
- Preserve the evidence-gating requirement: coordination work may only be emitted when upstream artifacts supply explicit justification.
- Ensure optional coordination work never displaces required operator-facing delivery (Gap 3).

**Non-Goals:**
- Mandatory coordination slice for every planning signal.
- Mandatory coordination plan step for every coordination slice.
- Blanket dependency wiring from coordination steps to all consumer-repo steps.
- Treating multi-repo scope, `delta_needed: true`, or `comp/*` evidence overlap as sufficient triggers on their own.
- Constraining where coordination steps appear in repo ordering (they often land first naturally via `#### Depends on:`; nothing forces or forbids that).
- Any change to how feature-delivery slices or plan steps are validated.
- Touching Gap 1, Gap 2, or Gap 3 artifacts (separate changes).

## Decisions

### Decision 1: Add `kind` field to slice blocks, not a separate section

**Options considered:**
- A) Add a separate `## 3b. Coordination Slices` section alongside `## 3. Slice Candidates`.
- B) Add an optional `kind: feature_delivery | coordination` field inside each slice block in `## 3. Slice Candidates`.

**Choice: B** — a single section keeps the artifact structure stable, avoids adding a new required section that would be empty in the common case, and makes the kind explicit at the slice level without requiring producers to know in advance whether coordination work will be needed.

**Consequence:** The quality helper validates `kind` when present; slices without `kind` are treated as `feature_delivery` for backward compatibility.

### Decision 2: Coordination slices must reference a `signal_ref` field

Coordination slices without grounding in upstream evidence are the primary risk. Requiring a `signal_ref` that resolves to a `signal_id` in section 6 of `technical_requirements.md` provides the minimum evidence anchor. The quality helper validates that the field is non-empty when `kind: coordination` is present; it does not cross-check the actual signal_id value (that would require coupling the slices helper to the technical requirements format).

### Decision 3: Coordination plan steps use `#### Coordination:` marker

To distinguish coordination steps from feature-delivery steps in the plan, a new optional `#### Coordination: true` marker is added on coordination-derived steps. This lets the quality helper validate that coordination steps are not the sole coverage for a required operator-facing surface without changing existing step validation for feature-delivery steps. The marker is optional; omitting it is valid and means the step is a normal feature-delivery step.

### Decision 4: Quality helpers treat coordination artifact absence as valid at every level

Neither `check_implementation_slices_quality.sh` nor `check_implementation_plan_quality.sh` will fail because no coordination slice or step is present. The only new failure modes are:
- A slice with `kind: coordination` lacks a non-empty `signal_ref`.
- A plan step with `#### Coordination: true` is the sole coverage for a required operator-facing surface.

## Risks / Trade-offs

- **Risk: coordination step becomes de facto mandatory through convention** → Mitigation: the rule explicitly states the absence of a coordination slice is valid; tests prove it.
- **Risk: `signal_ref` check is too weak** → The field only requires non-empty value; it does not verify the referenced signal exists. This is intentional — tight coupling to the technical requirements format would create a fragile cross-artifact dependency. Semantic correctness is left to the AI planner following the rule.
- **Risk: `#### Coordination: true` marker is ignored by the AI planner** → Mitigation: the rule explicitly describes when to add it and the golden example shows both valid paths.
- **Risk: coordination step crowds out required operator-facing delivery** → Mitigation: the existing `#### Preserved Surface:` mechanism already catches this; the new check that a `Coordination: true` step is not the sole surface coverage adds an extra guard at the plan level.

## Migration Plan

No runtime migration required. All changes are to rule files, templates, shell quality helpers, and test suites. The new `kind` and `signal_ref` fields are optional on existing slices; the `#### Coordination:` marker is optional on existing plan steps. No existing artifact produced before this change will fail the updated quality helpers.
