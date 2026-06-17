# Implementation Slice Planning Rule

Read this file fully before generating output.

## Purpose
- Generate implementation-driven executable slices before final ordered implementation-plan generation.
- Answer one question only:
  `What thin, executable slices should exist for this feature before Step 8.2 turns them into a fully ordered, fully traceable implementation plan?`
- Preserve required missing operator-facing surface delivery from upstream evidence so supporting-only slices cannot replace required surface outcomes.
- Produce deterministic output for `<TARGET_IMPLEMENTATION_SLICES_ARTIFACT>`.

## Ownership Boundaries
Owns:
- thin executable slice discovery across active repo classes
- recovery of execution shape that was flattened during Step 7 technical-requirements consolidation
- first usable increment framing per slice
- local prerequisite capture needed to begin implementation safely
- scaffold-aware frontend/mobile decomposition when relevant
- practical handoff notes for the later ordered implementation-plan phase
- explicit preservation of required missing operator-facing surfaces as feature-delivery slices

Must not own:
- full global step ordering across all slices
- full REQ/NFR-to-step coverage enforcement
- worker assignment/discovery
- architecture redesign unrelated to current feature inputs

## Authoritative Inputs And Outputs
- Read project/class scope from `<PROJECT_INIT_PROGRESS_DEFINITION_ARTIFACT>`.
- Read behavioral scope from `<REQUIREMENTS_EARS_ARTIFACT>`.
- Read current implementation state and technical evidence from `<TECHNICAL_REQUIREMENTS_ARTIFACT>`.
- Read contract prerequisites from `<FEATURE_CONTRACT_DELTA_ARTIFACT>`.
- Re-read applicable surface-map artifacts to recover repo execution context that may be flattened in technical requirements.
- Update only `<TARGET_IMPLEMENTATION_SLICES_ARTIFACT>`.
- Do not modify input artifacts.

## Scope Handling
- Generate implementation slices from the prompt-provided artifacts for the feature's active repo classes.
- Treat `project_type_code` as historical metadata only; do not branch slice generation on it.

## Output Format Baseline
- Use the prompt-provided template as structure contract.
- Use the prompt-provided golden example as style contract.
- Preserve sections and slice block structure.
- Keep each slice owned by one repo (`backend|frontend|mobile`).
- Use `status: existing|planned`.
- Slice headings describe executable slices, not final ordered implementation steps.
- Requirement refs on slice headings are optional hints only, not a completeness contract.
- Keep `ordering_scope: local_prerequisites_only` and `traceability_scope: slice_level_only`.
- Keep checklist bullets execution-shaped and concrete.
- Do not add lifecycle boilerplate bullets like `Plan and discuss the slice` or `Review slice readiness`; reserve that repeatable pattern for the later ordered implementation-plan phase.

## Planning Rules
- Start from `<TECHNICAL_REQUIREMENTS_ARTIFACT>` to identify concrete gaps and impacted components, but do not let its component/gap grouping dictate final slice boundaries.
- Re-open applicable surface maps when needed to recover execution structure lost during Step 7 consolidation, especially for thin or scaffold-heavy frontend/mobile repos.
- Use `<FEATURE_CONTRACT_DELTA_ARTIFACT>` for real contract, payload, schema, rollout, or compatibility prerequisites that affect whether a slice can begin.
- Use `<REQUIREMENTS_EARS_ARTIFACT>` to keep slices aligned with behavioral scope, but do not force full REQ/NFR coverage in this phase.
- For every required missing operator-facing surface identified by upstream requirement meaning and prerequisite evidence, include at least one explicit feature-delivery slice that delivers that surface itself.
- Supporting auth/API/contract/state/coordination slices may be added, but they never satisfy preserved operator-facing surface coverage on their own.
- Prefer the smallest meaningful delivery slice that either:
  - produces a first usable or admin-visible increment, or
  - cleanly unblocks another real slice.
- Pull first usable or admin-visible increments forward when feasible instead of burying them behind broad bucket work.
- When frontend/mobile repo state is thin, decompose slices by shell, composition, state, API adapter, UX behavior, or focused tests instead of collapsing them into one broad client bucket.
- Allow backend, frontend, and mobile slices to exist independently unless a real contract or state dependency blocks independence.
- Capture only local prerequisites needed to begin a slice safely; do not force full cross-repo ordering in this phase.
- Do not require every REQ id, NFR id, or evidence token to already appear in slice headings; Step 8.2 restores full ordering and traceability.
- Preserve operator-facing surface coverage semantically (page/screen/shell/route, CLI/admin tool/job/endpoint, or equivalent wording); do not rely on one hardcoded route literal, one UI framework label, or one delivery surface vocabulary.
- Mark assumptions as `[Inference]` when needed.

## Coordination Slices

- A coordination slice (`kind: coordination`) is optional and must be emitted only when at least one of the following conditions is met: shared contract semantics are materially ambiguous, multiple repos would otherwise implement incompatible interpretations, a concrete shared artifact must be frozen before safe parallel delivery, or a `cross_repo_contract_lock` signal in `technical_requirements.md` section 6 makes the drift risk explicit.
- Absence of any coordination slice is always a valid outcome; coordination slices must never be emitted reflexively based on scope alone.
- A coordination slice must carry both a `kind: coordination` field and a non-empty `signal_ref` field that identifies the upstream planning signal justifying the coordination work.
- Coordination slices are distinct from feature-delivery slices in intent; a coordination slice must not serve as the sole coverage for a required missing operator-facing surface.
- The following conditions are insufficient on their own to emit a coordination slice: multi-repo feature scope, `delta_needed: true` in `feature_contract_delta.md`, shared `comp/*` evidence overlap, or the presence of one or more planning signals.

## Final Self-Review
Before finishing, verify that:
- at least one slice exists,
- each slice has explicit repo ownership and evidence,
- local prerequisites are practical and minimal,
- slices remain thinner and more execution-shaped than the later final plan steps,
- required missing operator-facing surfaces remain represented by at least one explicit feature-delivery slice,
- supporting-only scaffolding slices are not substituted for required operator-facing surface delivery,
- frontend/mobile work was not flattened back into broad buckets just because technical requirements were consolidated,
- output remains slice-planning focused (not full ordered plan),
- no forbidden overreach (full ordering/full traceability enforcement) is introduced.

## Runtime Path Binding Rules
- Treat runtime bindings in prompt context as authoritative.
- Resolve outputs under runtime feature root.
- Do not hardcode `overmind/product/...` paths when runtime override is supplied.

## Completion Gate
- Before finalizing, run the prompt-provided quality gate command.
- If gate fails, revise and rerun.
- If gate compliance is not feasible with current inputs, use the prompt-provided failure line exactly.
- If gate passes, end with the prompt-provided success line exactly.
