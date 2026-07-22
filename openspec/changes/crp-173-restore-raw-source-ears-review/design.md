## Context

The legacy master step 5.1 compared `requirements_ears.md` directly with `user_br_input.md` and surfaced material source gaps, unsupported behavior, and missing boundaries. Commit `c2a9db0` changed the review source to `feature_br_summary.md`; CRP-163 later restored the raw file only as a narrowing backstop while keeping the summary authoritative. The measured v3 run then lost the raw precondition that account resolution applies to a registered Telegram user with an OFFCHAIN_POINTS account, copied that broader behavior through BR and EARS, and produced `no_findings: true`.

The failed CRP-163 configuration exposed only file paths in EARS-review context, unlike Task-to-BR context, which places the captured story in the model prompt. EARS review also lacks the `missing_br_data.md` ledger needed to distinguish an explicit operator clarification from an unsupported BR addition. The correction therefore changes both the model-owned review rule and the existing context assembly while retaining the same phase, artifacts, model session, review ledger, and deterministic validator.

## Goals / Non-Goals

**Goals:**

- Restore the raw story as an independent capture-fidelity source in step 5.1.
- Retain the clarified BR as authority for operator decisions and as the source for BR-to-EARS translation review.
- Present raw story content and explicit clarification provenance directly in the assembled review context.
- Detect semantic drift in both directions, not only added narrowing qualifiers.
- Keep finding provenance truthful for raw-derived and BR-only findings.
- Demonstrate recovery on the measured UMSS artifacts over repeated review runs.

**Non-Goals:**

- Add another review phase, source artifact, semantic validator, model call, or operator checkpoint.
- Automatically overwrite an explicit clarified BR decision with earlier raw wording.
- Require a fabricated raw citation for a translation finding based solely on a clarified BR decision.
- Change the current review states, one-finding-at-a-time interaction, mutable artifacts, or gate exit codes.

## Decisions

### 1. Run two ordered comparisons in the existing review session

The EARS-review skill will define two passes:

1. **Capture fidelity:** compare `user_br_input.md` with both `feature_br_summary.md` and `requirements_ears.md` for lost obligations, removed or added guards, unsupported broadening, unsupported narrowing, actor or state changes, contradictions, and invented behavior.
2. **Translation fidelity:** compare the authoritative clarified `feature_br_summary.md` with `requirements_ears.md` for missing, altered, or extra behavior.

The passes share the current findings ledger and operator loop. A single issue spanning both comparisons remains one finding and cites both sources.

Alternative considered: keep the CRP-163 mandatory narrowing sweep and append separate rules for broadening and omissions. Rejected because it would layer more exceptions onto a narrow workaround; one complete raw-fidelity definition is shorter and covers the legacy review responsibility directly.

### 2. Preserve clarified-decision authority without hiding discrepancies

An explicit operator decision is established by paired evidence: an answered `rised=true` item in `missing_br_data.md` whose `source=` locator names an affected BR field, and the resolved answer recorded in that mapped `feature_br_summary.md` field. That decision remains the expected current behavior. If it differs from raw wording, step 5.1 still records the discrepancy, cites both locations, and asks the operator whether to retain the clarification; it does not silently replace the BR with raw text.

An `Answer:` fragment or `confirmed_assumptions` text in the BR without a corresponding answered ledger item is not sufficient clarification provenance for the migrated flow. When the summary contains additional behavior without the paired evidence, the raw-fidelity pass treats it as potentially invented and raises a finding. This recovers the legacy review's ability to question unsupported additions while avoiding automatic rollback of legitimate answers.

Alternative considered: make raw input unconditionally authoritative. Rejected because step 4.2 exists specifically to turn later operator answers into the current BR source of truth.

### 3. Make citation requirements depend on finding origin

Every finding caused by raw-source drift uses a concrete `source_user_br_input_reference` and a concrete `source_br_summary_reference` when a corresponding summary location exists. A finding caused only by translation from an explicit clarified BR may use `source_user_br_input_reference: none`.

The literal `none` is not a general escape from reading raw input: the skill permits it only after the raw-fidelity pass confirms that the finding is unrelated to raw drift. Existing validator behavior and fields remain sufficient.

Alternative considered: prohibit `none` for every finding. Rejected because it would force fabricated raw provenance for decisions introduced legitimately during clarification and still would not constrain the `no_findings: true` path, where no finding fields exist.

### 4. Put raw story and clarification provenance in the existing context

The EARS-review context builder will continue to emit the authoritative BR, raw-input, EARS, and review-ledger paths. It will additionally require and emit the read-only `missing_br_data.md` path, inline the captured raw story text under a dedicated context heading using the existing Task-to-BR parsing pattern, and inline the clarification ledger under a separate read-only heading. A missing clarification ledger is a context error because current step 4.1 always creates or refreshes that artifact.

The BR and EARS remain path-bound artifacts that the review already reads and, for EARS, edits. Inlining the independent raw comparison source removes the failed context asymmetry without creating another model call or context mechanism. Inlining the typically small clarification ledger makes the source-precedence discriminator resolvable from the prompt.

The existing validator remains limited to ledger shape, required metadata, citations, finding states, and the `no_findings` terminal form; it cannot prove natural-language semantic coverage. Citation validation is not used as the discovery mechanism because it applies only after a finding exists and cannot prevent a false `no_findings: true` result.

Alternative considered: retain path-only raw binding and change only the skill prose, as CRP-163 did. Rejected because that leaves the primary independent comparison source outside the prompt and repeats the configuration that produced the measured false `no_findings: true` result.

### 5. Use measured defects as behavioral acceptance

One acceptance batch contains three clean review runs over frozen copies of the measured v3 raw, BR, clarification ledger, and EARS artifacts. The v3 review produced `no_findings: true` and made no EARS edit, so its current `requirements_ears.md` is the pre-review EARS state; it must be frozen with the other inputs before CRP-172 can change the BR baseline.

Every run in an accepted batch must identify the removed OFFCHAIN_POINTS-account precondition in account resolution as raw capture drift. A review must not report the administration-frontend display statement merely because the mandated EARS form uses `THE User Management Service System` in its single system-name slot; master uses the same conformant construction.

No second material BR-to-EARS defect was verified in the measured v3 fixture: the literal `User counts not working.` copy exists only in master's clarified BR, and v3's functional/NFR count-load split mirrors separate functional and security clauses in the v3 BR. Translation-fidelity behavior remains covered by the golden example and contract tests using an unambiguous clarified-BR omission or alteration; it is not fabricated as a measured finding.

If any run misses the raw-drift finding, the whole batch fails. The implementer does not extend a failed batch with extra samples: they identify the missed comparison obligation, revise the skill, context presentation, or example within this CRP, rerun contract verification, and start one fresh three-run batch. If that replacement batch also fails, the CRP remains behaviorally incomplete and returns to the owner for explicit disposition before acceptance is changed or further batches are run.

Alternative considered: accept a passing `no_findings` ledger gate as completion. Rejected because the measured defective ledger already passes that structural gate.

## Risks / Trade-offs

- [Risk] Raw/summary differences from legitimate clarification can create false alarms. → Mitigation: bind the answered clarification ledger, require paired ledger-to-BR evidence, preserve clarified-decision precedence, and ask for disposition rather than auto-editing.
- [Risk] Two comparisons can produce duplicate findings. → Mitigation: require one issue per finding and merge evidence when the same drift crosses raw, BR, and EARS.
- [Risk] Model variability can still miss a semantic issue. → Mitigation: fail the complete batch on a miss, allow one corrected fresh batch, and require owner disposition after a second failed batch rather than accumulating favorable samples.
- [Risk] Inlining source text increases prompt size. → Mitigation: inline only the parsed captured story and the small clarification ledger; keep the BR and EARS on their existing paths.
- [Risk] More review categories can expand prose. → Mitigation: replace the narrowing-only section with one compact fidelity taxonomy instead of appending categories.

## Migration Plan

1. Freeze the current measured v3 raw, BR, clarification-ledger, and EARS inputs; the current EARS file is the pre-review state because the original review made no edits.
2. Update EARS-review context assembly to require the existing clarification ledger and inline both the captured raw story and clarification evidence.
3. Rewrite the EARS-review purpose, precedence, and review-scope sections as the two ordered comparisons with paired clarification evidence.
4. Replace the narrowing-only worked example in the golden example with representative raw-loss/broadening evidence while retaining a genuine BR-only translation finding with `source_user_br_input_reference: none`.
5. Update context, contract, and installer tests for source presentation, the complete raw-fidelity taxonomy, and source-appropriate citations; retain existing validator behavior.
6. Run the existing coordinator, installer, and repository verification suites.
7. Install the candidate skill into clean runtime workspaces and run one three-run batch over the frozen v3 inputs.
8. On a missed required finding, revise the contract or context and run one fresh batch; after a second failed batch, keep acceptance incomplete and return to the owner.

Rollback is a normal revert of the skill, golden example, and tests; the artifact schema and stored review files do not migrate.

## Open Questions

None.
