# Phase Refactoring: Current Phase Architecture

High-level architecture of the current init/feature pipeline ("phases"), the design intent behind each step, and the observed weaknesses that motivate the redesign in `02_phase_redesign_and_target_architecture.md`.

Refs: `overmind/templates/init_progress_definition_TEMPLATE.yaml` (canonical step/gate definitions), `overmind/init_progress_definition_sequence_diagram.md` (flow), `overmind/init_progress_definition_data_model.md`, real runtime workspace `~/repo/asdlc` (projects `umss_spg`, `teleforecaster_umss_v2`).

Evidence caveat: the referenced real projects were **experimental**. Implementation-throughput observations (abandonment counts, planning-vs-implementation lag) are NOT valid evidence for redesign decisions. Artifact-content observations (duplication, information density, which gates ran) ARE valid and are used below.

---

## 1. System Context

- **Overmind (this repo)** is the coordinator. It turns a business request (Jira ticket / story) into two worker-facing artifacts: `requirements_ears.md` and `implementation_plan.md`.
- **Workers (yasdef repo)** consume those artifacts and ground the high-level plan into the exact codebase during implementation. The plan is intentionally high-level; code-level grounding is worker responsibility.
- **Handoff contract**: `implementation_plan.md` steps sized for one worker, each carrying `#### Repo:` (class ownership), `#### Depends on:` (same-feature and cross-feature `<feature-folder>/<step-id>` refs), `#### Evidence:`, `#### Preserved Surface:`, `#### Assigned: <worker-uuid>`. Worker commits carry step ids and REQ ids back into git history (`Step 1.5 post-review … [REQ-9] [NFR-1]`), so EARS IDs are a live coordination currency end to end.
- **Resumability**: every step finishes on artifact presence plus key-value gates; `node .overmind/overmind.js status <feature-path>` computes the canonical `next step`; `step_state*.md` checklists persist progress per feature.

## 2. Knowledge Architecture

Two deliberate tiers:

| Tier | Artifacts | Lifetime |
|---|---|---|
| Project-stable | `init_progress_definition.yaml`, `project_stack_blueprint_<class>.md`, `common_contract_definition.md` | Init phase; never re-litigated by features |
| Feature-scoped | everything under the feature folder | One feature; expresses deltas against the stable tier |

Cross-cutting invariants:

- **EARS wall**: `requirements_ears.md` is deliberately technology-free — pure business value. Everything from step 6 onward lives on the technical side of the wall. Steps 6→8.4 are one machine: ground the business feature into real codebase(s) — or blueprints for type A — in the most efficient way that yields the highest-quality plan.
- **Evidence ladder** (per-layer, demand-driven, permanent): repo scan (class state `ready`) → in-flight promises (committed sibling plans) → blueprint planned → placeholder. Knowledge degradation is always explicit, never silent. All repo scans read the default branch only.
- **Per-class gating**: steps gate on `class_repo_paths.<class>.state` (`ready` scanned, `deferred` skipped), replacing the older project-type branching (see `design_docs` per-class transition design decisions, June 2026).
- **Concurrency model**: a feature emits promises only when its plan passes the same readiness predicate worker assignment uses (all-or-nothing rule); assignment is the execution gate that re-validates cross-feature deps.

## 3. Step Inventory and Design Intent

Init phase (project-level, runs once):

| Step | Artifact | Intent |
|---|---|---|
| 1 Initialize Repo ASDLC Metadata | `init_progress_definition.yaml` | Machine-readable source of truth for project shape so all later steps can gate deterministically |
| 1.1 Define Project Stack Blueprints | `project_stack_blueprint_<class>.md` | For Type-A the blueprint **is** the technical reality — there is no repo to scan. Without it nothing downstream works: no surface enumeration, no per-class contract evidence, no blueprint rung in the evidence ladder. Substitute ground truth, not context |
| 2 Create Cross-Repository Contract Definition | `common_contract_definition.md` | The **inter-class treaty** and a hard precondition for planning: work cannot be split across classes before the classes agree what flows between them — otherwise each class plans against its own assumptions and cross-class ordering is fiction. Agreed once project-level, so features only ever express deltas (step 6) |

Feature phase (runs per feature):

| Step | Artifact | Intent |
|---|---|---|
| 3 BR scaffold | `feature_br_summary.md` | Anchor document + feature metadata (mechanical scaffold) |
| 4.1 Task-to-BR | `user_br_input.md` (+ BR update) | **Anti-hallucination intake**: verbatim source preserved; `[UNFILLED]` discipline; every unknown externalized to `missing_br_data.md` ledger; no invented facts |
| 4.2 Clarify loop | `feature_br_summary.md` `ready_to_ears: true` | Iterative Q&A until quality gate; don't formalize garbage — EARS conversion is expensive to redo |
| 5 BR → EARS | `requirements_ears.md` | Mint the **coordination currency**: technology-free, ID'd, testable requirements that survive into worker commits |
| 5.1 (opt) EARS review | `requirements_ears_review.md` | Audit formalization drift: EARS vs BR summary |
| 6 Feature contract delta | `feature_contract_delta.md` | **Contract-first parallelism**: agree the cross-class interface before per-class deep analysis so class tracks can run concurrently |
| 7 Surface maps | `project_surface_struct_resp_map_<class>.md` | **Unknown-unknown detector**: enumerate the repo's surfaces, then interrogate each against the feature — "must we touch this to make the feature work?" Enumeration converts unknown-unknowns into known decisions. Rows carry `transport_layer` / `user_reachable_surface` split (scar tissue from features delivered with no reachable entry point) |
| 7.1 (opt) MCP enrichment | in-place surface-map update | Fill `<to be defined during implementation>` placeholders from a knowledge base instead of guessing |
| 8 Technical requirements | `technical_requirements.md` | Per-REQ current-state/gap analysis with component impact and repo ownership — nothing in EARS may lack a technical answer |
| 8.1 Implementation slices | `implementation_slices.md` | **Separation of concerns, pass 1**: draft future implementation steps value-first (thin vertical cuts, first usable increment) explicitly freed from ordering and full traceability |
| 8.2 Prerequisite gap trace | `prerequisite_gaps.md` | **Dependency-closure discovery**: business asks precise functionality that silently assumes load-bearing pieces (canonical example: a page for C-level managers assumes the system can distinguish C-level from employees). Walk each REQ asking "what must exist for this to be invocable end-to-end?"; zero-unmet gate before planning |
| 8.3 Implementation plan | `implementation_plan.md` | **Separation of concerns, pass 2**: sequencing as a separate goal — order slices into worker-assignable steps with repo ownership and explicit cross-repo deps |
| 8.4 (opt) Semantic review | `implementation_plan_semantic_review.md` | Audit split quality, dependency ordering, operator reachability, scaffold readiness; in real usage the de facto interactive refinement checkpoint where accumulated improvements were applied to the plan (see W4) |

## 4. Composition Patterns

- **Business gaps are resolved on the business side, before formalization.** EARS preparation analyzes what is already implemented *first* (repo/blueprint scan during intake), so discovered business-visible gaps become operator clarification questions and enter EARS as first-class requirements (example: "salary report for C-level managers" + no role distinction in the system → ledger question → operator decides `C_LEVEL` role → REQ from the start). EARS is minted already gap-complete; the EARS wall never needs post-hoc appends from the technical side in the normal flow.
- **The technical side is a forced-answer sweep machine.** Three layers: (1) *enablers* — steps 1/1.1/2 create technical reality (blueprints as substitute ground truth for Type-A) and the inter-class treaty without which multi-class planning is meaningless; (2) *sweeps* — steps 6/7/8/8.2 repeatedly ask "did we forget anything important?" over progressively narrower rosters (contract impact → classes and surfaces → requirements → prerequisites), where "nothing" must always be written as an explicit `none`/"no delta", converting forgetting from a silent failure into a visible lie; (3) *assembly checks* — steps 8.1/8.3/8.4 ask delivery-shape questions (is the user-facing thing actually delivered, are cross-repo dependencies explicit, is the whole coherent). A "did we forget X?" question is only checkable because an earlier artifact holds the roster of X.
- **Create-then-audit pairs**: 5→5.1, 8.1→8.2, 8.3→8.4, and the 4.1↔4.2 loop. Each audit was born from an observed LLM failure mode (formalization drift, coverage holes, unreachable surfaces, invented facts).
- **Diverge-then-converge**: creative decomposition (8.1) is deliberately freed from traceability; enforcement (8.2) converges afterwards.
- **Ground before plan**: no planning artifact is written until per-class reality (7) and per-REQ gaps (8) exist.
- **Machine-checkable resumability**: artifact-presence + key-value gates per step.

## 5. Observed Weaknesses

Numbered for reference from `02_phase_redesign_and_target_architecture.md`.

- **W1 — Enforcement gap.** Most `finished_only_if_conditions_meet` entries are unverifiable prose ("enriched until required quality is reached"). Only artifact presence and key-value checks are actually enforced; declared gates are much stronger than enforceable ones.
- **W2 — Paraphrase-hop chain.** Source → `user_br_input.md` → `feature_br_summary.md` → `requirements_ears.md` → `technical_requirements.md` → `implementation_slices.md` → `implementation_plan.md` is five LLM paraphrases between what the user said and what the worker reads. Each hop can mutate semantics — the exact drift step 5.1 was invented to catch.
- **W3 — Duplicate documents.** Real artifacts show `implementation_plan.md` as a near 1:1 re-paraphrase of `implementation_slices.md` (7 slices → 10 steps, same bullets reworded); `technical_requirements.md` section `## 5. Impacted Components` largely restates surface-map inventory. Copies drift; drift is its own error class. The re-paraphrasing also proves the 8.1/8.3 separation of concerns is not actually enforced — decomposition work (rewording) leaks into the ordering pass because 8.3 must generate a fresh document.
- **W4 — Audits-as-documents run once, and their ledgers under-record value.** 5.1 was skipped or near-empty in practice (one finding ever, rejected) and 7.1 was never used in any project. 8.4 is different: its findings ledger also looks thin (one `no_findings` run, one run with 2 operator-reachability findings), **but the operator reports 8.4 as one of the most helpful steps in real usage** — it became the de facto refinement checkpoint where accumulated improvements were applied directly to the plan during the session. Lesson: recorded findings are a bad proxy for step value; the interactive refinement session is the real deliverable of 8.4. Remaining defects stand: the step is formally optional, and nothing re-checks a plan edited during/after 8.4 — which matters *more* given that 8.4 edits the plan.
- **W5 — Discovery and verification conflated in 8.2.** The real `prerequisite_gaps.md` is 557 lines carrying ~6 unique facts — every block reads "prerequisite X → `scheduled_in_slices` → slice-N". The discovery intent is real (see step 8.2 intent above; the admin-auth prerequisite was genuinely discovered and promoted to its own feature), but the artifact records confirmation, not discovery, and as a write-once document the check never re-runs.
- **W6 — Fixed ceremony cost.** ~13 artifacts (~190KB on the measured feature) regardless of feature size; the 7→8.3 tail consumed the majority of wall time on the measured feature.
- **W7 — Residual project-type branching.** Step 1 asserts `project_type_code` "is not read by feature-phase steps", yet 4.2/8/8.1/8.3/8.4 condition text still branches on Type A/B/C. Partially superseded by the per-class `class_repo_paths.<class>.state` design; the YAML text has not caught up.
- **W8 — Two sources of truth.** The sequence diagram declares itself "single source of truth" while the YAML template defines the actual gates; they already drift (diagram sub-steps 2.1/2.2/2.3 absent from YAML; numbering skips a base step 4).
- **W9 — Forward-only flow.** Worker-inserted sub-steps (1.4a, 1.6a, 1.8a, 1.9a on the implemented feature) show reality diverging immediately, with no channel back into overmind artifacts. Feedback loop is an explicitly deferred design topic — out of scope for this refactoring, but the target design must not make it harder.
- **W10 — Business-visible prerequisite disposition gap.** When closure discovery finds a business-visible gap (role distinction is a business concept), the formal options are "schedule a plan step" (which creates worker-built business functionality with no REQ ID — breaching the EARS wall from below) or, informally, spawning a feature (what actually happened with admin auth). No explicit disposition rule exists.
