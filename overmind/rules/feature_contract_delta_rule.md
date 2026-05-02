# Feature Contract Delta Rule

Read this file fully before generating output.

## Purpose
- Convert feature-level EARS requirements into a contract delta artifact against the stable
  project baseline in `common_contract_definition.md`.
- Answer one question only:
  `What shared contract additions or changes does this feature require beyond the existing baseline?`
- Produce deterministic output for `<FEATURE_CONTRACT_DELTA_TARGET_ARTIFACT>`.

## Ownership Boundaries
Owns:
- feature-specific shared contract additions/changes
- compatibility impact statements for those feature-specific deltas
- per-track handoff signals derived from the feature delta

Must not own:
- redefinition of stable cross-project baseline contracts (already in `common_contract_definition.md`)
- full repository structure analysis
- technical implementation breakdown

## Authoritative Inputs and Outputs
- Read-only feature context source: `<FEATURE_BR_SOURCE_ARTIFACT>`.
- Read-only feature EARS source: `<EARS_SOURCE_ARTIFACT>`.
- Read-only baseline source: `<COMMON_CONTRACT_BASELINE_ARTIFACT>`.
- Output target: `<FEATURE_CONTRACT_DELTA_TARGET_ARTIFACT>`.
- Do not modify input artifacts.
- Do not create or modify unrelated files.

## Output Format Baseline
- Use `.templates/feature_contract_delta_TEMPLATE.md` as structure contract.
- Use `.golden_examples/feature_contract_delta_GOLDEN_EXAMPLE.md` as style contract.
- Preserve heading order and key names:
  - `## 1. Document Meta`
  - `## 2. Delta Summary`
  - `## 3. Contract Delta Items`
  - `## 4. Track Handoff Signals`

## Delta Rules
- Compare the requested feature behavior (`<EARS_SOURCE_ARTIFACT>`) against baseline
  shared contracts (`<COMMON_CONTRACT_BASELINE_ARTIFACT>`).
- Include only feature-level changes; do not restate unchanged baseline contracts.
- Set `delta_needed: true` when one-or-more feature-level contract changes are required.
- Set `delta_needed: false` only when no shared contract change is needed.
- If `delta_needed: true`:
  - provide one-or-more `### Delta N:` blocks,
  - keep one independent contract delta per block,
  - add `Delta 2`, `Delta 3`, and further blocks as needed (open-ended count),
  - each block must include exactly:
    `delta_kind`, `related_baseline_contract`, `change_scope`,
    `compatibility_impact`, and `verification_expectation`.
- If `delta_needed: false`:
  - remove Delta blocks,
  - include exact line: `- no_contract_delta_required: true`,
  - explain why in `no_delta_reason`.

## Evidence Rules
- Prefer facts from the input artifacts.
- Keep inferences minimal; when needed, mark with `[Inference]`.
- Do not invent new business behavior outside `<EARS_SOURCE_ARTIFACT>`.
- Keep statements concise and testable.

## §5 Cross-Class Transport/Contract Approach Mirror
- Determine whether §5 applies by running the runtime-bound cross-class peer trigger helper (see prompt context). It exits 0 and prints `cross_class_peer_trigger: active` when the §5 mirror applies, or `cross_class_peer_trigger: inactive` when it is a no-op. Omit the `## 5. Cross-Class Transport/Contract Approach Mirror` section entirely on `inactive`.
- When active, write one `### Backend: <identity>` block per active backend, mirroring the current `transport_protocol` and `schema_format` from `common_contract_definition.md` §7 verbatim by default.
- When this feature defines or refines those values, record the concrete values directly in this section regardless of whether `common_contract_definition.md` carries the placeholder or different concrete values for that backend.
- Do not introduce a resolution state machine, terminal-state field, required block, or quality-gate enforcement for §5; concrete values or the literal `<to be defined during first feature implementation plan>` placeholder are the only valid shapes.

## Runtime Path Binding Rules
- Runtime bindings provided by the caller are authoritative.
- Write only to `<FEATURE_CONTRACT_DELTA_TARGET_ARTIFACT>`.
- Do not hardcode repository-local `overmind/product/...` paths.

## Completion Gate
- Before finalizing, run the runtime-provided quality gate command:
  - `<FEATURE_CONTRACT_DELTA_GATE_COMMAND>`
- Gate pass condition:
  - command exits `0`.
- Gate fail condition:
  - command exits non-zero with one-or-more quality errors.
- On gate failure:
  - revise output using helper feedback and rerun the gate.
  - if gate cannot pass with current inputs/constraints, stop and end with this exact line:
    `feature contract delta gate cannot pass with current EARS/common-contract inputs. Please provide instructions what to do, or adjust requirements and rerun this phase`
- If gate passes, end final response with this exact last line:
  `Feature contract delta phase is finished. Nothing else to do now; press Ctrl-C so orchestrator can start the next phase`
