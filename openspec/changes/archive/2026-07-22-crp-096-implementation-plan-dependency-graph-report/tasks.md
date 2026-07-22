## 1. Add the dependency-graph helper contract

- [ ] 1.1 Add `overmind/scripts/helper/render_implementation_plan_dependency_graph.sh` to parse `implementation_plan.md` step/dependency metadata and resolve a deterministic sibling output path.
- [ ] 1.2 Generate `implementation_plan_dependency_graph.md` with summary lines, per-step direct dependency listing, and a Mermaid `graph TD` block.
- [ ] 1.3 Enforce deterministic exit behavior for success, graph/content failure, and helper/runtime failure, including cycle and malformed-dependency cases.

## 2. Wire the helper into staged ASDLC assets

- [ ] 2.1 Update `overmind/scripts/project_mgmt/project_setup_first_init_machine.sh` so the new dependency-graph helper is staged into `asdlc/.helper/`.
- [ ] 2.2 Update staged-helper coverage in `tests/ai_scripts/project_setup_asdlc_tests.sh` so bootstrap/update flows verify the helper is present, executable, and byte-for-byte synced from repo sources.

## 3. Add automated coverage for graph behavior

- [ ] 3.1 Add a dedicated test suite under `tests/ai_scripts/` for successful report generation and report-file placement beside the target implementation plan.
- [ ] 3.2 Add tests that assert Mermaid output and direct-dependency sections are rendered deterministically for a valid sample plan.
- [ ] 3.3 Add tests for cyclic dependency failure, malformed dependency failure, and no-stale-report behavior after unsuccessful runs.

## 4. Update docs and validate apply-readiness

- [ ] 4.1 Update `Readme.md` and any nearby command guidance so the dependency-graph helper is documented as a post-quality-check report step for `implementation_plan.md`.
- [ ] 4.2 Run the relevant `tests/ai_scripts/` suites for the new helper and staging coverage from the repository root.
- [ ] 4.3 Run `openspec status --change crp-096-implementation-plan-dependency-graph-report` and confirm the change is apply-ready.
