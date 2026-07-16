## Context

Overmind has five documentation layers that currently overlap: root `README.md`, `overmind/README.md`, generated `quickrun.md`, `overmind/init_progress_definition_sequence_diagram.md`, and phase rules/skills. Root `README.md` mixes product onboarding, design history, CLI reference, release notes, and phase mechanics. `overmind/README.md` is short but devotes most of its content to a few recently changed phases while omitting the rest of the lifecycle. This accretion makes operator guidance incomplete and causes CRPs to duplicate exact behavior that already has an owning rule, skill, or executable contract.

The refactor must preserve current runtime behavior and commands. Repository constraints keep durable operational guidance in `overmind/README.md`, make `*_rule.md` files authoritative for operational and quality rules, and discourage parallel documentation variants.

## Goals / Non-Goals

**Goals:**

- Give each existing documentation layer a clear audience and responsibility.
- Make the complete Overmind lifecycle understandable from product and operator perspectives.
- Keep every workflow stage at comparable detail rather than emphasizing the most recently changed phases.
- Centralize public commands, human checkpoints, outputs, and recovery semantics without copying validator internals.
- Remove stale, historical, duplicated, and CRP-specific README prose.
- Make future CRP documentation updates integrate with the whole document instead of appending isolated notes.

**Non-Goals:**

- Change runtime behavior, workflow sequencing, artifacts, validators, exit classifications, CLI commands, or flags.
- Rewrite normative phase rules, templates, golden examples, or packaged skill behavior.
- Add a new general workflow document or a new generated documentation system.
- Document worker execution or feedback ingestion as available functionality while those capabilities remain unimplemented.

## Decisions

### 1. Use the existing documents as layered navigation

- Root `README.md` becomes the repository and product entry point. It explains what Overmind does, installation, the shortest happy path, the lifecycle at a high level, essential concepts, human review points, current limitations, and contributor verification.
- `overmind/README.md` becomes the durable operator guide. It explains the complete operational lifecycle, public commands, prerequisites, outputs, decision points, and recovery behavior.
- Generated `quickrun.md` remains the installed-workspace command cheat sheet.
- `overmind/init_progress_definition_sequence_diagram.md` remains the canonical end-to-end process map.
- `*_rule.md` files remain authoritative for operational and quality requirements; packaged skills and executable contracts carry invocation and enforcement mechanics.

This reuses the current documentation structure. A single large README was rejected because it would again mix onboarding with phase mechanics. A new `docs/workflow.md` was rejected because it would create another overlapping process source.

### 2. Rewrite both READMEs around stable information architecture

Root `README.md` will use this structure:

1. Product purpose and current maturity
2. Installation and first-time happy path
3. Lifecycle at a glance
4. Essential concepts that affect operator choices
5. Human checkpoints and produced planning outputs
6. Public command summary
7. Current limitations
8. Contributor verification and documentation links

`overmind/README.md` will use this structure:

1. Purpose, audience, and deployed-runtime relationship
2. Runtime asset and documentation map
3. Workspace setup
4. Project lifecycle
5. Feature-planning lifecycle
6. Worker registration and assignment handoff
7. Public command reference
8. Operator checkpoints and recovery
9. Output artifacts and sources of detailed truth

Incremental preservation of the present headings was rejected because the current headings encode the inconsistency: root content is organized partly by history and implementation inventory, while the operator guide has isolated headings for only recently changed behavior.

### 3. Describe lifecycle stages uniformly

The operator guide will group the canonical catalog into operator-meaningful stages while retaining step identifiers and optional/per-class status where useful:

- Workspace setup
- Project creation, class configuration, repository reconciliation, and project initialization (`1`–`2`)
- Feature scaffold, source capture, repository scan, and BR clarification (`3`–`4.2`)
- EARS generation and optional review (`5`–`5.1`)
- Contract delta, per-class surface mapping, and optional enrichment (`6`–`7.1`)
- Technical requirements, slices, prerequisite gaps, implementation plan, and optional semantic review (`8`–`8.4`)
- Worker registration and plan assignment handoff

Each stage will state its purpose, public entry command, material prerequisite or input, primary output, and operator decision or checkpoint. Exact prompts, literal artifact fields, mutable-artifact sets, gate inventories, and repair algorithms will remain in their owning sources.

### 4. Explain recovery once as a cross-cutting operator contract

`overmind/README.md` will explain the stable `0`/`1`/`2` meaning once and describe `run`, `--resume`, and `status` together. Phase sections may state that a stage can pause or require repair, but they will link back to the shared recovery section instead of repeating gate-specific algorithms.

Operator-visible exceptions, such as prerequisites that redirect from `run` to `project init` or `project reconcile`, remain documented. Internal gate-to-artifact mappings and exact ledger-field repairs do not.

### 5. Remove rather than relocate non-operational history

Historical version notes and internal decision identifiers are removed from the READMEs rather than moved into another workflow document. Git history and release metadata already retain historical change information. Current limitations remain because they affect product expectations.

The sequence diagram introduction will call it the canonical process map instead of an unqualified single source of truth, preserving the repository rule that `*_rule.md` files own normative operational and quality behavior.

### 6. Verify documentation against executable sources

Implementation will cross-check stage identifiers and optional/per-class behavior against `packages/asdlc-coordinator/src/sequencing/step-catalog.ts`, public commands against the CLI and generated quick-run guide, installed asset paths against the installer, and exit semantics against the runner. Documentation-only verification will include link/path searches and existing repository checks; no runtime behavior tests are required unless an executable source is changed unexpectedly.

## Risks / Trade-offs

- **Risk: Concision removes an operator-important exception.** → Preserve behavior that changes the next operator action, and move only literal mechanics or enforcement algorithms out of the READMEs.
- **Risk: The two READMEs still repeat the happy path.** → Root `README.md` carries only the shortest onboarding path; `overmind/README.md` owns explanations and recovery.
- **Risk: Generated `quickrun.md` drifts from the operator guide.** → Treat it as a command cheat sheet and link to it by role; do not copy its complete low-level context/gate inventory into either README.
- **Risk: Grouped stages obscure canonical step numbers.** → Include step ranges and links to the canonical process map while keeping prose product-readable.
- **Trade-off: Removing release notes reduces historical visibility in the README.** → Prefer current, actionable documentation; history remains available through version control and release metadata.

## Migration Plan

1. Rewrite root `README.md` using the entry-point structure and remove duplicate/historical sections.
2. Rewrite `overmind/README.md` using the complete operator lifecycle and shared recovery model.
3. Adjust the process-map authority wording and add or correct cross-document links.
4. Compare commands, steps, outputs, optionality, and recovery statements with executable sources.
5. Run documentation-oriented repository verification and review the final READMEs as complete documents.

Rollback is a normal documentation revert; there is no data or runtime migration.

## Open Questions

None. The existing repository documents are sufficient for this refactor.
