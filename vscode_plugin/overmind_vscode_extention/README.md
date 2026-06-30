# Overmind VS Code Extension

Local operator dashboard for ASDLC workspaces.

## Operator Usage

See `docs/operator_guide.md` for VSIX installation, dashboard startup, workspace states, actions, Windows notes, and diagnostics.

## Development

```bash
npm install
npm run compile
```

Use the `Run Extension` launch configuration to open an Extension Development Host, then run `Overmind: Open Dashboard` from the command palette.

## Packaging

```bash
npm run package
```

The local VSIX is written to `dist/overmind-vscode-extension.vsix`.

See `docs/internal_release.md` for the employee install flow, cross-platform smoke test matrix, and release checklist.
