## Context

`overmind/scripts/helper/check_implementation_plan_quality.sh` already validates that `#### Depends on:` references point only to earlier steps, which means a plan that passes the current gate is already acyclic in practice. What the workflow still lacks is a deterministic, human-readable graph artifact that exposes dependency shape directly and can be reviewed without manually reconstructing the DAG from raw markdown.

This change is small in implementation size but cross-cutting in effect: it introduces a new helper, a new generated artifact, staged-helper distribution, test coverage, and documentation updates. It should preserve the existing structural quality gate rather than folding graph rendering into it.

## Goals / Non-Goals

**Goals:**
- Add a dedicated helper that renders an implementation-plan dependency graph into a stable human-readable artifact.
- Make the output suitable for terminal inspection, commit review, and markdown rendering with Mermaid support.
- Re-validate graph consistency at render time so malformed or cyclic dependency metadata fails deterministically.
- Keep the helper shell-native and aligned with the repository’s current helper patterns.
- Stage the helper into ASDLC workspaces and cover it with script tests under `tests/ai_scripts/`.

**Non-Goals:**
- No redesign of `implementation_plan.md` structure or `#### Depends on:` syntax.
- No replacement of `check_implementation_plan_quality.sh` as the primary structure validator.
- No new generalized graph library or non-shell runtime dependency.
- No automatic recomputation of implementation-plan ordering or mutation of plan content.

## Decisions

1. Keep graph rendering separate from the existing quality gate
Rationale: `check_implementation_plan_quality.sh` already owns structural validation of the artifact contract. A separate graph helper keeps responsibilities clear: one script validates plan shape, the other produces a readable graph proof and performs defensive graph-specific checks.
Alternative considered: extend `check_implementation_plan_quality.sh` to also emit the report. Rejected because it mixes validation and artifact generation, complicates test expectations, and makes normal quality-gate use noisier.

2. Use a deterministic sibling Markdown output path
Rationale: writing `implementation_plan_dependency_graph.md` next to the target plan gives the user a durable artifact without adding new CLI flags. It also matches the repository preference for minimal shell interfaces.
Alternative considered: stdout-only output. Rejected because the user explicitly wanted an md/txt human-readable result and a file artifact is easier to inspect later and in review tooling.

3. Keep the parser shell-native with awk-driven extraction
Rationale: the existing helper stack is bash/awk/sed based, and the input structure is regular enough to parse deterministically without adding Python or Node.
Alternative considered: introduce a higher-level parser or graph library. Rejected as unnecessary dependency growth for a bounded artifact format.

4. Generate both textual and Mermaid views from the same parsed graph model
Rationale: plain-text sections are easy to diff and read in any terminal, while Mermaid gives immediate structural visualization in markdown-capable viewers. Producing both from one parse path keeps outputs aligned.
Alternative considered: Mermaid-only output. Rejected because it is harder to inspect in plain text and less useful when rendered markdown is unavailable.

5. Keep explicit exit semantics aligned with other helpers
Rationale: using `0` for success, `1` for content/graph failure, and `2` for helper/runtime failure matches established helper behavior and makes caller integration predictable.
Alternative considered: single non-zero exit for all failures. Rejected because callers and tests need to distinguish invalid plan content from script/runtime faults.

## Risks / Trade-offs

- [Risk] The new helper could drift from `check_implementation_plan_quality.sh` if both scripts parse step metadata independently. -> Mitigation: keep parsing rules narrowly aligned to the canonical step headings and dependency lines, and cover malformed/failure cases in dedicated tests.
- [Risk] Mermaid node labels may become unstable or awkward if titles contain punctuation or repeated wording. -> Mitigation: use deterministic synthetic Mermaid node ids derived from step ids and keep labels concise, based on step id plus repo/title fragments.
- [Risk] Users may mistake the graph report for a substitute quality gate. -> Mitigation: document it as a post-quality-check report helper and preserve the existing quality helper as the canonical validation gate.
- [Risk] A stale report file could survive after a later failed render. -> Mitigation: require failed runs to avoid leaving a misleading success artifact in place.

## Migration Plan

1. Add `overmind/scripts/helper/render_implementation_plan_dependency_graph.sh` with deterministic path resolution, graph parsing, report rendering, and cycle/graph validation.
2. Emit `implementation_plan_dependency_graph.md` beside the selected `implementation_plan.md`, including summary, direct-dependency listing, and Mermaid `graph TD` output.
3. Stage the helper through `overmind/scripts/project_mgmt/project_setup_first_init_machine.sh` so ASDLC workspaces receive it under `.helper/`.
4. Add script tests for successful report generation, Mermaid content, cycle failure, malformed dependency handling, and staged-helper sync.
5. Update user-facing docs to describe the recommended flow: run `check_implementation_plan_quality.sh` first, then run the dependency-graph helper.

Rollback strategy: remove the new helper and staged distribution, delete the generated report contract, and keep implementation-plan validation limited to the existing structural quality helper.

## Open Questions

- None. The only material design choice was whether to make the report stdout-only or file-backed, and this change resolves that in favor of a deterministic sibling markdown artifact.
