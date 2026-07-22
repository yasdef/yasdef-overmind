## Why

A type `A` project reaches its first implementation with an approved `project_stack_blueprint_<class>.md` but no agent-facing engineering guidance: the coding agent that later scaffolds the repository has no durable statement of mission, engineering rules, testing standard, quality gates, or definition of done, so each worker re-invents them per session and per class. The stack blueprint already establishes the class's stack choices and layer/folder conventions with operator approval, which makes it the natural derivation source for a per-class agent-guidelines handoff artifact.

## What Changes

- Add a per-class project-init artifact `project_agents_md_claude_md_<class>.md` at the project root for every active class of a type `A` project. It is the handoff document a downstream coding agent uses to author the repository's own `AGENTS.md` and `CLAUDE.md`.
- Add the packaged skill `overmind-agents-md` with class-specific template and golden-example assets for `backend`, `frontend`, and `mobile`.
- Add the context command `overmind context agents-md <project> --class <backend|frontend|mobile>`, binding the approved `project_stack_blueprint_<class>.md` as a required read-only input, the target artifact, the gate command, the class assets, `external_sources_status`, and `agents_md_status`.
- Add the deterministic TypeScript quality gate `overmind gate agents-md <path>` with the standard `0` / `1` / `2` exit-code contract.
- **BREAKING** Extend init step 1.1 with a second per-class action. Step 1.1 becomes: for each active class, a stack-blueprint session followed by an agents-md session. Its label changes to cover both artifacts, and the step is complete only when every active class has both artifacts present and gate-passing. Existing type `A` projects that completed step 1.1 before this change re-enter it until each active class has an agents-md artifact.
- Step 2 (Create Cross-Repository Contract Definition For This Project) blocks on the new artifact exactly as it blocks on missing blueprints today, and the step-2 initialization baseline commit adds `project_agents_md_claude_md_<class>.md` to its owned paths.
- The agents-md artifact carries a recognizable document-meta header so a future agent can identify it, sections derived from the approved blueprint (`Stack Baseline`, `Target Project Shape`, `Layer Responsibilities`), gate-required engineering sections sourced through the knowledge base / bounded fallback / operator-approval chain, and optional operator-input-only sections for frontend and mobile.

## Capabilities

### New Capabilities

- `overmind-agents-md-artifact-contract`: the structure and content rules of `project_agents_md_claude_md_<class>.md` — the recognition header, the blueprint-derived sections, the gate-required engineering sections, the optional class-specific sections, and prohibited content.
- `overmind-agents-md-quality-gate`: the deterministic TypeScript validator behind `overmind gate agents-md <path>` and its exit-code semantics.
- `overmind-agents-md-authoring-flow`: the `overmind-agents-md` skill and its `overmind context agents-md` binding — the knowledge-base / bounded-fallback / operator-approval source chain, the model-owned gate loop, the single-artifact write surface, and the presence-preserving behavior for an already-approved artifact.
- `overmind-agents-md-init-flow`: step 1.1's second per-class action, the extended step-1.1 completion condition, the step-2 precondition, and the initialization baseline commit's owned paths.

### Modified Capabilities

<!-- None. `openspec/specs/` holds no consolidated specs; the affected step-1.1 and blueprint behavior is captured by the new `overmind-agents-md-init-flow` capability. -->

## Impact

- `packages/asdlc-coordinator/src/sequencing/step-catalog.ts`: step 1.1 gains a second session action and a new label.
- `packages/asdlc-coordinator/src/context/agents-md.ts` (new) and `src/context/index.ts`: the agents-md context builder.
- `packages/asdlc-coordinator/src/validate/agents-md.ts` (new) and `src/validate/index.ts`: the agents-md gate.
- `packages/asdlc-coordinator/src/cli/run.ts`: `agents-md` registered in the gate and context registries.
- `packages/asdlc-coordinator/src/runner/execute-step.ts` and `src/runner/prompt-builder.ts`: agents-md session dispatch and prompt binding.
- `packages/asdlc-coordinator/src/context/common-contract-init.ts`: step-2 precondition extended to the new artifact.
- `packages/asdlc-coordinator/src/cli/run.ts` `commitInitializationBaseline`: owned paths extended.
- `packages/installer/_data/skills/overmind-agents-md/` (new): `SKILL.md` plus per-class template and golden-example assets; installer packaged-skill fan-out.
- `packages/installer/_data/templates/init_progress_definition_TEMPLATE.yaml`: step 1.1 required artifacts and completion conditions.
- `overmind/rules/`, `overmind/templates/`, `overmind/golden_examples/`: the source-of-truth rule, templates, and golden examples for the new artifact.
- No change to feature-phase steps 3 through 8.4; the artifact has no in-pipeline consumer, since the catalog ends at 8.4 and the worker that authors `AGENTS.md` / `CLAUDE.md` is external.
