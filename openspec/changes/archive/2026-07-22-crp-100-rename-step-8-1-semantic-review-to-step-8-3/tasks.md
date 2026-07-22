## 1. Renumber phase definitions to Step 8.3

- [x] 1.1 Update init-progress definition assets so implementation-plan semantic review is declared as optional Step `8.3` instead of optional Step `8.1`.
- [x] 1.2 Update sequence and workflow documentation references from semantic-review Step `8.1` to Step `8.3` while preserving current command and artifact names.

## 2. Update staging and command-facing phase references

- [x] 2.1 Update setup/bootstrap staging scripts and generated guidance so semantic-review positioning is documented as Step `8.3`.
- [x] 2.2 Verify semantic-review staged command contracts remain unchanged except for step-number positioning references.

## 3. Align scanner and test contracts with the new optional step index

- [x] 3.1 Update scanner expectations and related fixtures to treat semantic review as optional Step `8.3`.
- [x] 3.2 Update `tests/ai_scripts/` coverage for setup staging, scanner optional-step rendering, and semantic-review phase references to assert `8.3`.

## 4. Verify OpenSpec readiness

- [x] 4.1 Run relevant test suites from repository root for changed setup/scanner/semantic-review coverage.
- [x] 4.2 Run `openspec status --change crp-100-rename-step-8-1-semantic-review-to-step-8-3` and confirm all apply-required artifacts are complete.
