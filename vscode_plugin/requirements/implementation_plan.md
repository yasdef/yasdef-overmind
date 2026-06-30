# Implementation Plan - Overmind VS Code Extension

Use one shared implementation plan for the whole extension. Keep v1 read-only and defer mutation until dashboard behavior is stable.

### Step 1.1 Scaffold VS Code Extension Project [Requirement 1] [NFR 1]
#### Repo: extension
#### Depends on: none
#### Evidence: comp/extension-scaffold
#### Preserved Surface: VS Code command palette and extension activation
- [x] Create TypeScript VS Code extension scaffold under `overmind_vscode_extention`.
- [x] Add package metadata, activation events, extension entrypoint, and build/test scripts.
- [x] Add a basic command: `Overmind: Open Dashboard`.
- [x] Add packaging path for local `.vsix` distribution.
- [ ] Verify extension launches in VS Code extension host.

### Step 1.2 Implement ASDLC Workspace Detection [Requirement 1]
#### Repo: extension
#### Depends on: 1.1
#### Evidence: gap/Requirement-1, comp/asdlc-scanner
#### Preserved Surface: workspace selection / empty state
- [x] Detect `asdlc_metadata.yaml` in workspace folders.
- [x] Handle no workspace, one workspace, and multiple ASDLC workspaces.
- [x] Store only active workspace preference when needed.
- [x] Add diagnostics for missing or invalid ASDLC metadata.
- [x] Test workspace detection with fixtures.

### Step 1.3 Build Read-Only ASDLC Scanner [Requirement 2] [Requirement 3] [Requirement 6]
#### Repo: extension
#### Depends on: 1.2
#### Evidence: comp/asdlc-scanner
#### Preserved Surface: read-only local filesystem index
- [x] Parse `asdlc_metadata.yaml`.
- [x] Parse project `init_progress_definition.yaml`.
- [x] Discover feature folders using `feature_br_summary.md`.
- [x] Detect expected project-level and feature-level artifacts.
- [x] Isolate parse and permission errors per file.
- [x] Produce normalized dashboard JSON.
- [x] Add fixture-backed unit tests.

### Step 1.4 Implement Readiness Engine [Requirement 4]
#### Repo: extension
#### Depends on: 1.3
#### Evidence: comp/readiness-engine
#### Preserved Surface: project and feature readiness badges
- [x] Define readiness states: `ready`, `in_progress`, `blocked`, `deferred`, `unknown`.
- [x] Compute repo/class readiness from `meta_info.class_repo_paths`.
- [x] Compute feature readiness from artifacts and checklist state when available.
- [x] Compute project readiness from project steps and feature summaries.
- [x] Add tests for complete, partial, missing, deferred, and invalid states.

### Step 2.1 Build Webview Dashboard [Requirement 2] [Requirement 3] [Requirement 4]
#### Repo: extension
#### Depends on: 1.4
#### Evidence: comp/webview-dashboard
#### Preserved Surface: Overmind dashboard panel
- [x] Render project list with project readiness and repo/class readiness.
- [x] Render feature list per project with readiness and missing artifacts.
- [x] Add project and feature detail views.
- [x] Add empty, loading, stale, and error states.
- [x] Keep UI local and read-only for v1.
- [x] Smoke test dashboard against the example ASDLC workspace.

### Step 2.2 Add Artifact Open Actions [Requirement 5]
#### Repo: extension
#### Depends on: 2.1
#### Evidence: gap/Requirement-5, comp/webview-dashboard
#### Preserved Surface: artifact links
- [x] Add artifact records to dashboard model.
- [x] Add Webview message for opening an artifact.
- [x] Use VS Code file APIs to open existing artifacts.
- [x] Disable open actions for missing artifacts.
- [x] Test Webview-to-extension message handling.

### Step 2.3 Add Refresh and File Watchers [Requirement 6] [NFR 3] [NFR 4]
#### Repo: extension
#### Depends on: 2.1
#### Evidence: gap/Requirement-6, comp/asdlc-scanner
#### Preserved Surface: refresh action and stale-state indicator
- [x] Add manual refresh action.
- [x] Add file watchers for ASDLC metadata, project metadata, step state, and feature artifacts.
- [x] Mark dashboard stale when relevant files change during active scans.
- [x] Add output channel diagnostics for scan lifecycle.
- [x] Verify UI remains responsive during scans.

### Step 3.1 Add Safe Script Action Framework [Requirement 7] [Requirement 9] [NFR 2]
#### Repo: extension
#### Depends on: 2.3
#### Evidence: comp/action-controller, sig-001, sig-002
#### Preserved Surface: terminal-launched Overmind actions
- [x] Define an allow-list of script actions.
- [x] Validate active ASDLC, project, and feature paths before action execution.
- [x] Require confirmation before mutating script actions.
- [x] Construct commands only from validated paths and known script names.
- [x] Launch interactive scripts in visible VS Code terminals.
- [x] Add mocked terminal tests for command construction.

### Step 3.2 Add First Script Buttons [Requirement 7]
#### Repo: extension
#### Depends on: 3.1
#### Evidence: comp/action-controller
#### Preserved Surface: dashboard action buttons
- [x] Add `Run Scanner` action for selected feature where applicable.
- [x] Add `Create Feature / Continue E2E` terminal action for selected project.
- [x] Add `Create Project` terminal action for the ASDLC workspace.
- [x] Refresh dashboard after terminal action completion when completion can be detected.
- [x] Keep terminal output visible to the operator for interactive prompts.

### Step 4.1 Identify Non-Interactive Script Contracts [Requirement 8]
#### Repo: shell-runtime
#### Depends on: 3.2
#### Evidence: comp/script-contracts
#### Output: `requirements/non_interactive_script_contracts.md`
#### Preserved Surface: existing Overmind script behavior
- [x] List scripts that should become Webview form-driven.
- [x] Identify required inputs, validation rules, outputs, and failure modes.
- [x] Decide whether each action should keep terminal mode or receive a non-interactive script contract.
- [x] Record that task-to-BR capture already has a non-interactive shared-core contract: `overmind capture task-to-br`.
- [x] Do not add new script flags until requirements are explicit.
- [x] Capture accepted script contract changes in future Overmind artifacts.

### Step 4.2 Add Task-To-BR Capture Form [Requirement 10] [NFR 2]
#### Repo: extension
#### Depends on: 4.1
#### Evidence: comp/task-to-br-capture-core, sig-003
#### Preserved Surface: canonical `user_br_input.md` file contract
- [x] Add feature-level capture action when `user_br_input.md` is missing or the operator chooses to recapture.
- [x] Let the operator choose exactly one source: local `.txt`/`.md` file inside the feature folder or Jira ticket.
- [x] Validate Webview inputs before calling the extension host.
- [x] Call the shared core capture primitive (`overmind capture task-to-br` or imported core API) instead of rendering `user_br_input.md` in Webview code.
- [x] Refresh feature state and show capture errors from the core without mutating unrelated files.

### Step 4.3 Add Guided Webview Forms [Requirement 8] [NFR 2]
#### Repo: extension
#### Depends on: 4.1
#### Evidence: gap/Requirement-8, comp/webview-dashboard
#### Preserved Surface: BA/PO form-driven actions
- [x] Add form UI for the first approved non-interactive action.
- [x] Validate form input in Webview and extension host.
- [x] Call the approved script contract or fall back to terminal mode.
- [x] Show success, cancellation, and failure states.
- [x] Refresh dashboard after successful action completion.

### Step 5.1 Package and Internal Release [NFR 1] [NFR 4]
#### Repo: extension
#### Depends on: 2.3
#### Evidence: comp/extension-scaffold
#### Output: `overmind_vscode_extention/dist/overmind-vscode-extension.vsix`, `overmind_vscode_extention/docs/operator_guide.md`, `overmind_vscode_extention/docs/internal_release.md`
#### Preserved Surface: local `.vsix` install path
- [x] Build installable `.vsix` package.
- [x] Document employee install flow using `Extensions: Install from VSIX`.
- [x] Add short operator guide for opening ASDLC workspace and dashboard.
- [ ] Smoke test on macOS, Linux, and Windows WSL2. Manual release gate documented in `overmind_vscode_extention/docs/internal_release.md`; not executed from this Windows workspace.
- [x] Define release checklist for future versions.
