## 1. Gate rework — catalog parsing and integrity

- [x] 1.1 In `packages/asdlc-coordinator/src/validate/prerequisite-gaps.ts`, restrict `#### Prerequisite:` block parsing to the `## 2. Prerequisite Catalog` section (blocks under `## 3. Requirement Coverage` are not prerequisite blocks), keeping the existing per-block validation (`surface_kind`, `status`, `surface_identity`, `evidence`, `slice_ref`, `slice_ref` format) unchanged.
- [x] 1.2 Add a catalog-integrity check that fails with exit `1` and names the offending entry when a `#### Prerequisite:` heading appears more than once in the catalog.
- [x] 1.3 Parse the `## 3. Requirement Coverage` section into `### Requirement:` blocks, each with `requirement_summary` and a `prerequisites:` value (`none` or a `; `-separated list of catalog names).
- [x] 1.4 Add a reference-resolution check that fails with exit `1` and names the offending reference when a `prerequisites:` entry does not match any catalog heading (dangling reference).
- [x] 1.5 Add an orphan check that fails with exit `1` and names the entry when a catalog `#### Prerequisite:` block is referenced by no requirement.
- [x] 1.6 Confirm the EARS-literal cross-check still runs globally over catalog `evidence`/`slice_ref` + technical `user_reachable_surface`, and keep the `0`/`1`/`2` exit-code contract and whitespace-empty handling from CRP-140 intact.

## 2. Skill assets

- [x] 2.1 Rewrite `packages/installer/_data/skills/overmind-prerequisite-gaps/assets/prerequisite_gaps_TEMPLATE.md` into `## 1. Document Meta`, `## 2. Prerequisite Catalog` (one `#### Prerequisite:` block per unique surface with all five fields), and `## 3. Requirement Coverage` (`### Requirement:` blocks with `requirement_summary` and a `prerequisites:` reference line).
- [x] 2.2 Rewrite `packages/installer/_data/skills/overmind-prerequisite-gaps/assets/prerequisite_gaps_GOLDEN_EXAMPLE.md` to the new structure, including one surface referenced by two requirements, one `scheduled_in_slices` entry promoted from `unmet` (stable `surface_identity`), and one requirement with `prerequisites: none`.
- [x] 2.3 Update `packages/installer/_data/skills/overmind-prerequisite-gaps/SKILL.md` field/output rules to describe declare-once catalog semantics, `prerequisites:` reference lists, reference resolution, and the no-restatement rule; keep the exact success/failure lines unchanged.
- [x] 2.4 Verify the rewritten golden example passes `node .overmind/overmind.js gate prerequisite-gaps` against a fixture feature (build first).

## 3. TS tests — prerequisite-gaps

- [x] 3.1 Update `packages/asdlc-coordinator/test/prerequisite-gaps-validator.test.ts` fixtures to the catalog + reference format.
- [x] 3.2 Add validator cases: duplicate catalog entry fails; dangling requirement reference fails; orphan catalog entry fails; fully cross-referenced artifact passes.
- [x] 3.3 Add a validator case proving a surface referenced by two requirements is declared once and its single evidence satisfies the EARS-literal cross-check.
- [x] 3.4 Keep/adapt the existing per-block and exit-code (`0`/`1`/`2`) cases against catalog-format fixtures.

## 4. Downstream compatibility — regression tests

- [x] 4.1 Add a test asserting `extractScheduledSliceRefs`/`extractImplementationPlanRequiredSurfaces` in `validate/implementation-plan.ts` return the expected sets from a new-format catalog `prerequisite_gaps.md` (no logic change to the module).
- [x] 4.2 Add a test asserting `extractRequiredMissingSurfaces` in `validate/implementation-slices.ts` returns the expected required surfaces from a new-format catalog `prerequisite_gaps.md` (no logic change to the module).
- [x] 4.3 Confirm no edits are needed in `validate/implementation-plan.ts` or `validate/implementation-slices.ts`; if any parser incidentally depended on requirement nesting, fix it minimally and note it.

## 5. Build, test, and verification

- [x] 5.1 Run `npm run build` from the repository root.
- [x] 5.2 Run `npm test --workspace packages/asdlc-coordinator` and `npm test --workspace packages/installer`; all pass.
- [x] 5.3 Run `bash tests/ai_scripts/project_add_feature_e2e_tests.sh`, `bash tests/ai_scripts/project_setup_asdlc_tests.sh`, and `bash tests/ai_scripts/project_setup_update_project_tests.sh`; all pass.
- [x] 5.4 Run `openspec validate crp-143-optimize-prerequisite-gaps --strict`; change is valid.
