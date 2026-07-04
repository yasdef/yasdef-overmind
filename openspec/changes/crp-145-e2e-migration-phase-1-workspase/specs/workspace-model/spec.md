## ADDED Requirements

### Requirement: Runtime-root / staged-workspace detection

The system SHALL provide a pure `workspace/` function that detects the ASDLC runtime root (staged workspace) from a given path or environment, replacing the shell `resolve_runtime_root` + `asdlc_metadata.yaml` check (`02_responsibility_translation_map.md` row 1). Detection SHALL be a pure function over filesystem reads and SHALL NOT throw for a missing or unreadable root; instead it SHALL return a typed result carrying a `Diagnostic` describing the failure (`source` path, `reason`).

#### Scenario: Valid staged workspace resolves

- **WHEN** the function is given a path inside a staged ASDLC workspace containing the runtime-root marker
- **THEN** it returns the resolved runtime root as a typed value with no error-severity diagnostics

#### Scenario: Missing runtime root degrades, does not throw

- **WHEN** the function is given a path with no discoverable ASDLC runtime root
- **THEN** it returns a typed result without a runtime root and a populated `Diagnostic` naming the path and reason, and does not throw

### Requirement: Project discovery and validation

The system SHALL discover ASDLC projects by the presence of `init_progress_definition.yaml` and SHALL resolve and validate a supplied project path, replacing `discover_projects` / `resolve_project_path` (`02_responsibility_translation_map.md` row 2). The functions SHALL be pure over filesystem reads and reusable unchanged by the VS Code extension's project list.

#### Scenario: List projects by definition presence

- **WHEN** discovery runs against a projects root containing folders with and without `init_progress_definition.yaml`
- **THEN** it returns exactly the folders that contain `init_progress_definition.yaml` as valid projects

#### Scenario: Resolve a valid project path

- **WHEN** a path pointing at a folder that contains `init_progress_definition.yaml` is validated
- **THEN** it resolves to that project root as a typed value

#### Scenario: Invalid project path degrades with a diagnostic

- **WHEN** a path that does not point at a project (no `init_progress_definition.yaml` found at or above it, within the projects root) is validated
- **THEN** the result carries a `Diagnostic` with the path and reason and no valid project root, and no exception is thrown

### Requirement: Feature-folder discovery

The system SHALL discover feature folders under a resolved project and SHALL infer the owning project root from a supplied feature path, mirroring the scanner's `resolve_feature_root` / `infer_project_root_from_feature_root` behavior. A feature path SHALL be validated as an existing directory nested under the project (not the project root itself); violations SHALL be reported as diagnostics, not thrown.

#### Scenario: Infer project root from a feature path

- **WHEN** a feature path nested under a project containing `init_progress_definition.yaml` is supplied
- **THEN** the owning project root is returned and the feature's relative path is derivable from it

#### Scenario: Feature path equal to project root is rejected as a diagnostic

- **WHEN** the supplied feature path resolves to the project root itself
- **THEN** the result carries a `Diagnostic` explaining a feature-level folder is required, and no exception is thrown

### Requirement: Typed definition metadata read

The system SHALL extend `parse/` to expose, in one typed read of `init_progress_definition.yaml`, the `projectTypeCode`, the `projectClasses` list, and per-class `classRepoPaths` state (per the shape in `overmind/init_progress_definition_data_model.md`), replacing the awk metadata blocks `extract_project_type_code_from_definition`, `extract_project_classes`, and the reconciliation-candidate reads (`02_responsibility_translation_map.md` row 3). Malformed or absent fields SHALL degrade to empty/typed-missing values with a `Diagnostic`, never a throw.

#### Scenario: Read project type, classes, and class repo path states

- **WHEN** a well-formed `init_progress_definition.yaml` with `project_type_code`, `project_classes`, and `class_repo_paths` is read
- **THEN** the typed result exposes the project type code, the ordered class list, and each class's repo-path state in a single read

#### Scenario: Malformed metadata degrades with a diagnostic

- **WHEN** the definition file is present but its `meta_info` block is malformed or missing required fields
- **THEN** the read returns typed-missing/empty values plus a `Diagnostic` naming the file and reason, and does not throw
