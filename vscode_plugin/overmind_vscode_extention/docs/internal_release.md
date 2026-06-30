# Internal Release Guide

## Build Artifact

Run from `overmind_vscode_extention`:

```bash
npm install
npm run compile
npm test
npm run package
```

The VSIX is written to:

```text
dist/overmind-vscode-extension.vsix
```

## Employee Install Flow

1. Send the `.vsix` file and the operator guide to the employee.
2. In VS Code, open the Extensions view.
3. Select the `...` menu.
4. Select `Install from VSIX...`.
5. Choose `overmind-vscode-extension.vsix`.
6. Reload VS Code if prompted.
7. Open an ASDLC workspace folder and run `Overmind: Open Dashboard`.

Command-line install:

```bash
code --install-extension dist/overmind-vscode-extension.vsix
```

## Release Smoke Tests

Run these checks before distributing a build.

| Environment | Required checks |
|---|---|
| macOS | Install VSIX, open an ASDLC workspace, run `Overmind: Open Dashboard`, verify projects/features render, open an artifact, refresh dashboard, inspect `Overmind` output channel. |
| Linux | Install VSIX, open an ASDLC workspace, run `Overmind: Open Dashboard`, verify projects/features render, open an artifact, refresh dashboard, inspect `Overmind` output channel. |
| Windows with Remote WSL | Open the ASDLC workspace through Remote WSL, install VSIX in the remote extension host, run `Overmind: Open Dashboard`, verify projects/features render, open an artifact, refresh dashboard, inspect `Overmind` output channel, confirm shell-script actions are available only in the Unix-like context. |

Record results with date, tester, VS Code version, OS version, VSIX filename, and any diagnostics observed.

## Release Checklist

- [ ] Working tree contains only intended release changes.
- [ ] `npm run compile` passes.
- [ ] `npm test` passes.
- [ ] `npm run package` produces `dist/overmind-vscode-extension.vsix`.
- [ ] VSIX contents exclude test fixtures and development-only output.
- [ ] Operator guide is included and matches the shipped behavior.
- [ ] Install flow is verified with `Extensions: Install from VSIX...`.
- [ ] macOS smoke test is recorded.
- [ ] Linux smoke test is recorded.
- [ ] Windows Remote WSL smoke test is recorded.
- [ ] Known limitations are documented for the release owner.

## Known Limitations

- Create project and create/continue feature remain visible terminal actions until accepted non-interactive shell-runtime contracts exist.
- Task-to-BR capture depends on the shared Overmind core command or bundled API being available to the extension runtime.
- Local Windows shell-script actions require VS Code Remote WSL or another Unix-like execution context.
