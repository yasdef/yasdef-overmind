## Why

The migrated Task-to-BR stage can pass every structural and lexical gate while producing a weak clarification ledger: measured UMSS reruns surfaced four, three, and one questions after paraphrasing source ambiguity out of the derived BR. The legacy master step 4.1 session instead resolved five business uncertainties in-session and recorded the answers in `confirmed_assumptions`; it produced no `missing_br_data.md`, so step 4.2 did not run. Step 4.1 must recover that focused semantic discovery quality while deliberately retaining the migrated ledger handoff, without adding another artifact, phase, or semantic validator.

## What Changes

- Restore a concise raw-story-to-BR semantic extraction contract in the deployed `overmind-task-to-br` skill: inspect each source obligation for a missing business decision, unresolved acceptance condition, guard, outcome, or boundary before finalizing the BR.
- Require every material unresolved decision discovered by that source review to become one targeted business question in the existing `missing_br_data.md` ledger, with duplicate restatements consolidated into one question.
- Keep the existing TypeScript lexical ambiguity check as a deterministic backstop over generated BR fields; do not treat passing its closed token list as evidence that semantic question discovery is complete.
- Keep step 4.2 as the existing ledger-driven interview; improve the questions it receives rather than adding a second question-discovery loop.
- Simplify the model-facing semantic instructions where they duplicate gate mechanics, keeping TypeScript responsible for paths, structure, and stable gate behavior and the skill responsible for business judgment.
- Add behavioral acceptance evidence against the identical measured UMSS source, using the legacy run as the quality baseline and checking repeated runs for material-question recall and question relevance. This step-4.1 acceptance is independent of CRP-173's downstream step-5.1 review.

## Capabilities

### New Capabilities

- `task-to-br-semantic-question-discovery`: Focused source-obligation review that produces relevant unresolved-business questions in the existing clarification ledger before BR readiness.

### Modified Capabilities

<!-- None. openspec/specs/ contains no consolidated Task-to-BR semantic-question capability. -->

## Impact

- `packages/installer/_data/skills/overmind-task-to-br/SKILL.md` and its Task-to-BR golden examples.
- Task-to-BR skill-contract, installer-propagation, and measured behavioral acceptance coverage.
- The existing `packages/asdlc-coordinator/src/validate/task-to-br.ts` lexical backstop remains structurally scoped; no new semantic validator, artifact, phase, command, CLI option, or ledger format is introduced.
- Step 4.2 invocation, interaction protocol, and readiness transition remain unchanged.
