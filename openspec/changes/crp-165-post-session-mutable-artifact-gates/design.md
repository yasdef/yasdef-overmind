## Context

The migrated generic executor treats a session as successful when the agent exits `0`, read-only guards remain intact, and `requiredOutputs` exist. It does not invoke any quality gate. Gate execution is delegated to model instructions inside each installed skill: EARS review currently calls only `gate ears-review`, while plan semantic review instructs the model to alternate between `gate plan-semantic-review` and `gate implementation-plan` as it edits each artifact.

That instruction-only boundary has failed in the measured UMSS run. The completed EARS-review session left `requirements_ears.md` Requirements 12 and 13 with bullets shaped as `WHEN ..., THEN THE ... SHALL ...`; the current `requirements-ears` gate reports both bullets as invalid and both requirement blocks as containing no valid EARS pattern. The ledger could nevertheless complete because neither the model's final ledger gate nor the coordinator revalidated the mutable EARS artifact. This is direct evidence that an instruction can be skipped, applied to only the session's primary output, or become stale after a later edit.

CRP-163 already defines EARS review's write surface as exactly `requirements_ears.md` and `requirements_ears_review.md`, adds the raw business input as a read-only source, and explicitly leaves post-session mutable-artifact rechecking out of scope. Plan semantic review already exposes exactly two mutable targets and both gate commands in deterministic context. CRP-165 adds enforcement at the shared executor completion boundary and does not change either review's semantic rules.

## Goals / Non-Goals

**Goals:**

- Make successful completion of EARS review and plan semantic review conditional on every mutable artifact passing its owning gate after the session.
- Declare the complete artifact-to-gate mapping in the step catalog, adjacent to each session action's required outputs and guards.
- Run the whole declared gate set even when an earlier gate fails, so diagnostics show the complete post-session state.
- Preserve recoverable gate exit `1`, runtime gate exit `2`, and the existing rule that a failed action is not checkpointed.
- Keep in-session model gate/repair loops for immediate feedback while making coordinator verification authoritative at the handoff boundary.
- Preserve CRP-163's dedicated EARS read-only guards and two-artifact write surface.

**Non-Goals:**

- A terminal whole-feature chain gate or model-based semantic revalidation of upstream artifacts.
- Automatic coordinator repair, automatic session relaunch, or checkpointing artifacts that fail a gate.
- New artifact validators, validator-rule changes, review findings, CLI commands, or flags.
- Applying post-session re-gating to every single-output session in this change.
- Persisting a failed review across runs. The artifact-driven scanner derives progress from files on disk, never runs gates, and treats `5.1`/`8.4` as optional, so a later plain `overmind run` may still skip a previously failed review. Cross-run "sticky review" enforcement is tracked separately (see Open Questions).

## Decisions

### D1: Share one typed mutable-surface contract between context and catalog

Add a coordinator review-session contract module that exports each review's ordered mutable set as entries containing a feature-relative artifact name and its owning gate name. The EARS-review and plan-semantic-review context builders render their allowed-write surface and mutable runtime targets from these entries. The step catalog attaches the same entries to the matching session action as its optional `postSessionGates` list, so enforcement cannot diverge from the coordinator-generated write surface through duplicated filename lists. The two contracts are:

- Step `5.1`: `requirements_ears.md` → `requirements-ears`; `requirements_ears_review.md` → `ears-review`.
- Step `8.4`: `implementation_plan.md` → `implementation-plan`; `implementation_plan_semantic_review.md` → `plan-semantic-review`.

Normative artifacts are listed first and ledgers second for stable output, but every entry runs regardless of earlier results. Tests assert that both the rendered context and catalog action consume the same typed contract and preserve its exact mappings. CRP-163's separate step `5.1` read-only guard remains independent and unchanged by this property.

Alternative considered: infer gates from `requiredOutputs`. Rejected because `requiredOutputs` currently names the session's produced ledger, not every pre-existing artifact it may modify, and filenames do not always equal gate names. Alternative considered: parse allowed-write text from model context. Rejected because completion enforcement must be typed catalog data, not prose parsing.

### D2: Reuse one typed in-process gate registry for CLI and executor dispatch

Move the non-class gate mapping behind an exported typed registry in the coordinator validation layer. Standalone CLI dispatch continues to use that registry, and `StepExecutorDeps` receives an injectable gate registry defaulting to the same validators. A registry invocation accepts the action's feature path, runtime root, and optional progress sink, adapting those inputs to existing validator signatures without spawning the installed CLI as a subprocess. The standalone `br-clarification` path supplies its current progress sink through this invocation contract, so registry extraction does not bypass its progress output.

This preserves one validator implementation and makes executor behavior deterministic and unit-testable. An unknown declared gate is an executor configuration failure with exit `2`, but the executor continues through the remaining declared entries before returning.

Alternative considered: shell out to `node .overmind/overmind.js gate ...`. Rejected because it adds process overhead and output parsing around validators already linked into the coordinator. Alternative considered: duplicate four validator imports in the executor. Rejected because CLI and post-session dispatch could then drift.

### D3: Run the full gate set after a successful agent return and before action success

When the agent exits `0`, the executor performs its existing read-only verification and required-output checks, then invokes every `postSessionGates` entry against the current feature state. It does not stop after the first failure. Each non-zero result becomes an error diagnostic that names both the mutable artifact and gate and includes its recoverable problems or runtime error.

The action result is:

- exit `0` only when existing post-session checks and every declared gate pass;
- exit `1` when at least one gate returns `1` and no gate or other post-session check produces an exit-`2` condition;
- exit `2` when any gate returns `2`, a gate is unregistered, or an existing guard/output integrity check fails.

The feature orchestrator propagates the resulting exit `1` or `2` classification unchanged. Exit `1` remains a recoverable operator-facing result; it does not trigger automatic action or agent retry. Repair and retry occur only through a later operator-driven run or resume.

If the agent itself exits non-zero, its existing failure remains authoritative and post-session gates do not run because the session is not a completion candidate. Skipped actions likewise run no post-session gates.

Alternative considered: stop on the first failed gate. Rejected because both artifacts may be invalid after one session and local validators are cheap; complete diagnostics reduce blind repair cycles. Alternative considered: always run gates after non-zero agent exits. Rejected because partially written artifacts would add noisy diagnostics without changing the already-failed action outcome.

### D4: Block orchestration checkpointing through the existing failed-action path

No new checkpoint mechanism is needed. `executeStep` already returns immediately on a failed action, and the feature orchestrator checkpoints only successful step results. Post-session gate failures therefore prevent step `5.1` or `8.4` completion and checkpointing **within the run that produced them**. The block is in-run by design: the scanner derives progress from artifacts on disk and never runs gates, and `5.1`/`8.4` are optional, so this change does not persist a failed review — a later plain `overmind run` may skip the optional review. Repair is operator-driven: the failed run prints `overmind run --path <project> --resume <step>`, and rerunning or resuming the owning review re-runs the full declared set; the review step completes only when that set passes. The coordinator does not mutate model-owned files. Making a failed optional review re-block subsequent runs would convert it into a sticky/mandatory-once-attempted step — a product change tracked outside CRP-165 (see Open Questions).

### D5: Keep model instructions and validators unchanged

The review skills retain their current in-session gate loops. Those loops give the model fast repair feedback, while coordinator gates independently verify the final filesystem state. CRP-165 changes when existing validators are invoked, not what they accept. The installed skill assets require no behavioral update.

`overmind/init_progress_definition_sequence_diagram.md` and `overmind/templates/init_progress_definition_TEMPLATE.yaml` are updated at the full step headings `(optional) requirement_ears extra review` and `(optional) implementation plan semantic review` so the canonical completion definitions state that both mutable artifacts pass their owning post-session gates.

### D6: Deploy through the existing bundled coordinator path

The installer already copies the built coordinator as `.overmind/overmind.js`; no new staged asset is introduced. Installer fresh/update coverage proves that the newly built coordinator bundle is copied or refreshed at that path. A separate installed-workspace smoke flow provides the behavioral proof that the bundled executor rejects a review whose normative artifact fails.

## Risks / Trade-offs

- [Previously completed or newly reviewed artifacts that relied on skipped gates now fail the phase] → Report the exact artifact, gate, and problems; rerun the owning review session to repair before checkpointing.
- [Running two validators adds completion latency] → Both are fast local parsers; the deterministic cost is negligible relative to a model session.
- [CRP-163 and CRP-165 both touch step `5.1` catalog/tests] → Implement CRP-165 on top of CRP-163 or merge the catalog options so the dedicated dual-source guard and full mutable gate set coexist.
- [A test fixture that stubs sessions but contains placeholder artifacts begins failing real validators] → Make executor gate dependencies injectable and use explicit passing gate stubs in orchestration-only tests.
- [Future review ownership changes bypass the typed contract] → Generate coordinator context write surfaces and catalog `postSessionGates` from the shared review-session contract and test both consumers against the same exported entries; adding a mutable target requires an owning gate in that contract.
- [Both gates fail with different exit classes] → Run both, retain both diagnostics, and return exit `2` as the higher-severity action classification.

## Migration Plan

1. Implement or merge CRP-163's step `5.1` guard changes first, then add CRP-165's orthogonal `postSessionGates` mappings to the same catalog action.
2. Export the shared typed gate registry and inject it into the executor.
3. Add full-set execution, aggregation, exit classification, and artifact-specific diagnostics before action success.
4. Update canonical init-flow completion definitions and concise operational documentation.
5. Add the live invalid-EARS regression, plan regression, executor, orchestrator-checkpoint, and installed-runtime coverage; run all repository verification suites.

Rollback removes the two catalog gate sets and executor dispatch while leaving standalone validators, review skills, CRP-163 source guards, and artifacts unchanged.

## Open Questions

- None blocking. Extending the same mechanism to other multi-artifact sessions can be decided from their explicit write surfaces in later changes.
- Sticky reviews (deferred, tracked separately). Should a review whose post-session gate failed re-block a later plain `overmind run`, instead of being skippable as an optional step? Delivering that requires persisting failure state or making the artifact-driven scanner gate-aware, which converts optional reviews into mandatory-once-attempted steps — a product decision beyond CRP-165. Deferred to a dedicated change (candidate: CRP-164 or a follow-up).
