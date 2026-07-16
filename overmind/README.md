# Overmind Operator Guide

This is the durable guide for running Overmind: the complete lifecycle from an empty ASDLC workspace through project setup, feature planning, and worker handoff, with the commands, decisions, outputs, and recovery behavior for each stage.

This directory (`overmind/`) is the **source** of the runtime: templates, rules, golden examples, setup defaults, and the process map. `npm run setup` packages them into an **ASDLC workspace**, where you actually work. Editing files here changes what future installs receive; it does not change an already-installed workspace until you re-run setup against it.

## Which document to read

| You need | Read |
| --- | --- |
| What Overmind is, installation, the shortest path | [root `README.md`](../README.md) |
| How to operate the workflow — this guide | `overmind/README.md` |
| A command reminder inside an installed workspace | generated `quickrun.md` at the workspace root |
| The exact end-to-end sequence and phase boundaries | [`init_progress_definition_sequence_diagram.md`](init_progress_definition_sequence_diagram.md) |
| Normative operational and quality requirements, and how a model-driven step is invoked and validated | the packaged skill under `packages/installer/_data/skills/`, with its gate under `packages/asdlc-coordinator/src/validate/` |

## Workspace setup

**Purpose.** Create or update the ASDLC workspace that holds every project and artifact.

**Command.** `npm run setup` from this repository root, after `npm install` and `npm run build`.

**Input.** A workspace path at the prompt. A missing or empty directory is bootstrapped; a directory already containing `asdlc_metadata.yaml` is updated. A non-empty directory that is not a workspace is refused.

**Output.** `.overmind/overmind.js`, skills under `.codex/skills/` and `.claude/skills/`, `.templates/`, `.setup/`, `asdlc_metadata.yaml`, `projects/`, and `quickrun.md`.

**Notes.** The workspace itself is a plain directory and is not a git repository. Each project folder created under `projects/` *is* initialized as its own repository. All commands below run from the workspace root as `node .overmind/overmind.js …`.

Optional: to use a knowledge-base MCP source for stack guidance and placeholder enrichment, register it with your runner and declare it in `.setup/external_sources.yaml`.

---

## Project lifecycle

### Create the project

**Purpose.** Register a project and decide which classes it covers.

**Command.** `project create`

**Input.** Interactive: project name, project type, and class membership.

**Output.** `projects/<project-id>/` seeded with `init_progress_definition.yaml`, initialized as a git repository with a first commit.

**Decision.** Class membership. Selected classes start *deferred* under policy `A` with an empty repository path — planning may proceed for them without repository evidence.

### Adjust class membership

**Purpose.** Add a class that was missed, or reset a class that was bound to the wrong repository.

**Command.** `project add-class`

**Output.** The class is present as deferred with an empty path and policy `A`.

**Decision.** Resetting a class discards its current binding; rebinding runs through reconcile.

### Attach repositories and reconcile

**Purpose.** Bind existing repositories to classes and reality-check the project contract against the code that exists.

**Command.** `project reconcile [--path projects/<project-id>]` — with no `--path`, the single project is selected automatically, or you are asked to choose.

**Input.** A class policy per class and, for policy `B`/`C`, a valid repository path.

**Output.** Classes converted to *ready* with a bound path, and a reconciled `common_contract_definition.md`.

**Decision.** Policy per class: `A` keeps the class deferred and blueprint-backed; `B` declares an existing repository with partial context; `C` declares a code-first repository, where a layer present in the repository wins over the blueprint even when the two diverge, and the divergence is tagged rather than raised. Choosing `C` is a governance declaration and is honored as given.

**Checkpoint.** When a class first attaches, `common_contract_definition.md` has never been checked against real code. Reconcile diffs it against the as-built API and asks you to resolve the differences. This runs once per class attach; ongoing drift is not yet handled.

### Initialize the project — steps `1`–`2`

**Purpose.** Establish the baselines every feature plans against.

**Command.** `project init --path projects/<project-id>`

**Steps.**

- **`1` Initialize Repo ASDLC Metadata** — records project type, class membership, and deferred class metadata in `init_progress_definition.yaml`.
- **`1.1` Define Project Stack Blueprints And Agent Guidelines For Active Classes** *(type A only, per class)* — for each active `backend`, `frontend`, or `mobile` class, a stack-blueprint session followed by an agent-guidelines session, producing `project_stack_blueprint_<class>.md` and `project_agents_md_claude_md_<class>.md`.
- **`2` Create Cross-Repository Contract Definition For This Project** — produces project-level `common_contract_definition.md`. For type A projects this step waits until every active class has both step `1.1` artifacts.

**Checkpoint.** After step `1.1`, Overmind commits the stack baseline and asks `Continue with common contract definition? [Y/n]`. Yes or Enter continues into step `2` in the same invocation; no exits successfully with step `2` pending, and the same `project init` command resumes there later.

**Output.** A committed initialization baseline. Feature planning is unblocked once step `2` is complete.

---

## Feature planning lifecycle

Feature planning runs through one command:

```bash
node .overmind/overmind.js run --path projects/<project-id>
```

`run` first lists unfinished features and asks whether to start a new one or continue an existing one. It then evaluates progress from the artifacts on disk and continues from the next canonical step. It is the only feature-creation entrypoint.

**Before any feature work,** `run` refuses if a project-level prerequisite is pending, and names the command that owns it: `project init --path <project-path>` for incomplete initialization, or `project reconcile --path <project-path>` for a deferred policy `B`/`C` class that still needs a repository, or a ready class that has not been reconciled. Deferred policy `A` classes never block; scan-dependent steps simply skip them.

**Starting a new feature needs a clean project worktree.** Because a run commits the whole project folder at its checkpoints, beginning a new feature on top of uncommitted work would file the previous feature's artifacts under the new one. So `run` refuses to scaffold a new feature while the project worktree is dirty — before asking for the feature id and title — and names the uncommitted paths for you to commit or discard. Continuing or resuming an existing feature has no such requirement; its uncommitted work is its own.

### Intake and clarification — steps `3`–`4.2`

- **`3` Initialize and Enrich Business Requirements Structuring** — creates the feature folder and seeds `feature_br_summary.md`. **Your input:** save the epic or story into the feature folder as a `.txt` or `.md` file. A Jira ticket may be recorded as the source marker instead.
- **`4.1` Scan repo and apply task-to-BR update** — reads ready class repositories and folds the captured story into `feature_br_summary.md`. The repository scan runs only when at least one class is ready.
- **`4.2` Clarify BR and check EARS readiness** — resolves open questions against you and records them, then deterministically checks whether the feature is ready for EARS.

**Decision.** Step `4.2` is the main business conversation: answers here shape everything downstream. Unresolved items block the readiness transition until they are raised or resolved.

### Requirements — steps `5`–`5.1`

- **`5` Convert Business Requirements Structuring to EARS** — produces `requirements_ears.md` from the clarified summary.
- **`5.1` (optional) requirement_ears extra review** — an independent review pass that checks the EARS requirements against the clarified summary and the raw story, and records findings in `requirements_ears_review.md`. It may amend `requirements_ears.md`.

**Checkpoint.** `requirements_ears.md` is a required human review. Read it yourself before continuing.

### Contract and surface context — steps `6`–`7.1`

- **`6` Define Feature Contract Delta** — produces `feature_contract_delta.md`, the contract change this feature implies.
- **`7` Analyze Repos And Prepare Repo Execution Context** *(per class)* — one pass per class, producing `project_surface_struct_resp_map_<class>.md` for `backend`, `frontend`, or `mobile`.
- **`7.1` (optional) MCP placeholder enrichment** — fills surface-map placeholders from a configured knowledge-base source. Requires `.setup/external_sources.yaml` to declare one.

**Evidence.** Each surface row resolves through one source: repository scan, then in-flight sibling-feature promises, then the class blueprint, then a placeholder. Non-repository sources are tagged so the plan shows what rests on code and what rests on intent. Scans read the **committed default branch only** — a ready repository that is dirty or checked out elsewhere is refused with a `BLOCKED:` message telling you to merge or switch back.

### Technical planning — steps `8`–`8.4`

- **`8` Create Feature-Scoped Technical Requirements** — produces `technical_requirements.md` from the EARS requirements, the common contract, and the applicable surface maps.
- **`8.1` Create Implementation Slice Planning Artifact** — produces `implementation_slices.md`.
- **`8.2` Run Prerequisite Gap Trace** — produces `prerequisite_gaps.md`. Unmet prerequisites must reach zero before the plan is written.
- **`8.3` Create Shared Repository Implementation Plan** — produces `implementation_plan.md`, the assignable plan.
- **`8.4` (optional) implementation plan semantic review** — reviews the plan for semantic defects, asks which findings to apply, updates `implementation_plan.md`, and records decisions in `implementation_plan_semantic_review.md`.

**Terminal validation.** After the final `8.4` decision — accepted or declined — the run re-validates the whole feature before reporting plan completion. Every deterministic feature gate whose artifact exists runs again, including artifacts written many steps earlier and edited since; artifacts that do not exist, and gates whose phase condition does not hold (repository scanning with no ready class repository), are reported as skipped. All gates run even after one fails, so the report is complete. A failure blocks plan completion and the end-of-feature commit prompt, and names the earliest failing phase as the owning step:

```bash
node .overmind/overmind.js run --path projects/<project-id> --resume <owning-step>
```

That explicit resume reopens the cached feature even though its artifacts otherwise read as complete. If the project also holds unfinished features, the run offers both and you choose, since a terminal failure is not recorded anywhere it could be inferred from. Nothing is repaired or retried automatically.

**Checking a feature yourself.** The same chain is available standalone:

```bash
node .overmind/overmind.js gate all projects/<project-id>/<feature-folder>
```

It prints one row per gate with its artifact and class, ends with passed/failed/skipped counts, and exits `0`, `1`, or `2` on the same contract as every other command. It validates the applicable artifacts that **exist**; it does not establish that every required artifact is present. Required-artifact completeness stays owned by feature-flow sequencing and is visible through `status`.

**Commit prompt.** Once validation passes, the run asks `Commit completed feature work? [Y/n]` and, on yes, commits the project worktree. Every way a feature finishes reaches this one prompt — an accepted `8.4` or a declined `8.4` — and it is asked once per run. Declining leaves the planning artifacts on disk and uncommitted, which is a supported answer: the work is yours to commit or discard, and `run` will not let you start a *new* feature until you do. A clean worktree is reported rather than asked about, and a commit that cannot be made — no git, no worktree, a failing stage or commit — is reported without changing the run's outcome.

**Checkpoint.** `implementation_plan.md` is the second required human review and the last point before work leaves Overmind. Read it in full. To change either planning artifact, point your usual coding agent at the file; the next run picks up your edits.

---

## Worker handoff

Overmind's output is an assigned plan. Implementation happens outside the system, and worker results are not fed back into planning.

### Register a worker

**Purpose.** Make a worker available for assignment.

**Command.** `worker register --path projects/<project-id>` — one invocation per worker.

**Input.** Exactly one class: `backend`, `frontend`, `mobile`, or `infrastructure`.

**Output.** An active worker record in `projects/<project-id>/workers.yaml`, including the worker UUID. Give that UUID to the developer responsible for the worker so they can complete registration on their side.

### Assign the plan

**Purpose.** Attach an owner to every step of a reviewed plan.

**Command.** `worker assign --feature-path projects/<project-id>/<feature-folder>`

**Input.** An assignment-ready `implementation_plan.md`. The feature path must be an existing directory inside `projects/` that contains `feature_br_summary.md`.

**Output.** Every plan step carries an `#### Assigned:` value: a worker UUID, a marker that no active worker exists for that class, or a hold because a cross-feature dependency is not yet complete and merged.

**Decision.** When several workers of a class are active, you choose which one takes the step. Holds are re-evaluated on every run, so re-run assignment after dependencies merge.

**Cross-feature dependencies.** A feature becomes a promise to other features as soon as it holds an `implementation_plan.md`, and a `#### Depends on:` entry containing `/` points at another feature's step. A feature folder that is abandoned but not deleted keeps emitting promises and holds its dependents indefinitely — delete the folder to release them.

---

## Command reference

Run from the ASDLC workspace root as `node .overmind/overmind.js <command>`.

```text
project create
project add-class
project reconcile [--path projects/<project-id>]
project init --path projects/<project-id>
run [--path projects/<project-id>] [--resume <step>]
status projects/<project-id>[/<feature-folder>]
gate all projects/<project-id>/<feature-folder>
worker register --path projects/<project-id>
worker assign --feature-path projects/<project-id>/<feature-folder>
```

`status` is read-only and accepts either a project or a feature path. `gate all` is the read-only terminal validation chain described under technical planning. The workflow also exposes `capture`, `context`, individual `gate <step>`, `sync`, and `readiness` verbs; these are invoked by the packaged skills during a run and are not part of the operator path.

## Recovery

Every command reports one of three outcomes:

| Exit | Meaning | What to do |
| --- | --- | --- |
| `0` | Success, or a clean operator-requested stop | Continue; `run` again to proceed |
| `1` | Recoverable — an artifact failed validation, or a prerequisite is pending | Read the diagnostics, fix the named artifact or run the named command, then re-run or resume the same step |
| `2` | Blocking — validation or the runtime could not execute at all | Resolve the configuration or runtime problem, or escalate; re-running unchanged will not help |

**How to recover.** A failing run prints the exact resume command, including the step that owns the failure:

```bash
node .overmind/overmind.js run --path projects/<project-id> --resume <step>
```

Use `status` to see where a project or feature currently stands before deciding. Progress is derived from the artifacts on disk, not from a separate state file, so repairing an artifact and re-running is always a valid recovery.

Overmind never edits model-owned artifacts to repair them and never retries automatically. Optional review steps (`5.1`, `8.4`) re-verify their artifacts after the review session returns; a failure there fails the step within that run and is repaired by re-running or resuming the review session. The terminal chain applies the same contract at the end of planning: exit `1` for a recoverable artifact defect, exit `2` when a gate or the runtime could not execute, and in both cases the named owning step is the one to resume.

## Outputs and where the details live

Project-level artifacts, in `projects/<project-id>/`:

| Artifact | Produced by | Detailed rules |
| --- | --- | --- |
| `init_progress_definition.yaml` | `project create`, step `1` | [`init_progress_definition_data_model.md`](init_progress_definition_data_model.md) |
| `project_stack_blueprint_<class>.md` | step `1.1` | packaged skill `overmind-stack-blueprint` |
| `project_agents_md_claude_md_<class>.md` | step `1.1` | packaged skill `overmind-agents-md` |
| `common_contract_definition.md` | step `2`, `project reconcile` | packaged skill `overmind-common-contract` |
| `workers.yaml` | `worker register` | — |

Feature-level artifacts, in `projects/<project-id>/<feature-folder>/`:

| Artifact | Produced by |
| --- | --- |
| `user_br_input.md`, `feature_br_summary.md` | steps `3`–`4.2` (packaged skill `overmind-task-to-br`) |
| `requirements_ears.md`, `requirements_ears_review.md` | steps `5`, `5.1` |
| `feature_contract_delta.md` | step `6` |
| `project_surface_struct_resp_map_<class>.md` | steps `7`, `7.1` |
| `technical_requirements.md`, `implementation_slices.md`, `prerequisite_gaps.md` | steps `8`–`8.2` |
| `implementation_plan.md`, `implementation_plan_semantic_review.md` | steps `8.3`, `8.4` |

For anything more exact than the operator-visible behavior above — literal artifact fields, validation algorithms, and repair procedures — the owning packaged skill under `packages/installer/_data/skills/` and the coordinator's gate implementations are authoritative. The step sequence itself is defined in `packages/asdlc-coordinator/src/sequencing/step-catalog.ts` and mapped in [`init_progress_definition_sequence_diagram.md`](init_progress_definition_sequence_diagram.md).
