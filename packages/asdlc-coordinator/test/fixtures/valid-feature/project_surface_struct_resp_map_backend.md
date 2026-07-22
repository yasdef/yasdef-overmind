# Project Surface Structure + Responsibility Map (Backend)

## 1. Document Meta
- repo_name: demo-repo
- service_name: demo-service
- project_type_code: B
- project_classes: backend
- feature_id: FEAT-1
- feature_title: Operator task management
- analyzed_repo_paths: /repo/demo
- source_inputs_used: requirements_ears.md
- last_updated: 2026-06-15
- was_enriched_with_mcp: false

## 2. Feature Scope
- feature_summary: Adds operator task creation.
- in_scope_feature_delta: New create-task behavior.
- out_of_scope_notes: none

## 3. Key Parts of Repo and Their Responsibilities

### 3.1 API Layer
- responsibility_summary: Covers 3.1 API Layer.
- main_repo_paths: src/3.1
- key_components: TaskService
- transport_layer: TaskService.handle
- user_reachable_surface: none

### 3.2 Application / Service Layer
- responsibility_summary: Covers 3.2 Application / Service Layer.
- main_repo_paths: src/3.2
- key_components: TaskService
- transport_layer: TaskService.handle
- user_reachable_surface: none

### 3.3 Domain Layer
- responsibility_summary: Covers 3.3 Domain Layer.
- main_repo_paths: src/3.3
- key_components: TaskService
- transport_layer: TaskService.handle
- user_reachable_surface: none

### 3.4 Persistence / Data Layer
- responsibility_summary: Covers 3.4 Persistence / Data Layer.
- main_repo_paths: src/3.4
- key_components: TaskService
- transport_layer: TaskService.handle
- user_reachable_surface: none

### 3.5 Integration Layer
- responsibility_summary: Covers 3.5 Integration Layer.
- main_repo_paths: src/3.5
- key_components: TaskService
- transport_layer: TaskService.handle
- user_reachable_surface: none

### 3.6 Runtime / Ops Layer
- responsibility_summary: Covers 3.6 Runtime / Ops Layer.
- main_repo_paths: src/3.6
- key_components: TaskService
- transport_layer: TaskService.handle
- user_reachable_surface: none

### 3.7 Test Layer
- responsibility_summary: Covers 3.7 Test Layer.
- main_repo_paths: src/3.7
- key_components: TaskService
- transport_layer: TaskService.handle
- user_reachable_surface: none

### 3.8 Another Layer(s)
> none

## 4. Backend Surfaces Touched With Current Feature

### 4.1 API Surface
- surface_summary: Covers 4.1 API Surface.
- applicability: applicable
- repo_paths: src/4.1
- why_feature_touches_it: Requirement REQ-1.
- expected_changes: Update behavior.
- evidence: repo src; requirements_ears.md REQ-1
- transport_layer: TaskService.handle
- user_reachable_surface: Operator task page

### 4.2 Application / Service Surface
- surface_summary: Covers 4.2 Application / Service Surface.
- applicability: not_applicable
- repo_paths: src/4.2
- why_feature_touches_it: Requirement REQ-1.
- expected_changes: Update behavior.
- evidence: repo src; requirements_ears.md REQ-1
- transport_layer: TaskService.handle
- user_reachable_surface: Operator task page

### 4.3 Domain Surface
- surface_summary: Covers 4.3 Domain Surface.
- applicability: not_applicable
- repo_paths: src/4.3
- why_feature_touches_it: Requirement REQ-1.
- expected_changes: Update behavior.
- evidence: repo src; requirements_ears.md REQ-1
- transport_layer: TaskService.handle
- user_reachable_surface: Operator task page

### 4.4 Persistence / Data Surface
- surface_summary: Covers 4.4 Persistence / Data Surface.
- applicability: not_applicable
- repo_paths: src/4.4
- why_feature_touches_it: Requirement REQ-1.
- expected_changes: Update behavior.
- evidence: repo src; requirements_ears.md REQ-1
- transport_layer: TaskService.handle
- user_reachable_surface: Operator task page

### 4.5 Integration Surface
- surface_summary: Covers 4.5 Integration Surface.
- applicability: not_applicable
- repo_paths: src/4.5
- why_feature_touches_it: Requirement REQ-1.
- expected_changes: Update behavior.
- evidence: repo src; requirements_ears.md REQ-1
- transport_layer: TaskService.handle
- user_reachable_surface: Operator task page

### 4.6 Runtime / Ops Surface
- surface_summary: Covers 4.6 Runtime / Ops Surface.
- applicability: not_applicable
- repo_paths: src/4.6
- why_feature_touches_it: Requirement REQ-1.
- expected_changes: Update behavior.
- evidence: repo src; requirements_ears.md REQ-1
- transport_layer: TaskService.handle
- user_reachable_surface: Operator task page

### 4.7 Test Surface
- surface_summary: Covers 4.7 Test Surface.
- applicability: not_applicable
- repo_paths: src/4.7
- why_feature_touches_it: Requirement REQ-1.
- expected_changes: Update behavior.
- evidence: repo src; requirements_ears.md REQ-1
- transport_layer: TaskService.handle
- user_reachable_surface: Operator task page

### 4.8 Unexpected Backend Surface
- surface_summary: Covers 4.8 Unexpected Backend Surface.
- applicability: not_applicable
- repo_paths: src/4.8
- why_feature_touches_it: Requirement REQ-1.
- expected_changes: Update behavior.
- evidence: repo src; requirements_ears.md REQ-1
- transport_layer: TaskService.handle
- user_reachable_surface: Operator task page
