## Context

`overmind/scripts/project_mgmt/project_setup_asdlc.sh` currently contains a single flow that initializes repo ASDLC metadata. The requested behavior is to make this script a top-level selector that asks the user what operation to run and delegates execution to one of three helper scripts.

This change is cross-cutting because it affects:
- entrypoint UX and control flow for ASDLC setup
- script decomposition (moving current logic into helper #2)
- fail-fast routing behavior and return-code propagation
- script-test and README expectations

Options `1` and `3` are intentionally placeholders in this change; their internal logic will be provided later. Option `2` keeps the current implementation behavior.

## Goals / Non-Goals

**Goals:**
- Make `project_setup_asdlc.sh` a dispatcher with fixed prompt text and three fixed numbered options.
- Route each valid option to exactly one helper script.
- Move existing logic from `project_setup_asdlc.sh` into helper script #2 (`add new project`) without behavior regression.
- Preserve existing canonical metadata persistence semantics and validation via option `2`.
- Keep shell-only implementation and avoid new CLI flags/options.

**Non-Goals:**
- Implement full business logic for option `1` and option `3`.
- Redesign metadata model (`meta_info`) or downstream consumer behavior.
- Add automatic project inference or non-interactive modes.

## Decisions

1. Use `project_setup_asdlc.sh` only as orchestration/dispatch shell.
Rationale: keeps entrypoint simple and allows isolated evolution of each flow.
Alternative considered: keep all flows in one script behind branching. Rejected for maintainability and readability.

2. Keep current metadata initialization logic intact but relocate to option `2` helper.
Rationale: preserves proven behavior while enabling the new routing model with minimal regression risk.
Alternative considered: rewrite option `2` logic during extraction. Rejected to avoid accidental behavior drift.

3. Treat helper flows `1` and `3` as explicit callable placeholders for now.
Rationale: user explicitly deferred their content to later input; placeholders make routing contract testable immediately.
Alternative considered: postpone creating helper files until later. Rejected because dispatcher routing contract requires concrete targets now.

4. Dispatcher returns selected helper's exit code.
Rationale: preserves operational transparency for callers/tests and avoids masking errors.
Alternative considered: normalize all exits in dispatcher. Rejected because it hides helper failures.

## Risks / Trade-offs

- [Risk] Option `1` and `3` placeholders may be mistaken as fully implemented.
  Mitigation: enforce explicit placeholder output and non-success status or clear "not implemented yet" messaging contract in helper behavior.

- [Risk] Logic extraction to helper `2` could change behavior unintentionally.
  Mitigation: copy behavior as-is first, then run existing regression tests for metadata flow.

- [Risk] Dispatcher prompt/option text may drift from required exact wording.
  Mitigation: add tests that assert exact prompt and option labels.

- [Risk] Helper path coupling introduces routing breakage if files are renamed.
  Mitigation: centralize helper path constants in dispatcher and validate required files before dispatch.

## Migration Plan

1. Add helper scripts for options `1`, `2`, and `3` under `overmind/scripts/`.
2. Move current `project_setup_asdlc.sh` body into helper `2` with no functional changes.
3. Replace `project_setup_asdlc.sh` body with prompt + option parsing + helper dispatch.
4. Add/adjust tests for:
   - exact prompt/options text
   - valid option routing behavior
   - invalid selection fail-fast behavior
   - preserved option `2` metadata behavior
5. Update Overmind README references to explain dispatcher behavior and helper split.

Rollback strategy: restore previous single-flow `project_setup_asdlc.sh` and remove helper dispatch paths.

## Open Questions

- Should placeholder helpers for options `1` and `3` exit non-zero until implemented, or exit zero with a clear "not implemented yet" message?
- Should dispatcher allow retry-on-invalid-input loop, or fail-fast immediately on invalid selection?
