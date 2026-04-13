# Common Contract Definition

## 1. Document Meta
- project_id: [UNFILLED]
- project_path: [UNFILLED]
- source_repo_count: [UNFILLED]
- source_repositories: [UNFILLED]
- last_updated: [UNFILLED]
- confidence_level: [UNFILLED]

## 2. Source Repository Evidence
> Use one or more repository-evidence blocks. Add as many `### Repository:` blocks as needed.
### Repository: [UNFILLED]
- class: [UNFILLED]
- repo_path: [UNFILLED]
- contract_evidence_summary: [UNFILLED]
- key_surfaces_reviewed: [UNFILLED]
- notes: [UNFILLED]

## 3. Common Contract Baseline
> Use one or more common-contract blocks. Add as many `### Contract:` blocks as needed.
### Contract: [UNFILLED]
- contract_kind: [http_api | event | async_message | db_schema | config | auth_token | file_interface | library_api | other]
- interaction_mode: [sync | async | pull | push]
- producer_repositories: [UNFILLED]
- consumer_repositories: [UNFILLED]
- contract_surface: [UNFILLED]
- contract_status: [aligned | drifted | single_source | inferred]
- source_of_truth: [UNFILLED]
- canonical_shape: [UNFILLED]
- shared_types: [enums/ids/schema objects or none]
- trust_boundary: [public | internal | service_to_service | admin_only | none]
- compatibility_rule: [UNFILLED]
- planning_implication: [none | reconcile consumer drift | define shared schema | verify ownership | add client module | add contract tests | other]
- notes: [UNFILLED]

## 4. Reconciliation Decisions
> Use one or more numbered decisions (`decision_1`, `decision_2`, ...).
- decision_1: [UNFILLED]
- decision_2: [UNFILLED]

## 5. Known Risks / Uncertainties
> Use one or more numbered uncertainty entries (`uncertainty_1`, `uncertainty_2`, ...).
- uncertainty_1: [UNFILLED]
- uncertainty_2: [UNFILLED]

## 6. Common Planning Signals
> Capture shared pre-implementation coordination implied by section 3 contract statuses.
> Use one or more numbered prep entries (`prep_1`, `prep_2`, ...).
- prep_1: [UNFILLED]
- prep_2: [UNFILLED]
