# Implementation Slices

Use this artifact to capture implementation-driven executable slices before final cross-repo ordering and full traceability enforcement.
This phase prioritizes thin vertical cuts, first usable increments, and minimal local prerequisites.

## 1. Document Meta
- feature_id: [UNFILLED]
- feature_title: [UNFILLED]
- project_type_code: [UNFILLED]
- source_requirements_ears: [UNFILLED]
- source_technical_requirements: [UNFILLED]
- source_feature_contract_delta: [UNFILLED]
- source_surface_map_artifacts: [UNFILLED]
- analyzed_repo_classes: [UNFILLED]
- ordering_scope: local_prerequisites_only
- traceability_scope: slice_level_only
- last_updated: [UNFILLED]
- confidence_level: [UNFILLED]

## 2. Slice Planning Guardrails
- objective: Discover executable slices before ordered implementation-plan synthesis.
- non_goals:
  - Do not produce a full global ordering for all slices.
  - Do not force full REQ/NFR traceability coverage at this stage.
- decomposition_bias:
  - first usable increment early
  - scaffold-aware frontend/mobile decomposition where applicable
  - minimal prerequisite capture only

## 3. Slice Candidates
### Slice 1: [UNFILLED title]
- repo: [backend|frontend|mobile]
- status: [existing|planned]
- kind: [optional; omit for normal feature-delivery slices; set to `coordination` only when evidence-gated cross-repo contract work is needed]
- signal_ref: [optional; required when kind: coordination — reference to cross_repo_contract_lock signal_id from technical_requirements.md section 6]
- objective: [UNFILLED]
- first_increment: [UNFILLED]
- prerequisites: [none|UNFILLED]
- preserved_operator_surface: [none|UNFILLED]
- evidence: [gap/TECH_REQ-1 | gap/TECH_REQ-NFR-1, comp/component-slug]
- [ ] [UNFILLED concrete implementation slice]
- [ ] [UNFILLED concrete implementation slice]
- [ ] [UNFILLED concrete implementation slice]

## 4. Handoff To Ordered Plan
- ordering_intent: [UNFILLED]
- unresolved_ordering_questions: [UNFILLED]
- unresolved_traceability_questions: [UNFILLED]

## 5. Golden Example: With Coordination Slice

A feature where a shared contract must be frozen before parallel downstream implementation can proceed safely. The coordination slice carries `kind: coordination` and a `signal_ref` pointing to the upstream planning signal. A separate feature-delivery slice covers required operator-facing surface delivery — the coordination slice does not substitute for it.

```markdown
### Slice 1: Cross-repo contract freeze
- repo: backend
- status: planned
- kind: coordination
- signal_ref: signal-contract-lock-1
- objective: Freeze the shared order payload contract before parallel downstream implementation begins.
- first_increment: Contract document is reviewed and frozen for consumer repo alignment.
- prerequisites: none
- preserved_operator_surface: none
- evidence: gap/TECH_REQ-4, comp/backend-order-service
- [ ] Draft shared order payload contract document and circulate for review
- [ ] Confirm all consumer repo owners acknowledge the frozen contract before downstream slices start

### Slice 2: Backend order query endpoint
- repo: backend
- status: planned
- objective: Deliver the backend order query endpoint returning projection-backed results.
- first_increment: Backend order query endpoint returns correct projection-backed order status.
- prerequisites: none
- preserved_operator_surface: none
- evidence: gap/TECH_REQ-6, comp/backend-order-service
- [ ] Implement read service and repository wiring for projection-backed query
- [ ] Add controller mapping and integration tests for the query endpoint
```

Both slices pass the quality gate. The coordination slice passes because `signal_ref` is non-empty. Absence of coordination slices is equally valid — see the next example.

## 6. Golden Example: Without Coordination Slice

A feature with no cross-repo contract ambiguity. No coordination slice is emitted. The quality gate passes with only feature-delivery slices present, confirming that absence of coordination slices is a valid outcome.

```markdown
### Slice 1: Backend order query endpoint
- repo: backend
- status: planned
- objective: Deliver the backend order query endpoint returning projection-backed results.
- first_increment: Backend order query endpoint returns correct projection-backed order status.
- prerequisites: none
- preserved_operator_surface: none
- evidence: gap/TECH_REQ-6, comp/backend-order-service
- [ ] Implement read service and repository wiring for projection-backed query
- [ ] Add controller mapping and integration tests for the query endpoint

### Slice 2: Frontend order projection client
- repo: frontend
- status: planned
- objective: Map projection-backed order status fields in the frontend client.
- first_increment: Frontend order list reflects projection-backed status without page reload.
- prerequisites: none
- preserved_operator_surface: none
- evidence: gap/TECH_REQ-4, comp/frontend-order-client
- [ ] Update frontend API adapter to map projection status fields from backend payload
- [ ] Update order list UI state and rendering for projection-backed status display
```

No `kind` or `signal_ref` fields are present. The quality gate passes because coordination slice absence is always valid.
