# Step 8.4 Migration Parity Inventory

## Responsibility Ownership

| Legacy responsibility | New owner | Status |
|---|---|---|
| Operator finding selection | `overmind-plan-semantic-review/SKILL.md` live model session | kept |
| Dynamic feature, project, class, surface-map, target, and gate bindings | `context/plan-semantic-review.ts` | kept |
| Review-ledger generation and finding-application loop | `overmind-plan-semantic-review/SKILL.md` | kept |
| Review-ledger structural validation | `validate/plan-semantic-review.ts` | kept |
| Read-only input immutability and required-output assertion | `project_add_feature_e2e.sh` snapshot/`cmp` launcher guard | kept |
| Cross-step sequencing and optional-phase confirmation | transitional `project_add_feature_e2e.sh` | kept |
| Runtime installation | TypeScript installer and ASDLC setup runner-skill staging | changed |

## Instruction And Check Comparison

| Old instruction/check | New location | Status |
|---|---|---|
| Optional post-plan semantic-review goal | `SKILL.md` Purpose and Review Scope | kept |
| Two mutable artifacts and all read-only inputs | context manifest plus `SKILL.md` Required Invocation | kept |
| Runtime root, feature, project definition, requirements, technical requirements, prerequisite gaps, surface maps, template, example, helper/gate, and plan-gate Context lines | `context/plan-semantic-review.ts` deterministic output | changed |
| Six finding types | `SKILL.md` Allowed Finding Types and TS gate enum | kept |
| Four finding states and terminal-state workflow | `SKILL.md` Finding State Rules and TS gate | kept |
| Four-step delivered-surface reachability heuristic | `SKILL.md` Review Scope | kept |
| In-flight sibling surface-map overlap rule | `SKILL.md` Review Scope | kept |
| Deferred repo-scaffold readiness rule | `SKILL.md` Review Scope and Deferred-Class Scaffold Readiness Guidance | kept |
| Minimal plan-patch guidance | `SKILL.md` Minimal Plan Patch Guidance | kept |
| Exact operator question | `SKILL.md` Required Invocation | kept |
| Exact success and infeasibility lines | `SKILL.md` Required Invocation only | kept |
| Run review gate after every ledger write/repair, including initial ledger | `SKILL.md` Required Invocation | changed |
| Run implementation-plan gate after every plan write/repair | `SKILL.md` Required Invocation | changed |
| Gate exit-code handling | `SKILL.md` Required Invocation | kept |
| Required sections | `validate/plan-semantic-review.ts` | kept |
| Eight required meta keys and review-status enum | `validate/plan-semantic-review.ts` | kept |
| `no_findings` consistency | `validate/plan-semantic-review.ts` | kept |
| Twelve required finding fields | `validate/plan-semantic-review.ts` | kept |
| Severity, finding-type, and state enums | `validate/plan-semantic-review.ts` | kept |
| Terminal product-fit resolution notes | `validate/plan-semantic-review.ts` | kept |
| Delivered-surface REQ/NFR reference | `validate/plan-semantic-review.ts` | kept |
| Complete review rejects non-terminal findings | `validate/plan-semantic-review.ts` | kept |
| `[UNFILLED]` rejection | `validate/plan-semantic-review.ts` | kept |
| Missing target exit `2`; empty/whitespace target exit `1` | `validate/plan-semantic-review.ts` | kept |
| Legacy command argument/runtime/source checks | context path resolution and e2e installed-skill/CLI checks | changed |
| Legacy read-only mutation scenarios | phase-8.4 e2e tests over context-emitted manifest | ported |
| Legacy prompt, output, and model-failure scenarios | phase-8.4 e2e tests | ported |
| Legacy helper success/content/runtime scenarios | TS gate tests | ported |
| Legacy class, surface-map, and missing-input scenarios | TS context tests | ported |

No row is missing. The deterministic immutability guard remains outside advisory skill text, and literal final-response lines occur only in `SKILL.md`; legacy deletion is unblocked.
