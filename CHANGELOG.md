# CHANGELOG

## v0.1.0 — alpha baseline (2026-07-22)

First versioned release of Overmind since its extraction from `yasdef` as a
standalone project. Overmind existed before this tag as a bash-script-and-
markdown proof of concept; this release marks its rebuild into a real
TypeScript + Skills application (an MVC-shaped coordinator).

### Highlights

- **Planning workflow**: epic/story in, through EARS requirements, technical
  requirements, implementation slices, prerequisite gaps, and an ordered
  implementation plan, to worker assignment.
- **TypeScript coordinator**: pipeline steps moved from bash scripts and
  markdown instructions to `asdlc-coordinator` skills and validators under
  `packages/asdlc-coordinator/`, installed via `overmind-installer`.
- **Project lifecycle**: `project create`, `project init`, `project reconcile`,
  and per-class (A/B/C) repo transition handling for planning against existing
  repositories.
- **Runner and checkpoints**: session-scoped runner config, checkpoint
  commits, and a feature orchestrator loop driving steps to completion.
- **`--version`/`-v`**: both `overmind` CLI entrypoints (the installer's `init`
  command and the operator-facing coordinator CLI) report the package version.

### Notes

- Package versions (`package.json` at the repo root and under `packages/*`)
  are kept in sync at this version; bump all of them together on release.
- No prior tagged releases exist; this is the baseline for future CHANGELOG
  entries.
