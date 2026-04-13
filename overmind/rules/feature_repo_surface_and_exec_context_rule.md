# Repo Surface And Execution Context Rule

Read this file fully before generating output.

## Purpose
- Convert feature requirements plus feature contract delta into a repository surface map for the target track.
- Describe two things only:
  - key parts of the target repository and their general responsibilities
  - repository surfaces touched by the current feature for the target track
- Produce deterministic output for `<TARGET_PROJECT_SURFACE_MAP_ARTIFACT>`.

## Track Binding
- This rule is shared across multiple tracks.
- Treat the prompt-provided track bindings as authoritative for:
  - target track name
  - applicable project classes
  - repository paths to scan
  - target template and golden example
  - `project_classes` value to write in artifact meta
  - quality gate command and completion wording
- Do not infer another track when the prompt already binds one.

## Ownership Boundaries
Owns:
- repository-level structure summary for the bound track
- feature-scoped surface mapping for the bound track

Must not own:
- another track execution context
- business requirements decomposition
- contract governance redesign
- broad risk analysis outside repository structure and touched surfaces

## Authoritative Inputs And Outputs
- Read project type and class applicability from prompt context.
- Read these input artifacts:
  - `<PROJECT_INIT_PROGRESS_DEFINITION_ARTIFACT>`
  - `<REQUIREMENTS_EARS_ARTIFACT>`
  - `<FEATURE_CONTRACT_DELTA_ARTIFACT>`
- Use only repository paths listed in prompt context as scan scope.
- Update only `<TARGET_PROJECT_SURFACE_MAP_ARTIFACT>`.

## Project Type Branching
- If project type is `B` or `C`: produce the surface map from repository evidence plus feature inputs.
- If project type is `A`: this stage is unsupported for now; do not generate pseudo-content.

## Output Format Baseline
- Use the prompt-provided template as the structure contract.
- Use the prompt-provided golden example as the style contract.
- Preserve heading order and key names from the template.
- Keep section `3` general to the repository or codebase layer responsibilities.
- Keep section `4` focused only on surfaces touched with the current feature.

## Evidence Rules
- Use only repository-proven evidence plus declared feature input artifacts.
- Do not invent layers, module boundaries, or touched surfaces without evidence.
- Keep feature scope narrow to this feature delta.
- Explain each layer or touched surface in concise plain language.
- Do not duplicate details that belong in other artifacts.

## Runtime Path Binding Rules
- Treat runtime path bindings in prompt context as authoritative for this invocation.
- Resolve outputs under runtime feature root.
- Do not hardcode `overmind/product/...` when runtime override is supplied.

## Completion Gate
- Before finalizing, run the prompt-provided quality gate command.
- If the gate fails, revise the output and rerun the gate command.
- If gate compliance is not feasible with current evidence and constraints, stop and use the prompt-provided failure line exactly.
- If the gate passes, end with the prompt-provided success line exactly.
