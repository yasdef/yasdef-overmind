## 1. Canonical documentation audit

- [x] 1.1 Build a keep, shorten, remove, and link map for every current section of root `README.md` and `overmind/README.md`, assigning each retained detail to the document responsibility defined by the spec
- [x] 1.2 Cross-check the lifecycle stage and optional/per-class inventory against `packages/asdlc-coordinator/src/sequencing/step-catalog.ts`, public commands and paths against the CLI and installer quick-run generator, and exit `0`/`1`/`2` semantics against the runner contracts

## 2. Root product README

- [x] 2.1 Rewrite root `README.md` title, product purpose, maturity statement, installation, and first-time happy path as a concise entry point that links to the operator guide
- [x] 2.2 Add a high-level workspace-to-project-to-feature-planning-to-worker-handoff lifecycle, clearly state the planning/assignment product boundary, and identify `requirements_ears.md` and `implementation_plan.md` as critical human-review outputs
- [x] 2.3 Consolidate the public command summary and essential operator-facing concepts while preserving current limitations and contributor verification commands
- [x] 2.4 Remove historical release notes, internal decision shorthand, low-level per-skill inventory, duplicate CLI/input contracts, phase-specific validator mechanics, unfinished navigation prose, and stale duplication from root `README.md`

## 3. Durable operator README

- [x] 3.1 Rewrite `overmind/README.md` introduction with its operator audience, source-to-deployed runtime relationship, documentation-layer map, and workspace setup guidance
- [x] 3.2 Document project creation, class configuration, repository reconciliation, and project initialization steps `1`–`2` with consistent purpose, public command, prerequisite/input, output, and operator-checkpoint information
- [x] 3.3 Document feature intake and BR clarification steps `3`–`4.2`, EARS steps `5`–`5.1`, contract/surface steps `6`–`7.1`, and technical-planning steps `8`–`8.4` at comparable operator-facing detail, including optional and per-class markers
- [x] 3.4 Document worker registration and assignment as the implementation handoff, consolidate all public commands, and add one shared recovery section covering `run`, `--resume`, `status`, and exit `0`/`1`/`2`
- [x] 3.5 Add a concise primary-output and source-of-detailed-truth map, then remove selected-phase direct commands, literal source-reference rules, ledger-field algorithms, mutable-artifact gate inventories, and phase-specific repair instructions from `overmind/README.md`

## 4. Cross-document consistency

- [x] 4.1 Update `overmind/init_progress_definition_sequence_diagram.md` to identify itself as the canonical end-to-end process map while preserving `*_rule.md` authority for operational and quality rules
- [x] 4.2 Add or correct relative navigation among root `README.md`, `overmind/README.md`, the process map, generated `quickrun.md`, and owning rule/skill locations without copying the same detailed explanation
- [x] 4.3 Review both rewritten READMEs from start to finish and normalize terminology, command forms, lifecycle boundaries, stage granularity, and operator-facing tone

## 5. Verification

- [x] 5.1 Verify every canonical step `1` through `8.4`, including optional and per-class steps, is represented in `overmind/README.md`, and verify every documented command, output path, link target, and exit classification against its authoritative source
- [x] 5.2 Inspect the implementation diff and confirm it changes only the two READMEs, process-map wording/navigation, and CRP artifacts, with no runtime, template, rule, skill, CLI, or generated asset behavior change
- [x] 5.3 Run `npm run verify` from the repository root and resolve documentation or repository verification failures
