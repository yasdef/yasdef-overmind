## Context

Feature-phase execution from `Initialize and Enrich Business Requirements Structuring` to Step `8.3` is currently manual and script-by-script. Startup is project-scoped (`feature_br_scaffold.sh --path`), while downstream scripts are feature-scoped (`--feature_path`). The BR structuring portion needs an explicit split between Step `4.1` (`feature_scan_repo_for_br.sh` then `feature_task_to_br.sh`) and Step `4.2` (`feature_user_br_clarification.sh` then `feature_br_check_ears_readiness.sh`). Operators must remember ordering, optional-step behavior, and where to resume after interruptions, which creates inconsistent execution and avoidable mistakes.

The repository already has a robust orchestrator reference pattern in `ai/scripts/orchestrator.sh` and a canonical progress status source in `overmind/scripts/project_mgmt/init_progress_scanner.sh` (`next step: ...`). The design should reuse these patterns while staying lightweight: orchestrate existing feature scripts without changing their internal contracts.

## Goals / Non-Goals

**Goals:**
- Add a lightweight overmind feature orchestrator that covers scripts from Step `3` through Step `8.3`.
- Require `--path <project-folder-path>` as orchestrator input and run `feature_br_scaffold.sh` first.
- Capture and persist scaffold-created `feature_path`, then invoke all downstream scripts with that saved `--feature_path`.
- Run progress scanner with resolved `feature_path` and show current status before continuing feature-phase execution.
- Support default resume from current progress and explicit `--resume <step>` override.
- Require user confirmation before each script and enforce optional-vs-required decline semantics.
- Support multi-script phases with deterministic one-by-one execution and explicit pre-run messaging.
- Stage the orchestrator into ASDLC bootstrap/update flows and document quickrun usage.
- Make Step `4.1` and Step `4.2` mapping explicit and deterministic:
  - Step `4.1`: `feature_scan_repo_for_br.sh` -> `feature_task_to_br.sh`
  - Step `4.2`: `feature_user_br_clarification.sh` -> `feature_br_check_ears_readiness.sh`

**Non-Goals:**
- Replacing or rewriting internal logic of existing feature scripts.
- Changing scanner artifact-evaluation semantics beyond resume-consumer clarity.
- Introducing new flags/options on existing feature scripts.
- Extending orchestration after Step `8.3`.

## Decisions

### Decision: Introduce a dedicated `project_add_feature_e2e.sh` under `overmind/scripts/project_mgmt`
Add a new orchestrator script that follows the `ai/scripts/orchestrator.sh` interaction model (ordered phases, interactive confirmations, deterministic stop reasons) but targets overmind feature scripts and project-to-feature startup flow.

Rationale: Reusing known orchestration patterns reduces operator surprise and implementation risk.

Alternatives considered:
- Embed orchestration logic into each feature script: rejected due to duplicated control flow and harder maintenance.
- Extend `ai/scripts/orchestrator.sh` to run overmind feature scripts: rejected because it mixes two orchestration domains and artifact models.

### Decision: Use project-scoped `--path` and derive `feature_path` via scaffold
The orchestrator will require `--path <project-folder-path>`, run `feature_br_scaffold.sh --path <project-folder-path>` as first-phase initialization, capture the `Created feature folder: ...` value, and persist that `feature_path` for subsequent script invocations and resume runs.

Rationale: This keeps existing feature script CLIs unchanged and provides one deterministic feature target for downstream steps.

Alternatives considered:
- Require users to pass `--feature_path` directly to orchestrator: rejected because requested flow starts before feature folder exists.
- Infer active feature only from latest-folder heuristics: rejected due to ambiguity when multiple feature folders exist.

### Decision: Define an explicit ordered phase map with grouped scripts and optional flags
The orchestrator will keep an internal ordered map from scaffold initialization through `feature_implementation_plan_semantic_review.sh`, where each entry declares:
- phase/step id,
- optional flag,
- one or more script commands.

The startup and Step `4` split is explicit in the map:
- Step `3`: `feature_br_scaffold.sh --path <project-folder-path>`
- Step `4.1`: `feature_scan_repo_for_br.sh` then `feature_task_to_br.sh`
- Step `4.2`: `feature_user_br_clarification.sh` then `feature_br_check_ears_readiness.sh`

Rationale: A data-driven map keeps execution deterministic and allows consistent resume and prompt behavior.

Alternatives considered:
- Hardcoded branching logic for each step: rejected due to poor readability and brittle resume handling.

### Decision: Resume routing uses scanner output and persisted feature context
For runs where a saved `feature_path` already exists, default start will run scanner for that feature and begin from the first unfinished required step. For first-time runs without saved `feature_path`, orchestrator executes scaffold first, then scanner-based routing. `--resume <step>` overrides the derived start anchor when provided.

Rationale: Scanner owns completion calculation, while persisted feature context makes resume deterministic across runs.

Alternatives considered:
- Infer completion by direct artifact checks in orchestrator: rejected because it duplicates scanner behavior.
- Always require explicit `--resume`: rejected because it reduces usability.

### Decision: Confirmation is per script, and decline handling follows step optionality
Before each script starts, orchestrator asks for confirmation. Decline behavior:
- optional step: skip to next required step; if none remains, finish successfully;
- required step: stop immediately with deterministic terminal reason.

Rationale: This matches requested operator control while preserving deterministic workflow outcomes.

Alternatives considered:
- One confirmation per phase group only: rejected because it cannot gate each script in multi-script phases.
- Always continue on decline: rejected because required steps must remain hard gates.

### Decision: Multi-script phases print explicit pre-run context messages
For phase groups with multiple scripts, orchestrator prints a deterministic message that includes phase id, script position (`n/m`), and command path before confirmation/execution.

Rationale: Operators need clear context when several scripts belong to one step family.

Alternatives considered:
- Generic prompts without script identity: rejected due to ambiguity and audit difficulty.

## Risks / Trade-offs

- [Risk] Scaffold output format drift could break feature-path capture. -> Mitigation: parse deterministic output marker (`Created feature folder:`) and add regression tests.
- [Risk] Scanner output format drift could break resume parsing. -> Mitigation: rely on canonical `next step: ...` contract in spec and cover parser behavior with tests.
- [Risk] Optional-step skip logic may be misapplied when optional and required phases interleave. -> Mitigation: implement ordered-map traversal helpers and add targeted tests.
- [Risk] Staged-command updates can miss bootstrap/update paths. -> Mitigation: update both first-init and update scripts plus staged quickrun checks.
- [Risk] Interactive confirmation loops can dead-end on invalid input. -> Mitigation: enforce deterministic yes/no validation with explicit retry messages.

## Migration Plan

1. Add `overmind/scripts/project_mgmt/project_add_feature_e2e.sh` with mandatory `--path`, optional `--resume`, scaffold-first initialization, saved `feature_path` handling, scanner invocation, phase map, confirmations, and decline handling.
2. Stage the new command in `project_setup_first_init_machine.sh` and `project_setup_update_project.sh`; update quickrun guidance.
3. Update `overmind/README.md` and sequence diagram references for orchestrated feature execution.
4. Add script tests under `tests/ai_scripts/` for required `--path`, scaffold-first behavior, saved-feature-path propagation to downstream scripts, scanner-driven default resume, explicit resume, optional/required decline handling, and multi-script phase messaging.
5. Run affected test suites and verify `openspec status --change crp-103-lightweight-feature-orchestrator-br-structuring-to-8-3` is apply-ready.
6. Rollback strategy: remove staged command wiring and orchestrator script together, restoring manual command-by-command operation.

## Open Questions

- Where should persistent orchestrator feature state live in project scope (for example `<project>/feature_orchestrator_state.yaml`) to keep resume deterministic and auditable?
- Should `--resume <step>` accept only numeric step ids (for example `3`, `4.1`, `4.2`, `8.2`) or also script aliases (for example `feature_br_to_ears`)?
