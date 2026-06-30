# Overmind Operator Guide

## Install From VSIX

1. Open VS Code.
2. Open the Extensions view.
3. Select the `...` menu.
4. Select `Install from VSIX...`.
5. Choose `dist/overmind-vscode-extension.vsix`.
6. Reload VS Code if prompted.

Alternative command-line install:

```bash
code --install-extension dist/overmind-vscode-extension.vsix
```

## Open The Dashboard

1. Open an ASDLC workspace folder in VS Code. The folder must contain `asdlc_metadata.yaml` at its root.
2. Run `Overmind: Open Dashboard` from the Command Palette.
3. If more than one ASDLC workspace is open, select the active workspace when prompted.
4. Review projects, features, readiness, missing artifacts, diagnostics, and artifact links.
5. Use `Refresh` after scripts or files change.

## Workspace States

- No ASDLC workspace: open or add a folder containing `asdlc_metadata.yaml`.
- Multiple ASDLC workspaces: select the active workspace.
- Stale dashboard: a watched ASDLC file changed; refresh is queued or available.
- Failed scan: diagnostics show the affected path and reason. When possible, the dashboard keeps the last usable scan data.

## Actions

- Artifact buttons open existing files in VS Code. Missing artifacts show a disabled action.
- Terminal actions run existing Overmind scripts in a visible integrated terminal and require confirmation.
- Task-to-BR capture accepts exactly one source: a `.txt` or `.md` story file inside the feature folder, or a Jira ticket identifier. The extension delegates capture to the shared Overmind core and does not render `user_br_input.md` itself.

## Windows Notes

Read-only dashboard features work in normal local workspaces. Shell-script actions require VS Code Remote WSL or another Unix-like execution context.

## Diagnostics

Open the `Overmind` output channel for scanner, watcher, artifact, and action events. Diagnostics should include affected paths and reasons without exposing file contents.
