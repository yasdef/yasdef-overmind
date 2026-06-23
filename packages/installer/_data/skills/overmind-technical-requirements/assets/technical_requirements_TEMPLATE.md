# Technical Requirements

## 1. Document Meta
- feature_id: [UNFILLED]
- feature_title: [UNFILLED]
- project_type_code: [UNFILLED]
- source_requirements_ears: [UNFILLED]
- source_common_contract_definition: [UNFILLED]
- source_surface_map_artifacts: [UNFILLED]
- analyzed_repo_classes: [UNFILLED]
- last_updated: [UNFILLED]
- confidence_level: [UNFILLED]

## 2. Feature Scope and Inputs
- feature_summary: [UNFILLED]
- included_behavior: [UNFILLED]
- excluded_behavior: [UNFILLED]

## 3. Repository Evidence
> Use one or more repository-evidence blocks. Add as many `### Repository:` blocks as needed.
### Repository: [UNFILLED]
- class: [backend | frontend | mobile]
- evidence_scope: [UNFILLED]
- primary_paths: [UNFILLED]
- key_findings: [UNFILLED]
- constraints: [UNFILLED]
- open_gaps: [UNFILLED]

## 4. Requirement Coverage and Gaps
> Use one or more requirement blocks. Add one `### Requirement:` block for each relevant `REQ-*` or `NFR-*`.
### Requirement: [REQ-1 | NFR-1]
- requirement_summary: [UNFILLED]
- transport_layer: [UNFILLED]
- user_reachable_surface: [UNFILLED]
- gap_status: [fully_implemented | partially_implemented | not_implemented | unclear]
- repo_impact: [backend | frontend | mobile | multiple]
- evidence: [UNFILLED]
- gap_to_close: [UNFILLED]

## 5. Impacted Components
> Use one or more component blocks. Add as many `### Component:` blocks as needed.
### Component: [UNFILLED]
- repo: [backend | frontend | mobile]
- component_kind: [controller | service | dto | mapper | domain | persistence | migration | security | config | test | ui | state | api_client | other]
- relevant_paths: [UNFILLED]
- requirement_refs: [REQ-1]
- current_state: [UNFILLED]
- required_behavior: [UNFILLED]
- gap_to_close: [UNFILLED]
- dependency_notes: [UNFILLED]
- evidence: [UNFILLED]

## 6. Cross-Repo Constraints and Planning Signals
> Use zero or more typed `### Planning Signal:` blocks.
> If no signal is needed, use the exact line: `- planning_signals: none`.
### Planning Signal: [UNFILLED]
- signal_id: [UNFILLED]
- signal_type: [cross_repo_contract_lock]
- owner_repo: [backend | frontend | mobile]
- consumer_repos: [backend | frontend | mobile]
- required_artifact: [UNFILLED]
- must_precede: [UNFILLED]
- output_requirements: [UNFILLED]
- source_evidence: [REQ-1 | NFR-1 | comp/component-slug]

## 7. Known Risks / Uncertainties
> Use one or more numbered risk entries (`risk_1`, `risk_2`, ...).
- risk_1: [UNFILLED]
