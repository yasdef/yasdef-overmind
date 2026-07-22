## Why

The `implementation-slices` gate decides whether a required missing operator-facing surface is delivered by resolving its `slice_ref` and then judging the linked slice's prose through `looksSupportingOnly(...)`. That judgement blocks correct plans. Its "supporting" vocabulary — `api`, `service`, `dto`, `repository`, `schema`, `state`, `mapper`, `payload` — is what every backend slice is written in, so a backend slice passes only when its prose also happens to contain one of roughly eighteen accepted surface words.

A measured run failed exactly this way: a slice whose `first_increment` reads `` `POST /api/v1/telegram-identities` accepts valid new users `` was rejected as supporting-only scaffolding, because it named its surface as an HTTP method and path rather than using the word `endpoint`. The four artifacts agreed, the plan was correct, and the operator was sent back to step `8.1` to rewrite wording until the vocabulary matched. That is the same failure shape CRP-171 was written to remove: a gate rejecting a feature whose artifacts agree.

## What Changes

- Decide coverage of a required missing operator-facing surface from referential integrity alone: the `slice_ref` is present, has the form `slice-<N>`, and resolves to exactly one slice declared in `implementation_slices.md`.
- **BREAKING** Retire the supporting-only judgement of the linked slice from the `implementation-slices` gate, and with it the gate's only rule that reads free artifact prose to form an opinion about meaning.
- Rest the delivery judgement on the artifacts that already carry it: the `evidence` field the `prerequisite-gaps` gate requires on every scheduled entry, the `slice/<ref>` plan-step evidence token the `implementation-plan` gate requires, and semantic review.
- Teach the `implementation-plan` gate's per-step preserved-surface judgement to recognize an HTTP method and path as surface wording, keeping the rule itself as CRP-171 decision `D6` left it.

## Capabilities

### New Capabilities

- None.

### Modified Capabilities

- `slice-ref-surface-coverage`: coverage of a required missing operator-facing surface stops depending on how the linked slice is worded and rests on the resolved link, and an HTTP method with a path counts as operator-facing surface wording where a gate still judges one. Defined by the pending delta in `openspec/changes/crp-171-slice-ref-surface-coverage/specs/slice-ref-surface-coverage/spec.md`; `openspec/specs/` holds no synced capability yet, so this change archives after CRP-171.

## Impact

- `packages/asdlc-coordinator/src/validate/implementation-slices.ts`: drop the supporting-only branch from the coverage loop, and drop `looksSupportingOnly(...)` once the module no longer uses it.
- `packages/asdlc-coordinator/src/validate/implementation-plan.ts`: its private `looksSupportingOnly(...)` learns the HTTP method and path form; the per-step preserved-surface rule keeps its current behavior otherwise.
- `packages/asdlc-coordinator/test/implementation-slices-validator.test.ts`: the supporting-only link test is replaced by one proving a slice worded as scaffolding still covers a surface whose link resolves.
- `packages/asdlc-coordinator/test/implementation-plan-validator.test.ts`: covers a step whose preserved surface is named as an HTTP method and path.
- `packages/installer/_data/skills/overmind-implementation-slices/SKILL.md`: the wording rule that exists to satisfy the retired judgement is no longer a gate condition.
- `packages/installer/_data/skills/overmind-prerequisite-gaps/SKILL.md`: states that `evidence` carries the delivery justification the gate no longer infers from slice wording.
- Features already planned keep every field they carry; the gate reaches fewer conclusions from them.
- No change to step ordering, the catalog, the terminal gate chain, the `prerequisite-gaps` gate's own rules, repair-step ownership, or the CLI surface.
