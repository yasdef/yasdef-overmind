## Why

CRP-172 improved direct source extraction but did not restore master-era question discovery: the post-change UMSS run produced one lexical question with no acceptance impact, while the successful master run produced five targeted business questions from the same story before step 4.2. Step 4.1 must return to master's concise active-gap-discovery behavior instead of adding another semantic decision framework.

## What Changes

- Restore the master Task-to-BR rule that every unresolved or low-confidence business detail is externalized as a targeted business question in the existing `missing_br_data.md` ledger.
- Replace CRP-172's source-obligation materiality decision tree and question-suppression clauses with a concise business-gap discovery instruction adapted only to current runtime paths and ledger syntax.
- Remove the closed lexical ambiguity policy and its generated-BR validator enforcement; keep the Task-to-BR validator focused on deterministic artifact structure, ledger state, source bindings, and terminal consistency.
- Keep the current TypeScript context builder, captured-source binding, artifact ownership, ledger format, gate exit codes, and Jira/linked-artifact behavior.
- Keep step 4.2 unchanged as the consumer that asks the questions step 4.1 records.
- Revise the existing golden example and contract tests to demonstrate master-style active discovery without making example wording or the measured UMSS question set normative.

## Capabilities

### New Capabilities

- `task-to-br-active-business-gap-discovery`: Master-style discovery and externalization of unresolved or low-confidence business details during step 4.1 using the existing clarification ledger.

### Modified Capabilities

<!-- None. openspec/specs/ contains no consolidated Task-to-BR discovery capability. -->

## Impact

- `packages/installer/_data/skills/overmind-task-to-br/SKILL.md` and its existing golden examples.
- `packages/asdlc-coordinator/src/validate/task-to-br.ts` and focused validator tests that currently enforce the closed lexical list.
- Installer semantic-preservation and fresh-install contract coverage for the packaged Task-to-BR skill.
- No change to step 4.2, step 5, step 5.1, templates, artifact schemas, commands, CLI options, public workflow, or README behavior.
