# Overmind

Overmind is a planning coordinator for AI-assisted development. It takes an epic or story and drives it through a structured workflow into two reviewed planning artifacts — `requirements_ears.md` and `implementation_plan.md` — then assigns the resulting plan steps to registered workers.

Overmind plans and assigns work. It does not execute implementation, and it does not yet consume worker feedback to revise plans.

> ⚠️ **Pre-alpha.** Interfaces, artifacts, and workflow steps change without notice, and things may break. Take precautions before pointing it at a repository you care about.

Current version: **v0.1.0** — see [`CHANGELOG.md`](CHANGELOG.md) for release notes.

- **Operator guide:** [`overmind/README.md`](overmind/README.md) — the complete workflow, commands, checkpoints, and recovery.
- **Process map:** [`overmind/init_progress_definition_sequence_diagram.md`](overmind/init_progress_definition_sequence_diagram.md) — canonical end-to-end sequence.

## Install

```bash
git clone <this-repo>
cd yasdef-overmind
npm install
npm run build
npm run setup
```

`npm run setup` prompts for an **ASDLC workspace path** — a directory outside this repository where your projects, features, and planning artifacts live. A missing or empty path is bootstrapped; an existing workspace containing `asdlc_metadata.yaml` is updated in place.

The workspace receives the bundled CLI at `.overmind/overmind.js`, Overmind skills under `.codex/skills/` and `.claude/skills/`, runtime templates, setup defaults, `asdlc_metadata.yaml`, `projects/`, and a generated `quickrun.md` command cheat sheet.

## First feature

Run these from the ASDLC workspace root. See [`overmind/README.md`](overmind/README.md) for what each stage does and what it asks you.

```bash
node .overmind/overmind.js project create
node .overmind/overmind.js project init --path projects/<project-id>
node .overmind/overmind.js run --path projects/<project-id>
node .overmind/overmind.js worker register --path projects/<project-id>
node .overmind/overmind.js worker assign --feature-path projects/<project-id>/<feature-folder>
```

`run` is the single feature entrypoint: it creates the feature, asks you to supply the epic or story as a `.txt` or `.md` file in the feature folder, and walks the planning workflow through to the implementation plan.

Planning against **existing** repositories takes one more step — `project reconcile --path projects/<project-id>` binds each class to its repository before feature work begins.

## Lifecycle

1. **Workspace** — one ASDLC workspace holds all projects and their artifacts.
2. **Project** — a project declares its classes (`backend`, `frontend`, `mobile`, `infrastructure`) and, once initialized, carries a stack baseline and a cross-repository contract definition.
3. **Feature planning** — each feature runs from raw story through clarified business requirements, EARS requirements, contract and surface context, technical requirements, slices, and prerequisite gaps into an implementation plan.
4. **Worker handoff** — registered workers are assigned to plan steps by class. Implementation itself happens outside Overmind.

### Review these yourself

Two artifacts decide the quality of everything downstream, and neither should be accepted on trust:

- **`requirements_ears.md`** — what the feature must do.
- **`implementation_plan.md`** — how it will be built and in what order.

Read both before handing work to anyone. To change them, point your usual coding agent at the file and ask for the edit; the workflow picks up your changes on the next run.

## Concepts that affect your choices

**Classes and repository attachment.** Each class is tracked independently. A class starts *deferred* with no repository under policy `A`, meaning planning proceeds without repository evidence for that class. Attaching an existing repository moves the class to *ready* under policy `B` (partial context) or `C` (code-first context), after which planning scans it. Classes transition on their own timeline — a project can be part blueprint-backed and part repo-backed.

**Where evidence comes from.** For each surface a feature touches, Overmind resolves one source per row:

```
repo scan → in-flight feature promises → blueprint (planned) → placeholder
```

Non-repository sources are tagged, so a plan always shows which parts rest on committed code and which rest on intent.

**Planning reads the default branch only.** Worker branches and uncommitted edits are invisible to planning. Accepted work must be merged to the default branch before the next feature plans against it, and a ready repository that is dirty or off its default branch is refused before scanning.

**Features can depend on each other.** A feature becomes a promise to other features as soon as it has an `implementation_plan.md`. Steps depending on unfinished cross-feature work are held during assignment and re-evaluated on every run.

## Commands

| Command | Purpose |
| --- | --- |
| `project create` | Create a project, its folder, and its class membership |
| `project add-class` | Add a missing class, or reset a class to deferred policy `A` |
| `project reconcile [--path <project>]` | Set class policy, attach repositories, reconcile the contract |
| `project init --path <project>` | Run project initialization to the contract baseline |
| `run [--path <project>] [--resume <step>]` | Create or continue feature planning |
| `status <project[/feature]>` | Read-only progress for a project or feature |
| `gate all <feature>` | Re-validate every applicable existing feature artifact |
| `worker register --path <project>` | Register one worker of one class |
| `worker assign --feature-path <feature>` | Assign plan steps to active workers |

Plan completion runs `gate all` for you: a run reports a finished plan only when every applicable feature artifact still passes its deterministic gate, and a failure names the earliest owning step to resume from. Standalone, `gate all` checks the applicable artifacts that exist and does not by itself prove that every required artifact is present — that remains part of the run's own sequencing, visible through `status`.

All are invoked as `node .overmind/overmind.js <command>` from the workspace root. Full input and output detail is in [`overmind/README.md`](overmind/README.md); the installed workspace also carries a generated `quickrun.md`.

## Current limitations

- Work cannot be distributed across several workers of the same class — when more than one is active you pick one per step, rather than having the plan split between them.
- No worker-feedback ingestion; plans are not revised from implementation outcomes.
- Policy `B` interactive divergence review is not yet enforced.
- Epics and stories are supplied as local `.txt`/`.md` files; Jira capture records a ticket marker but issue-tracker ingestion is not the primary path.
- Workspace artifacts live only on the local filesystem; there is no built-in artifact versioning flow.

## Contributing

```bash
npm test
npm run verify
```

Optional: an MCP knowledge-base source can supply stack guidance for type A projects and enrich surface-map placeholders. Register the MCP with your runner, then declare it in the workspace `.setup/external_sources.yaml`:

```yaml
sources:
  - name: yasdef-knowledge-kb
    type: stack_knowledge_base
    description: Approved stack blueprints, architecture references, and project bootstrap conventions
```

Repository conventions live in [`AGENTS.md`](AGENTS.md). Normative workflow and quality rules live in the packaged skills under `packages/installer/_data/skills/`, alongside the gate implementations in `packages/asdlc-coordinator/src/validate/`.
