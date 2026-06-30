# Non-Interactive Script Contract Inventory

## Document Meta
- feature_id: overmind-vscode-extension
- implementation_step: 4.1 Identify Non-Interactive Script Contracts
- source_requirements: `requirements_ears.md`, `technical_requirements.md`, `implementation_plan.md`
- last_updated: 2026-06-30
- status: accepted planning baseline

## Purpose

This document records which Overmind actions may become Webview form-driven and which actions must remain terminal-driven until the shell-runtime or shared core exposes an explicit non-interactive contract.

The extension must preserve ASDLC files, existing Overmind scripts, and shared core primitives as the source of truth. This inventory does not add script flags, alter script behavior, or duplicate workflow artifact rendering in the Webview.

## Contract Decisions

| Action | Current entrypoint | Scope | Decision |
|---|---|---:|---|
| Run scanner | `.commands/init_progress_scanner.sh` | Feature | Keep terminal-driven. It may receive a future non-interactive contract only if the shell-runtime defines stable inputs, outputs, idempotency, and failure reporting. |
| Create Feature / Continue E2E | `.commands/project_add_feature_e2e.sh` | Project | Keep terminal-driven. It is a good future form candidate, but current interactive prompt behavior remains authoritative. |
| Create Project | `.commands/project_setup_add_new_project.sh` | Workspace | Keep terminal-driven. A form requires a new accepted shell-runtime contract for project metadata, class setup, repository paths, and validation. |
| Task-to-BR capture | `overmind capture task-to-br` or bundled core API | Feature | Approved for non-interactive Webview capture through the shared core. Implement in step 4.2 without rendering `user_br_input.md` in Webview code. |

## Candidate Contract Details

### Run Scanner
- Required input: active ASDLC workspace path and selected feature path from the current dashboard model.
- Existing validation: active workspace exists, selected project and feature paths match scanner DTOs, `.commands/init_progress_scanner.sh` exists, and shell runtime is Unix-like or VS Code Remote WSL on Windows.
- Expected output: scanner-maintained readiness or step-state artifacts under the ASDLC project or feature, plus visible terminal output.
- Failure modes: missing script, non-executable script, unsupported Windows runtime, invalid selected feature path, script-level scanner failure, or operator cancellation.
- Accepted mode: terminal. No Webview form is required because the operator selects an existing feature from dashboard context.
- Future contract requirement: shell-runtime must define whether the scanner is idempotent, which files it may update, how it reports structured success or failure, and whether it accepts a feature path, project path, or workspace path.

### Create Feature / Continue E2E
- Required input for any future form: active ASDLC workspace path, selected project path, feature folder identifier or selected existing feature, feature display name or summary source if required by the script, and an explicit create-versus-continue choice.
- Validation rules for any future form: project path must resolve inside the active ASDLC workspace; feature folder id must be a single safe path segment; create mode must reject an existing feature folder unless the contract explicitly supports overwrite or continue; continue mode must require an existing feature folder; user-provided text must be non-empty where required.
- Expected output: shell-runtime remains responsible for creating or updating the canonical feature folder and Overmind artifacts.
- Failure modes: duplicate feature id, missing project folder, invalid feature id, missing required source material, script-level validation failure, or operator cancellation.
- Accepted mode: terminal. A non-interactive form must wait for an accepted shell-runtime artifact that names exact inputs, outputs, and cancellation behavior.

### Create Project
- Required input for any future form: active ASDLC workspace path, project id, project name, project type code, project classes, and class repository path or deferred state for each class.
- Validation rules for any future form: project id must be a single safe path segment and unique in `asdlc_metadata.yaml`; project name must be non-empty; project type and classes must come from an approved Overmind configuration source; class repository paths must either be valid operator-provided paths or the explicit `deferred` state.
- Expected output: shell-runtime remains responsible for updating `asdlc_metadata.yaml`, creating the project folder, writing `init_progress_definition.yaml`, and any other canonical setup artifacts.
- Failure modes: duplicate project id, invalid project type, invalid or missing class repository path, metadata parse or write failure, script-level setup failure, or operator cancellation.
- Accepted mode: terminal. A non-interactive form must wait for an accepted shell-runtime artifact that defines project setup inputs and write semantics.

### Task-to-BR Capture
- Required input: selected feature path and exactly one source.
- Source option 1: local `.txt` or `.md` story file inside the selected feature folder.
- Source option 2: Jira ticket identifier.
- Validation rules: feature path must match the current dashboard model; exactly one source must be supplied; local source file must exist inside the feature folder and have a `.txt` or `.md` extension; Jira ticket input must be non-empty and must not contain path separators or control characters.
- Expected output: shared core writes canonical `user_br_input.md`; the extension refreshes the dashboard and shows the artifact as present.
- Failure modes: invalid source selection, local file outside feature folder, unreadable story file, invalid Jira identifier, core capture failure, or workspace refresh failure after a successful capture.
- Accepted mode: non-interactive shared-core contract. The Webview may collect inputs, but the extension host must call `overmind capture task-to-br` or the bundled core API and must not render canonical `user_br_input.md` content itself.

## Future Overmind Artifacts

Before adding Webview forms for create project, create feature, or scanner replacement, the accepted shell-runtime artifact must include:

- command entrypoint and invocation mode;
- required and optional inputs;
- path and text validation rules;
- files that may be created or updated;
- structured success and failure reporting;
- cancellation behavior;
- whether the command is idempotent;
- compatibility expectations for local Unix-like hosts and VS Code Remote WSL.

Until those artifacts exist, the extension must keep the existing terminal actions visible, confirmation-gated, and allow-listed.
