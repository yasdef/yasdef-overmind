---
name: overmind-contract-reconciliation
description: Use for one-time, first-attach reconciliation of common_contract_definition.md against the as-built API of the classes whose repos just attached during overmind project reconcile.
---

# Overmind Contract Reconciliation

Use this skill during `overmind project reconcile` to reconcile
`common_contract_definition.md` against the as-built API of the in-scope classes
whose repositories have just attached. This inlines the durable reconciliation rule;
it is the single normative source.

## Purpose

- One-time, first-attach reconciliation of `common_contract_definition.md` against the
  as-built API of the in-scope classes.
- Clear blueprint-era drift only: the contract was authored from blueprint intent and
  never reality-checked. Ongoing drift after first attach is out of scope (the feedback
  loop owns it). Do not perform continuous or repeat reconciliation.

## Required Invocation

Run these commands from the installed ASDLC workspace root:

1. Assemble deterministic context (repeat `--class` for every pending class named by the orchestrator):

```bash
node .overmind/overmind.js context contract-reconciliation <project-path> --class <class> [--class <class> ...]
```

2. Read the emitted context block. Use only the listed **in-scope repositories** as
   as-built API evidence. `common_contract_definition.md` is your only writable artifact.

3. Validate after every write or repair with the exact gate command from context:

```bash
node .overmind/overmind.js gate contract-reconciliation <project-path>
```

## Scope: reconcile each in-scope class's role

- The context lists the in-scope classes (with their repositories) and the out-of-scope
  classes. For every contract entry, reconcile only the role played by an in-scope class,
  judged against that class's repository.
- You may correct fields an in-scope class is the `source_of_truth` for — for example, the
  produced `canonical_shape` of an API it serves. Attribute each role using the contract's
  `producer_repositories` / `consumer_repositories` / `source_of_truth` fields and the
  repository-to-class source blocks in `common_contract_definition.md`.
- When every participant of a contract is in scope, you may reconcile the whole entry. When
  a participant is out of scope, reconcile only the in-scope side.

## Out-of-scope classes are untouchable

- Treat any contract surface owned or produced by an out-of-scope class as read-only: do not
  flag, remove, rewrite, or challenge it.
- An out-of-scope class has no attached repository in this run, so the absence of its surface
  from the in-scope repositories is never evidence of drift. Absence means "this participant
  is not attached yet," never "this contract is wrong."
- Never remove a contract entry because one of its participants has not attached.
- Record a consumer-side mismatch (an in-scope consumer that does not match a contract whose
  source of truth is out of scope) as `planning_implication: reconcile consumer drift`, not by
  rewriting the `canonical_shape`.
- If a contract's owning class cannot be determined from its fields, leave it out of scope; do
  not guess.

## Operator decision loop

- Read the current `common_contract_definition.md` (path in context) as the documented
  contract to reconcile.
- List the mismatches between the in-scope documented contract and the as-built API for
  operator review.
- For each proposed correction, ask the operator to **approve, reject, or revise** before
  editing.
- Write back only operator-approved corrections. If the operator approves none, leave the
  contract unchanged.

## Quality gate (you own this loop)

- After changing the contract, run the exact gate command and make it exit `0` before
  finishing. Nothing downstream re-validates the contract for you.
- `0`: the contract passes — proceed.
- `1`: content problems — treat each `missing: quality gate failed: ...` line as authoritative
  fix instructions, correct only `common_contract_definition.md`, and rerun until it exits `0`.
- `2`: the helper itself failed (environment/runtime, not your content) — stop and report; do
  not loop.

## Must not own / must not do

- Do not modify `init_progress_definition.yaml`.
- Do not modify any attached repository source files.
- Do not infer or invent surface for a class with no attached repository.

If gate compliance is not feasible with the current attached-repo evidence, briefly explain the
blocker and end with this exact line:

```text
contract reconciliation gate cannot pass with current repository evidence. Please provide instructions what to do, or adjust inputs and rerun this phase
```

When the gate passes, end the final response with this exact last line:

```text
Contract reconciliation phase is finished. Nothing else to do now; press Ctrl-C so orchestrator can start the next phase
```
