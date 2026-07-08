# Implementation Plan - Overmind VS Code Extension

Use one shared implementation plan for the whole extension. Keep v1 read-only and defer mutation until dashboard behavior is stable.

Checked items below were delivered by the e2e migration Slice 5 (`crp-149-migration-phase5-cleanup-extension`) as the workspace package `packages/vscode-extension`: a read-only activity-bar tree view backed by the coordinator read model, with watcher-driven refresh.

## CRP Breakdown

Proposed 2026-07-11. The remaining steps land as six OpenSpec changes; steps too thin to verify
alone are paired so every change is operator-visible and `npm run verify`-green.

| CRP | Steps | Scope |
|---|---|---|
| CRP-158 workspace detection & readiness completion | rest of 1.2 + 1.4 | Multi-workspace handling, active-workspace preference, detection fixtures, project-level presentation, full readiness test matrix (complete/partial/missing/deferred/invalid). Read-model only, no UI change. |
| CRP-159 webview dashboard | 2.1 + rest of 2.3 | Webview replacing the tree view: project list with repo/class readiness, per-project feature list, detail views, empty/loading/degraded/error states; manual refresh command and output-channel diagnostics folded in. |
| CRP-160 artifact open actions | 2.2 | First webview→extension-host message channel, artifact records, open-in-editor with disabled state for missing artifacts. Separate because it establishes the message-passing contract every later action reuses. |
| CRP-161 safe action framework + first actions | 3.1 + 3.2 | Verb allow-list, path validation, mutation confirmations, coordinator-vs-terminal routing, plus Create Feature (`overmind scaffold feature`) and Continue E2E (terminal-hosted `overmind run`). Merged: the framework alone has no observable behavior to verify. |
| CRP-162 coordinator action contracts + task-to-BR capture form | 4.1 + 4.2 | Contract binding in `asdlc-coordinator` plus its first consumer, the task-to-BR capture form. Merged: the contract's only proof is a consumer. |
| CRP-163 package & internal release | rest of 1.1 + 5.1 | `.vsix` packaging, extension-host launch verification, install docs, cross-platform smoke, release checklist. |

Step 4.3 (guided webview forms) is absorbed by CRP-162 — the capture form is the first form and
establishes the pattern; 4.3 becomes its own change only when a concrete second non-interactive
action is approved.

Recommended order: CRP-158 → CRP-159 → CRP-163 (early internal dogfooding of the read-only
dashboard; step 5.1 depends only on 2.3) → CRP-160 → CRP-161 → CRP-162.

### Step 1.1 Scaffold VS Code Extension Project [Requirement 1] [NFR 1]
#### Repo: extension
#### Depends on: none
#### Evidence: comp/extension-scaffold
#### Preserved Surface: VS Code command palette and extension activation
- [x] Create TypeScript VS Code extension scaffold as the workspace package `packages/vscode-extension`.
- [x] Add package metadata, activation events, extension entrypoint, and build/test scripts.
- [x] Add a read-only dashboard entrypoint: the activity-bar view `overmind.dashboard` (shipped instead of an `Overmind: Open Dashboard` palette command; the v1 manifest contributes no commands).
- [ ] Add packaging path for local `.vsix` distribution.
- [ ] Verify extension launches in VS Code extension host.

### Step 1.2 Implement ASDLC Workspace Detection [Requirement 1]
#### Repo: extension
#### Depends on: 1.1
#### Evidence: gap/Requirement-1, comp/coordinator-read-model
#### Preserved Surface: workspace selection / empty state
- [x] Detect `asdlc_metadata.yaml` in workspace folders (through coordinator `workspace/detectRuntimeRoot` from the first workspace folder).
- [ ] Handle no workspace, one workspace, and multiple ASDLC workspaces.
- [ ] Store only active workspace preference when needed.
- [x] Add diagnostics for missing or invalid ASDLC metadata (coordinator diagnostics carried into the dashboard model and rendered as rows).
- [ ] Test workspace detection with fixtures.

### Step 1.3 Bind the Read-Only Coordinator Model [Requirement 2] [Requirement 3] [Requirement 6]
#### Repo: extension
#### Depends on: 1.2
#### Evidence: comp/coordinator-read-model
#### Preserved Surface: read-only in-process progress model
- [x] Import only `asdlc-coordinator/workspace` and `asdlc-coordinator/sequencing` (enforced by the `package-contract` test).
- [x] Resolve runtime, project, and feature paths through `workspace/`.
- [x] Compute `ProgressReport` through `sequencing/` for every discovered feature.
- [x] Obtain `FeatureSummary` through the existing `toFeatureSummary(report)` projection.
- [x] Carry coordinator diagnostics into a degraded but renderable dashboard model.
- [x] Add fixture-backed unit tests proving every declared step contributes to the projection totals.

### Step 1.4 Implement Readiness Engine [Requirement 4]
#### Repo: extension
#### Depends on: 1.3
#### Evidence: comp/feature-summary-projection
#### Preserved Surface: project and feature readiness badges
- [x] Reuse readiness states from the canonical `FeatureSummary` projection.
- [x] Compute feature readiness from the coordinator `ProgressReport`.
- [ ] Compute project presentation from coordinator workspace/sequencing results.
- [ ] Add tests for complete, partial, missing, deferred, and invalid states (delivered tests cover ready, blocked, and unknown only).

### Step 2.1 Build Webview Dashboard [Requirement 2] [Requirement 3] [Requirement 4]
#### Repo: extension
#### Depends on: 1.4
#### Evidence: comp/webview-dashboard
#### Preserved Surface: Overmind dashboard panel
- [ ] Render project list with project readiness and repo/class readiness.
- [ ] Render feature list per project with readiness and missing artifacts.
- [ ] Add project and feature detail views.
- [ ] Add empty, loading, degraded, and error states.
- [ ] Keep UI local and read-only for v1.
- [ ] Smoke test dashboard against the example ASDLC workspace.

### Step 2.2 Add Artifact Open Actions [Requirement 5]
#### Repo: extension
#### Depends on: 2.1
#### Evidence: gap/Requirement-5, comp/webview-dashboard
#### Preserved Surface: artifact links
- [ ] Add artifact records to dashboard model.
- [ ] Add Webview message for opening an artifact.
- [ ] Use VS Code file APIs to open existing artifacts.
- [ ] Disable open actions for missing artifacts.
- [ ] Test Webview-to-extension message handling.

### Step 2.3 Add Refresh and File Watchers [Requirement 6] [NFR 3] [NFR 4]
#### Repo: extension
#### Depends on: 2.1
#### Evidence: gap/Requirement-6, comp/coordinator-read-model
#### Preserved Surface: fresh in-process progress recomputation
- [ ] Add manual refresh that invokes `sequencing/` in process.
- [x] Add file watchers for ASDLC metadata, project metadata, and feature artifacts (`asdlc_metadata.yaml` and `projects/**/*` watchers).
- [x] Trigger a fresh computation when relevant files change; persist no stale scanner state.
- [ ] Add output channel diagnostics for computation lifecycle.
- [ ] Verify UI remains responsive during recomputation.

### Step 3.1 Add Safe Overmind Action Framework [Requirement 7] [Requirement 9] [NFR 2]
#### Repo: extension
#### Depends on: 2.3
#### Evidence: comp/action-controller, sig-001, sig-002
#### Preserved Surface: coordinator-backed and terminal-hosted Overmind actions
- [ ] Define an allow-list of shipped `overmind` verbs.
- [ ] Validate active ASDLC, project, and feature paths before action execution.
- [ ] Require confirmation before mutating actions.
- [ ] Check `.overmind/overmind.js` or the bundled coordinator core before CLI action execution.
- [ ] Route deterministic actions to coordinator primitives and model sessions to terminal-hosted `overmind run`.
- [ ] Add mocked terminal tests for command construction.

### Step 3.2 Add First Overmind Actions [Requirement 7]
#### Repo: extension
#### Depends on: 3.1
#### Evidence: comp/action-controller
#### Preserved Surface: dashboard action buttons
- [ ] Use in-process `sequencing/` recomputation for read-only status; provide no terminal scanner action.
- [ ] Add Create Feature through the `overmind scaffold feature` primitive.
- [ ] Add Continue E2E through terminal-hosted `overmind run`.
- [ ] Postpone Create Project until a shared coordinator primitive or shipped `overmind` verb exists.
- [ ] Refresh dashboard after terminal action completion when completion can be detected.
- [ ] Keep terminal output visible to the operator for interactive prompts.

### Step 4.1 Bind Coordinator Action Contracts [Requirement 8]
#### Repo: asdlc-coordinator
#### Depends on: 3.2
#### Evidence: comp/coordinator-action-contracts
#### Preserved Surface: shared coordinator behavior
- [ ] List deterministic actions that should become Webview form-driven.
- [ ] Bind their inputs, validation, outputs, and failures to capture/scaffold primitives and `InteractionPort`.
- [ ] Keep model-session actions in terminal-hosted `overmind run`.
- [ ] Record that task-to-BR capture already has a shared-core contract: `overmind capture task-to-br`.
- [ ] Add no new CLI flags until requirements are explicit.

### Step 4.2 Add Task-To-BR Capture Form [Requirement 10] [NFR 2]
#### Repo: extension
#### Depends on: 4.1
#### Evidence: comp/task-to-br-capture-core, sig-003
#### Preserved Surface: canonical `user_br_input.md` file contract
- [ ] Add feature-level capture action when `user_br_input.md` is missing or the operator chooses to recapture.
- [ ] Let the operator choose exactly one source: local `.txt`/`.md` file inside the feature folder or Jira ticket.
- [ ] Validate Webview inputs before calling the extension host.
- [ ] Call the shared core capture primitive (`overmind capture task-to-br` or imported core API) instead of rendering `user_br_input.md` in Webview code.
- [ ] Refresh feature state and show capture errors from the core without mutating unrelated files.

### Step 4.3 Add Guided Webview Forms [Requirement 8] [NFR 2]
#### Repo: extension
#### Depends on: 4.1
#### Evidence: gap/Requirement-8, comp/webview-dashboard
#### Preserved Surface: BA/PO form-driven actions
- [ ] Add form UI for the first approved non-interactive action.
- [ ] Validate form input in Webview and extension host.
- [ ] Call the approved coordinator primitive or use terminal-hosted `overmind run` for model sessions.
- [ ] Show success, cancellation, and failure states.
- [ ] Refresh dashboard after successful action completion.

### Step 5.1 Package and Internal Release [NFR 1] [NFR 4]
#### Repo: extension
#### Depends on: 2.3
#### Evidence: comp/extension-scaffold
#### Preserved Surface: local `.vsix` install path
- [ ] Build installable `.vsix` package.
- [ ] Document employee install flow using `Extensions: Install from VSIX`.
- [ ] Add short operator guide for opening ASDLC workspace and dashboard.
- [ ] Smoke test on macOS, Linux, and Windows WSL2.
- [ ] Define release checklist for future versions.
