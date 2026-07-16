## Context

Feature progress is currently structural. `evaluate(...)` marks steps done from artifact presence and selected terminal fields, `nextStep(...)` ignores optional remainders, and `runFeatureFlow(...)` reports `finished` or `completed` when no required catalog work remains. The only final checkpoint after optional plan review is emitted immediately after step `8.4`; there is no whole-feature validator pass between the last review decision and that checkpoint or success outcome.

All registered artifact validators are synchronous local parsers and are read-only. CRP-165 introduces one typed in-process gate registry for standalone CLI and executor dispatch, plus unchanged propagation of gate exit `1` and `2`. CRP-166 builds on that registry rather than launching `.overmind/overmind.js` recursively. The measured UMSS feature supplies two regression fixtures: artifact-presence progress is complete, but `requirements_ears.md` Requirements 12 and 13 fail `requirements-ears` because `WHEN ..., THEN THE ... SHALL ...` is not a valid accepted EARS pattern; separately, the migrated `implementation_plan.md` begins directly with `### Step 1.1`, having lost the template's leading `# Implementation Plan` header and preamble while still passing `implementation-plan`.

The feature chain covers these pipeline-owned gates in stable phase order:

| Order | Artifact trigger | Gate invocation | Applicability | Repair step |
| --- | --- | --- | --- | --- |
| 1 | `feature_br_summary.md` | `repo-br-scan` | At least one class repository has state `ready` | `4.1` |
| 2 | `feature_br_summary.md` | `task-to-br` | Artifact exists | `4.1` |
| 3 | `feature_br_summary.md` | `br-clarification` | Artifact exists | `4.2` |
| 4 | `requirements_ears.md` | `requirements-ears` | Artifact exists | `5` |
| 5 | `requirements_ears_review.md` | `ears-review` | Optional artifact exists | `5.1` |
| 6 | `feature_contract_delta.md` | `contract-delta` | Artifact exists | `6` |
| 7 | `project_surface_struct_resp_map_<class>.md` | `surface-map --class <class>` | Each existing backend, frontend, or mobile artifact | `7` |
| 8 | `technical_requirements.md` | `technical-requirements` | Artifact exists | `8` |
| 9 | `implementation_slices.md` | `implementation-slices` | Artifact exists | `8.1` |
| 10 | `prerequisite_gaps.md` | `prerequisite-gaps` | Artifact exists | `8.2` |
| 11 | `implementation_plan.md` | `implementation-plan` | Artifact exists | `8.3` |
| 12 | `implementation_plan_semantic_review.md` | `plan-semantic-review` | Optional artifact exists | `8.4` |

## Goals / Non-Goals

**Goals:**

- Provide one deterministic `gate all <feature-path>` command with complete per-gate evidence and aggregate `0/1/2` classification.
- Make the command and feature-flow completion hook consume the same typed gate definitions and runner.
- Run every applicable feature gate even after earlier failures, including every existing supported-class surface map.
- Place the hook after the final optional-review decision and before plan-complete output or the after-`8.4` checkpoint.
- Block completion on failure and make the earliest owning step explicitly resumable without automatic repair or retry.
- Close the measured plan-header gap in the existing implementation-plan validator with one deterministic regex.
- Preserve existing individual gate commands, all other validator behavior, and the installed runtime shape.

**Non-Goals:**

- Model-based semantic re-review or broader validator acceptance-rule changes beyond the implementation-plan header presence check.
- Replacing artifact-presence progress evaluation with gate execution for every status query.
- Treating `gate all` as a missing-artifact completeness scanner; the feature flow continues to own required-artifact sequencing.
- Persisting a new terminal-review artifact or mutating feature artifacts during the chain.

## Decisions

### D1: Extend CRP-165's typed registry with terminal feature metadata

CRP-165's shared gate registry becomes the source of both validator invocation and terminal eligibility. A gate definition supports the current target path, runtime root, optional progress sink, and optional class argument, plus optional terminal metadata:

- feature-relative artifact selector: one exact filename or the supported-class surface-map family;
- stable pipeline order;
- owning repair step;
- optional pipeline predicate such as `hasReadyClassRepo`.

The current class-gate dispatch is adapted into this registry so `surface-map` uses the same validator through standalone `--class`, post-session consumers, and terminal class fan-out. Existing CLI syntax remains unchanged. Feature catalog contract tests assert that every feature session whose skill name resolves to a deterministic artifact gate has terminal metadata, while the manifest table above asserts the exact order, selector, predicate, and repair step. This makes future gate additions fail tests until terminal behavior is deliberately classified.

Alternative considered: maintain a second hardcoded `gate all` function list. Rejected because it can drift from individual CLI dispatch. Alternative considered: derive validators from artifact filenames. Rejected because multiple gates own different contracts on `feature_br_summary.md`, gate names do not always match filenames, and `surface-map` needs a class argument.

### D2: Resolve applicability before invoking the full ordered chain

The chain runner first resolves the input through the existing workspace/feature-path rules. It expands terminal definitions in pipeline order:

- an exact-file entry runs when its trigger artifact path exists; the owning validator remains responsible for rejecting a directory or unreadable entry;
- a nonexistent trigger is reported as skipped, including optional review ledgers;
- `repo-br-scan` additionally requires the existing `hasReadyClassRepo` predicate, matching its step `4.1` execution condition;
- the surface-map family expands backend, frontend, and mobile in that stable order and runs for artifact paths that exist.

`hasReadyClassRepo` is intentionally evaluated from the current project definition at terminal time, not from historical step `4.1` state. If a repository is attached and reconciled after BR scanning, `repo-br-scan` becomes applicable and may fail because the existing `feature_br_summary.md` lacks populated `## 13. Existing-System Context`; this state-change failure correctly assigns repair owner `4.1` so the newly available repository evidence is incorporated before plan completion.

Once applicability is resolved, every applicable validator runs even if an earlier one returns non-zero. A valid feature directory with no applicable recognized artifact returns exit `2` rather than reporting a vacuous pass. Required-artifact absence remains visible to the feature progress scanner; `gate all` reports what it checked and skipped.

An existing pre-dual-source `requirements_ears_review.md` is applicable and follows CRP-163's migration policy: `ears-review` returns recoverable exit `1`, the terminal chain fails with repair owner `5.1`, and the ledger must be regenerated or upgraded. Only absence of the optional ledger is skipped; existing legacy content is not grandfathered.

Alternative considered: run every feature validator unconditionally. Rejected because optional review artifacts and intentionally skipped repository scanning would become false runtime failures. Alternative considered: infer applicability from current progress state. Rejected because progress checks artifact presence rather than each validator's primary target and loses class-specific invocation data.

### D3: Return a structured aggregate result and preserve validator exits

Add an injectable terminal chain runner returning the ordered entry results, aggregate `GateExitCode`, diagnostics, and earliest failing repair step. Each entry records gate, artifact, optional class, and `passed`, `failed`, or `skipped` status. Applicable entries preserve their underlying `GateResult`.

Aggregation is:

- exit `0` when at least one gate runs and every applicable gate passes;
- exit `1` when one or more gates return `1` and none returns `2`;
- exit `2` when path/applicability resolution fails, no recognized artifact is applicable, a gate is unavailable, or any gate returns `2`.

All applicable gates still run for complete diagnostics. The repair step is the earliest pipeline entry that failed; aggregate severity does not reorder it. The runner makes no writes and supplies no clarification progress sink during the aggregate pass, avoiding standalone per-rule chatter while retaining the same `br-clarification` validator.

Alternative considered: stop at the first failure. Rejected because the cost is local parser time and complete evidence avoids sequential repair surprises. Alternative considered: collapse all failures to exit `1`. Rejected because a recoverable artifact defect and an unavailable validator/runtime remain operationally different.

### D4: Make the implementation-plan gate cover its template header

Before the aggregate chain can serve as a complete deterministic safety net, the owning implementation-plan gate must detect the second measured defect. `validateImplementationPlanContent(...)` will apply one start-anchored regex equivalent to `^# Implementation Plan\r?\n`. A plan must therefore begin at byte zero with the exact template heading `# Implementation Plan`; a missing heading, a leading `### Step`, or an alternate heading such as `# Repository Implementation Plan` returns recoverable exit `1` with `implementation_plan.md must start with exact header: # Implementation Plan`.

The regex is a structural sentinel for the measured header/preamble loss. It does not exact-match the following explanatory prose, so template guidance remains guidance rather than a validator-owned behavioral rule. The source and packaged implementation-plan templates already use the required heading and need no structural change. Direct `gate implementation-plan`, CRP-165's post-session recheck, and CRP-166's terminal chain all receive the fix through the same validator.

Alternative considered: make `gate all` inspect the plan header separately. Rejected because standalone and post-session implementation-plan validation would retain the hole and the chain would duplicate an owning validator rule. Alternative considered: regex-match the full preamble prose. Rejected because the stable structural contract is the heading, while prose wording may evolve without weakening plan structure.

### D5: Route `gate all` through the aggregate runner

`runGate(...)` recognizes the reserved step name `all` and requires exactly `overmind gate all <feature-path>`. The top-level CLI threads its resolved `cwd` into gate dispatch, and `gate all` passes that value to the in-process terminal runner for workspace/feature resolution. It renders one stable row per expanded entry naming status, gate, artifact, optional class, and problems/error; a final summary reports passed, failed, and skipped counts. The process exit is the aggregate result. Existing individual gate commands and `surface-map --class` behavior keep their current rendering and syntax.

Alternative considered: add a new top-level command. Rejected because `all` is an aggregation mode of the existing gate surface. Alternative considered: shell out once per gate. Rejected because CRP-165 already makes the validators available in process.

### D6: Centralize terminal feature completion behind one hook

Refactor the successful terminal paths in `runFeatureFlow(...)` through one injected `runTerminalGateChain` completion helper. It runs:

- after step `8.4` succeeds, following CRP-165's mutable-set recheck and before the after-`8.4` checkpoint;
- after the operator declines optional step `8.4`, before the `finished` outcome;
- before returning success when the scanner reports no remaining required step or the catalog loop reaches its end.

Earlier agent/action failures, operator stops, and non-terminal optional skips do not invoke the chain. A passing chain preserves the existing `finished` versus `completed` outcome and applicable checkpoint behavior. A non-zero chain returns a failed flow outcome with the same `1/2` classification, emits all gate diagnostics, suppresses terminal success output, and does not create the after-`8.4` checkpoint. There is no automatic retry.

Alternative considered: append a synthetic step `9`. Rejected because this is a completion invariant, not a model-owned phase or artifact. Alternative considered: run only after step `8.3`. Rejected because optional step `8.4` may subsequently edit the plan.

### D7: Make explicit terminal repair resumes reopen the cached feature

For a recoverable chain failure, CLI guidance uses the earliest failing definition's repair step. Every manifest repair-step token is a catalog id that must resolve through the same `resolveStep(...)` path used by `--resume`; a contract test rejects an unresolved or remapped token. Feature selection accepts an explicit feature-step `--resume` against the valid cached feature even when artifact-presence scanning calls it complete; the explicit resume is the operator's authorization to reopen it. This generalizes the current completed-cache special case from only `--resume 8.4` to every resolved terminal repair owner, so existing feature-selection errors that direct operators to start a new feature or use `--resume 3` are updated to describe cached-feature repair when applicable. The selected owning phase and downstream phases run normally, and the terminal hook must pass before completion is reported again. Without an explicit resume, existing new/unfinished feature selection behavior remains unchanged.

Exit `2` retains the same owning-step context but instructs the operator to fix the named validation/runtime problem before using the explicit resume. Neither classification causes the orchestrator to invoke a model automatically.

Alternative considered: delete or rename the failing artifact so scanning sees pending work. Rejected because the coordinator must not mutate model-owned evidence to encode state. Alternative considered: persist a new terminal ledger. Rejected because the aggregate is a deterministic recheck and needs no durable artifact.

### D8: Record the completion invariant in canonical and installed guidance

Add the terminal `gate all` check after `(optional) implementation plan semantic review` in `overmind/init_progress_definition_sequence_diagram.md`. Add the plan-completion condition under `init_progress_definition_TEMPLATE.yaml` `Create Shared Repository Implementation Plan`, and update the existing runtime documentation plus the installer's generated quick-run guide with the standalone command and repair behavior.

The installer continues to copy the built coordinator as `.overmind/overmind.js`; no skill, helper, template, or setup payload is added. Fresh/update tests prove bundle freshness, while an installed-workspace CLI/flow smoke proves behavior.

## Risks / Trade-offs

- [Previously completed features contain defects or pre-dual-source review ledgers accepted by older gates] → `gate all` reports every affected artifact and earliest repair step; existing legacy ledgers follow CRP-163's recoverable upgrade policy rather than receiving a compatibility pass.
- [Repository scanning was intentionally inapplicable] → Reuse the catalog's `hasReadyClassRepo` predicate instead of treating shared `feature_br_summary.md` presence as sufficient.
- [A new deterministic feature gate is omitted from terminal validation] → Registry/catalog coverage tests require terminal metadata for every feature session backed by a gate definition.
- [Several failures produce a long report] → Preserve stable phase order, group details under artifact-and-gate rows, and print aggregate counts.
- [Explicit resume reopens the wrong completed feature] → Allow completed-feature repair only for the valid cached feature under the selected project and only when `--resume` is explicit.
- [Terminal validation duplicates recent step checks] → Validators are fast local parsers; the deterministic cost is intentionally traded for an end-to-end safety net.
- [Existing plans use a non-template or missing top-level heading] → Return recoverable exit `1` owned by step `8.3`; prepend the exact `# Implementation Plan` heading without rewriting plan steps.

## Migration Plan

1. Implement CRP-163 and CRP-165 first so CRP-163's dual-source EARS ledger diagnostics and CRP-165's shared typed gate registry plus `1/2` flow propagation are available.
2. Add the exact leading implementation-plan header check and focused direct-gate regression tests.
3. Generalize the registry for class-aware invocation and terminal metadata; add the exact feature chain definitions and coverage tests.
4. Implement and test the aggregate runner, applicability expansion, output model, and `gate all` CLI dispatch.
5. Add the centralized feature-flow terminal hook and explicit cached-feature repair resume.
6. Update canonical workflow definitions, runtime documentation, quick-run generation, and installed-runtime tests.
7. Run coordinator, installer, repository, and verification suites.

Rollback removes the implementation-plan header regex, terminal metadata, aggregate dispatch, and the flow-end hook; CRP-165's post-session gate wiring remains unchanged.

## Open Questions

- None blocking. Extending terminal validation to project-initialization artifacts can be considered as a separate project-scope chain.
