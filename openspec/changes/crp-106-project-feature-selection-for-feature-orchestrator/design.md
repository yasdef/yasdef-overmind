## Context

`overmind/scripts/project_mgmt/project_add_feature_e2e.sh` currently uses `projects/<project-id>/.project_add_feature_e2e_state.env` as the single persisted feature selector for a project. That keeps the first scaffold-to-resume flow simple, but it breaks down once a project has more than one feature folder because the orchestrator silently resumes whichever feature path was saved last. The scanner already provides the missing source of truth needed for a better flow: given a feature folder, it can report deterministic checklist state and a canonical `next step` line that identifies whether the feature is still unfinished.

This change needs to preserve the existing project-scoped command entrypoint (`--path <project-folder-path>`), keep Step `3` scaffold as the new-feature bootstrap, and avoid adding new script flags. It also needs to stay within the current shell-script architecture and preserve resume behavior after a feature is selected.

## Goals / Non-Goals

**Goals:**
- Make project-level feature orchestration safe when multiple feature folders exist under the same project.
- Discover existing feature folders from project state instead of treating `.project_add_feature_e2e_state.env` as the only source of truth.
- Ask the operator to choose between starting a new feature and continuing an unfinished existing feature.
- Use scanner output as the canonical status signal for whether a feature is unfinished and what step it should resume from.
- Preserve current downstream execution semantics once a feature is selected, including `--resume <step>` handling and feature-path persistence.

**Non-Goals:**
- Changing the CLI of `project_add_feature_e2e.sh` or downstream feature scripts.
- Redesigning scanner checklist semantics beyond the stability required for project-level feature selection.
- Adding support for concurrent locking across multiple orchestrator processes.
- Introducing a new registry file for feature discovery when the project directory and scanner status already provide the needed information.

## Decisions

### Decision: Feature discovery will scan project child directories and validate them through scanner-compatible rules
The orchestrator will enumerate direct child directories under the selected project path, ignore hidden paths, and treat only valid feature-level directories as candidates for continuation. Candidate classification will stay conservative: the directory must resolve inside the project and must be a scanner-valid feature folder. This avoids inventing new metadata just to discover features.

Rationale: The project directory structure is already the natural namespace for feature folders, and scanner validation provides a real behavior-based check rather than filename heuristics alone.

Alternatives considered:
- Keep using only `.project_add_feature_e2e_state.env`: rejected because it cannot represent multiple in-flight features safely.
- Maintain a separate project-level feature registry: rejected because it duplicates information already present on disk and adds synchronization risk.
- Infer feature folders only from artifact-name heuristics: rejected because it is brittle when feature scaffolding evolves.

### Decision: Scanner output will classify feature folders as unfinished or complete
For each discovered feature candidate, the orchestrator will run `init_progress_scanner.sh --path <feature-path>` and parse the canonical final `next step` line. `next step: none` means the feature is complete and should not appear in the continue list. Any `next step: <number> (<name>)` value means the feature is unfinished and resumable.

Rationale: Scanner already owns progress calculation. Reusing its output keeps “unfinished” semantics centralized and prevents drift between orchestration and checklist logic.

Alternatives considered:
- Reimplement unfinished-feature detection directly in `project_add_feature_e2e.sh`: rejected because it duplicates scanner logic and increases maintenance cost.
- Show all feature folders, including completed ones: rejected because it makes the continue prompt noisy and weakens the “continue unfinished work” contract.

### Decision: Operator choice will be explicit whenever unfinished features exist
If the project has one or more unfinished features, the orchestrator will prompt the user to choose:
- start a new feature;
- continue an existing unfinished feature.

If the operator chooses continue, the script will present the unfinished feature list in deterministic order together with each feature’s scanner-reported next step. If no unfinished features exist, the orchestrator will skip the continue choice and proceed with new-feature scaffold flow.

Rationale: The ambiguity exists at project scope, so the script must resolve it before it can safely choose a feature target.

Alternatives considered:
- Auto-resume the last cached unfinished feature when only one exists: rejected because the user asked for explicit choice and the safer default is to avoid hidden selection.
- Always force manual feature-path editing or deletion of cache: rejected because it externalizes orchestrator responsibility to the operator.

### Decision: The state file remains a last-selected-feature cache, not the source of truth
`projects/<project-id>/.project_add_feature_e2e_state.env` will remain as a convenience cache for the most recently selected feature. The orchestrator may use it to prefill or prioritize messaging, but it must not bypass discovery or override the user’s explicit choice. Stale or missing cache values will be ignored safely.

Rationale: Keeping the file preserves current resume convenience and minimizes migration churn, while demoting its authority removes the multi-feature correctness problem.

Alternatives considered:
- Delete the file entirely: rejected because a last-selected cache is still useful after the operator chooses a feature.
- Expand the file into a full multi-feature registry: rejected because the scanner and filesystem already provide the authoritative state.

### Decision: Resume semantics remain unchanged after feature selection
Once the operator selects a feature, the existing orchestration model stays intact:
- continue flow sets `FEATURE_PATH` to the selected unfinished feature;
- new flow runs Step `3` scaffold to create/select a fresh feature folder, then persists it;
- `--resume <step>` applies only after the active feature is known.

Rationale: This isolates the change to project-level feature selection and avoids destabilizing downstream phase execution.

Alternatives considered:
- Apply `--resume` before feature selection: rejected because step resume is meaningless until the target feature is known.

## Risks / Trade-offs

- [Risk] Scanning many feature folders adds startup latency. -> Mitigation: keep discovery limited to project child directories and parse only the canonical scanner `next step` line needed for classification.
- [Risk] Non-feature directories under a project could be misdetected as candidates. -> Mitigation: require scanner-valid feature paths and ignore directories that fail feature-level validation.
- [Risk] Users may expect the cache file to auto-resume the last feature without prompting. -> Mitigation: update docs and terminal messaging to explain that cache is advisory and project-level selection is now explicit.
- [Risk] Scanner output format drift could break unfinished-feature classification. -> Mitigation: add regression coverage for the canonical `next step` line as a machine-consumable contract.

## Migration Plan

1. Update `project_add_feature_e2e.sh` to discover feature candidates under the selected project and classify them via scanner.
2. Add the project-scope decision flow for `start new feature` versus `continue existing unfinished feature`.
3. Keep persisting the selected feature into `.project_add_feature_e2e_state.env`, but only after discovery and operator selection.
4. Update quickrun and README documentation to explain multi-feature behavior and the revised role of the state file.
5. Extend regression coverage for discovery, unfinished filtering, explicit selection, stale cache handling, and scanner-line parsing.
6. Rollback strategy: restore the current single-cache-selection flow and remove the new prompt/listing behavior.

## Open Questions

- None.
