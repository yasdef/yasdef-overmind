# Project Contract Reconciliation Rule

Read this file fully before editing.

## Purpose
- One-time, first-attach reconciliation of `common_contract_definition.md` against the as-built API of the classes whose repos have just attached.
- It clears blueprint-era drift only: the contract was authored from blueprint intent and never reality-checked. Ongoing drift after first attach is out of scope (the feedback loop owns it).

## Scope: reconcile each in-scope class's role
- The prompt context lists the in-scope classes (with their repositories) and the out-of-scope classes. Use only the in-scope repositories as as-built API evidence.
- For every contract entry, reconcile only the role played by an in-scope class, judged against that class's repository:
  - You may correct fields an in-scope class is the `source_of_truth` for — for example, the produced `canonical_shape` of an API it serves.
  - Attribute each role using the contract's `producer_repositories` / `consumer_repositories` / `source_of_truth` fields and the repository-to-class source blocks in `common_contract_definition.md`.
- When every participant of a contract is in scope, you may reconcile the whole entry. When a participant is out of scope, reconcile only the in-scope side.

## Out-of-scope classes are untouchable
- Treat any contract surface owned or produced by an out-of-scope class as read-only: do not flag, remove, rewrite, or challenge it.
- An out-of-scope class has no attached repository in this run, so the absence of its surface from the in-scope repositories is never evidence of drift. Absence means "this participant is not attached yet," never "this contract is wrong."
- Never remove a contract entry because one of its participants has not attached.
- Record a consumer-side mismatch (an in-scope consumer that does not match a contract whose source of truth is out of scope) as `planning_implication: reconcile consumer drift`, not by rewriting the `canonical_shape`.
- If a contract's owning class cannot be determined from its fields, leave it out of scope; do not guess.

## Workflow
- Read the current `common_contract_definition.md` (path given in the prompt context) as the documented contract to reconcile.
- List the mismatches between the in-scope documented contract and the as-built API for operator review.
- For each proposed correction, ask the operator to approve, reject, or revise before editing.
- Write back only operator-approved corrections to `common_contract_definition.md`. If the operator approves none, leave it unchanged.

## Quality gate (you own this)
- After changing the contract, run the quality gate command provided in the prompt and make it exit 0 before finishing. You own this loop; nothing downstream re-validates the contract for you.
- Exit 0 means the contract passes — proceed.
- Exit 1 means content problems: treat the helper output as authoritative fix instructions, correct the contract, and rerun until it exits 0.
- Exit 2 means the helper itself failed (environment/helper error, not your content): stop and report; do not loop.
- Do not finish a changed contract that has not passed the gate; if it cannot pass with the available evidence, stop with the exact "cannot pass" line given in the prompt.

## Must not own / must not do
- Do not modify `init_progress_definition.yaml`.
- Do not modify any attached repository source files.
- Do not perform continuous or repeat reconciliation; this phase runs once per class at first attach.
- Do not infer or invent surface for a class with no attached repository.
