# Technical Requirements - Overmind VS Code Extension

## 1. Document Meta
- feature_id: overmind-vscode-extension
- feature_title: Local VS Code operator dashboard for ASDLC workspaces
- project_type_code: architecture
- source_requirements_ears: `overmind_vscode_extention/requirements_ears.md`
- source_common_contract_definition: none
- source_surface_map_artifacts: none
- analyzed_repo_classes: extension, filesystem, coordinator
- last_updated: 2026-07-07
- confidence_level: medium

## 2. Feature Scope and Inputs
- feature_summary: Build a VS Code extension that provides a local operator UI over an ASDLC workspace, starting with read-only project/feature readiness and evolving toward safe coordinator-backed workflow actions.
- included_behavior: Workspace detection, in-process coordinator progress computation, Webview dashboard, artifact opening, refresh recomputation, terminal-hosted `overmind run`, coordinator-backed forms, and task-to-BR source capture through the shared Overmind core.
- excluded_behavior: Cloud backend, multi-user synchronization, duplicate scanning/readiness logic, authoritative state storage outside ASDLC files, direct implementation-worker execution, and Create Project until a shared primitive or shipped verb exists.

## 3. Target Architecture

```text
VS Code Extension Host
  |- activation/workspace detection
  |- asdlc-coordinator/workspace
  |- asdlc-coordinator/sequencing
  |- command/action controller
  |- VS Code terminal-hosted overmind run
  `- Webview message bridge

Webview Dashboard
  |- project list
  |- feature list
  |- readiness summaries
  |- artifact links
  `- action buttons/forms

ASDLC Workspace
  |- asdlc_metadata.yaml
  |- .overmind/overmind.js
  `- projects/<project-id>/<feature-folder>/*
```

## 4. Repository Evidence

### Repository: yasdef-overmind
- class: extension
- evidence_scope: Existing Overmind runtime produces a local ASDLC workspace with a bundled CLI, project metadata, and generated artifacts.
- primary_paths: `README.md`, `packages/asdlc-coordinator/`, `packages/vscode-extension/`
- key_findings: The coordinator exposes reusable workspace and sequencing modules while ASDLC files under `projects/` remain authoritative.
- constraints: BA/PO users should not be required to type commands; extension must not duplicate coordinator workflow logic.
- open_gaps: The read-only dashboard surface is minimal and later interactive surfaces remain planned.

### Repository: asdlc runtime workspace
- class: filesystem
- evidence_scope: Example runtime state under `/Users/aleksandrkalinin/repo/asdlc`.
- primary_paths: `asdlc_metadata.yaml`, `.overmind/overmind.js`, `projects/*/init_progress_definition.yaml`, feature artifact folders.
- key_findings: Enough filesystem data exists for a read-only dashboard without adding a service or database.
- constraints: Readiness is recomputed from current files through `sequencing/`; no persisted scanner state is consumed.
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
- transport_layer: `asdlc-coordinator/workspace` discovers project folders.
- user_reachable_surface: Webview project list.
- gap_status: not_implemented
- repo_impact: extension
- evidence: `requirements_ears.md` Requirement 2
- gap_to_close: Project workspace results must be projected into dashboard rendering.

### Requirement: Requirement 3
- requirement_summary: Show feature dashboard.
- transport_layer: `asdlc-coordinator/workspace` discovers features and `sequencing/` evaluates declared steps.
- user_reachable_surface: Webview feature list and detail panel.
- gap_status: not_implemented
- repo_impact: extension
- evidence: `requirements_ears.md` Requirement 3
- gap_to_close: Render the canonical `FeatureSummary` projection for discovered features.

### Requirement: Requirement 4
- requirement_summary: Compute readiness.
- transport_layer: Canonical `sequencing/toFeatureSummary` projection over `ProgressReport`.
- user_reachable_surface: Badges, percentages, and missing-artifact warnings.
- gap_status: not_implemented
- repo_impact: extension
- evidence: `requirements_ears.md` Requirement 4
- gap_to_close: Reuse and test the existing projection without a second readiness algorithm.

### Requirement: Requirement 5
- requirement_summary: Open artifacts from the dashboard.
- transport_layer: VS Code command API and URI/file APIs.
- user_reachable_surface: Artifact open buttons.
- gap_status: not_implemented
- repo_impact: extension
- evidence: `requirements_ears.md` Requirement 5
- gap_to_close: Implement Webview-to-extension artifact open messages.

### Requirement: Requirement 6
- requirement_summary: Recompute progress from current workspace files.
- transport_layer: Manual refresh and file watchers invoke in-process `sequencing/` evaluation.
- user_reachable_surface: Refresh button and diagnostic state.
- gap_status: not_implemented
- repo_impact: extension
- evidence: `requirements_ears.md` Requirement 6
- gap_to_close: Implement recomputation lifecycle and diagnostic rendering without persisted stale state.

### Requirement: Requirement 7
- requirement_summary: Invoke allow-listed shipped Overmind actions.
- transport_layer: In-process coordinator primitives plus a VS Code integrated terminal for `overmind run`.
- user_reachable_surface: Read-only status, Create Feature, and Continue E2E actions; Create Project is postponed.
- gap_status: not_implemented
- repo_impact: extension, asdlc-coordinator
- evidence: `requirements_ears.md` Requirement 7
- gap_to_close: Add an `overmind` verb allow-list, core availability check, and terminal adapter.

### Requirement: Requirement 8
- requirement_summary: Add guided Webview forms for common actions.
- transport_layer: Webview forms with validated message payloads and coordinator primitive contracts.
- user_reachable_surface: Create Feature and capture forms; Create Project remains postponed.
- gap_status: not_implemented
- repo_impact: extension, asdlc-coordinator
- evidence: `requirements_ears.md` Requirement 8
- gap_to_close: Bind deterministic inputs to capture/scaffold primitives and model sessions to terminal-hosted `overmind run`.

### Requirement: Requirement 9
- requirement_summary: Preserve ASDLC source of truth.
- transport_layer: Architecture boundary and code review rule.
- user_reachable_surface: none
- gap_status: not_implemented
- repo_impact: extension
- evidence: `requirements_ears.md` Requirement 9
- gap_to_close: Enforce coordinator projection/action boundaries in module design.

### Requirement: Requirement 10
- requirement_summary: Capture task-to-BR story input through a guided UI.
- transport_layer: Webview form validates local story file or Jira ticket, then calls the shared `asdlc-coordinator` capture primitive.
- user_reachable_surface: Task-to-BR capture form on a feature detail view.
- gap_status: not_implemented
- repo_impact: extension, asdlc-coordinator
- evidence: `requirements_ears.md` Requirement 10
- gap_to_close: Add form UI and extension-host action that calls `overmind capture task-to-br` or the core API, then refreshes feature state.

## 6. Impacted Components

### Component: extension-scaffold
- repo: extension
- component_kind: config
- relevant_paths: `packages/vscode-extension/package.json`, `packages/vscode-extension/src/extension.ts`
- requirement_refs: Requirement 1, NFR 1
- current_state: Scaffolded by the e2e migration Slice 5 (`crp-149-migration-phase5-cleanup-extension`) as a read-only tree-view package; Webview registration and VSIX packaging still missing.
- required_behavior: Provide VS Code extension activation, commands, Webview registration, and extension packaging.
- gap_to_close: Scaffold extension project with TypeScript, linting, tests, and VSIX packaging.
- dependency_notes: Must be established before coordinator read-model and UI work.
- evidence: architecture decision from conversation.

### Component: coordinator-read-model
- repo: asdlc-coordinator, extension
- component_kind: service
- relevant_paths: `packages/asdlc-coordinator/src/workspace/`, `packages/asdlc-coordinator/src/sequencing/`, `packages/vscode-extension/src/read-model.ts`
- requirement_refs: Requirement 1, Requirement 2, Requirement 3, Requirement 6
- current_state: Coordinator workspace discovery and sequencing exist; extension glue is minimal.
- required_behavior: Resolve ASDLC/project/feature paths, evaluate every declared step, and return diagnostics as values.
- gap_to_close: Bind the existing pure coordinator APIs to the extension view.
- dependency_notes: Extension imports only the `workspace` and `sequencing` package subpaths.
- evidence: Runtime ASDLC structure inspection.

### Component: feature-summary-projection
- repo: asdlc-coordinator
- component_kind: service
- relevant_paths: `packages/asdlc-coordinator/src/sequencing/projections.ts`
- requirement_refs: Requirement 4
- current_state: `toFeatureSummary(report)` exists.
- required_behavior: Convert `ProgressReport` into the canonical feature readiness fields.
- gap_to_close: Consume and test this projection in the extension; do not duplicate it.
- dependency_notes: Depends only on sequencing values.
- evidence: Existing `init_progress_definition.yaml`, `step_state.md`, and feature artifacts.

### Component: webview-dashboard
- repo: extension
- component_kind: ui
- relevant_paths: `src/webview/`, `media/`
- requirement_refs: Requirement 2, Requirement 3, Requirement 4, Requirement 5, Requirement 6, Requirement 8, Requirement 10
- current_state: Missing.
- required_behavior: Render project list, feature list, readiness cards, artifact links, refresh action, and future forms including task-to-BR capture.
- gap_to_close: Build simple responsive Webview with message bridge to extension host.
- dependency_notes: Must avoid direct filesystem access; all data comes from extension messages.
- evidence: Product direction from conversation.

### Component: action-controller
- repo: extension
- component_kind: service
- relevant_paths: `src/actions/actionController.ts`, `src/actions/terminalRunner.ts`
- requirement_refs: Requirement 7, Requirement 8, Requirement 9, Requirement 10, NFR 2
- current_state: Missing.
- required_behavior: Validate requested action, confirm mutations, call coordinator primitives for deterministic work, and host `overmind run` in a visible terminal for model sessions.
- gap_to_close: Implement allow-listed actions after the read-only dashboard stabilizes.
- dependency_notes: Mutating actions should remain disabled until v3.
- evidence: Future path v2-v4.

### Component: coordinator-action-contracts
- repo: asdlc-coordinator
- component_kind: other
- relevant_paths: `packages/asdlc-coordinator/src/capture/`, `packages/asdlc-coordinator/src/interaction/`, `packages/asdlc-coordinator/src/cli/run.ts`
- requirement_refs: Requirement 7, Requirement 8
- current_state: Deterministic capture/scaffold primitives, `InteractionPort`, and `overmind run` exist.
- required_behavior: Deterministic form inputs call coordinator primitives; model sessions remain visible through terminal-hosted `overmind run`.
- gap_to_close: Bind future forms to existing core contracts as each surface is implemented.
- dependency_notes: Create Project is postponed until a shared primitive or shipped verb exists.
- evidence: AGENTS.md constraint says not to add new CLI flags unless explicitly requested.

### Component: task-to-br-capture-core
- repo: asdlc-coordinator
- component_kind: service
- relevant_paths: `packages/asdlc-coordinator/src/capture/task-to-br.ts`
- requirement_refs: Requirement 8, Requirement 9, Requirement 10
- current_state: Core capture primitive exists as `overmind capture task-to-br`.
- required_behavior: Given a feature path and exactly one explicit source (`--source-file` inside the feature folder or `--jira` ticket), write `user_br_input.md` in the canonical format. Local-file capture embeds the story text; Jira capture records a `jira:<ticket>` source marker for the later task skill/context MCP fetch.
- gap_to_close: Extension-host action must call this core primitive instead of rendering `user_br_input.md` itself.
- dependency_notes: Enables the future guided Webview capture form without duplicating workflow mutation logic.
- evidence: Task-to-BR migration decision.

## 7. Dashboard Data Contract

### DashboardModel
- `workspacePath`: absolute active ASDLC workspace path.
- `progressStatus`: `ready | computing | degraded`.
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
- A feature is ready for implementation when the canonical sequencing projection reports no remaining required steps.
- Unknown parse state must degrade to `unknown`, not crash the whole dashboard.

## 9. Cross-Repo Constraints and Planning Signals

### Planning Signal: source-of-truth-boundary
- signal_id: sig-001
- signal_type: source_of_truth_boundary
- owner_repo: extension
- consumer_repos: asdlc-coordinator
- required_artifact: ASDLC files and shared coordinator primitives
- must_precede: Any mutating Webview action
- output_requirements: Extension must call coordinator primitives or shipped `overmind` verbs instead of duplicating workflow mutation logic.
- source_evidence: Requirement 9

### Planning Signal: action-routing
- signal_id: sig-002
- signal_type: operator_safety
- owner_repo: extension
- consumer_repos: asdlc-coordinator
- required_artifact: Capture/scaffold primitives, `InteractionPort`, and visible terminal-hosted `overmind run`
- must_precede: Guided action implementation
- output_requirements: Deterministic actions use coordinator primitives; model sessions use terminal-hosted `overmind run`.
- source_evidence: Requirement 7, Requirement 8

### Planning Signal: core-capture-boundary
- signal_id: sig-003
- signal_type: source_of_truth_boundary
- owner_repo: asdlc-coordinator
- consumer_repos: extension
- required_artifact: `overmind capture task-to-br` / capture core API
- must_precede: Task-to-BR guided capture Webview form
- output_requirements: Extension UI collects source-file/Jira input, but canonical `user_br_input.md` rendering stays in the shared core; Jira fetch and persistence stay in the task skill/context flow.
- source_evidence: Requirement 10

## 10. Known Risks / Uncertainties
- risk_1: BA/PO users may still find VS Code intimidating; mitigate with a single dashboard command and minimal visible technical concepts.
- risk_2: File changes can race a computation; mitigate by recomputing from current files on manual refresh and watcher events and rendering returned diagnostics.
- risk_3: Terminal-hosted model sessions need a supported Node execution context; use the active local or Remote WSL extension host.
- risk_4: Webview forms could duplicate coordinator logic; bind them only to capture/scaffold primitives and `InteractionPort` contracts.
- risk_5: Large ASDLC workspaces may make naive full scans slow; mitigate with asynchronous scans and file watchers.
