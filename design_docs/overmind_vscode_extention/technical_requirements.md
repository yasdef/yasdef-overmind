# Technical Requirements - Overmind VS Code Extension

## 1. Document Meta
- feature_id: overmind-vscode-extension
- feature_title: Local VS Code operator dashboard for ASDLC workspaces
- project_type_code: architecture
- source_requirements_ears: `overmind_vscode_extention/requirements_ears.md`
- source_common_contract_definition: none
- source_surface_map_artifacts: none
- analyzed_repo_classes: extension, filesystem, shell-runtime
- last_updated: 2026-05-24
- confidence_level: medium

## 2. Feature Scope and Inputs
- feature_summary: Build a VS Code extension that provides a local operator UI over an ASDLC workspace, starting with read-only project/feature readiness and evolving toward safe script-driven workflow actions.
- included_behavior: Workspace detection, filesystem scanner, readiness model, Webview dashboard, artifact opening, refresh, terminal-launched script actions, and future guided forms.
- excluded_behavior: Cloud backend, multi-user synchronization, replacing Overmind shell scripts, authoritative state storage outside ASDLC files, direct implementation-worker execution.

## 3. Target Architecture

```text
VS Code Extension Host
  |- activation/workspace detection
  |- TypeScript ASDLC scanner
  |- readiness computation
  |- command/action controller
  |- VS Code terminal/script launcher
  `- Webview message bridge

Webview Dashboard
  |- project list
  |- feature list
  |- readiness summaries
  |- artifact links
  `- action buttons/forms

ASDLC Workspace
  |- asdlc_metadata.yaml
  |- .commands/*.sh
  `- projects/<project-id>/<feature-folder>/*
```

## 4. Repository Evidence

### Repository: yasdef-overmind
- class: extension
- evidence_scope: Existing Overmind runtime produces a local ASDLC workspace with scripts, rules, templates, project metadata, and generated artifacts.
- primary_paths: `README.md`, `overmind/scripts/`, `overmind/templates/`, `overmind/rules/`
- key_findings: The current operator workflow is CLI/script based and persists state in ASDLC files under `projects/`.
- constraints: BA/PO users should not be required to type commands; extension must not duplicate shell workflow logic.
- open_gaps: No extension scaffold exists yet.

### Repository: asdlc runtime workspace
- class: filesystem
- evidence_scope: Example runtime state under `/Users/aleksandrkalinin/repo/asdlc`.
- primary_paths: `asdlc_metadata.yaml`, `.commands/`, `projects/*/init_progress_definition.yaml`, `projects/*/step_state.md`, feature artifact folders.
- key_findings: Enough filesystem data exists for a read-only dashboard without adding a service or database.
- constraints: Some readiness state may be stale unless the scanner or `init_progress_scanner.sh` is run.
- open_gaps: There is no normalized dashboard JSON contract yet.

## 5. Requirement Coverage and Gaps

### Requirement: Requirement 1
- requirement_summary: Detect ASDLC workspace.
- transport_layer: VS Code workspace APIs and Node filesystem APIs.
- user_reachable_surface: Dashboard empty state and active workspace selector.
- gap_status: not_implemented
- repo_impact: extension
- evidence: `requirements_ears.md` Requirement 1
- gap_to_close: Implement workspace discovery service and selection state.

### Requirement: Requirement 2
- requirement_summary: Show project dashboard.
- transport_layer: TypeScript scanner reads YAML and project folders.
- user_reachable_surface: Webview project list.
- gap_status: not_implemented
- repo_impact: extension
- evidence: `requirements_ears.md` Requirement 2
- gap_to_close: Implement project scanner, normalized project DTO, and dashboard rendering.

### Requirement: Requirement 3
- requirement_summary: Show feature dashboard.
- transport_layer: TypeScript scanner reads project child folders and artifacts.
- user_reachable_surface: Webview feature list and detail panel.
- gap_status: not_implemented
- repo_impact: extension
- evidence: `requirements_ears.md` Requirement 3
- gap_to_close: Implement feature discovery and expected artifact mapping.

### Requirement: Requirement 4
- requirement_summary: Compute readiness.
- transport_layer: Deterministic readiness module using YAML, checklist, and artifact presence.
- user_reachable_surface: Badges, percentages, and missing-artifact warnings.
- gap_status: not_implemented
- repo_impact: extension
- evidence: `requirements_ears.md` Requirement 4
- gap_to_close: Define readiness algorithm and fixture-backed tests.

### Requirement: Requirement 5
- requirement_summary: Open artifacts from the dashboard.
- transport_layer: VS Code command API and URI/file APIs.
- user_reachable_surface: Artifact open buttons.
- gap_status: not_implemented
- repo_impact: extension
- evidence: `requirements_ears.md` Requirement 5
- gap_to_close: Implement Webview-to-extension artifact open messages.

### Requirement: Requirement 6
- requirement_summary: Refresh scanner state.
- transport_layer: Manual refresh command plus file watchers.
- user_reachable_surface: Refresh button and stale-state indicator.
- gap_status: not_implemented
- repo_impact: extension
- evidence: `requirements_ears.md` Requirement 6
- gap_to_close: Implement scan lifecycle, error isolation, and stale state handling.

### Requirement: Requirement 7
- requirement_summary: Launch Overmind scripts through VS Code terminal.
- transport_layer: VS Code integrated terminal.
- user_reachable_surface: Action buttons for scanner, create feature, create project, and orchestrator.
- gap_status: not_implemented
- repo_impact: extension, shell-runtime
- evidence: `requirements_ears.md` Requirement 7
- gap_to_close: Add allow-listed script action controller and terminal runner.

### Requirement: Requirement 8
- requirement_summary: Add guided Webview forms for common actions.
- transport_layer: Webview forms with validated message payloads and script contracts.
- user_reachable_surface: Create project and create feature forms.
- gap_status: not_implemented
- repo_impact: extension, shell-runtime
- evidence: `requirements_ears.md` Requirement 8
- gap_to_close: Decide which Overmind scripts need non-interactive contracts before replacing prompts.

### Requirement: Requirement 9
- requirement_summary: Preserve ASDLC source of truth.
- transport_layer: Architecture boundary and code review rule.
- user_reachable_surface: none
- gap_status: not_implemented
- repo_impact: extension
- evidence: `requirements_ears.md` Requirement 9
- gap_to_close: Enforce scanner/action boundaries in module design.

## 6. Impacted Components

### Component: extension-scaffold
- repo: extension
- component_kind: config
- relevant_paths: `overmind_vscode_extention/package.json`, `overmind_vscode_extention/src/extension.ts`
- requirement_refs: Requirement 1, NFR 1
- current_state: Missing.
- required_behavior: Provide VS Code extension activation, commands, Webview registration, and extension packaging.
- gap_to_close: Scaffold extension project with TypeScript, linting, tests, and VSIX packaging.
- dependency_notes: Must be established before scanner and UI work.
- evidence: architecture decision from conversation.

### Component: asdlc-scanner
- repo: extension
- component_kind: service
- relevant_paths: `src/scanner/asdlcScanner.ts`, `src/scanner/projectScanner.ts`, `src/scanner/featureScanner.ts`
- requirement_refs: Requirement 1, Requirement 2, Requirement 3, Requirement 6
- current_state: Missing.
- required_behavior: Read ASDLC metadata, projects, feature folders, artifact existence, and parseable status files.
- gap_to_close: Implement deterministic filesystem indexing with parse errors isolated per file.
- dependency_notes: Should produce pure JSON DTOs independent of Webview rendering.
- evidence: Runtime ASDLC structure inspection.

### Component: readiness-engine
- repo: extension
- component_kind: service
- relevant_paths: `src/scanner/readiness.ts`
- requirement_refs: Requirement 4
- current_state: Missing.
- required_behavior: Convert scanner output into project, feature, artifact, and repo/class readiness states.
- gap_to_close: Define readiness states and scoring rules.
- dependency_notes: Depends on scanner DTOs and known artifact contracts.
- evidence: Existing `init_progress_definition.yaml`, `step_state.md`, and feature artifacts.

### Component: webview-dashboard
- repo: extension
- component_kind: ui
- relevant_paths: `src/webview/`, `media/`
- requirement_refs: Requirement 2, Requirement 3, Requirement 4, Requirement 5, Requirement 6, Requirement 8
- current_state: Missing.
- required_behavior: Render project list, feature list, readiness cards, artifact links, refresh action, and future forms.
- gap_to_close: Build simple responsive Webview with message bridge to extension host.
- dependency_notes: Must avoid direct filesystem access; all data comes from extension messages.
- evidence: Product direction from conversation.

### Component: action-controller
- repo: extension
- component_kind: service
- relevant_paths: `src/actions/actionController.ts`, `src/actions/scriptRunner.ts`
- requirement_refs: Requirement 7, Requirement 8, Requirement 9, NFR 2
- current_state: Missing.
- required_behavior: Validate requested action, confirm mutating operations, construct safe script commands, and launch terminal.
- gap_to_close: Implement allow-listed actions for scanner refresh and later mutating scripts.
- dependency_notes: Mutating actions should remain disabled until v3.
- evidence: Future path v2-v4.

### Component: script-contracts
- repo: shell-runtime
- component_kind: other
- relevant_paths: `<asdlc>/.commands/*.sh`
- requirement_refs: Requirement 7, Requirement 8
- current_state: Existing scripts are primarily CLI/interactive.
- required_behavior: Existing interactive scripts can be launched in a visible terminal; future non-interactive form flows require stable script input contracts.
- gap_to_close: Identify required non-interactive contracts only when v4 is started.
- dependency_notes: Do not add script flags before the requirement is explicit.
- evidence: AGENTS.md constraint says not to add new CLI flags unless explicitly requested.

## 7. Dashboard Data Contract

### DashboardModel
- `workspacePath`: absolute active ASDLC workspace path.
- `scanStatus`: `ready | stale | scanning | failed`.
- `projects`: array of `ProjectSummary`.
- `diagnostics`: non-sensitive parse and consistency diagnostics.

### ProjectSummary
- `projectId`: ASDLC project id.
- `name`: display name from metadata.
- `folderPath`: project folder path.
- `createdAt`: optional ISO timestamp.
- `projectTypeCode`: optional type code from `init_progress_definition.yaml`.
- `classes`: array of class readiness records.
- `projectReadiness`: `complete | partial | blocked | unknown`.
- `features`: array of `FeatureSummary`.

### FeatureSummary
- `featureId`: folder-derived id.
- `folderPath`: feature folder path.
- `readiness`: `ready | in_progress | blocked | unknown`.
- `completedSteps`: number.
- `totalSteps`: number.
- `missingArtifacts`: array of artifact names.
- `artifacts`: array of artifact link records.

## 8. Readiness Rules
- Project class state `ready` with a non-empty path maps to ready.
- Project class state `deferred` maps to deferred and must not count as failure.
- Missing `init_progress_definition.yaml` maps project readiness to blocked.
- A feature folder is recognized when it contains `feature_br_summary.md`.
- A feature is ready for implementation when required planning artifacts exist and scanner/checklist state indicates no remaining required steps.
- Unknown parse state must degrade to `unknown`, not crash the whole dashboard.

## 9. Cross-Repo Constraints and Planning Signals

### Planning Signal: source-of-truth-boundary
- signal_id: sig-001
- signal_type: source_of_truth_boundary
- owner_repo: extension
- consumer_repos: shell-runtime
- required_artifact: ASDLC files and existing scripts
- must_precede: Any mutating Webview action
- output_requirements: Extension must call scripts or documented file contracts instead of duplicating workflow mutation logic.
- source_evidence: Requirement 9

### Planning Signal: terminal-first-mutation
- signal_id: sig-002
- signal_type: operator_safety
- owner_repo: extension
- consumer_repos: shell-runtime
- required_artifact: Visible VS Code terminal session
- must_precede: Guided form replacement for interactive scripts
- output_requirements: v3 script actions use terminal launch; v4 forms require explicit non-interactive script contracts.
- source_evidence: Requirement 7, Requirement 8

## 10. Known Risks / Uncertainties
- risk_1: BA/PO users may still find VS Code intimidating; mitigate with a single dashboard command and minimal visible technical concepts.
- risk_2: Readiness can become inconsistent if relying only on stale `step_state.md`; mitigate by supporting manual refresh and later scanner script launch.
- risk_3: Windows without WSL cannot run `.sh` scripts directly; mitigate by requiring Remote WSL for script actions.
- risk_4: Webview forms could duplicate shell prompt logic; mitigate by delaying v4 until script contracts are explicit.
- risk_5: Large ASDLC workspaces may make naive full scans slow; mitigate with asynchronous scans and file watchers.
