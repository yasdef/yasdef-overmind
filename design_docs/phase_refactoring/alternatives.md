# Phase Refactoring: Alternative Approaches (Exploration Record)

Status: **exploration record, kept for decision provenance — not an active design document.** This doc asked whether the consolidation redesign (12 steps → 5, audits → gates; preserved in `design_docs/phase_refactoring_light_version/`) was too timid, and proposed three paradigm-breaking alternatives. Outcome (July 2026): **Alternatives 2 + 3 were fused into the roundtable design and promoted to the target architecture** — `02_phase_redesign_and_target_architecture.md` is the authoritative description. Alternative 1 was not chosen and is preserved here as the main road not taken.

---

## 1. What the consolidation redesign did not question

Four assumptions pass from the old pipeline into the consolidation target untouched:

- **A1 — Knowledge lives in prose documents, connected by paraphrase hops.** The consolidation cuts hops from 5 to 4. It reduces drift; it does not remove the mechanism that creates drift.
- **A2 — The plan comes last.** All knowledge is built up front, then planning starts. Waterfall shape, unchanged.
- **A3 — The coordinator grounds everything centrally.** It scans repos it does not own and builds surface maps — and then the worker re-grounds every step into the codebase anyway (yasdef worker runs its own design and planning phases per step). Grounding happens twice by design.
- **A4 — Every feature pays the same process.** Admitted as unresolved in `design_docs/phase_refactoring_light_version/02_phase_redesign_and_target_architecture.md ## 8. Pending Decisions and Deferred Topics` (feature-size proportionality).

Each alternative below breaks one of them.

---

## 2. Alternative 1 — Feature dossier instead of a document pipeline (breaks A1)

**Outcome: not chosen.** Preserved because it may resurface: the roundtable's pending "machine-readable transcript trace" (closure answers, coverage, dispositions consumed by gates) is a mini-dossier — if that trace grows, revisit this idea.

**Idea.** One structured store per feature (a "dossier": yaml/json, or one file with strict sections). Pipeline state is "which questions are answered, with what evidence" — not "which documents exist". The worker-facing artifacts (`requirements_ears.md`, `implementation_plan.md`) are **rendered views** of the dossier, generated in the exact current format. Nothing downstream is hand-paraphrased from something upstream.

**What changes.**
- Steps stop being the unit of progress. What remains is a fixed catalog of questions — exactly the current sweeps. `status` lists unanswered questions instead of the next step.
- A fact is written once and referenced everywhere. The copy-drift error class (W2, W3) is deleted structurally, not audited down.
- Gates become cheap: mechanical checks over structured fields instead of parsing prose (finishes W1).
- The two-sources-of-truth problem (W8) disappears: diagrams and documents are all renders.

**What it costs / risks.**
- Biggest build effort of the three: schema design, renderers, migration of templates.
- LLMs reason better in prose than in schemas. The working style must be "think in prose, commit to fields".
- The schema becomes the new thing that can rot; changing it mid-project is harder than editing a template.

---

## 3. Alternative 2 — Plan-first, then attack it (breaks A2)

**Outcome: chosen** — fused with Alternative 3 into the roundtable (`02_phase_redesign_and_target_architecture.md`).

**Idea.** Draft a plan almost immediately — right after intake and EARS — cheap and admittedly wrong. Then run every current sweep as an **attack pass** on the draft: "which surface did the draft miss?", "which REQ has no step?", "what does step 3 silently assume exists?". Each attack produces findings; findings fix the draft; loop until a full attack round comes back empty.

**Key properties.** Discovery becomes targeted (sweeps interrogate a concrete proposal); cost becomes proportional to feature size for free (resolves A4/W6 without a separate express lane); the sweeps and explicit-`none` discipline survive, just re-aimed. Main risks: anchoring on the early draft (attacks must run in fresh context) and completeness now depending on attack quality — mitigated by keeping the surface inventory and class list as the attack checklist.

---

## 4. Alternative 3 — Workers ground their own repos (breaks A3)

**Outcome: chosen in essence.** Its real value turned out to be *per-repo perspective*, not *remote workers*: the per-class voices became local fresh-context seats (enforced ignorance) in the roundtable. The remote-worker variant was rejected (see section `## 7. Deep dive outcome` below); its async mechanics survive only as the fallback seat and the feedback-channel shape in `02_phase_redesign_and_target_architecture.md`.

**Idea.** The coordinator stops scanning repos it does not own. It keeps the business side (intake, EARS) and the inter-class treaty. Each class answers a **grounding questionnaire** about its own repo — surface interrogation, current state and gap per REQ, closure answers, proposed step candidates — with evidence from the repo it knows best. The coordinator merges, orders across classes, arbitrates.

**Key properties.** Grounding happens once, done by the party that will implement; class tracks become genuinely parallel; the answer channel doubles as the deferred feedback loop (W9). Main risks in the remote form: protocol growth, early worker registration, trust shift — all of which the local-seat form avoided.

---

## 5. How they compared

| | Attacks primarily | Main risk | Build effort | Outcome |
|---|---|---|---|---|
| Consolidation redesign (light version) | W1 W3 W4 W5, some W2 W6 | low — same paradigm | low | preserved as fallback |
| 1. Dossier | W1 W2 W3 W8 at the root | schema rigidity | high | not chosen; may resurface via transcript trace |
| 2. Plan-first attacks | W6 and A4 at the root; W5 naturally | anchoring | medium | **chosen** (fused) |
| 3. Worker grounding | double-grounding, opens W9 | protocol complexity | medium-high | **chosen in essence** (local seats) |

## 6. Assessment at the time

The consolidation halved ceremony and fixed enforcement, but treated drift, waterfall cost, and double-grounding as things to *reduce*, while each alternative deleted one of them *structurally*. The suggested cheap probe — run Alternative 2 manually on one small feature — became Phase 0 of `03_refactoring_plan.md`.

## 7. Deep dive outcome

The deep dive that fused Alternatives 2 + 3 went through two drafts:

1. **Async review-thread over git** (coordinator ↔ remote worker machines, PR-review style): rejected by the operator — planning rounds would take days, and the PO would have to chase N humans into running commands just so models can talk. The durable lesson: *distribute only where the humans are distributed* — planning has one human (the PO), execution has many.
2. **Roundtable planning on one machine** (local per-class seats with enforced ignorance): accepted and promoted. The full design — principles, F1/F2/F3 pipeline, sweep survival map, gates, settled decisions D1–D3 — lives in `02_phase_redesign_and_target_architecture.md`; the rollout lives in `03_refactoring_plan.md`. This document intentionally no longer describes that architecture, to keep a single source of truth.
