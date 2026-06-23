## Context

Step 8.2 produces `prerequisite_gaps.md`, a per-EARS-requirement trace of externally-invocable prerequisites. CRP-140 migrated the step to the `overmind-prerequisite-gaps` skill + `asdlc-coordinator` TS gate (`validate/prerequisite-gaps.ts`) while preserving the legacy artifact shape one-for-one.

That shape nests one `#### Prerequisite:` block under each `### Requirement:`. A surface needed by N requirements (e.g. a shared login page or an account endpoint) is restated N times — ~3.3× bloat on real features. The full artifact is a required input to the step 8.3 implementation-plan model session, so the redundancy is paid in downstream context tokens, and the N restated copies of one `surface_identity`/`status` must be kept byte-identical by the model or the gate flags a spurious inconsistency.

Current consumers of `prerequisite_gaps.md` (all migrated to TS):
- **`validate/prerequisite-gaps.ts`** (this step's gate): iterates `#### Prerequisite:` blocks for per-block validation; runs a **global** EARS-literal cross-check (every URL/route/verb literal from `requirements_ears.md` must appear in some block's `evidence`/`slice_ref` or a `user_reachable_surface` in `technical_requirements.md`); global, not per-requirement.
- **`validate/implementation-plan.ts`** (step 8.3 gate): `parsePrerequisiteCatalog` scans `#### Prerequisite:` blocks **flat**, ignoring `### Requirement:` grouping, to extract scheduled `slice_ref`s (must be covered by a plan step `slice/<ref>` evidence token) and required-missing `surface_identity`s (crp-112 preservation).
- **`validate/implementation-slices.ts`** (step 8.1 gate, optional input): `extractRequiredMissingSurfaces` also scans `#### Prerequisite:` blocks flat for required-missing `surface_identity`s.

The decisive fact: **no downstream consumer depends on the per-requirement nesting**; all three read prerequisites as a flat set of `#### Prerequisite:` blocks. The nesting exists only for human/model traceability, and that is exactly what causes the duplication.

## Goals / Non-Goals

**Goals:**
- Declare each externally-invocable prerequisite surface exactly once.
- Preserve per-requirement traceability via lightweight references, not restatement.
- Keep the gate's per-block checks, global EARS-literal cross-check, and `0`/`1`/`2` exit-code contract behaviorally identical.
- Keep downstream step 8.1/8.3 gates working with zero logic change, locked by regression tests.
- Preserve crp-112 operator-facing-surface preservation semantics (`surface_identity` remains the key).

**Non-Goals:**
- Changing prerequisite-gaps context or sync modules (they do not parse the artifact body).
- Changing upstream steps (requirements/technical/slices) or their artifacts.
- Changing implementation-plan/slices gate logic (only add regression coverage).
- Introducing a machine-readable ID scheme beyond the human-readable prerequisite name.

## Decisions

### D1: Two-section schema — Prerequisite Catalog + Requirement Coverage
`prerequisite_gaps.md` becomes:
1. `## 1. Document Meta` — unchanged.
2. `## 2. Prerequisite Catalog` — one `#### Prerequisite:` block per **unique** surface, each with `status`/`surface_kind`/`surface_identity`/`evidence`/`slice_ref`. Declared exactly once across the whole feature.
3. `## 3. Requirement Coverage` — one `### Requirement:` block per in-scope `REQ-*`/`NFR-*`, each with `requirement_summary` and a `prerequisites:` line that either is `none` or references catalog entries.

Rationale: the catalog is precisely the flat set the downstream gates already read, so their parsers see the deduped catalog unchanged. Requirement blocks carry no `#### Prerequisite:` children, so they are invisible to the flat parsers.

Alternative considered: keep nesting but add a `shared_ref:` pointer on duplicates. Rejected — still restates the block skeleton and complicates every parser.

### D2: References key on the prerequisite name
The `#### Prerequisite:` heading text is the catalog key. `prerequisites:` in a requirement block is a `; `-separated list of catalog names (or `none`). Names must match a catalog heading exactly.

Rationale: `surface_identity` is `none` for present surfaces, so it cannot be the universal key; the heading name is already unique and human-meaningful. No new ID field is introduced.

Alternative considered: reference by `surface_identity`. Rejected — undefined for present surfaces and unstable across `unmet`→`scheduled` promotion.

### D3: Gate adds catalog- and reference-integrity checks
`validate/prerequisite-gaps.ts` is reworked to:
- Parse the catalog section into blocks and run the existing per-block rules (surface_kind, status, surface_identity, evidence, slice_ref, slice_ref format) unchanged.
- Fail (exit `1`) when a `#### Prerequisite:` heading appears outside the first `## 2. Prerequisite Catalog` section, so downstream flat parsers cannot consume a block that this gate skipped; reject catalog-field restatement in Requirement Coverage.
- Fail (exit `1`) when a catalog prerequisite name is declared more than once.
- Fail (exit `1`) when a `### Requirement:` `prerequisites:` reference names a prerequisite absent from the catalog (dangling reference).
- Fail (exit `1`) when a catalog entry is referenced by no requirement (orphan), to prevent catalog drift.
- Keep the **global** EARS-literal cross-check over catalog `evidence`/`slice_ref` + technical `user_reachable_surface`, unchanged in outcome (the catalog still holds all evidence).
- Keep exit `2` for runtime failures (absent target/siblings) and the whitespace-empty exit `1`, per CRP-140.

Rationale: catalog + reference integrity is the new invariant that replaces "the model kept N copies consistent." It is strictly local and deterministic.

### D4: Downstream gates unchanged; add regression tests
`implementation-plan.ts` and `implementation-slices.ts` keep their current flat `#### Prerequisite:` parsing. Add TS tests feeding a new-format `prerequisite_gaps.md` (catalog + references, incl. a shared surface) and asserting the same extracted `slice_ref`s / required surfaces as before.

Rationale: the compatibility is real but load-bearing; a regression test makes it enforced rather than assumed.

### D5: Golden example demonstrates sharing
The rewritten golden example includes one surface (e.g. an account endpoint) referenced by two requirements, proving the single-declaration payoff and giving the model a concrete pattern.

## Risks / Trade-offs

- [Risk] A downstream parser subtly depends on requirement nesting after all. → Mitigation: D4 regression tests assert byte-for-byte-equal extracted sets from a new-format fixture before merge; the parsers demonstrably flush on `### Requirement:` and key only on `#### Prerequisite:`.
- [Risk] Orphan-catalog-entry failure (D3) is stricter than legacy and could reject a valid artifact where a surface is intentionally unreferenced. → Mitigation: by definition a prerequisite exists because some requirement needs it; an unreferenced catalog entry is dead data. The failure message names the entry so the model either references or removes it.
- [Risk] Model emits reference names that drift from catalog headings (typos, casing). → Mitigation: exact-match resolution with an actionable "reference X does not resolve to any catalog entry" message drives a fast repair loop.
- [Trade-off] Reference-by-name adds one indirection a reader must resolve. → Accepted: the catalog is co-located in the same file and far smaller than the duplication it removes.
- [Risk] This is a BREAKING artifact-shape change relative to CRP-140, which is not yet archived. → Mitigation: crp-143 supersedes the CRP-140 schema requirement via a MODIFIED delta; both are applied on the same branch before archive, so no archived consumer observes the old shape.

## Migration Plan

1. Land the gate rework + new template/golden/SKILL.md together with updated and new tests.
2. `npm run build` and run the asdlc-coordinator + installer test suites; run the affected shell suites.
3. No data migration: prerequisite_gaps.md is regenerated per feature run; there is no persisted store to convert.
4. Rollback: revert the gate + asset changes; the CRP-140 nested schema and its gate remain intact in history.

## Open Questions

- Should an orphan catalog entry be a hard failure (D3) or a warning? Current decision: hard failure for tightness; revisit if it proves noisy in practice.
