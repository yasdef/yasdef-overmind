# Overmind: Distribution & Update Model

Brief reference for **what we ship and how it updates**, for the TypeScript skills + VS Code extension product (Approach A: one shared core CLI). See `design_docs/to_skills_migration/migration_to_skill_architecture_overview.md` for the architecture and `technical_requirements.md` for the extension itself.

## What we ship

One monorepo, one version, built into a few artifacts. The shared core (`asdlc-coordinator`) is **compiled once and bundled into two outputs**:

```
SOURCE                                  BUILD OUTPUTS
packages/asdlc-coordinator/  ─compile─► (internal lib; not shipped alone)
                                 ├─bundle─► overmind-gate.js   (fat file: launcher + core)
packages/vscode-extension/   ─bundle────► overmind.vsix        (extension + core bundled in)
skills/overmind-*/           ─copy──────►   (carried as payload inside .vsix and the CLI)
packages/installer/          ─bundle────► overmind CLI         (optional headless channel)
```

- `asdlc-coordinator` is never published or installed on its own; it exists only bundled inside the `.vsix` and inside `overmind-gate.js`. Same source + version → both copies stay in sync.

## How we distribute

| Channel | Artifact | For |
|---|---|---|
| VS Code Marketplace | `overmind.vsix` (extension + core + skills payload + `overmind-gate.js`) | GUI users — one install gets everything |
| npm (optional) | `overmind` CLI (installer + skills payload + `overmind-gate.js`) | headless / no-extension users |

Both channels embed the skills folder and a copy of `overmind-gate.js`, so either can provision a project.

## What lands in a user's project (`overmind init`)

Triggered by an extension button or the CLI, init copies the payload into the user's ASDLC workspace:

```
<user-project>/
  .claude/skills/overmind-<step>/{SKILL.md, assets}   ┐ same skill fanned into
  .codex/ · .github/ · .agents/ skills/overmind-<step>/┘ each runner layout
  .overmind/overmind-gate.js                           ← the one bundled gate CLI
```

Skills are markdown + assets; every skill shells the single `overmind-gate.js`.

## Where the core runs

- **Extension** imports the bundled core **in-process** (readiness panel, `overmind run` orchestrator) — no shelling out.
- **Agent/skills** use the core via the **CLI**: `node .overmind/overmind-gate.js <step> <path>`.
- Both are the same version (one build), so there is no extension-vs-CLI drift.

## How we update

- **GUI:** VS Code auto-updates the extension from the Marketplace → new `.vsix` (new core + skills + gate). The extension compares its bundled version with the project's `.overmind/overmind-gate.js --version`; on mismatch it offers **"update workspace"**, which re-runs init to refresh the in-project gate + skill files.
- **CLI:** `npx overmind@latest init` re-drops the new gate + skills.

**One coordination point:** right after an extension update the in-project gate is briefly stale until init re-runs — the extension detects the version mismatch and prompts to refresh. Everything traces to one monorepo version.
