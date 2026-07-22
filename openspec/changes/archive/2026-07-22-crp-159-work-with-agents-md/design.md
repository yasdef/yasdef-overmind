## Context

Init step 1.1 today runs one `overmind-stack-blueprint` session per active class of a type `A` project, producing `project_stack_blueprint_<class>.md`. That artifact captures stack choices and layer/folder conventions with explicit operator approval, validated by `overmind gate stack-blueprint`. It is durable planned evidence: step 2 refuses to build the common contract without it, the initialization baseline commit owns it, and step 7 keeps it as read-only fallback evidence once a repository is attached.

Nothing in the pipeline turns that approved structure into agent-facing engineering guidance. The step catalog ends at 8.4; the agent that eventually scaffolds and implements the repository is external to Overmind and starts with no durable statement of mission, engineering rules, testing standard, quality gates, or definition of done for its class.

This change adds a sibling artifact, `project_agents_md_claude_md_<class>.md`, produced in the same step, from the same operator-approval discipline, and derived from the blueprint that step 1.1 has just approved.

## Goals / Non-Goals

**Goals:**

- Produce one gate-passing agent-guidelines artifact per active class of a type `A` project, at the project root, alongside that class's stack blueprint.
- Derive the artifact's structural sections from the approved blueprint so the two artifacts cannot drift apart.
- Reuse the blueprint's source chain unchanged: knowledge base when configured, bounded fallback otherwise, explicit operator approval before any write.
- Make the artifact recognizable to a future agent through a stable document-meta header.
- Preserve an already-approved artifact byte-for-byte when step 1.1 is re-entered.

**Non-Goals:**

- Authoring the repository's real `AGENTS.md` or `CLAUDE.md`. That remains the external worker's duty; this change produces the handoff document only.
- Adding an in-pipeline consumer for the artifact. No feature-phase step (3 through 8.4) reads it.
- Extending eligibility beyond the blueprint's. Project type `B` and `C`, class `state`, and per-class `policy` are outside this change.
- Reworking the step-1.1 dispatch loop's re-run behavior for existing classes. This change works within it.

## Decisions

**Second action inside step 1.1, not a new step 1.2.**
Step 1.1's per-class dispatch already loops the active classes; adding a second session action to the existing step keeps one class's blueprint and its guidelines in one dispatch, so a class is never left with a blueprint and no guidelines. The alternative — a separate step 1.2 — would let the two artifacts be approved and resumed independently, but it adds a numbered step, a second completion condition to sequence against step 2, and a window in which a project sits with blueprints only. The cost of the chosen option is that the two artifacts share one completion condition and cannot be re-run independently; the presence-preserving behavior below makes that cost acceptable.

**Blueprint is a required read-only input, not an optional one.**
`overmind context agents-md` errors (exit `2`) when the class's blueprint is absent. `Stack Baseline`, `Target Project Shape`, and `Layer Responsibilities` are projections of blueprint sections 2 and 3; without the blueprint they would have to be invented, which is exactly the drift this design exists to prevent. Ordering the two actions within step 1.1 guarantees the blueprint exists by the time the agents-md session runs.

**Presence is the trigger, and an existing artifact is preserved.**
The step-1.1 dispatch runs a session for every active class whenever the step goes pending — for example when a class is added to an existing type `A` project. The context command therefore reports `agents_md_status: present|absent`. On `present`, the skill verifies the artifact against the gate and stops without writing; it does not regenerate. Revising a present artifact requires the same explicit operator approval as initial creation. This mirrors the blueprint skill's revision rule, which today is the only thing preventing approved blueprints from being silently rewritten on re-entry.

**Gate validates structure, not judgment.**
`overmind gate agents-md` checks the document-meta header, the presence and order of required sections, `last_updated` format, and the absence of `[UNFILLED]` placeholders — the same shape as the blueprint gate, with the same `0` / `1` / `2` contract. It does not check whether the guidance is good, whether it came from the knowledge base, or whether the operator approved it. Those remain operator responsibilities, consistent with how the blueprint gate already works.

**Optional sections are operator-input only.**
`Accessibility (a11y)`, `Internationalization (i18n)`, `UI Automation IDs`, and `Applied Visual Style Contract` apply to `frontend` and `mobile`. Fonts, hex palettes, and automation-id conventions are project decisions that no knowledge base or bounded default can supply honestly, so the gate does not require them; when present, the gate validates their heading form only.

## Risks / Trade-offs

**Existing type `A` projects re-enter step 1.1.** → Every completed type `A` project goes pending on 1.1 until each active class has an agents-md artifact. The blueprint session runs again for those classes as part of the same dispatch. Mitigated by the presence-preserving rule applying to both artifacts: a present, gate-passing blueprint is verified and left unchanged, so re-entry adds the missing artifact rather than rewriting the approved one.

**One completion condition covers two artifacts.** → A class cannot have its guidelines re-approved without re-entering the blueprint session too. Accepted: the presence check makes the blueprint session a no-op verification in that case.

**The artifact has no in-pipeline consumer.** → Nothing enforces that the produced guidelines are ever used; a worker may ignore the file. Accepted for this change. The document-meta recognition header exists precisely so a later change can bind it to a worker step without re-cutting the artifact format.

**Class-specific golden examples set a quality bar the fallback cannot reach.** → The frontend golden example is a full enterprise Angular guideline document; a knowledge-base-less run producing a bounded-fallback artifact will be visibly thinner. Accepted: golden examples are quality targets, not normative rules, and the gate enforces structure only.
