# Phase Refactoring: Roundtable Planning — Target Architecture

What we change, which problems each change solves (W1–W10 from `01_current_phase_architecture.md`), and the resulting target pipeline.

Status: **agreed design direction (July 2026), pre-implementation.** This design supersedes the earlier consolidation redesign (12 steps → 5, audits → gates), which is preserved as a fallback in `design_docs/phase_refactoring_light_version/`. The exploration that led here is recorded in `alternatives.md` (Alternatives 2 + 3 fused; that document is a historical exploration record and no longer describes the architecture). Implementation lands inside the TypeScript skills port (`design_docs/to_skills_migration/`), not as patches to the current shell+md pipeline.

Core idea in one sentence: **planning stops being a pipeline of documents and becomes a moderated conversation around a draft plan — held between a PO agent and one developer seat per class, all on the coordinator machine, converging on a single artifact.**

---

## 1. Design Principles

- **P1 — Plan first.** The plan is drafted right after EARS, knowingly imperfect. All grounding and discovery interrogates the draft instead of building intermediate pictures "just in case". Cost becomes proportional to feature size by construction.
- **P2 — Dialogue over documents.** The technical tail (old steps 6→8.4) is a conversation, not a document chain. Intermediate documents become dialogue turns; the durable artifacts are the plan, the contract delta, and a transcript.
- **P3 — Enforced ignorance.** One fresh-context agent seat per class, given only its own repo (local clone + that repo's `AGENTS.md`), the draft plan, and the inter-class treaty. A seat cannot silently assume another repo has something — it must ask. Isolation of seats replaces distribution of machines and is what makes the dialogue produce discoveries.
- **P4 — Distribute only where humans are distributed.** At planning time there is one human (the PO), so planning is centralized on the coordinator machine. Execution humans are distributed, so execution stays distributed (workers, unchanged).
- **P5 — Collapsing documents is fine; collapsing sweeps is not.** Every roster×question sweep from the current pipeline, the explicit-`none` discipline, and the discovery cognition must survive as questionnaire items or gates. Acceptance test: the Sweep Survival Map in section `## 3. Target Pipeline`.
- **P6 — The EARS wall holds in both directions.** No technology in EARS; no business-visible functionality entering the plan without a REQ ID. The wall now physically coincides with the PO/seat boundary. EARS amendments happen only through the operator (see decision D2).
- **P7 — Single-writer law.** Seats speak; only the coordinator writes `implementation_plan.md` and `feature_contract_delta.md`. The dialogue is memory; the artifacts are law — nothing agreed in the thread is binding until landed in an artifact.
- **P8 — Exactly two human gates.** `ready_to_ears` on the business side; plan approval at the end of the roundtable on the technical side. The interactive refinement checkpoint (old 8.4, the most valuable step in real usage) is no longer a step at the end — it is the session itself.
- **P9 — No unowned work in the dialogue.** Every draft plan step carries a class owner (`#### Repo:`) from revision 1. Ownership is what routes questions to seats and turns answers into obligations — "can you do this?" must have an addressee, or no seat feels responsible for answering. A step the PO cannot assign to any class is itself a finding (a missing class/blueprint, or a wrongly cut step), never a step left blank. Worker-level `#### Assigned: <worker-uuid>` stays at execution/assignment time, unchanged — seats represent classes, not individual workers.

## 2. Problem → Change Map

| Problem | Change | What improves |
|---|---|---|
| W1 enforcement gap | Forced-answer questionnaire (every addressed item must be answered; explicit `none` allowed, silence blocks) + mechanical gates that re-run on every plan edit and at assignment | Declared gate = enforced gate |
| W2 paraphrase hops | Grounding stops being a paraphrase document; hops from captured input to plan: 5 → 3 (input → brief → EARS → plan draft); the plan is then revised in place, and revisions are edits, not paraphrases | Less drift to create, less to audit |
| W3 duplicate documents | Surface maps, `technical_requirements.md`, `implementation_slices.md`, `prerequisite_gaps.md`, and the semantic review cease to exist as documents; one plan revised in place | Whole error class (copy divergence) deleted |
| W4 skippable audits | The refinement checkpoint is the session itself — it cannot be skipped because it is where the plan gets made; gates re-run after every applied change | Audits always run |
| W5 discovery/verification conflated | Discovery = seats answering the closure question in dialogue, where the repo evidence is in view; verification = mechanical zero-unmet readiness gate, re-runnable | Each job gets the right tool |
| W6 ceremony cost | Small feature = few seats, short dialogue; drafts improve as project knowledge accumulates, so the system gets cheaper per feature over time — the opposite of fixed ceremony | Proportional cost by construction |
| W7 residual type branching | Seating gates only on `class_repo_paths.<class>.state`; a Type-A class is a blueprint-played seat, not a branch in step logic | Internal consistency |
| W8 two sources of truth | YAML step definitions canonical; diagram generated or explicitly labeled derived (unchanged from the light version) | Drift impossible or declared |
| W9 forward-only | The dialogue message shape IS the future worker→coordinator channel: worker design phase acts as lazy sign-off; `raised_to_coordinator` findings trigger a new roundtable round. Full loop still a deferred design thread | Channel shape settled; no regression |
| W10 disposition gap | Two-case model refined: intake keeps a light current-state analysis (most business gaps caught before EARS); gaps the dialogue uncovers follow decision D2 (operator-approved EARS amendment, or spawned feature for large gaps); technical gaps → enabler plan steps or spawned feature | Wall preserved, with an explicit exception rule |

## 3. Target Pipeline

Init phase: **unchanged** (steps 1, 1.1, 2). Strategically upgraded rationale: blueprints and the common contract are what allow seats to exist and to talk — a multi-seat conversation is impossible before the classes agree what flows between them. A fully greenfield project cannot convene the roundtable until init is done.

Feature phase: 12 steps → **3 steps**.

| # | Step | Absorbs | Artifact(s) | Gate |
|---|---|---|---|---|
| F1 | Intake & Clarify | 3, 4.1, 4.2 | `feature_br_summary.md`, `user_br_input.md`, `missing_br_data.md` | `ready_to_ears: true` |
| F2 | Formal Requirements | 5, 5.1 | `requirements_ears.md` with mandatory embedded `## Verification` section | verification ran, no escalated findings |
| F3 | Roundtable | 6, 7, 7.1, 8, 8.1, 8.2, 8.3, 8.4 | `implementation_plan.md`, `feature_contract_delta.md`, dialogue transcript | dialogue completeness + plan readiness gate + `plan_approved_by_operator` |

### F1 — Intake & Clarify

As in the light version: one step, one gate, all anti-hallucination mechanics unchanged (verbatim source capture, `[UNFILLED]` discipline, missing-data ledger, human-in-the-loop Q&A until `ready_to_ears`). Intake keeps a **light current-state analysis** — enough awareness of what exists to ask informed clarification questions, so most business-perspective gaps become ledger questions and enter EARS from the start. Deep grounding no longer happens here; it moved into F3.

### F2 — Formal Requirements

As in the light version: EARS stays a distinct formalization step (REQ IDs are the coordination currency in worker commits), with the drift audit as a mandatory embedded verification pass writing into the EARS document's own `## Verification` section. EARS is immutable after F2 except through decision D2's operator-approved amendment path.

### F3 — Roundtable

Everything technical is one moderated session on the coordinator machine:

1. **Draft.** The PO agent drafts a plan and a contract-delta sketch from what the coordinator already knows: the project-stable tier (blueprints, common contract), EARS, committed sibling promises, and the living surface inventory. Every draft step is assigned to a class from the start (P9) — that assignment is the routing table for the whole dialogue. Deliberately no fresh deep repo scans — the draft only needs to be good enough to be attacked; its errors are recoverable by design.
2. **Seating.** Every active class gets a seat: a fresh-context agent bound to that class's local repo clone plus that repo's own `AGENTS.md` (repo-tier evidence), or — for Type-A / not-yet-attached classes — a seat played from the blueprint (blueprint-tier evidence). A class may also be explicitly `deferred`, never silently skipped.
3. **Question rounds.** The PO agent addresses each seat with the questionnaire — simultaneously the attack checklist and the grounding sweep (see Sweep Survival Map). Per-step questions ("can you do this? what is missing? what does it silently assume?") go to the seat that owns the step; roster questions (surface sweep, per-REQ current state, contract impact) go to every seat. Answers must cite evidence; "no impact on my repo" is a valid answer, silence is not. Seats may cross-question other seats (FE→BE: "can you return this in the same JSON?"); the PO routes, arbitrates, and lands every resolution in the plan or the contract delta.
4. **Revise and loop.** The PO applies answers and bumps the plan revision. Rounds are bounded (~3, then the human decides). The human PO watches and steers the whole session — free-form improvements, decisions on objections, D2 amendments.
5. **Commit.** Dialogue-completeness and plan-readiness gates pass, collision review against sibling promises is shown to the operator, the operator sets `plan_approved_by_operator` → plan commits, promises emit.
6. **Optional — distill step designs (D3).** The PO distills each step's seat answers into a per-step design doc in the shape the worker's design phase already produces (scope contract, selected EARS, evidence references, risks, Things-to-Decide, bootstrap decision) and commits it alongside the plan. The dialogue knowledge that would otherwise die in the transcript becomes the worker's design input; a worker finding a valid step-design starts directly from its step-plan phase.

**Greenfield behavior falls out for free.** A blueprint-played seat's closure answers are necessarily "nothing exists yet — repo scaffold first", so the first feature's plan comes out front-loaded and correctly ordered: contract materialization (e.g. the actual `openapi.yaml`) → scaffolds → one thin vertical slice. An FE-first request against a nonexistent backend cannot pass the readiness gate silently — it must be reordered, built against the contract with mocks, or explicitly rejected by the operator. As classes climb the evidence ladder from blueprint to repo tier, these enabler answers disappear on their own.

**Degradations.** Single-class project → a roundtable with one seat is simply a plan-attack loop. Repo the PO cannot clone → async fallback seat through the worker channel, or blueprint-tier answers; the evidence ladder prices this honestly (repo seat > async worker answer > blueprint > placeholder).

### Sweep Survival Map

Per P5, every current forced-answer sweep must have a named home in the target. This table is the redesign's acceptance checklist:

| Current sweep ("did we forget…?") | Target home |
|---|---|
| 6: a shared-contract impact? (explicit "no delta") | F3 questionnaire item per seat: contract impact for your class — explicit `none` required |
| 6: the agreed cross-class transport/schema? (mirror) | script check on `feature_contract_delta.md` at plan commit |
| 7: a class? | F3 seating rule: every active class seated (repo or blueprint tier) or explicitly `deferred` |
| 7: a surface? (enumeration + interrogation) | F3 questionnaire: each seat sweeps its own repo's surfaces against the feature (roster = repo reality + living inventory) |
| 7: delivery vs reachability side? | questionnaire row schema keeps both subfields (`transport_layer` / `user_reachable_surface`) |
| 7: that we actually don't know? | every seat answer carries its evidence tier |
| 8: a requirement without a technical answer? | questionnaire per REQ touching the class: current state + gap; completeness gate: every REQ answered by ≥1 seat |
| 8.2: a load-bearing prerequisite? | questionnaire closure question per REQ ("what must exist for this to run end-to-end?"); readiness gate item 2 (zero-unmet, re-runnable) |
| 8.1: delivering the user-facing thing itself? | questionnaire preserved-surface item + readiness gate item 3 |
| 8.3: a sequencing dependency / repo owner? | seats' ordering objections in dialogue + readiness gate items 4–5 |
| 8.4: coherence + operator improvements? | the session itself (bounded rounds, operator steering) + `plan_approved_by_operator` |

## 4. Artifact Inventory Before → After

| Current (per feature) | Target |
|---|---|
| `feature_br_summary.md` | kept (F1) |
| `user_br_input.md` | kept (F1) |
| `missing_br_data.md` | kept (F1, ledger) |
| `requirements_ears.md` | kept (F2), gains embedded `## Verification` |
| `requirements_ears_review.md` | **absorbed** into F2 verification section |
| `feature_contract_delta.md` | kept, **negotiated inside F3** (decision D1) — sketched in the draft, refined by cross-questions, landed by the PO |
| `project_surface_struct_resp_map_<class>.md` | **replaced**: seats sweep their own repos live; project-level living inventory feeds the draft |
| `technical_requirements.md` | **becomes dialogue turns** (seat answers in the transcript; evidence lands on plan steps) |
| `implementation_slices.md` | **gone** — the draft plan is the decomposition; ordering objections come from seats |
| `prerequisite_gaps.md` | **split**: discovery → closure answers in dialogue; verification → readiness gate |
| `implementation_plan.md` | kept (F3), unchanged worker-facing format, revised in place across rounds |
| `implementation_plan_semantic_review.md` | **gone** — the session is the review; objections/dispositions live in the transcript |
| — | **new**: dialogue transcript (audit artifact: who asked what, what evidence answered, which objections were overruled and why) |
| — | **new, optional (D3)**: per-step design docs distilled from seat answers, in the worker's existing step-design shape |

Net: ~13 artifacts → 7. Paraphrase hops from captured input to plan: 5 → 3.

## 5. Mechanical Gate Inventory (target)

**Plan readiness gate** — runs on every plan edit **and** at worker-assignment time (assignment stays the execution gate, per the concurrency design):

1. Every REQ/NFR maps to ≥1 plan step or an explicit recorded deferral.
2. Every unmet prerequisite from closure answers is scheduled (step ref) or resolved by a committed cross-feature promise — zero-unmet.
3. Every required missing `user_reachable_surface` appears as a `#### Preserved Surface:` on some step.
4. Dependency graph acyclic, including cross-feature refs; steps with incomplete cross-feature deps get a hold marker (existing rule, unchanged).
5. Each step has exactly one `#### Repo:` owner.

(The light version's item 6 — Pass B structural prose diff — is dropped: there are no Pass A/B anymore; decompose/order separation is replaced by draft + seat objections.)

**Dialogue completeness gate** — at session end: every active class seated or explicitly deferred; every addressed questionnaire item answered (explicit `none` counts, silence blocks); every REQ covered by ≥1 seat; closure answers recorded in machine-readable form so the readiness gate can consume them.

Other gates: `ready_to_ears` (existing), EARS verification ran with zero escalated findings, mirror script check on `feature_contract_delta.md` at commit, EARS amendments only via operator-approved D2 entries, and **`plan_approved_by_operator`** — the technical-side twin of `ready_to_ears`; without it the plan cannot commit or emit promises, and the model cannot set it.

## 6. What Is Deliberately NOT Cut

- EARS as a separate formalization step (coordination currency in worker commits).
- `feature_contract_delta.md` as an artifact and the mirror discipline (only the standalone step is gone — D1).
- Evidence-tier ladder and per-class `state` gating (settled per-class transition design).
- The `ready_to_ears` human-in-the-loop clarify gate (anti-hallucination core).
- The interactive refinement checkpoint — it became the session itself.
- The worker handoff contract (`#### Repo/Depends on/Evidence/Preserved Surface/Assigned`, cross-feature dep syntax, step sizing) and the promise/concurrency model (all-or-nothing promise eligibility, hold markers, collision review at plan commit). The base contract — EARS + implementation plan — stays valid as-is; D3's step-design docs are an optional extension on top of it, never a replacement.
- The forced-answer sweep discipline: every roster×question sweep survives (Sweep Survival Map), and "nothing" is always an explicit recorded `none`.

## 7. Target Flow (informal)

```mermaid
sequenceDiagram
  autonumber
  actor OP as Operator (human PO)
  participant PO as PO agent (coordinator)
  participant S as Class seats (fresh context, one per class, own repo each)
  Note over PO: init phase unchanged (1, 1.1, 2) — treaty precedes any roundtable
  PO->>OP: F1 Intake & Clarify (loop until ready_to_ears)
  PO->>PO: F2 EARS + embedded verification
  PO->>PO: F3 draft plan + contract-delta sketch (stable tier + EARS + promises + inventory)
  loop bounded rounds (~3)
    PO->>S: questionnaire (attack checklist + grounding sweep, per seat)
    S-->>PO: evidence-backed answers, cross-questions, ordering objections
    PO->>PO: arbitrate, land resolutions in plan / contract delta, bump revision
    OP->>PO: steer; approve EARS amendment if a missed business gap surfaces (D2)
  end
  PO->>OP: gates green + collision review → sign-off request
  OP->>PO: plan_approved_by_operator
  PO->>PO: commit plan, emit promises → workers implement (lazy sign-off via design phase)
```

## 8. Settled Decisions, Pending Decisions, Deferred Topics

Settled (July 2026):

- **D1 — Contract delta folds into the roundtable.** The artifact and the mirror check survive; the standalone early step does not. Old F3's purpose was letting class tracks run in parallel for days; the roundtable is one sitting, so early publication buys nothing — and greenfield showed contract materialization becomes a plan step anyway. Distinct from `common_contract_definition.md` (init-level treaty), which is untouched.
- **D2 — Missed business-visible gap uncovered mid-dialogue** (closes the light version's "open sliver"): pause the session, the operator decides, EARS gets a controlled operator-approved amendment (new REQ), the session resumes. Cheap because the operator is already present. Large gaps → spawn a prerequisite feature (admin-auth precedent) and depend on it via promises. Never a silent append.
- **D3 — Optional step-design handoff.** The roundtable can distill seat answers into per-step design docs in the worker's existing step-design shape. Worker-side rule (small yasdef change): if a valid step-design artifact already exists for the selected step, skip the design phase and start from step-plan — validity is decided by the worker's existing design readiness gate, not by provenance. Backward compatible in both directions: overmind without distillation → worker designs as today; a stale or thin committed design fails the readiness gate → worker's design phase runs as a refresh/complete fallback. Worker-local knowledge (ADR shortlist, UR rules) is never produced by the coordinator — the worker's planning phase overlays it as today. This also removes the last double-grounding: the seat's evidence-backed work becomes the design input instead of being rediscovered.

Pending (decide before/while specifying — see `03_refactoring_plan.md`):

- **Questionnaire template** — the design-heavy piece: sweep completeness (the unknown-unknown detector) now lives here instead of in step documents. Front-loading round 1 is what keeps round counts low.
- **Transcript format** — including the machine-readable trace (closure answers, coverage, dispositions) that the gates consume, and session resumability (an interrupted roundtable must resume from the transcript).
- **Living inventory** — bootstrap for existing repos and update timing as features land (it is a drafting input; seats sweeping real repos make it non-load-bearing for correctness).
- **Seat context recipe** — exactly what a seat receives (repo clone, `AGENTS.md`, draft, treaty, which slice of EARS) to keep enforced ignorance real.
- **Step-design distillation depth (D3)** — how much of the design template the roundtable fills (recommendation: the spec core — scope contract, EARS selection, evidence, contract decisions, risks, bootstrap, Things-to-Decide — leaving full design depth to the worker when needed) and when distillation is worth running at all.

Deferred (unchanged from before):

- **Feedback loop** — full worker→coordinator re-planning design; the channel shape is now settled (dialogue messages, lazy sign-off via worker design phase, `raised_to_coordinator` triggers a new round), the rest remains a separate thread.
- **Multi-repo class** — class=repo=worker 1:1:1 assumption unchanged; list-shaped `class_repo_paths` hedge stands.
- **Async fallback seat protocol** for repos the PO cannot clone — design only if the case materializes.
- **Worker as a generic SDD-spec executor** (yasdef-side product thread): D3's readiness-gate-as-acceptance already implies that any spec filling the step-design contract can drive the worker from step-plan onward (OpenSpec, spec-kit, hand-written designs). Needs a spec-intake mode not bound to a coordinator project and coordinator-mode extras (plan sync-back, REQ-id commit currency, `raised_to_coordinator`) made optional. Splits the products cleanly: overmind = spec producer, worker = spec executor.
