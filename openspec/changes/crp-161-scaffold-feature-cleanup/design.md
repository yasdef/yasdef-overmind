## Context

Feature creation has two invocation surfaces over one implementation. `scaffoldFeature()` in `packages/asdlc-coordinator/src/capture/scaffold-feature.ts` is the deterministic capture primitive: it resolves the project, enforces the pending init/reconciliation checkpoint gate, collects feature ID and title through the interaction port, and renders `feature_br_summary.md`, returning the created path as a typed result. Two callers reach it:

- `overmind run` — `runFeatureFlow` dispatches catalog step `3` through the executor's deterministic action registry when the operator selects "Start a new feature", then persists `.overmind_feature_state.json` and continues into the feature phase loop (steps `4.1` onward).
- `overmind scaffold feature --path <project>` — `runScaffold` in `packages/asdlc-coordinator/src/cli/run.ts` calls the same primitive with a TTY interaction port, prints the created path, and exits.

The standalone verb is the weaker of the two: it performs the same write, skips the feature-state cache, and stops. Feature discovery scans the project directory rather than trusting that cache, so a feature created either way is still offered under "Continue an existing unfinished feature" — the verb's only distinct effect is leaving the operator at a shell prompt mid-flow.

Three forces converge on removing it. The migration docs (`03_target_architecture.md`, `02_responsibility_translation_map.md`) retained the verb "for standalone and extension-form use", and `requirements_ears.md` put it on the extension's shipped-verb allow-list. But the shipped verb parses only `--path` and rejects unknown arguments, so `featureId` and `featureTitle` — which `ScaffoldFeatureDeps` accepts as options — are reachable only through interactive prompts. A webview form cannot drive it. The verb therefore does not serve the consumer it was kept for. Separately, the generated `quickrun.md` happy path sequences `scaffold feature` before `run`, and `run` then asks "1. Start a new feature / 2. Continue an existing unfinished feature"; answering `1` — the intuitive answer for a new feature — scaffolds a second, empty feature folder. The documented path is a trap.

## Goals / Non-Goals

**Goals:**

- One feature-creation entrypoint: `overmind run`.
- Remove the `scaffold` CLI verb, its handler, and its usage-string entry, so the removed verb is rejected as an unknown command rather than silently accepted.
- Preserve `scaffoldFeature()` and every behavior it owns, above all the `crp-160` pending init/reconciliation checkpoint gate — refuse before requesting feature input, write nothing, and name the owning command.
- Give the VS Code extension a feature-creation surface it can actually drive from a form: the coordinator primitive, imported in-process.
- Make the generated `quickrun.md` describe a path that cannot produce a duplicate empty feature folder.

**Non-Goals:**

- Adding `--feature-id` / `--title` (or any other) CLI flags. This change removes a surface; it does not grow one.
- Changing `scaffoldFeature()`'s inputs, its typed result, its rendered feature output, or the step `3` catalog action and its registry dispatch. (The pending-checkpoint classification is completed to inspect the applicable step `1.1` paths so it enforces the interrupted init-only checkpoint the spec requires; the gate's observable refusal contract is otherwise unchanged.)
- Changing feature discovery, `.overmind_feature_state.json`, or the feature-selection prompts.
- Building the VS Code extension. This change fixes the docs' stated integration contract; it ships no extension code.

## Decisions

**Delete the verb rather than fix it.** The alternative — keep `scaffold feature` and add `--feature-id` / `--title` so it becomes non-interactive and form-drivable — was rejected. It preserves two ways to create a feature, which is the source of the `quickrun.md` trap, and it adds CLI flags, which the repository's working rules forbid absent an explicit request. The verb has no operator use case that `run` does not already cover: `run` scaffolds, caches the selection, and continues into the phase loop, while the verb stops after the write.

**The extension imports the primitive; it does not shell out.** The allow-list in `requirements_ears.md` exists to bound what the extension may execute as a subprocess, which is the right shape for `overmind status` (read-only) and `overmind run` (terminal-hosted, long-lived, interactive). Feature creation is neither: it is a single deterministic write with typed inputs and a typed result. The extension and the coordinator are TypeScript in the same npm workspace, so `import { scaffoldFeature } from "asdlc-coordinator"` gives the webview form direct access to `featureId` / `featureTitle` and the typed `featurePath` back — no TTY, no argument parsing, no stdout scraping. The process boundary bought nothing and cost the form its inputs. The allow-list narrows to `overmind status` and `overmind run`.

**The checkpoint gate keeps its boundary and contract; its classification is completed.** `crp-160` specified the pending init/reconciliation refusal (and required the classifier to combine the applicable step `1.1` paths) in terms of "the operator invokes `scaffold feature`". The gate lives inside `scaffoldFeature()`, not the CLI handler, so it survives verb removal and now fires at the step `3` boundary reached through `run`. Its observable contract — refuse before requesting feature ID or title, create no feature directory, name the exact `project init` or `project reconcile` command — is restated against the `run` trigger in this change's spec. The shipped classifier inspected only the shared project-definition files, so it missed the interrupted init-only checkpoint for type A step `1.1` artifacts; this change completes it to inspect the resolved initial-baseline paths (`resolveProjectInitOwnership().initialBaselinePaths`) — refusing when an applicable step `1.1` artifact exists without a finalized checkpoint — matching the `crp-160` contract and this change's spec scenario. No other gate behavior changes.

**Removal is scoped to the CLI adapter layer.** `runScaffold` is the only deletion in `cli/run.ts` beyond the two lines that dispatch and advertise it. The adapter overrides it consumed (`interaction`, `clock`, `projectGit`) remain in `CliAdapterOverrides` because `run` and `project init` still use them; only imports left with no remaining consumer are dropped. `scaffold-feature.test.ts` drives the primitive directly and gains only guard assertions that its diagnostics never name the removed verb; the two CLI-verb tests in `cli-run.test.ts` ("scaffold requires --path", "standalone scaffold dispatch creates a feature and exits zero") are removed, and an unknown-command assertion covers the removed verb.

## Risks / Trade-offs

**Operators or scripts calling `overmind scaffold feature` break with no fallback.** → This is the intended breaking change, and the blast radius is small: the verb is interactive-only, so it cannot appear in unattended automation. The failure is a loud unknown-command usage error naming the supported verbs, not a silent misbehavior. The generated `quickrun.md` — the one place that taught the command — is updated in the same change, and the `run` flow it points to covers the use case.

**Losing "create the feature folder and stop" as a distinct capability.** → No consumer needs it. The extension needs the primitive (which it gets, in a form it can actually call); the operator needs a feature they can work on, which `run` delivers. Batch pre-creation of several features was never supported anyway: the verb prompts interactively for each one.

**`crp-160`'s scaffold-gate scenarios are stated against a command that will no longer exist.** → Left alone, the archived spec would describe a trigger with no surface. This change's spec restates the gate scenarios against the `run` step `3` boundary, so the requirement stays covered by a live trigger and the tests that enforce it keep a home.
