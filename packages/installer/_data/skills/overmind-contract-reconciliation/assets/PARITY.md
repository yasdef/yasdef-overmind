# Reconciliation Old→New Parity Table

Maps every legacy instruction, deterministic check, exact completion line, runtime
binding, and test behavior to its new skill/context/gate/executor/test owner. No row
is missing an owner; architecture-driven changes are called out.

| Legacy source | Item | New owner | Status |
|---|---|---|---|
| `project_contract_reconciliation_rule.md` — Purpose | one-time first-attach reconciliation | `SKILL.md` ## Purpose | kept |
| rule — Scope | reconcile in-scope role only | `SKILL.md` ## Scope | kept |
| rule — Out-of-scope untouchable | absence ≠ drift; consumer drift note | `SKILL.md` ## Out-of-scope | kept |
| rule — Workflow | operator approve/reject/revise loop | `SKILL.md` ## Operator decision loop | kept |
| rule — Quality gate 0/1/2 | model-owned gate loop | `SKILL.md` ## Quality gate | kept |
| rule — Must not | no definition/source edits, no repeat | `SKILL.md` ## Must not | kept |
| old prompt — context command | `context contract-reconciliation <project> --class ...` | `src/context/contract-reconciliation.ts` + prompt recipe | ported |
| old prompt — gate command | `gate contract-reconciliation <project>` | `src/validate/contract-reconciliation.ts` | ported |
| old prompt — cannot-pass final line | exact blocker line | `SKILL.md` (only place) | kept |
| old prompt — success final line | exact success line | `SKILL.md` (only place) | kept |
| initial common-contract gate | all 0/1/2 checks | `validateCommonContractContent` | ported; shell retired |
| `common_contract_definition_TEMPLATE.md` | structure reference | `assets/common_contract_definition_TEMPLATE.md` | copied |
| `common_contract_definition_GOLDEN_EXAMPLE.md` | style reference | `assets/common_contract_definition_GOLDEN_EXAMPLE.md` | copied |
| definition immutability guard (`cmp`) | `init_progress_definition.yaml` unchanged | catalog `mustExistUnchanged` guard | ported |
| `.contract_reconciled_<class>` marker | completion signal | `class_repo_paths.<class>.contract_reconciled` field | changed (D8, clean break) |
