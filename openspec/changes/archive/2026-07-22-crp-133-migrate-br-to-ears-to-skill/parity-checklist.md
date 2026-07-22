# BR-to-EARS Migration Parity Checklist

## Old Responsibility Inventory

| Old responsibility | Old location | New owner | Status |
|---|---|---|---|
| Resolve feature path, `feature_br_summary.md`, and `requirements_ears.md` | `feature_br_to_ears.sh` | `context/requirements-ears.ts` | kept |
| Verify `ready_to_ears: true` in `feature_br_summary.md ## 1. Document Meta` | `feature_br_to_ears.sh` `ensure_ready_to_ears` | `context/requirements-ears.ts` | kept |
| Bind workspace root, feature root, target artifact, read-only source, asset refs, and gate command | `feature_br_to_ears.sh` prompt | `context/requirements-ears.ts` + thin e2e launcher | kept |
| Convert BR summary into EARS requirements | `br_to_ears.md` + model prompt | `overmind-requirements-ears/SKILL.md` | kept |
| Run and handle the EARS quality loop | `br_to_ears.md` + model prompt | `overmind-requirements-ears/SKILL.md` | kept |
| Validate EARS block fields, patterns, and numbering | `check_requirements_ears_quality.sh` | `validate/requirements-ears.ts` | kept |
| Stage runnable bash command, rule, and helper | `project_setup_first_init_machine.sh` | removed; package runner skill instead | changed |

No `capture` verb is added because the BR summary is an upstream artifact. No `readiness` verb is added because readiness is produced by `readiness br-clarification` and only verified by this step.

## Required Parity Rows

| Old instruction/check | New location | Status |
|---|---|---|
| Success final line: `BR->requirement-EARS phase is finished. Nothing else to do now; press Ctrl-C so orchestrator can start the next phase` | `SKILL.md` only | kept |
| Infeasibility final line: `based on provided reasons, EARS gate cannot pass with current BR input. Please provide instructions what to do, or adjust requirements and rerun this phase` | `SKILL.md` only | kept |
| Gate exit `0` means complete | `SKILL.md` | kept |
| Gate exit `1` means repair `requirements_ears.md` and rerun gate | `SKILL.md` | kept |
| Gate exit `2` means stop and report blocker | `SKILL.md` | kept |
| `ready_to_ears: true` precondition with `readiness br-clarification` hint | `context/requirements-ears.ts` | kept |
| Read-only BR boundary for `feature_br_summary.md` | `context/requirements-ears.ts` allowed-write list + `SKILL.md` | kept |
| Allowed write list is `requirements_ears.md` only | `context/requirements-ears.ts` + `SKILL.md` | kept |
| EARS allowed patterns: `THE ... SHALL ...`, `WHEN ..., THE ... SHALL ...`, `IF ..., THEN THE ... SHALL ...`, `WHILE ..., THE ... SHALL ...`, `WHERE ..., THE ... SHALL ...`, `WHEN ... AND WHILE ..., THE ... SHALL ...` | `validate/requirements-ears.ts` + `SKILL.md` | kept |
| Independent 1-based sequential numbering with duplicate detection for `Requirement` and `NFR` | `validate/requirements-ears.ts` + `SKILL.md` | kept |
| `## 16. Linked Artifacts` registry propagation and per-requirement associations | `SKILL.md` | kept |
| Source-of-truth, `[Inference]`, `Unresolved gap:`, atomic splitting, ordering, and prohibited-content rules | `SKILL.md` | kept |
| Template and golden example asset refs use skill-relative `assets/...` paths | `context/requirements-ears.ts` + `SKILL.md` | kept |
| e2e wrapper prompt supplies runtime bindings and exact commands only | `project_add_feature_e2e.sh` | kept |

## Test Scenarios To Port

### From `tests/ai_scripts/check_requirements_ears_quality_tests.sh`

- Valid complete EARS content exits `0`: ported.
- Missing target path argument exits `2`: ported.
- Missing target artifact exits `2`: ported.
- Empty target exits `1`: ported.
- Missing required block field exits `1`: ported.
- Duplicate or non-sequential `Requirement` numbering exits `1`: ported.
- Additional port coverage required by CRP-133: invalid EARS bullet, no valid pattern, no bullets, NFR numbering, and no blocks found: ported.

### From `tests/ai_scripts/init_br_to_ears_tests.sh`

- Missing feature path usage is handled by the new e2e/CLI paths: ported.
- Non-staged copied command test is deleted with the migrated command: changed.
- `ready_to_ears` missing/not true blocks before model launch: ported to context tests.
- Required context inputs report actionable exit `2`: ported.
- Model phase config checks are replaced by `MODEL_CMD=codex` launcher checks: ported.
- Orchestrator does not run the gate directly; the skill owns the gate loop: ported.
- Phase 5 launches Codex with runtime root bindings, exact context/gate commands, and no literal final lines: ported.
- Absolute feature paths remain accepted by context/launcher path handling: ported.
- Linked artifact registry, per-requirement `**Linked Artifacts:**`, and empty-registry omission survive in `SKILL.md` instructions: kept.
