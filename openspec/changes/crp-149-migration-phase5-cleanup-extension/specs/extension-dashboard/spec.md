## ADDED Requirements

### Requirement: The coordinator exposes workspace and sequencing as dedicated package subpath exports

`asdlc-coordinator` today exports only `.`, whose root barrel (`src/index.ts`) re-exports `cli/` and `orchestrator/`; any import from the package root therefore pulls the whole barrel, making zero-coupling consumption impossible. This change SHALL add dedicated package subpath exports — at least `asdlc-coordinator/workspace` and `asdlc-coordinator/sequencing` — resolving to modules whose transitive imports do not include `cli/` or `orchestrator/`, so a consumer can import the reusable core without loading the CLI or orchestrator. The root `.` export MAY continue to re-export everything for existing consumers.

#### Scenario: Subpath exports resolve without pulling cli/orchestrator
- **WHEN** a consumer imports `asdlc-coordinator/workspace` or `asdlc-coordinator/sequencing`
- **THEN** the resolved module and its transitive imports include no `cli/` or `orchestrator/` module, and the `exports` map in `asdlc-coordinator/package.json` declares both subpaths with their type and default targets

### Requirement: The extension consumes the reusable core in-process with zero orchestrator coupling

The `packages/vscode-extension` dashboard SHALL obtain its project, feature, and progress data by importing the dedicated `asdlc-coordinator/workspace` and `asdlc-coordinator/sequencing` subpaths and calling them in process. It SHALL NOT import the root `asdlc-coordinator` barrel, nor import, spawn, or otherwise depend on `orchestrator/`, `cli/`, or any `overmind` CLI entrypoint, and its only runtime package dependency SHALL remain `asdlc-coordinator`.

#### Scenario: Dashboard reads progress without the CLI
- **WHEN** the dashboard needs a project's step progress
- **THEN** it calls the `asdlc-coordinator/sequencing` computation over workspace-resolved inputs and renders the result without invoking `overmind run`, `overmind status`, or any child process

#### Scenario: No orchestrator or CLI coupling
- **WHEN** the extension package is built
- **THEN** its source imports resolve only through the `asdlc-coordinator/workspace` and `asdlc-coordinator/sequencing` subpaths, reference neither the root barrel nor any `orchestrator/`/`cli/` module, and its manifest lists `asdlc-coordinator` as the sole runtime dependency — proven by a test that inspects the extension's import specifiers

### Requirement: The extension contributes a minimal read-only dashboard view

The extension SHALL activate and contribute a minimal read-only dashboard surface (a contributed view) that renders the projected `FeatureSummary` for discovered projects/features. The surface SHALL be read-only — it SHALL contribute no command, form, or terminal that mutates workspace state or launches a model session — and its rendered content SHALL be produced from the projection read model, not from an independent scan. A full extension-host end-to-end harness is out of scope; the render/provider path SHALL instead be exercised by an in-process test (see the read-model-is-proven-by-tests requirement).

#### Scenario: A read-only view renders the projected summary
- **WHEN** the extension activates in a workspace containing a resolvable project/feature
- **THEN** it contributes a read-only view whose rendered content is built from the `FeatureSummary` projection (readiness, completed/total steps, missing artifacts) with no mutating command, form, or terminal

#### Scenario: The view surfaces diagnostics without crashing
- **WHEN** the underlying `ProgressReport` carries diagnostics
- **THEN** the contributed view renders the degraded summary and surfaces those diagnostics rather than failing to activate or throwing

### Requirement: The extension manifest is a valid VS Code extension manifest

The `packages/vscode-extension/package.json` SHALL be a valid VS Code extension manifest, not merely a TypeScript library manifest. It SHALL declare the fields VS Code requires and this dashboard uses: `publisher`, `engines.vscode`, a `main` entrypoint whose module exports an `activate` function, `contributes` declaring the read-only dashboard view, and `activationEvents` (or an equivalent implicit activation) covering that view. A test SHALL validate the manifest and the activation entrypoint so `npm run verify` fails if any required field, the contributed view, or the exported `activate` is missing. Because a full extension-host launch is out of scope and a real entrypoint imports the host-provided `vscode` module (unavailable in the repository's plain-Node test process), the entrypoint check SHALL NOT execute a bare `import` of the real `main` module. It SHALL instead either inspect the compiled entrypoint statically for the exported `activate`, or load it with the `vscode` host module mocked/stubbed; an extension-development-host test is an acceptable alternative but not required.

#### Scenario: Required manifest metadata is present and validated
- **WHEN** the manifest validation test runs
- **THEN** it asserts `publisher`, `engines.vscode`, `main`, the contributed dashboard view under `contributes`, and `activationEvents` are all present and internally consistent, failing `npm run verify` if any is missing

#### Scenario: The activation entrypoint is checked without a real host
- **WHEN** the validation test verifies the `main` module exports `activate`
- **THEN** it does so by static inspection of the compiled entrypoint or by loading it with the `vscode` module mocked — never by importing the real host `vscode` in plain Node — so the check passes in the repository test process and a non-activating entrypoint still fails

#### Scenario: The extension keeps host access out of the pure read model
- **WHEN** the read model and projection are tested
- **THEN** they are exercised without importing `vscode`, because the `vscode`-dependent activation/view layer is separated from the host-free read model that reuses `asdlc-coordinator/sequencing`

### Requirement: The dashboard reuses the existing sequencing projection

The dashboard read model SHALL obtain the extension `FeatureSummary` (`readiness`, `completedSteps`, `totalSteps`, `missingArtifacts`, per `design_docs/overmind_vscode_extention/technical_requirements.md ## 7. Dashboard Data Contract`) by calling the existing `sequencing/toFeatureSummary(report)` export in `asdlc-coordinator`. The extension SHALL NOT define or maintain its own `ProgressReport → FeatureSummary` mapping, and SHALL add no independent step scan, definition parse, or filesystem walk beyond what `workspace/` and `sequencing/` already provide.

#### Scenario: FeatureSummary comes from the canonical projection
- **WHEN** the read model needs a feature's `FeatureSummary`
- **THEN** it calls `sequencing/toFeatureSummary` on the `ProgressReport` from `sequencing/` rather than computing its own summary, so there is exactly one projection of record

#### Scenario: No duplicate projection is introduced
- **WHEN** the extension source is reviewed
- **THEN** it contains no second implementation of the `readiness`/`completedSteps`/`totalSteps`/`missingArtifacts` derivation that could drift from `toFeatureSummary`

#### Scenario: Projection is total over declared steps
- **WHEN** the `ProgressReport` declares every step from `init_progress_definition.yaml` with per-step state
- **THEN** the reused projection yields `totalSteps` equal to the declared step count and `completedSteps` counting exactly the steps marked complete, with no joined or omitted steps

### Requirement: The dashboard renders degraded state from diagnostics instead of throwing

When the underlying `ProgressReport` carries `Diagnostic` values for malformed or missing inputs, the dashboard SHALL render a degraded but non-crashing view that surfaces those diagnostics. It SHALL NOT throw for data-level problems that `sequencing/` already reports as diagnostics.

#### Scenario: Malformed inputs yield a diagnostic view
- **WHEN** the `ProgressReport` has degraded step states and a populated `diagnostics` list
- **THEN** the dashboard read model returns a result carrying those diagnostics and a still-renderable `FeatureSummary` rather than raising

### Requirement: The dashboard read model is proven by tests in this change

This change SHALL add tests in `packages/vscode-extension` that exercise the read model against representative `ProgressReport` inputs, asserting the `FeatureSummary` projection, the total-over-declared-steps property, the diagnostic-carrying degraded path, and the view/provider render path — validating reuse claim 5 of `04_migration_plan.md ## Definition of done (whole effort)` in code rather than in prose. The tests SHALL run in-process (no extension-host launch) so `npm run verify` stays self-contained.

#### Scenario: Reuse claim is validated by a passing test
- **WHEN** `npm run verify` runs
- **THEN** the extension package's tests build against `asdlc-coordinator` and pass, proving the `FeatureSummary` contract is derivable from `ProgressReport` by projection with no orchestrator-CLI dependency

#### Scenario: The view render path is covered
- **WHEN** the read-model test suite runs
- **THEN** it exercises the contributed view's render/provider path against a `ProgressReport`-backed input and asserts the rendered read-only content reflects the projected summary and any diagnostics
