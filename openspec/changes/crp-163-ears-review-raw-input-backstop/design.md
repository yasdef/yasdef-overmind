## Context

The original EARS-review pipeline compared `requirements_ears.md` directly with `user_br_input.md`. Commit `c2a9db0` changed the sole source to `feature_br_summary.md`; that fixed the immediate source-of-truth concern but removed independent visibility of information lost or weakened during task-to-BR compression. In the measured comparison, the old review raised five findings while the migrated review raised one, and the migrated path missed a material narrowing: the raw story prohibited duplicate accounts for the same user and account type, while the summary/EARS path limited protection to an existing `ACTIVE` account.

The current TypeScript runtime binds only `feature_br_summary.md` in `buildEarsReviewContext`, protects only that BR source in step `5.1`, and describes only that source in the installed skill, review template, golden example, and validator. The light-version target architecture repeats the same sole-source design in `design_docs/phase_refactoring_light_version/02_phase_redesign_and_target_architecture.md` `### F2 — Formal Requirements`.

## Goals / Non-Goals

**Goals:**

- Restore `user_br_input.md` as an independent, read-only drift-detection input to EARS review.
- Preserve `feature_br_summary.md` as the authority for clarified business decisions.
- Make narrowing from raw input into either the BR summary or EARS impossible to ignore silently: every such discrepancy is a material finding with source references.
- Keep the current context/skill/gate CLI and two-artifact write surface.
- Carry the same dual-source contract into `02_phase_redesign_and_target_architecture.md` `### F2 — Formal Requirements`.

**Non-Goals:**

- No deterministic semantic parser for natural-language narrowing.
- No source-coverage ledger, terminal gate chain, or post-session mutable-artifact gate recheck.
- No changes to task-to-BR decomposition, BR clarification, or EARS syntax validation.
- No automatic overwrite of clarified summary decisions from raw input.

## Decisions

### D1: Use the BR summary as decision authority and raw input as a mandatory drift backstop

The review performs two comparisons in one semantic sweep:

1. Treat `feature_br_summary.md` as the authoritative expected behavior when it records a clarified decision.
2. Compare both `feature_br_summary.md` and `requirements_ears.md` with `user_br_input.md` for lost, weakened, or narrowed raw obligations.

Every narrowing relative to raw input is recorded as a finding; the summary's authority controls the recommended resolution, not whether the discrepancy is surfaced. The skill must not silently replace a clarified summary decision with raw wording. If the summary clearly records an intentional clarification, the finding cites that decision and asks the operator to confirm or retain it through the normal review disposition. If the narrowing is not explained by a clarified decision, the finding recommends restoring the broader raw obligation. An added condition or qualifier that permits behavior forbidden by the raw story is narrowing; the motivating example is adding `ACTIVE` to an otherwise status-independent duplicate-account prohibition.

This favors auditable false positives over silent semantic weakening at the final business-requirements gate. Alternative considered: use raw input only, matching the oldest implementation exactly. Rejected because it would discard clarified decisions already consolidated into `feature_br_summary.md` and force unnecessary source conflicts.

### D2: Bind and protect both sources through the existing context and session guard mechanisms

`buildEarsReviewContext` requires `feature_br_summary.md`, `user_br_input.md`, and `requirements_ears.md`. It emits distinct, unambiguous bindings for the authoritative summary and raw backstop. The EARS-review session prompt recipe names both read-only artifacts before directing the model to the context command. Missing either business source is exit `2`, because review without one side cannot satisfy the dual-source contract.

Step `5.1` declares both business files under a dedicated `mustExistUnchanged` read-only guard. It does not widen the shared `brSummaryGuard` used by step `5`, so the `requirements-ears` generation contract continues to require only `feature_br_summary.md`. This keeps the executor generic and preserves the existing review write surface: only `requirements_ears.md` and `requirements_ears_review.md` are mutable. Alternative considered: rely only on the skill instruction not to edit inputs. Rejected because the coordinator already has deterministic read-only enforcement for session inputs.

### D3: Make dual-source reasoning durable in the review ledger

The review template and golden example add `source_user_br_input` to document metadata and `source_user_br_input_reference` to each finding while retaining `source_feature_br_summary` and `source_br_summary_reference`. A finding not motivated by raw-source drift uses the literal `none` for `source_user_br_input_reference`; a raw-narrowing finding must cite a concrete raw location. The validator requires the new metadata and finding field structurally, while semantic correctness remains the model-owned review responsibility.

The golden example includes a raw duplicate-account rule narrowed by an `ACTIVE` qualifier so the intended finding quality is concrete. Alternative considered: overload `source_br_summary_reference` with either source. Rejected because it would make it impossible to audit the raw-to-summary-to-EARS comparison unambiguously.

### D4: Keep operational rules in the installed skill and structure in assets

The installed `overmind-ears-review` `SKILL.md` owns precedence, narrowing detection, mandatory-finding behavior, and interaction rules. Its template defines only required fields and layout; its golden example illustrates the target. The TypeScript context emits paths and write boundaries but does not duplicate semantic instructions.

### D5: Amend `02_phase_redesign_and_target_architecture.md` `### F2 — Formal Requirements` in the same change

`design_docs/phase_refactoring_light_version/02_phase_redesign_and_target_architecture.md` `### F2 — Formal Requirements` is updated so its mandatory embedded verification pass checks EARS against the authoritative summary and independently sweeps raw input for narrowing. This prevents the planned consolidated pipeline from reintroducing the sole-summary weakness.

## Risks / Trade-offs

- [Raw wording and clarified decisions can legitimately differ, increasing review findings] → Keep summary precedence explicit and resolve discrepancies through the existing operator disposition loop rather than automatically reverting to raw text.
- [A model may still miss a semantic narrowing] → Put the obligation in the normative skill, add the concrete `ACTIVE` counterexample to the golden example, and add static contract tests plus an implementation smoke fixture for the dual-source scenario.
- [Existing review ledgers lack the new fields] → Gate failures are recoverable exit `1`; rerunning EARS review upgrades the ledger using the current template while preserving prior findings. When a future terminal artifact-chain check is introduced, pre-dual-source ledgers must be regenerated or upgraded before that check can pass; absence of raw-source evidence is not conditionally grandfathered.
- [Top-level legacy template/example copies can diverge from packaged skill assets] → Treat `packages/installer/_data/skills/overmind-ears-review/` as the deployed source and verify installed Codex and Claude copies through installer tests; do not revive deleted shell-step ownership.

## Migration Plan

1. Update the EARS-review context, step `5.1` guards, installed skill, assets, validator, and tests as one atomic contract change.
2. Amend `02_phase_redesign_and_target_architecture.md` `### F2 — Formal Requirements` and concise operational documentation.
3. Run coordinator, installer, and repository verification suites, then smoke the `ACTIVE`-qualifier scenario in a temporary installed workspace.

Rollback restores the sole-summary context/skill/assets/validator contract and removes the additional read-only guard; no runtime data migration is required.

## Open Questions

- None blocking. Whether a future deterministic coverage ledger should supplement semantic narrowing review remains separate hardening work.
