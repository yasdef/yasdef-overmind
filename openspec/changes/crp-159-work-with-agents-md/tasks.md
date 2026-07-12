## 1. Artifact Contract Assets

- [x] 1.1 Write `overmind/rules/project_agents_md_claude_md_rule.md` as the source of truth for the artifact: recognition header (`artifact_kind`, `class`, `project`, `source_blueprint`, `last_updated`), blueprint-derived sections, required engineering sections, optional frontend/mobile sections, and prohibited content
- [x] 1.2 Write `overmind/templates/project_agents_md_claude_md_be_TEMPLATE.md`, `..._fe_TEMPLATE.md`, and `..._mobile_TEMPLATE.md` — structure only: headings, heading order, required field names, `[UNFILLED]` placeholders
- [x] 1.3 Write `overmind/golden_examples/project_agents_md_claude_md_fe_GOLDEN_EXAMPLE.md` to the enterprise-Angular quality target: mission, stack baseline, non-negotiable rules, project shape, layer responsibilities, coding standards, a11y, i18n, UI automation IDs, applied visual style contract, testing standard with coverage floor, linting/quality gates, definition of done, decision guidance
- [x] 1.4 Write `overmind/golden_examples/project_agents_md_claude_md_be_GOLDEN_EXAMPLE.md` and `..._mobile_GOLDEN_EXAMPLE.md` at the same quality bar for their classes

## 2. Quality Gate

- [x] 2.1 Implement `packages/asdlc-coordinator/src/validate/agents-md.ts` with `validateAgentsMd(inputPath, cwd)` and an exported `validateAgentsMdContent(content)`, following the structure of `validate/stack-blueprint.ts`
- [x] 2.2 Validate the `## 1. Document Meta` header: `artifact_kind` equals `project_agents_md_claude_md`, `class` in `backend|frontend|mobile`, `project` and `source_blueprint` present, `last_updated` matching `YYYY-MM-DD`
- [x] 2.3 Validate the required section set, reject the four optional sections on a `backend` artifact, reject unrecognized top-level sections, reject an empty artifact, and reject any remaining `[UNFILLED]` placeholder
- [x] 2.4 Return the standard exit-code contract: `0` pass, `1` recoverable with one rendered problem per failure, `2` when validation cannot run (missing path, missing file, directory target)
- [x] 2.5 Export from `src/validate/index.ts` and register `agents-md` in the gate registry in `src/cli/run.ts`
- [x] 2.6 Add `packages/asdlc-coordinator/test/agents-md-gate.test.ts` covering pass, each failure class, and each exit code

## 3. Context Command

- [x] 3.1 Implement `packages/asdlc-coordinator/src/context/agents-md.ts` with `buildAgentsMdContext(projectInput, klass, cwd)`, following `context/stack-blueprint.ts`
- [x] 3.2 Exit `2` when `project_type_code` is not `A`, when the class is absent from `meta_info.project_classes`, or when `project_stack_blueprint_<class>.md` does not exist, with a message stating the artifact is derived from the blueprint
- [x] 3.3 Emit runtime paths, `target_class`, `target_agents_md`, `gate_command`, per-class template and golden-example asset paths, `external_sources_status`, `agents_md_status: present|absent`, the read-only inputs (project definition, class blueprint, external sources when available), and the single allowed write surface
- [x] 3.4 Export from `src/context/index.ts` and register `agents-md` in the context registry in `src/cli/run.ts`
- [x] 3.5 Add `packages/asdlc-coordinator/test/agents-md-context.test.ts` covering the emitted bindings, `agents_md_status` both ways, and all three exit-`2` rejections

## 4. Skill Package

- [x] 4.1 Create `packages/installer/_data/skills/overmind-agents-md/SKILL.md`: required invocation of the context command, runtime bindings, allowed write surface, artifact content rules, the knowledge-base → bounded-fallback → operator-approval chain with no silent defaults, the present-artifact verify-don't-regenerate rule, the model-owned gate loop, and the final response line
- [x] 4.2 Copy the six template and golden-example assets into `packages/installer/_data/skills/overmind-agents-md/assets/`
- [x] 4.3 Add `overmind-agents-md` to the installer's packaged-skill fan-out and extend `packages/installer/test/init.test.ts` to assert the skill and its assets install

## 5. Step 1.1 Wiring

- [x] 5.1 In `src/sequencing/step-catalog.ts`, relabel step 1.1 to `Define Project Stack Blueprints And Agent Guidelines For Active Classes` and append the `agents-md` session action (model phase `project_agents_md_claude_md`, required output `project_agents_md_claude_md_<class>.md`) after the stack-blueprint action
- [x] 5.2 Register the `agents-md` context builder in `defaultStepExecutorDeps.context` in `src/runner/execute-step.ts`
- [x] 5.3 Add the `agents-md` prompt entry in `src/runner/prompt-builder.ts` binding the target artifact, the context command, the gate command, and the source blueprint as read-only
- [x] 5.4 Add the agents-md model phase to `packages/installer/_data/setup/models.md`
- [x] 5.5 Extend `packages/asdlc-coordinator/test/step-executor.test.ts` and the prompt-capture tests to assert both sessions dispatch per class in order and that the gate command appears in the agents-md prompt

## 6. Step Definition And Step 2 Gating

- [x] 6.1 In `packages/installer/_data/templates/init_progress_definition_TEMPLATE.yaml`, update step 1.1's name and add the three `project_agents_md_claude_md_<class>.md` artifacts with `required_if` on `project_type_code: A` and the matching active class, plus the completion conditions
- [x] 6.2 In `src/context/common-contract-init.ts`, extend the type `A` precondition so a missing `project_agents_md_claude_md_<class>.md` blocks step 2 the same way a missing blueprint does
- [x] 6.3 In `commitInitializationBaseline` in `src/cli/run.ts`, add the per-class agent guidelines artifacts to the owned paths for type `A` projects
- [x] 6.4 Extend `packages/asdlc-coordinator/test/cli-project-init.test.ts` and `stack-blueprint-gate.test.ts` fixtures to cover step-1.1 completion requiring both artifacts, step-2 blocking, and the baseline commit's owned paths

## 7. Verification

- [x] 7.1 Run `npm test` and `npm run verify` from the repository root
- [x] 7.2 Drive one type `A` project init end to end against a fixture workspace: confirm both sessions dispatch per class, the gate passes, step 2 unblocks, and the baseline commit contains the new artifacts
- [x] 7.3 Re-enter step 1.1 on that completed project after adding a class: confirm the new class gets both artifacts and the existing class's gate-passing artifacts are left byte-unchanged
- [x] 7.4 Update `overmind/README.md` and `QUICKRUN.md` with the new gate and context commands and the revised step 1.1
