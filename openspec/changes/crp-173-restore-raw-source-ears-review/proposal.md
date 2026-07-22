## Why

The current EARS review can declare `no_findings: true` when the BR and EARS agree with each other after Task-to-BR has already lost or broadened a raw-story obligation. Step 5.1 must restore the legacy master review's independent raw-source recovery role while retaining the useful BR-to-EARS translation-consistency check.

## What Changes

- Make step 5.1 perform two explicit ordered semantic comparisons in its existing model session: raw `user_br_input.md` to BR/EARS for capture fidelity, then authoritative `feature_br_summary.md` to `requirements_ears.md` for translation fidelity.
- Make the raw story salient by inlining its captured story text into the existing EARS-review context, and bind plus inline the existing `missing_br_data.md` ledger as read-only clarification provenance.
- Replace the CRP-163 narrowing-only raw sweep with a complete raw-fidelity review covering lost obligations, removed guards, unsupported broadening, unsupported narrowing, contradictions, and invented behavior.
- Keep explicit operator clarifications evidenced by an answered `missing_br_data.md` item and its mapped `feature_br_summary.md` answer authoritative; a raw/summary discrepancy still becomes a finding for traceable operator disposition rather than being silently overwritten.
- Require a concrete `source_user_br_input_reference` for findings caused by raw-source drift and retain the literal `none` only for findings that arise solely from a clarified BR-to-EARS translation mismatch.
- Keep both comparisons in the existing `requirements_ears_review.md` ledger and the existing one-finding-at-a-time operator loop.
- Add behavioral acceptance evidence against the measured UMSS raw, BR, clarification-ledger, and EARS artifacts for the verified lost OFFCHAIN account-resolution precondition, while rejecting the template-conformant EARS system-name construction as a finding.

## Capabilities

### New Capabilities

- `dual-fidelity-ears-review`: One EARS-review session that independently checks raw capture fidelity and clarified-BR translation fidelity with source-appropriate findings and citations.

### Modified Capabilities

<!-- None. openspec/specs/ contains no consolidated dual-fidelity EARS-review capability. -->

## Impact

- `packages/installer/_data/skills/overmind-ears-review/SKILL.md` and its review golden example.
- EARS-review skill-contract, installer-propagation, and measured behavioral acceptance coverage.
- `packages/asdlc-coordinator/src/context/ears-review.ts` and its tests gain raw-story inlining plus a read-only binding for the existing `missing_br_data.md` clarification ledger.
- Existing review template fields, review artifact, mutable-artifact guards, interaction loop, and gate exit codes are reused.
- No new phase, artifact, command, CLI option, semantic validator, or model session is introduced.
