> **Dependencies:** CRP-163 and CRP-165 must be implemented or merged first. CRP-166 consumes CRP-163's dual-source EARS-review field diagnostics and extends CRP-165's shared typed validator registry plus unchanged `1/2` feature-flow propagation; do not add a parallel validator map or collapse terminal failures to one exit class.

## 1. Shared gate definitions and terminal inventory

- [x] 1.1 Add one start-anchored `^# Implementation Plan\r?\n` regex to `packages/asdlc-coordinator/src/validate/implementation-plan.ts`; return recoverable exit `1` with `implementation_plan.md must start with exact header: # Implementation Plan` while leaving following preamble prose outside exact-text validation
- [x] 1.2 Generalize CRP-165's shared typed gate definitions and invocation adapter to support the existing optional class argument alongside target path, runtime root, and progress sink; route the current `surface-map --class <class>` CLI path through that same registry without changing individual gate syntax or output
- [x] 1.3 Add typed terminal metadata for stable order, exact artifact selector, owning repair step, and optional applicability predicate to the feature gates listed in the design table
- [x] 1.4 Reuse the catalog's `hasReadyClassRepo` semantics for `repo-br-scan`, and define stable backend/frontend/mobile expansion for existing `project_surface_struct_resp_map_<class>.md` files
- [x] 1.5 Add registry/catalog contract tests proving the exact terminal order and mappings, every feature session backed by a deterministic registered gate has terminal metadata, and project-scope gate definitions do not enter the feature chain
- [x] 1.6 Add a contract test that passes every terminal `repairStep` token through the production `resolveStep(...)` path and proves it resolves to the same catalog id without diagnostics

## 2. Terminal chain runner

- [x] 2.1 Add an injectable in-process terminal feature-gate runner that resolves `projects/<project-id>/<feature-folder>` through existing workspace rules and returns ordered per-entry results, aggregate `GateExitCode`, diagnostics, and earliest failing repair step
- [x] 2.2 Expand exact-file, predicate-controlled, optional-ledger, and supported-class surface-map entries from path existence; report nonexistent or inapplicable entries as skipped, pass malformed existing entry types to their owning validators, and return exit `2` when no recognized artifact is applicable
- [x] 2.3 Invoke every applicable registered validator without fail-fast and preserve entry-level gate, artifact, class, pass message, recoverable problems, and runtime error data
- [x] 2.4 Implement aggregate exit `0` for an all-pass nonempty run, exit `1` for recoverable failures without an exit-`2` condition, and exit `2` for path/configuration/runtime failures while keeping the earliest pipeline failure as repair owner
- [x] 2.5 Prove the aggregate runner performs no feature or project filesystem writes and suppresses the standalone `br-clarification` progress sink during chain invocation

## 3. Standalone gate all command

- [x] 3.1 Update `packages/asdlc-coordinator/src/cli/run.ts` so `node .overmind/overmind.js gate all <feature-path>` requires exactly one feature path, threads the top-level `run(...)` cwd into gate dispatch and feature resolution, and dispatches the injected terminal runner without spawning the CLI or adding a flag
- [x] 3.2 Render stable passed/failed/skipped rows naming gate, artifact, optional class, and problems/error plus final passed/failed/skipped counts; return the aggregate `0/1/2` unchanged
- [x] 3.3 Preserve current behavior and output for every individual `gate <step> <path>` command, including `surface-map --class <class>` and `br-clarification` progress output

## 4. Feature-flow terminal hook and repair resume

- [x] 4.1 Add the terminal runner as an injectable feature-flow dependency and centralize successful terminal outcomes behind one helper rather than duplicating chain calls across return branches
- [x] 4.2 Run the hook after successful `(optional) implementation plan semantic review` post-session checks and before the after-`8.4` checkpoint, catalog-end message, or successful flow outcome
- [x] 4.3 Run the hook after the operator declines `(optional) implementation plan semantic review` and before `finished`, and before success when feature scanning reports no remaining required step
- [x] 4.4 Keep earlier action failures, operator stops, and non-terminal skips on their existing paths without invoking terminal validation
- [x] 4.5 On terminal failure, propagate aggregate exit `1` or `2` unchanged, retain every gate diagnostic, suppress plan-complete output and the after-review checkpoint, and provide the earliest owning repair step without automatic retry
- [x] 4.6 Generalize feature selection's completed-cache reopening from the current `--resume 8.4` special case so any resolved terminal owning-step token explicitly reopens the valid cached feature, while an ordinary run preserves current new/unfinished selection behavior
- [x] 4.7 Update feature-selection and CLI error/guidance text that currently assumes completed features can reopen only at `8.4` or directs other resumes to `--resume 3`, so terminal repair guidance names the resolved owning step without implying a new feature is required

## 5. Canonical workflow and runtime guidance

- [x] 5.1 Update `overmind/init_progress_definition_sequence_diagram.md` after `(optional) implementation plan semantic review` to show terminal `gate all` validation before plan-complete reporting
- [x] 5.2 Update `overmind/templates/init_progress_definition_TEMPLATE.yaml` `Create Shared Repository Implementation Plan` completion conditions to require the terminal deterministic gate chain after the final optional-review decision
- [x] 5.3 Document `gate all`, applicability/skips, aggregate exits, flow-end blocking, and explicit repair resume concisely in `overmind/README.md` and the existing runtime section of `README.md`; state explicitly that standalone `gate all` validates applicable artifacts that exist and does not prove required-artifact completeness, which remains owned by feature-flow sequencing
- [x] 5.4 Update `packages/installer/src/init.ts` quick-run generation to list `node .overmind/overmind.js gate all projects/<project-id>/<feature-folder>` and its concise repair guidance

## 6. Coordinator and regression tests

- [x] 6.1 Add runner tests for invalid feature paths, no applicable artifacts, exact-path selection, malformed existing entry types, absent optional ledgers, ready-repository predicate behavior including a repository attached after BR scanning that makes `repo-br-scan` fail with repair owner `4.1`, stable surface-class fan-out, and stable pipeline order
- [x] 6.2 Add aggregation tests for all pass, multiple exit-`1` failures, mixed exit `1/2` with exit-`2` precedence, unavailable registered dispatch, later-gate execution after failure, earliest repair ownership, and byte-for-byte filesystem immutability
- [x] 6.3 Add CLI tests for exact `gate all` usage, injected-cwd relative path resolution, auditable rows and summary counts, exit `0/1/2`, and unchanged individual gate syntax, output, and dispatch
- [x] 6.4 Add feature-flow tests for accepted step `8.4`, declined step `8.4`, no-next-step, and catalog-end terminal paths, asserting chain-before-checkpoint/output ordering and no invocation on earlier stop/failure paths
- [x] 6.5 Update implementation-plan validator fixtures to start with the exact template header, then add focused tests proving the exact header passes while a leading step and `# Repository Implementation Plan` each return exit `1` with the actionable header diagnostic
- [x] 6.6 Add the measured header-loss terminal fixture with otherwise-valid artifact-complete inputs and an `implementation_plan.md` that begins directly with `### Step 1.1`; prove terminal exit `1`, repair owner step `8.3`, complete diagnostics, and no after-review checkpoint or completion message
- [x] 6.7 Add the measured EARS regression fixture with artifact-complete downstream files and invalid `WHEN ..., THEN THE ... SHALL ...` EARS bullets; prove terminal exit `1`, repair owner step `5`, complete diagnostics, and no after-review checkpoint or completion message
- [x] 6.8 Add a pre-dual-source EARS-review ledger fixture proving CRP-163 field diagnostics propagate as terminal exit `1`, repair owner step `5.1`, and no legacy-compatible pass
- [x] 6.9 Add feature-selection/flow tests proving explicit repair resume reopens only the valid cached completed feature, performs no automatic model retry, and requires a later terminal pass before completion

## 7. Bundled runtime deployability

- [x] 7.1 Extend installer fresh/update coverage to prove the newly built coordinator bundle and regenerated `quickrun.md` are copied or refreshed without adding a skill, helper, template, or setup payload
- [x] 7.2 Add an installed-workspace smoke test proving `.overmind/overmind.js gate all` returns the same aggregate classification and rows as the source coordinator
- [x] 7.3 Add an installed feature-flow smoke with stubbed model execution proving an earlier invalid artifact blocks terminal success and the after-review checkpoint
      <!-- No model stub is needed: declining optional step 8.4 reaches the plan-completion boundary with zero model invocations. The smoke drives exactly one prompt because the installed CLI creates a readline interface per question, so piped stdin cannot answer a second one. -->

- [x] 7.4 Include the measured missing-plan-header fixture in installed-bundle smoke coverage so `.overmind/overmind.js gate all` returns exit `1` with repair owner step `8.3`

## 8. Verification

- [x] 8.1 Run `npm run test --workspace asdlc-coordinator` and fix regressions
- [x] 8.2 Run `npm run test --workspace overmind-installer` and fix regressions
- [x] 8.3 Run `npm test` and `npm run verify` from the repository root and fix regressions
