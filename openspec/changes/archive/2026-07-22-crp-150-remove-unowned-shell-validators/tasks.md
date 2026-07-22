## 1. No-Consumer Audit

- [x] 1.1 Confirm the former step 7.1 shell orchestrator is absent and neither validator has a production, packaged-skill, CLI, or staging consumer.
- [x] 1.2 Confirm `validate/surface-map.ts` is the sole production quality owner and the installed `overmind-surface-map` skill invokes its CLI gate per class, preserving `0`/`1`/`2` semantics.
- [x] 1.3 Record the audit in `design.md`.

## 2. Remove Validators and Compatibility Artifacts

- [x] 2.1 Delete both surface-map shell validators.
- [x] 2.2 Delete the deployed-shell cleanup manifest, historically-staged helper inventory, and their consistency tests.
- [x] 2.3 Delete the transitional shell inventory guard test.
- [x] 2.4 Remove validator-specific stale-copy fixtures/assertions while retaining synthetic generic-reconcile coverage.
- [x] 2.5 Align `design_docs/e2e_orchestrator_migration/06_sh_remove_plan.md` and this change's artifacts with the fresh-install, no-parity-ceremony baseline.

## 3. Verification

- [x] 3.1 Run the installer tests and `tests/ai_scripts/project_setup_asdlc_tests.sh`.
- [x] 3.2 Run `npm run verify` and confirm all named shell suites remain green.
- [x] 3.3 Run strict OpenSpec validation and `git diff --check`.
