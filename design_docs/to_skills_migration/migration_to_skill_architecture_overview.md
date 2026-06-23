# Overmind → Skills Migration: Architecture Overview

Migrate the Overmind init/feature pipeline from **md (rule) + sh (orchestrator) + sh (helper)** to **agent skills backed by a TypeScript core**.

**End state:** source is **`.ts` + `.md`**; data/config may be **`.yaml`/`.json`** — no `.sh`, no Python. Clean break, no backward compatibility: bash (incl. `tests/ai_scripts/*.sh`) is deleted, not deprecated, one step at a time. "Step by step" keeps the repo testable through the move, not old behavior alive.

Refs: `overmind/init_progress_definition_sequence_diagram.md` (step order/gating), `.codex/skills/overmind-step-architecture/SKILL.md` (current split), `design_docs/overmind_vscode_extention/technical_requirements.md` (TS extension).

---

## 1. Tech Stack — TypeScript on plain Node

| Layer | Choice |
|---|---|
| Skill body | Markdown `SKILL.md` — the model is the orchestrator; logic in prose |
| Capture/context/gates | TS `asdlc-coordinator` → `overmind capture/context/gate <step> ...` CLI; capture writes deterministic step input artifacts, gate keeps `0/1/2` exit contract (replaces `check_*_quality.sh`) |
| Parsing / paths / readiness | TS `asdlc-coordinator` modules (replaces `awk` + `common_libs`) |
| Installer + sequencing | TS (replaces `project_setup_first_init_machine.sh` + scanner/orchestrators) |
| Runtime | Node — assumed present via the extension |

**Why TS, not Python:** the VS Code extension already needs a TS parser/readiness engine over the *same* artifacts. TS → that logic lives once in `asdlc-coordinator`, shared by gates + extension; Python → two parsers of the same formats. (Worker stays Python; accepted — the family is bound by file format, not code.)

**Deferred:** standalone CLI binary (`bun build --compile` etc.) to drop the Node dependency — only if a no-extension mode appears.

---

## 2. Migration Logic — `sh + md + sh` → skill + TS core

The **per-step** `.sh` orchestrator dissolves into the agent runtime; its content moves to prose, its gate is rewritten in TS. (Cross-step *sequencing* is the separate TS orchestrator below, not a skill.)

```
overmind/scripts/<step>.sh (orchestrator)  →  DISSOLVES → host runtime + SKILL.md body
overmind/rules/<step>_rule.md              →  SKILL.md body
overmind/templates/<step>_TEMPLATE.*       →  skill assets/
overmind/golden_examples/<step>_*.md       →  skill assets/
overmind/scripts/helper/check_<step>_*.sh  →  asdlc-coordinator/validate/<step>.ts (overmind gate)
overmind/scripts/common_libs/*.sh          →  asdlc-coordinator modules
overmind/setup/models.md                   →  typed runner config (asdlc-coordinator: which agent/model per step)
```

Each migrated step yields **(a)** a skill folder and **(b)** capture/context/validator modules as needed in the shared core:

```
skills/overmind-<step>/            packages/asdlc-coordinator/
  SKILL.md                           parse/      YAML+md readers
  assets/<step>_TEMPLATE.*           capture/<step>.ts
  assets/<step>_GOLDEN_EXAMPLE.md    context/<step>.ts
                                     validate/<step>.ts
                                     readiness/  (also used by extension)
(no per-skill scripts — the shared   types/      shared DTOs
 overmind CLI owns mechanics)        bin/overmind   capture/context/gate CLI
```

- Capture commands are deterministic write primitives for step-owned input artifacts, designed for both headless use and future VS Code Webview forms. For task-to-BR, the extension UI should collect local story/Jira input and call `overmind capture task-to-br ...` instead of duplicating `user_br_input.md` writing rules. Jira capture records the ticket marker; the task skill/context step still owns MCP fetch and persistence of fetched story text.
- Gate contract `0=pass / 1=model fixes & reruns / 2=escalate` is the model↔gate interface; the model owns the repair loop (no orchestrator auto-runs it).
- Each step's tests port from `tests/ai_scripts/<step>.sh` to the TS runner in the same move.
- **Sequencing** (`init_progress_scanner.sh`, resume, per-class gating) is a **TS orchestrator / state machine in `asdlc-coordinator`** (not a skill), reused by a headless `overmind run` CLI and, later, embedded in the VS Code extension. It reads `init_progress_definition.yaml`, computes next step + gating, and invokes each step-skill via the configured agent runner. Step-skills stay individually invokable.

---

## 3. Storage & Distribution

Canonical TS monorepo; current `overmind/{scripts,rules,templates,golden_examples}` is drained in and deleted:
```
packages/asdlc-coordinator/         lib + overmind CLI
packages/installer/          `overmind init`
packages/vscode-extension/   imports asdlc-coordinator
skills/overmind-<step>/{SKILL.md, assets/}
```

`overmind init` fans each skill into every runner and drops the shared core CLI:
```
.claude/skills/overmind-<step>/    .github/skills/overmind-<step>/
.codex/skills/overmind-<step>/     .agents/skills/overmind-<step>/
.claude/commands/overmind/<step>.md  (optional)
.overmind/overmind.js        → skills call `node .overmind/overmind.js capture|context|gate <step> ...`
```
- One canonical skill → N runner copies (per-runner tweaks at install time).
- Core CLI installed once as a bundled JS (plain Node, no `node_modules`).
- **Deleted, no compat:** `project_setup_first_init_machine.sh`, the flat `.commands/.rules/.templates/.golden_examples/.helper/.setup` dirs.
- `models.md` → reborn as a typed **runner config** (TS/JSON) in `asdlc-coordinator`: the orchestrator must know which agent CLI/model to invoke per step (headless + extension-driven runs).

**Implemented vs. deferred runner targets (CRP-130):** the fan-out above is the end-state. As of CRP-130, both the TypeScript `overmind init` installer and the legacy `project_setup_first_init_machine.sh` setup/update path install the packaged `overmind-task-to-br` skill into the **supported** local runner directories `.codex/skills/overmind-task-to-br/` and `.claude/skills/overmind-task-to-br/`, while `.overmind/overmind.js` stays the single shared CLI. The `.github/skills/` and `.agents/skills/` targets remain **deferred** until their local layouts are validated in this repo.

---

## 4. Steps → Skills

Gate name = skill name minus the `overmind-` prefix.

| Step | Current script(s) | → Skill | Status |
|---|---|---|---|
| 1.1 Stack blueprints (Type A) | `init_project_stack_blueprints.sh` | `overmind-stack-blueprint` | — |
| 2.3 Common contracts | `init_common_contract_definition.sh` | `overmind-common-contract` | — |
| 3. BR scaffold | `feature_br_scaffold.sh` | `overmind-br-scaffold` | — |
| 4.1 Scan repo + task-to-BR | ~~`feature_scan_repo_for_br.sh`~~, ~~`repo_br_scan_rule.md`~~ | `overmind-repo-br-scan`, `overmind-task-to-br` | **done** (CRP-130, CRP-131) |
| 4.2 BR clarification + EARS readiness | ~~`feature_user_br_clarification.sh`~~, ~~`feature_br_check_ears_readiness.sh`~~ | `overmind-br-clarification` + `overmind readiness br-clarification` | **done** (CRP-132) |
| 5. BR → EARS | ~~`feature_br_to_ears.sh`~~ | `overmind-requirements-ears` | **done** (CRP-133) |
| 5.1 EARS review (opt) | ~~`feature_requirements_ears_review.sh`~~ | `overmind-ears-review` | **done** (CRP-134) |
| 6. Contract delta | ~~`feature_contract_delta.sh`~~ | `overmind-contract-delta` | **done** (CRP-135) |
| 7. Surface map BE/FE | ~~`feature_repo_surface_and_exec_context.sh`~~ | `overmind-surface-map` | **done** (CRP-136) |
| 7.1 MCP enrichment (opt) | ~~`feature_surface_map_mcp_placeholder_enrichment.sh`~~ | `overmind-surface-map-enrich` | **done** (CRP-137) |
| 8. Technical requirements | ~~`feature_technical_requirements.sh`~~ | `overmind-technical-requirements` | **done** (CRP-138) |
| 8.1 Implementation slices | ~~`feature_implementation_slices.sh`~~ | `overmind-implementation-slices` | **done** (CRP-139) |
| 8.2 Prerequisite gaps | ~~`feature_prerequisite_gaps.sh`~~ | `overmind-prerequisite-gaps` | **done** (CRP-140) |
| 8.3 Implementation plan | ~~`feature_implementation_plan.sh`~~ | `overmind-implementation-plan` | **done** (CRP-141) |
| 8.4 Semantic review (opt) | ~~`feature_implementation_plan_semantic_review.sh`~~ | `overmind-plan-semantic-review` | **done** (CRP-142) |

Cross-cutting → `asdlc-coordinator` / installer: sequencing (`init_progress_scanner.sh`, `project_add_feature_e2e.sh`) → **TS orchestrator/state machine in `asdlc-coordinator`** (+ `overmind run` CLI, embeddable in the extension); shared libs (`class_repo_paths.sh`, …) → `asdlc-coordinator`; worker reg/assign (`register_worker.sh`, `feature_assing_workers.sh`) → `asdlc-coordinator` CLI; staging (`project_setup_first_init_machine.sh`) → `installer`.

---

## Decided
- **Sequencing (Q1)** → **TS orchestrator / state machine in `asdlc-coordinator`**, not a conductor skill — chosen so it can be embedded in the VS Code extension and run headless (`overmind run`). Steps stay skills; the orchestrator invokes them per the runner config. Consequence: `models.md` returns as a typed runner config (which agent/model per step).
- **Type & per-class branching (Q3)** → resolved by the **orchestrator**, not SKILL.md conditionals. Project type (A/B/C) includes/excludes steps deterministically from `project_type_code`. Per-class (BE/FE/MB) runs one invocation per **ready** class (passes `class=be|fe`, selecting that class's template+gate); class scope/state (`ready`/`deferred`) stays **operator-set, as today** (repo-attach). Step-skills stay single-case and parameterized.
- **`rule.md`** → inline in `SKILL.md` body (no separate `assets/rule.md`).
- **Data formats** — `.yaml`/`.json` acceptable for data/config; `init_progress_definition*` and `external_sources.yaml` stay YAML as-is.
- **First step / reference (Q5)** → **`task-to-br`** (step 4.1): earliest gated step; its BR upstream input (`feature_br_summary.md`) is supplied via `feature_br_summary_GOLDEN_EXAMPLE.md`, and `user_br_input.md` is created by the shared `overmind capture task-to-br` primitive from a local story file or Jira ticket. Builds the `asdlc-coordinator` skeleton + `overmind` capture/context/gate CLI + TS test runner + one-skill installer alongside it. Optionally paired with the gateless **`br-scaffold`** (step 3) for a runnable scaffold→task-to-br mini-flow.
- **Monorepo tooling (Q4)** → one multi-module repo built with **npm workspaces**. `asdlc-coordinator` is an in-repo module dependency, bundled (fat-jar style) into the shipped extension `.vsix` and the `overmind.js` CLI at build time. No registry publishing unless an external consumer appears later.

- **Repo sync boundary (D7)** → `git pull --rebase` on class repos runs in the **shell orchestrator** via `overmind sync <step> <feature-path>`, called before the model session starts — mirrors the yasdef `_sync_bound_project()` pattern. Model-invoked subprocesses (e.g., `spawnSync` inside `overmind context`) inherit the model session's sandbox and cannot write to external repo paths (e.g., `.git/FETCH_HEAD`) outside the ASDLC workspace. The context builder only reads (branch/clean/upstream checks via `checkRepoBranchState`); the sync command (`overmind sync`) performs writes. A D7 block from the context means a precondition the sync cannot fix (wrong branch, dirty tree), not a sync failure.

## Open questions
_None — design settled._
