---
name: overmind-contract-delta
description: Use when defining feature_contract_delta.md from EARS requirements and the project common-contract baseline.
---

# Overmind Contract Delta

Use this skill for step 6 to define only the feature-specific shared contract additions or changes beyond `common_contract_definition.md`.

## Required Invocation

Run these commands from the installed ASDLC workspace root:

1. Assemble deterministic context:

```bash
node .overmind/overmind.js context contract-delta <feature-path>
```

2. Read the emitted context block and write only `<feature-path>/feature_contract_delta.md`.

3. Validate after every write or repair:

```bash
node .overmind/overmind.js gate contract-delta <feature-path>
```

Handle gate exit codes exactly:

- `0`: gate passed; finish.
- `1`: recoverable artifact issue; read every `missing: quality gate failed: ...` line, repair only `feature_contract_delta.md`, and rerun the gate.
- `2`: validation cannot complete; stop, report the blocker, and wait for operator instructions without further edits.

The model owns the context/write/gate/repair loop. Ask the operator only for missing human decisions; do not ask for paths, repo state, trigger values, or validation details supplied by context and gate.

If gate compliance is not feasible with the current EARS/common-contract inputs, briefly explain the blocker and end with this exact line:

```text
feature contract delta gate cannot pass with current EARS/common-contract inputs. Please provide instructions what to do, or adjust requirements and rerun this phase
```

When the gate passes, end the final response with this exact last line:

```text
Feature contract delta phase is finished. Nothing else to do now; press Ctrl-C so orchestrator can start the next phase
```

## Assets

Asset paths are relative to this loaded skill directory. Use the current runner's installed copy; do not hardcode `.codex/skills/...`, `.claude/skills/...`, or source-repository paths.

- `assets/feature_contract_delta_TEMPLATE.md`
- `assets/feature_contract_delta_GOLDEN_EXAMPLE.md`

## Inlined Feature Contract Delta Rule

### Purpose

- Compare feature-level EARS requirements with the stable project baseline.
- Answer only: what shared contract additions or changes does this feature require beyond the baseline?
- Produce deterministic `feature_contract_delta.md` output.

### Ownership and Authoritative Inputs

- Read `feature_br_summary.md`, `requirements_ears.md`, project `common_contract_definition.md`, and context-listed pending sibling `feature_contract_delta.md` files as read-only inputs.
- Write only the current feature's `feature_contract_delta.md`.
- Keep stable cross-project baseline contracts in `common_contract_definition.md`.
- Keep repository structure analysis and technical implementation breakdown in their owning downstream steps.
- Do not create or modify unrelated files.

### Output Format Baseline

- Use `assets/feature_contract_delta_TEMPLATE.md` as the structure contract.
- Use `assets/feature_contract_delta_GOLDEN_EXAMPLE.md` as the style contract.
- Preserve these headings and key names:
  - `## 1. Document Meta`
  - `## 2. Delta Summary`
  - `## 3. Contract Delta Items`
  - `## 4. Track Handoff Signals`

### Delta Rules

- Compare `requirements_ears.md` against `common_contract_definition.md`.
- Include feature-level changes only; do not restate unchanged baseline contracts.
- Set `delta_needed: true` when one or more feature-level shared contract changes are required.
- Set `delta_needed: false` only when no shared contract change is needed.
- For `delta_needed: true`, add one `### Delta N:` block per independent delta, with an open-ended count. Every block contains exactly `delta_kind`, `related_baseline_contract`, `change_scope`, `compatibility_impact`, and `verification_expectation`.
- For `delta_needed: false`, remove all Delta blocks, include the exact line `- no_contract_delta_required: true`, and explain the decision in `no_delta_reason`.

### Evidence Rules

- Prefer facts from the read-only inputs.
- Keep inferences minimal and mark each one with `[Inference]`.
- Do not invent business behavior outside `requirements_ears.md`.
- Keep statements concise and testable.
- Treat every context entry `Pending contract delta source: <folder>/feature_contract_delta.md` as an in-flight sibling contract claim. Report overlaps without resolving them in this step.

### Cross-Class Transport/Contract Approach Mirror

- Read `cross_class_peer_trigger` from the context block; do not recompute it or run the legacy helper.
- When the value is `inactive`, omit `## 5. Cross-Class Transport/Contract Approach Mirror` entirely.
- When the value is `active`, write one `### Backend: <identity>` block per active backend.
- Mirror the backend's current `transport_protocol` and `schema_format` from `common_contract_definition.md` `## 7. Cross-Class Transport/Contract Approaches` verbatim by default.
- When the feature defines or refines either value, record the concrete feature value even if the baseline contains a placeholder or a different concrete value.
- Otherwise use the literal `<to be defined during first feature implementation plan>` placeholder.
- Section 5 has no resolution state machine, terminal-state field, required block, or quality-gate enforcement.

### Runtime Path Binding Rules

- Runtime bindings emitted by `node .overmind/overmind.js context contract-delta <feature-path>` are authoritative.
- Use the emitted workspace root, project root, feature root, source paths, ready-repository paths, pending sibling paths, trigger, target, assets, allowed-write list, and exact gate command.
- Do not assume fixed source-repository paths or runner-specific installation paths.

### Quality Criteria and Completion Gate

- Draft the target before invoking the gate.
- Run `node .overmind/overmind.js gate contract-delta <feature-path>` after every write or repair.
- Preserve the `delta_needed` branch shape, required metadata, per-delta fields, and handoff signals.
- On exit `1`, repair exactly the reported structural failures and rerun the gate.
- On exit `2`, make no further edits and wait for operator instructions.
- Finalize only after exit `0`.
