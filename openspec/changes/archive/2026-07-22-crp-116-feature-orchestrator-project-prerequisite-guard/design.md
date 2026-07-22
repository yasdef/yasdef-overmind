## Context

`project_add_feature_e2e.sh` is a feature-phase orchestrator. It accepts a project path, obtains a feature path through selection or Step `3` scaffold, runs `init_progress_scanner.sh --path <feature-path>`, then maps the scanner `next step` result into its supported feature phase map.

The scanner can legitimately report project-level unfinished steps such as Step `1.1` for type A stack blueprints or Step `2` for common contract definition. The orchestrator currently treats those as generic unmapped scanner steps, even though the real problem is that project initialization is incomplete before feature orchestration can continue.

## Goals / Non-Goals

**Goals:**
- Keep `init_progress_scanner.sh` as the canonical next-step source.
- Fail clearly when scanner returns a step earlier than the orchestrator's first supported feature step.
- Preserve existing behavior for scanner steps that map to Step `3` or later.
- Include actionable guidance for known project-level steps `1.1` and `2`.
- Keep the change local to `project_add_feature_e2e.sh` and its tests.

**Non-Goals:**
- Changing `init_progress_scanner.sh` to accept project-level paths.
- Running scanner before Step `3` creates a feature folder.
- Adding new CLI flags to `project_add_feature_e2e.sh`.
- Automatically running Step `1.1` or Step `2` from the feature orchestrator.

## Decisions

### Decision: Use scanner output as the only prerequisite source

The orchestrator will continue to call scanner after a feature path is known and will inspect the parsed scanner step before attempting feature-phase mapping.

Rationale: Scanner already owns `required_if` and artifact completion semantics. Duplicating those checks inside the feature orchestrator would create drift.

Alternatives considered:
- Add direct artifact checks for Step `1.1` and Step `2`: rejected because it duplicates scanner behavior and would need updates for future pre-feature steps.
- Add project-path scanner mode first: rejected for this change because it expands scanner scope and changes the startup contract.

### Decision: Compare dotted step ids against first supported step `3`

Add a small helper that compares dotted numeric step ids segment by segment. If scanner returns a valid step id earlier than `3`, the orchestrator prints a prerequisite error and exits nonzero before `map_scanner_step_to_phase`.

Rationale: This keeps the guard generic for future project-level steps such as `2.5` while preserving normal mapping for `3` and later.

Alternatives considered:
- Compare as raw strings: rejected because values such as `2.10` and `2.2` sort incorrectly as strings.
- Hard-code only `1.1` and `2`: rejected because it misses future pre-feature project steps.

### Decision: Provide known command guidance for current project prerequisites

For Step `1.1`, the message will point to:

```bash
.commands/init_project_stack_blueprints.sh --path projects/<project-id>
```

For Step `2`, the message will point to:

```bash
.commands/init_common_contract_definition.sh --path projects/<project-id>
```

For other earlier steps, the message will tell the operator to complete the scanner-reported step before rerunning the feature orchestrator.

Rationale: Known guidance addresses the immediate operator problem without making the feature orchestrator execute project-init scripts.

Alternatives considered:
- Keep a generic message for every earlier step: rejected because it leaves the common Step `1.1` and Step `2` cases under-explained.

## Risks / Trade-offs

- [Risk] A malformed scanner step id could be misclassified by the comparison helper. -> Mitigation: only treat valid dotted numeric ids as comparable; unknown ids keep the existing unmapped-step failure path.
- [Risk] Brand-new feature runs can still create Step `3` scaffold before scanner reports an earlier project step. -> Mitigation: this change intentionally preserves scanner contract and improves the post-scanner error; project-path preflight is out of scope.
- [Risk] New future pre-feature steps may need better command guidance. -> Mitigation: provide generic prerequisite messaging for all earlier steps and add specific command hints later when a runnable command exists.

## Migration Plan

1. Add the dotted step comparison and prerequisite error helpers to `project_add_feature_e2e.sh`.
2. Call the guard after scanner parsing and before `map_scanner_step_to_phase`.
3. Add tests for scanner `next step: 1.1`, `next step: 2`, and a supported Step `3` or later result.
4. Run `bash tests/ai_scripts/project_add_feature_e2e_tests.sh`.

Rollback is limited to reverting the helper, its call site, and related tests.

## Open Questions

- None.
