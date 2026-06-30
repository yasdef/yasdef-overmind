# Overmind VS Code Extension Requirements Compliance Report

Date: 2026-06-30

Scope analyzed:
- Implementation: `overmind_vscode_extention`
- Product baseline: `requirements/requirements_ears.md`

Verification performed:
- `npm test` from `overmind_vscode_extention`
- Result: passed, 51 tests passing
- Note: the first sandboxed run failed with `spawn EPERM` because the VS Code extension test host could not be launched. Rerunning with permission to spawn the VS Code test host succeeded.

Status legend:
- Passed: implementation and tests substantially satisfy the requirement.
- Partially passed: meaningful implementation exists, but one or more acceptance criteria or verification expectations are incomplete or not proven.
- Failed: implementation is absent or materially contradicts the requirement.

## Summary

| ID | Requirement | Status | Important Notes |
|---|---|---|---|
| Requirement 1 | ASDLC Workspace Detection | Partially passed | Detection, empty state, and multi-workspace selection are implemented. Stored workspace reuse means the operator is not asked on every multi-workspace open. |
| Requirement 2 | Project Dashboard | Passed | Projects, missing folders, project metadata, repo classes, and class readiness are scanned and rendered. |
| Requirement 3 | Feature Dashboard | Passed | Feature folders are recognized by `feature_br_summary.md`; non-feature folders are ignored. |
| Requirement 4 | Readiness Computation | Passed | Project, feature, and repo/class readiness are derived with unknown/blocked degradation. |
| Requirement 5 | Artifact Access | Passed | Existing artifacts can be opened; missing artifacts render disabled actions and are rejected if requested. |
| Requirement 6 | Scanner Refresh | Passed | Manual refresh, file watcher stale state, queued refresh, and last usable data retention are implemented. |
| Requirement 7 | Script Launching Through VS Code Terminal | Partially passed | Allow-listed terminal actions, confirmation, path validation, and Windows non-WSL blocking are implemented. Real `.commands` script compatibility was not smoke-tested here. |
| Requirement 8 | Guided Webview Forms | Partially passed | Task-to-BR form is implemented. Other guided forms remain terminal-driven pending non-interactive contracts. |
| Requirement 9 | Preserve ASDLC Source Of Truth | Passed | Read-only scan boundaries hold; durable extension state is limited to active workspace preference; mutation delegates to scripts/core. |
| Requirement 10 | Task-To-BR Input Capture Form | Passed | Exactly-one-source validation and shared core delegation are implemented and tested. |
| NFR 1 | Cross-Platform Operation | Partially passed | VS Code filesystem APIs are used and Windows shell actions require WSL, but macOS/Linux/Windows WSL manual smoke records are still missing. |
| NFR 2 | Safety | Passed | Mutating actions are confirmation-gated and allow-listed; unknown/unsafe actions are rejected. |
| NFR 3 | Performance | Partially passed | Async scanning patterns exist, but no 50-project/500-feature performance smoke test proves the 2-second target. |
| NFR 4 | Diagnostics | Partially passed | Output channel and path/reason diagnostics exist; permission-failure test coverage is not explicit. |

## Requirement-by-Requirement Findings

### Requirement 1 - ASDLC Workspace Detection

Status: Partially passed

Acceptance criteria:
- Passed: A workspace folder containing root `asdlc_metadata.yaml` is detected as an ASDLC workspace.
- Passed: No-workspace and no-ASDLC states render clear empty-state messages.
- Partially passed: Multiple ASDLC workspaces are selectable through Quick Pick. However, if an active workspace URI was previously stored, the extension reuses it without asking the operator again.

Important implementation notes:
- Detection is implemented in `src/scanner/workspaceDetection.ts`.
- Dashboard empty-state mapping is implemented in `src/extension.ts`.
- The active workspace preference key is `overmind.activeAsdlcWorkspaceUri`.

Test coverage:
- `src/test/suite/workspaceDetection.test.ts` covers no workspace, missing metadata, single workspace, stored multi-workspace selection, prompted multi-workspace selection, cancelled selection, and invalid metadata diagnostics.

Residual risk:
- Stored selection is useful behavior, but it is a softer interpretation of "SHALL ask" when multiple ASDLC workspaces are open.

### Requirement 2 - Project Dashboard

Status: Passed

Acceptance criteria:
- Passed: Projects are listed from `asdlc_metadata.yaml`.
- Passed: Missing listed project folders are marked blocked/inconsistent with diagnostics instead of failing the dashboard.
- Passed: Project name, ID, creation date, project type, active repo classes, and class repo readiness are present in the scan model and dashboard rendering.

Important implementation notes:
- Project extraction and project scanning are implemented in `src/scanner/asdlcScanner.ts`.
- Project rendering is implemented in `src/webview/dashboardView.ts`.
- Repo class readiness is extracted from `init_progress_definition.yaml` metadata.

Test coverage:
- `src/test/suite/asdlcScanner.test.ts` validates project metadata parsing, missing folders, class readiness, and project artifacts.
- `src/test/suite/dashboardView.test.ts` validates dashboard rendering for projects, project details, and repo classes.

Residual risk:
- YAML support is intentionally simple; unusual valid YAML shapes outside supported fixtures may produce diagnostics or unknown state.

### Requirement 3 - Feature Dashboard

Status: Passed

Acceptance criteria:
- Passed: Feature folders under projects are listed when they contain `feature_br_summary.md`.
- Passed: Feature name, step completion, missing artifacts, and readiness summary are shown.
- Passed: Non-feature folders are ignored unless they contain `feature_br_summary.md`.

Important implementation notes:
- Feature discovery is implemented in `scanFeatures` in `src/scanner/asdlcScanner.ts`.
- Feature artifacts are defined by `FEATURE_ARTIFACT_DEFINITIONS`.
- Feature rendering is implemented in `src/webview/dashboardView.ts`.

Test coverage:
- `src/test/suite/asdlcScanner.test.ts` covers complete features, incomplete features, and non-feature folder filtering.
- `src/test/suite/dashboardView.test.ts` covers missing artifacts and blocked feature rendering.

Residual risk:
- Feature recognition is marker-file based only; this matches the current technical requirement but depends on consistent ASDLC artifact generation.

### Requirement 4 - Readiness Computation

Status: Passed

Acceptance criteria:
- Passed: Project readiness is computed from project-level steps, feature readiness, diagnostics, and class readiness.
- Passed: Feature readiness is computed from expected artifacts and checklist state.
- Passed: Repo/class readiness is computed from `meta_info.project_classes` and `meta_info.class_repo_paths`.
- Passed: Unknown or invalid states degrade to `unknown`, `blocked`, or stale diagnostics rather than crashing.

Important implementation notes:
- Readiness logic is implemented in `src/scanner/readiness.ts`.
- Deferred class state is treated as non-blocking.
- Missing required artifacts block readiness.

Test coverage:
- `src/test/suite/readiness.test.ts` covers complete, partial, missing, deferred, invalid, and unknown states.

Residual risk:
- Checklist parsing counts Markdown checkbox lines only; richer checklist semantics are not interpreted.

### Requirement 5 - Artifact Access

Status: Passed

Acceptance criteria:
- Passed: Existing artifacts render Open actions and open through VS Code document APIs.
- Passed: Missing expected artifacts are shown as missing and have disabled Webview actions.
- Passed: Project-level and feature-level artifact groups are rendered separately.

Important implementation notes:
- Artifact open handling is implemented in `src/actions/artifactActions.ts`.
- Artifact rendering is implemented in `src/webview/dashboardView.ts`.
- Open requests are resolved against the current dashboard model, so arbitrary Webview URI requests are rejected.

Test coverage:
- `src/test/suite/artifactActions.test.ts` verifies existing artifact open and missing artifact rejection.
- `src/test/suite/dashboardView.test.ts` verifies Open versus Missing button rendering.

Residual risk:
- File-open behavior was tested with mocked VS Code APIs and fixture files, not manually smoke-tested in a real VS Code operator session.

### Requirement 6 - Scanner Refresh

Status: Passed

Acceptance criteria:
- Passed: Refresh Webview messages trigger rescans.
- Passed: Relevant ASDLC file changes mark dashboard data stale and schedule refresh.
- Passed: File-level scan failure reports path/reason and keeps last usable dashboard data when available.

Important implementation notes:
- Scan lifecycle is implemented in `src/dashboard/dashboardScanSession.ts`.
- Watch patterns are implemented in `src/dashboard/fileWatchers.ts`.
- Last usable dashboard data is retained when a later scan fails.

Test coverage:
- `src/test/suite/dashboardScanSession.test.ts` covers manual refresh, stale state, queued refresh, and failed-scan fallback.
- `src/test/suite/fileWatchers.test.ts` validates watched metadata, project state, and feature artifact patterns.

Residual risk:
- Watcher behavior is tested through the session abstraction and pattern list, not by full end-to-end filesystem event simulation in a real VS Code window.

### Requirement 7 - Script Launching Through VS Code Terminal

Status: Partially passed

Acceptance criteria:
- Passed: Script actions are allow-listed and point to scripts under `.commands/`.
- Passed: Interactive scripts launch in visible VS Code integrated terminals.
- Passed: Mutating script actions show exact script and target path and require confirmation.
- Passed: Missing or non-executable scripts are rejected with blocking errors.
- Partially passed: Actual compatibility with real Overmind shell scripts was not verified in this local analysis because the repository fixtures do not include a real executable `.commands` runtime workspace.

Important implementation notes:
- Allow-listed actions are `runInitProgressScanner`, `createOrContinueFeature`, and `createProject`.
- Windows local shell execution is blocked unless VS Code runs under Remote WSL.
- Target paths are derived from the current dashboard model and safe project/feature IDs.

Test coverage:
- `src/test/suite/actionController.test.ts` covers allow-listing, confirmations, invalid IDs, Windows runtime blocking, missing/non-executable scripts, and confirmation text.
- `src/test/suite/scriptRunner.test.ts` covers terminal launch and shell quoting.

Residual risk:
- The current commands add `--path` to two scripts. This must be confirmed against the real ASDLC `.commands/*.sh` contracts before distribution.

### Requirement 8 - Guided Webview Forms

Status: Partially passed

Acceptance criteria:
- Passed for approved contract: Task-to-BR capture collects required inputs in a Webview form.
- Passed for approved contract: Webview and extension host validate form inputs before mutation.
- Passed: Other script actions remain terminal-driven because no accepted non-interactive contracts exist.
- Partially passed: The requirement refers to common Overmind actions such as creating projects/features; those are not form-driven yet by design.

Important implementation notes:
- Task-to-BR is the first approved guided form.
- `requirements/non_interactive_script_contracts.md` records that create project, create feature, and scanner remain terminal-driven.
- Browser-side form behavior is implemented in inline Webview script; extension-host validation is authoritative.

Test coverage:
- `src/test/suite/taskToBrCapture.test.ts` covers extension-host validation and core delegation.
- `src/test/suite/dashboardView.test.ts` checks that the form and messages are present in rendered HTML.

Residual risk:
- Webview form behavior is mostly tested through static HTML assertions rather than browser-level interaction tests.

### Requirement 9 - Preserve ASDLC Source Of Truth

Status: Passed

Acceptance criteria:
- Passed: ASDLC files, existing scripts, and shared core primitives remain source of truth.
- Passed: The extension does not persist authoritative project, feature, or readiness state outside ASDLC.
- Passed: Durable extension state is limited to active workspace preference.

Important implementation notes:
- Scanner reads ASDLC files and produces in-memory dashboard DTOs.
- Webview does not access the filesystem directly.
- Script actions launch existing scripts; task-to-BR capture delegates to shared core.

Test coverage:
- Covered indirectly by scanner, action controller, artifact action, and task-to-BR tests.

Residual risk:
- This requirement is partly architectural and should remain a code-review gate for future mutating actions.

### Requirement 10 - Task-To-BR Input Capture Form

Status: Passed

Acceptance criteria:
- Passed: The operator can choose exactly one source: local `.txt`/`.md` story file inside the feature folder or Jira ticket.
- Passed: Local and Jira submissions call the shared core capture contract and do not render canonical `user_br_input.md` content in Webview code.
- Passed: Jira capture sends the ticket identifier only; story fetch/persistence remains outside the Webview.
- Passed: Capture success triggers dashboard refresh and posts a result message back to the Webview.
- Passed: Validation and core failures are surfaced without mutating unrelated artifacts.

Important implementation notes:
- Capture host logic is implemented in `src/actions/taskToBrCapture.ts`.
- Capture result refresh is handled in `src/extension.ts`.
- The core command resolves to workspace `.overmind/overmind.js` when present, otherwise `overmind`.

Test coverage:
- `src/test/suite/taskToBrCapture.test.ts` covers local story file capture, Jira capture, invalid combinations, unsafe paths, missing local files, cancellation, core failure, message recognition, and argument construction.

Residual risk:
- Real capture success depends on the shared Overmind core command or bundled core API being available in the operator environment.

## Non-Functional Requirements

### NFR 1 - Cross-Platform Operation

Status: Partially passed

Acceptance criteria:
- Passed: VS Code workspace and filesystem APIs are used where practical.
- Passed: Local Windows shell-script actions are blocked unless the extension runs in Remote WSL or another Unix-like context.
- Partially passed: Manual smoke tests for macOS, Linux, and Windows WSL2 are documented but not recorded.

Important implementation notes:
- `vscode.workspace.fs` is used for scanning and artifact access.
- `src/actions/actionController.ts` rejects Windows local shell runtime for script actions.
- `docs/internal_release.md` lists the required cross-platform smoke tests.

Residual risk:
- Remote filesystem edge cases and actual WSL terminal behavior need manual verification.

### NFR 2 - Safety

Status: Passed

Acceptance criteria:
- Passed: Read-only dashboard features and mutating workflow actions are visually and behaviorally separated.
- Passed: Mutating actions require explicit confirmation.
- Passed: The extension does not run destructive git or filesystem commands directly.

Important implementation notes:
- Script actions are rendered as terminal actions and confirmation-gated.
- Unknown action IDs and unsafe project/feature IDs are rejected.
- Task-to-BR capture validates exact target feature and exact source before core invocation.

Test coverage:
- `src/test/suite/actionController.test.ts` and `src/test/suite/taskToBrCapture.test.ts` cover confirmation gates, allow-listing, invalid paths, and cancellation.

Residual risk:
- Future guided forms must keep the same allow-list and confirmation discipline.

### NFR 3 - Performance

Status: Partially passed

Acceptance criteria:
- Not proven: No generated 50-project/500-feature performance smoke test was found.
- Partially passed: Scans are asynchronous and use concurrent project/artifact checks, reducing UI blocking risk.

Important implementation notes:
- Project scans and artifact checks use `Promise.all`.
- Refreshes are debounced and queued during active scans.

Test coverage:
- Functional refresh tests exist.
- No performance smoke test exists for the required scale and 2-second target.

Residual risk:
- Large workspaces may perform acceptably, but the required performance target is not measured.

### NFR 4 - Diagnostics

Status: Partially passed

Acceptance criteria:
- Passed: Parse errors include file path and reason.
- Passed: The `Overmind` output channel logs scanner, watcher, artifact, and action events.
- Passed: Routine diagnostics include paths and reasons, not file contents.
- Partially passed: Explicit permission-failure diagnostic tests were not found.

Important implementation notes:
- Diagnostics use structured severity/code/path/message records.
- Output channel creation is in `src/extension.ts`.
- Scanner and action layers return user-visible errors for missing/unreadable files and scripts.

Test coverage:
- Scanner tests cover parse failures and missing project folders.
- Action tests cover missing scripts.
- Dashboard scan session tests cover failed-scan retention.

Residual risk:
- Permission errors should be tested explicitly, especially for remote and locked-file workspaces.

## Test Result Detail

Command:

```powershell
npm test
```

Working directory:

```text
D:\Projects\SPG\vscode-plugin\overmind_vscode_extention
```

Result:

```text
51 passing
```

Covered test suites:
- Script action controller
- Artifact actions
- ASDLC scanner
- Dashboard scan session
- Dashboard Webview
- Extension scaffold
- ASDLC file watchers
- Readiness engine
- Script runner
- Task-to-BR capture action
- ASDLC workspace detection

## Highest Priority Follow-Ups

1. Add a generated 50-project/500-feature performance smoke test and assert the initial dashboard scan/render target.
2. Record macOS, Linux, and Windows Remote WSL smoke results before broad internal distribution.
3. Verify terminal script invocations against a real ASDLC `.commands` workspace, especially `--path` compatibility.
4. Add browser-level Webview interaction tests for the task-to-BR form.
5. Add explicit permission-failure tests for scanner and action diagnostics.
