# Overmind npm Publishing Guide

Recorded 2026-07-11. How to distribute Overmind through npm so operators bootstrap workspaces
with `npx` instead of cloning and building `yasdef-overmind`. This is a future-work guide, not a
committed change; when picked up, it becomes one OpenSpec change.

## Target operator UX

```bash
npx @yasdef/overmind init        # no clone, no build — Node is the only prereq
ASDLC workspace path: ~/asdlc
```

- The published tarball ships prebuilt `dist/` and the full `_data/` payload; users never build.
- Updating a workspace = `npx @yasdef/overmind@latest init`, answer the same path; the
  `crp-156-interactive-init-target` update branch refreshes package-owned payload and preserves
  operator-owned files.
- The interactive prompt works under `npx` (TTY stdin). Headless/CI installs stay unsupported
  until a target argument is explicitly requested.

## Current state (why this is ~80% ready)

- `packages/installer` already has `bin: { "overmind": "dist/src/bin/overmind.js" }` and owns its
  complete support-asset payload under `packages/installer/_data/` (skills, templates, setup).
- Payload completeness is already enforced at install time by required-source validation, which
  doubles as a tarball sanity check.
- The one publish-blocking coupling: `installProject` resolves the runtime bundle through the
  `asdlc-coordinator` workspace dependency (`getBundledOvermindPath()`), so the installer package
  is not self-contained.

## Decisions

1. **Publish one self-contained package, not two.** At build/`prepack` time copy the coordinator
   bundle `overmind.js` into `packages/installer/_data/cli/` and drop the installer's runtime
   dependency on `asdlc-coordinator`. One published artifact, no installer/bundle version skew,
   consistent with the single-file-runtime philosophy. `asdlc-coordinator` and
   `vscode-extension` stay `private: true`.
2. **Scoped public name.** Plan on `@yasdef/overmind` with `publishConfig.access: public`; the
   bare `overmind` name is assumed taken on npm.
3. **`_data/` is the canonical, final source of packaged assets.** Publishing freezes the already
   -true convention that `packages/installer/_data/skills/` (plus templates and setup) is the
   source the tarball is built from.
4. **Publishing gets one tag-triggered CI workflow; development stays CI-free.** The engineering
   baseline (`design_docs/e2e_orchestrator_migration/03_target_architecture.md ## Engineering
   baseline`) is local verification with no remote CI. Publishing is the one act where that is
   risky: a broken publish is public and immutable. A `v*`-tag GitHub Actions workflow running
   `npm ci && npm run verify && npm publish --provenance` (npm OIDC trusted publishing, no stored
   token) is the sole remote gate. Alternative — fully local `npm publish` after
   `npm run verify` — is acceptable but loses provenance and leaves a long-lived token on one
   machine; rejected as the default for a tool that installs executable payloads.
5. **Version stamping lands with the publish change.** Write the installer version into the
   workspace during init (workspace metadata or `quickrun.md`) so updates can report
   `updating <old> → <new>`. Cheap alongside publishing, not needed before it.
6. **No repo restructuring.** npm workspaces layout stays as is; only `packages/installer`
   manifest and build wiring change.

## Step-by-step plan

1. **Self-containment:** add a `prepack`/build step copying
   `packages/asdlc-coordinator/dist/overmind.js` into `packages/installer/_data/cli/`; point
   `installCli` at the payload copy; remove `asdlc-coordinator` from installer `dependencies`;
   keep required-source validation covering the new payload entry.
2. **Publish metadata on `packages/installer/package.json`:** rename to `@yasdef/overmind`,
   remove `private: true`, add `files: ["dist", "_data"]`, `license` (+ LICENSE file),
   `repository`, `publishConfig.access: public`; keep the `engines` Node floor.
3. **`prepublishOnly` guard:** build + verify + payload validation so an incomplete tarball
   cannot be published.
4. **Publish workflow:** GitHub Actions on `v*` tags — `npm ci`, `npm run verify`,
   `npm publish --provenance` via OIDC trusted publishing. Configure the trusted publisher on
   npmjs.com; store no token.
5. **Version stamping:** stamp installer version into the workspace at init; report
   install-vs-update with versions in the bin output.
6. **Docs:** update `README.md`/`QUICKRUN.md` to lead with `npx @yasdef/overmind init`; the
   clone-and-build flow remains only as the contributor/development path.
7. **Release:** `npm version <bump>`, push the tag, verify the published tarball with
   `npm pack --dry-run` beforehand and a scratch `npx` install afterwards.

## Prerequisites

- `crp-156-interactive-init-target` landed (interactive target selection is the entry point npm
  distribution relies on).
- npm org/scope for `@yasdef` and a public GitHub repo if provenance is used.
