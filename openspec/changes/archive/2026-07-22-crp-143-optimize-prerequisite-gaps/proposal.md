## Why

Step 8.2's `prerequisite_gaps.md` restates every prerequisite block verbatim under each EARS requirement that needs it, so a surface shared across N requirements is written out N times. On real features this inflates the artifact ~3.3×, and that redundant text is fed downstream into the step 8.3 implementation-plan model context. The duplication also creates N copies of the same `surface_identity`/`status` that the model must keep byte-consistent, which is a correctness hazard rather than a help. This change normalizes the artifact so each prerequisite surface is declared exactly once.

## What Changes

- **BREAKING (artifact schema):** Restructure `prerequisite_gaps.md` into two sections: a **Prerequisite Catalog** that declares each externally-invocable surface exactly once (one `#### Prerequisite:` block with `status`/`surface_kind`/`surface_identity`/`evidence`/`slice_ref`), and a **Requirement Coverage** section where each `### Requirement:` block lists lightweight references to catalog entries by name (or `prerequisites: none`) instead of restating their fields.
- Rework the gate `packages/asdlc-coordinator/src/validate/prerequisite-gaps.ts`: validate catalog blocks with the existing per-block rules; additionally enforce catalog integrity (each prerequisite name declared once) and reference integrity (every `### Requirement:` reference resolves to a catalog entry, and every catalog entry is referenced by at least one requirement). The EARS-literal cross-check and exit-code contract (`0`/`1`/`2`) are unchanged.
- Rewrite the skill assets `packages/installer/_data/skills/overmind-prerequisite-gaps/assets/prerequisite_gaps_TEMPLATE.md` and `prerequisite_gaps_GOLDEN_EXAMPLE.md` to the catalog + reference structure, with a golden example that demonstrates one surface shared by multiple requirements.
- Update the inlined field/output rules in `packages/installer/_data/skills/overmind-prerequisite-gaps/SKILL.md` to describe declare-once catalog semantics and reference resolution.
- Update the prerequisite-gaps TS tests (validator + golden fixtures) and add regression tests proving the migrated downstream gates (`validate/implementation-slices.ts`, `validate/implementation-plan.ts`) consume the new catalog format correctly.

## Capabilities

### New Capabilities
<!-- none: this refines an existing capability -->

### Modified Capabilities

- `prerequisite-gaps`: The `prerequisite_gaps.md` artifact schema becomes a declare-once catalog plus per-requirement references, and the gate gains catalog-integrity and reference-resolution validation while preserving the existing per-block checks, EARS-literal cross-check, and exit-code contract.

## Impact

- **Modified:** `packages/asdlc-coordinator/src/validate/prerequisite-gaps.ts` (catalog parse + reference resolution), `packages/installer/_data/skills/overmind-prerequisite-gaps/assets/prerequisite_gaps_TEMPLATE.md`, `packages/installer/_data/skills/overmind-prerequisite-gaps/assets/prerequisite_gaps_GOLDEN_EXAMPLE.md`, `packages/installer/_data/skills/overmind-prerequisite-gaps/SKILL.md`, and the prerequisite-gaps TS tests.
- **Verified compatible, no logic change:** `packages/asdlc-coordinator/src/validate/implementation-slices.ts` and `packages/asdlc-coordinator/src/validate/implementation-plan.ts` already parse `#### Prerequisite:` blocks flat and ignore `### Requirement:` grouping, so they read the catalog unchanged; locked with regression tests. The crp-112 operator-facing-surface preservation key (`surface_identity`) is retained one-for-one, now declared once.
- **Not changed:** the prerequisite-gaps context and sync modules (they do not parse the artifact body), upstream steps (requirements/technical/slices), and the gate's exit-code contract.
- **Builds on:** the CRP-140 migration (skill + `asdlc-coordinator` TS primitives); no new runtime dependency.
- **Out of scope:** any change to steps 8.1/8.3/8.4 model semantics beyond confirming input compatibility; the cross-step orchestrator.
