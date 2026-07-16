## Why

The migrated EARS review uses `feature_br_summary.md` as its sole business source, a behavior introduced by commit `c2a9db0`. In the measured old-versus-new run this coincided with a five-findings-versus-one review gap and allowed an `ACTIVE` qualifier to narrow the raw duplicate-account rule without a finding, so raw `user_br_input.md` must be restored as a drift-detection backstop without displacing clarified decisions recorded in the BR summary.

## What Changes

- Give the EARS-review context and skill both read-only business inputs: authoritative `feature_br_summary.md` and backstop `user_br_input.md`.
- Require a source-precedence rule: explicit clarified decisions in `feature_br_summary.md` remain authoritative; raw input independently detects loss, weakening, or narrowing between the original request, the BR summary, and EARS.
- Make every narrowing found in `feature_br_summary.md` or `requirements_ears.md` relative to raw input a mandatory material finding, including added qualifiers such as limiting duplicate-account protection to an `ACTIVE` existing account; summary authority controls resolution, not whether the discrepancy is surfaced.
- Extend the review ledger structure, examples, validator, and runtime context so findings can cite both the authoritative summary and the raw source.
- Protect both business inputs as immutable session inputs and fail context assembly when either required source is missing.
- Amend `design_docs/phase_refactoring_light_version/02_phase_redesign_and_target_architecture.md` `### F2 — Formal Requirements` so the future embedded verification pass retains the same authoritative-summary plus raw-input-backstop contract.

## Capabilities

### New Capabilities

- `ears-review-raw-input-backstop`: Dual-source EARS review with clarified-summary precedence, mandatory raw-source narrowing findings, traceable review records, and an aligned `02_phase_redesign_and_target_architecture.md` `### F2 — Formal Requirements` design.

### Modified Capabilities

<!-- None. openspec/specs/ contains no consolidated EARS-review capability. -->

## Impact

- `packages/installer/_data/skills/overmind-ears-review/SKILL.md` and its review template/golden-example assets.
- `packages/asdlc-coordinator/src/context/ears-review.ts`, `src/validate/ears-review.ts`, `src/runner/prompt-builder.ts`, and step `5.1` read-only guards in `src/sequencing/step-catalog.ts`.
- Coordinator and installer tests for dual-source context, missing inputs, immutable inputs, ledger shape, and installed skill/assets.
- `design_docs/phase_refactoring_light_version/02_phase_redesign_and_target_architecture.md` `### F2 — Formal Requirements` and concise operational documentation where the EARS-review input contract is described.
- No new CLI command or flag; `overmind context ears-review`, `overmind gate ears-review`, and the two mutable review artifacts remain unchanged.
