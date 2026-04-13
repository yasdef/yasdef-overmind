# Flow Gaps

Compared against:
- `overmind/init_progress_definition_sequence_diagram.md`
- `overmind/templates/init_progress_definition_TEMPLATE.yaml`

Status meanings:
- `have it`
- `don't have it`
- `have it but need to change`

## Steps

### 1. Initialize Repo ASDLC Metadata
- Artifact: `init_progress_definition.yaml`
- Status: `have it`
- Existing: `project_setup_first_init_machine.sh`, `project_setup_add_new_project.sh`, `project_setup_update_project.sh`, `init_progress_definition_TEMPLATE.yaml`
- Gap: none

### 2. Create Cross-Project Contract Inventory and Common Contracts Definition
- Artifact: `common_contract_definition.md`
- Status: `have it`
- Existing: `init_common_contract_definition.sh`, `common_contract_definition_rule.md`, quality helper, model entry, template + golden
- Gap: none

### 3. Initialize and Enrich Business Requirements Structuring (scaffold)
- Artifact: `feature_br_summary.md`
- Status: `have it`
- Existing: `feature_br_scaffold.sh`, `feature_task_to_br.sh`, `feature_user_br_clarification.sh`, `feature_scan_repo_for_br.sh`, EARS readiness check, related rules/models, template + golden
- Gap: none

### 4.1 Scan repo and apply task-to-BR update
- Artifacts: `user_br_input.md` (and BR updates in `feature_br_summary.md`)
- Status: `have it`
- Existing: `feature_scan_repo_for_br.sh`, `feature_task_to_br.sh`, related rules/helpers
- Gap: none

### 4.2 Clarify BR and check EARS readiness
- Artifact: `feature_br_summary.md` (`ready_to_ears: true`)
- Status: `have it`
- Existing: `feature_user_br_clarification.sh`, `feature_br_check_ears_readiness.sh`, related rules/helpers
- Gap: none

### 5. Convert Business Requirements Structuring to EARS
- Artifact: `requirements_ears.md`
- Status: `have it`
- Existing: `feature_br_to_ears.sh`, `br_to_ears.md`, quality helper, model entry, template + golden
- Gap: filename typo in `reqirements_ears_*` is retained for compatibility

### 5.1. (optional) requirement_ears extra review
- Artifact: `requirements_ears_review.md`
- Status: `have it`
- Existing: `feature_requirements_ears_review.sh`, `requirements_ears_review_rule.md`, quality helper, model entry, template + golden
- Gap: none

### 6. Define Feature Contract Delta
- Artifact: `feature_contract_delta.md`
- Status: `have it`
- Existing: `feature_contract_delta.sh`, `feature_contract_delta_rule.md`, quality helper, model entry, template + golden
- Gap: none

### 7. Analyze Repos And Prepare Repo Execution Context
- Artifacts:
  - `project_surface_struct_resp_map_backend.md`
  - `project_surface_struct_resp_map_frontend.md`
  - `project_surface_struct_resp_map_mobile.md`
- Status: `have it`
- Existing: `feature_repo_surface_and_exec_context.sh`, shared rule/model entry, BE/FE helper gates, templates + golden examples, setup staging support
- Gap: none

### 8. Create Feature-Scoped Technical Requirements
- Artifact: `technical_requirements.md`
- Status: `have it`
- Existing: `feature_technical_requirements.sh`, rules/helpers, template + golden
- Gap: none

### 8.1 Create Implementation Slice Planning Artifact
- Artifact: `implementation_slices.md`
- Status: `have it`
- Existing: `feature_implementation_slices.sh`, `implementation_slices_rule.md`, quality helper, model entry, template + golden
- Gap: none

### 8.2 Create Shared Repository Implementation Plan
- Artifact: `implementation_plan.md`
- Status: `have it but need to change`
- Existing: `feature_implementation_plan.sh`, `implementation_plan_rule.md`, quality helper, model entry, template + golden example
- Gap: project type A / MCP-guided planning is still unsupported; current scaffold covers B/C flow only

### 8.3 (optional) implementation plan semantic review
- Artifact: `implementation_plan_semantic_review.md`
- Status: `have it`
- Existing: `feature_implementation_plan_semantic_review.sh`, rules/templates/golden
- Gap: none

## Outside Current Flow

- Legacy repo-summary/contracts-inventory/missing-details/technical-structuring scaffolds were removed from active repository assets.

## Suggested Order

1. Add project type A / MCP-guided support for shared repository implementation planning.
2. Keep `README.md`, `setup/models.md`, and tests aligned with the active simplified pipeline.
