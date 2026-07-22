## ADDED Requirements

### Requirement: Worker registration is a deterministic TypeScript primitive

Registering a project worker SHALL be performed by a typed coordinator module (`packages/asdlc-coordinator/src/workers/registry.ts`) invoked through `overmind worker register --path <project>`, not by shell. The repository SHALL NOT contain `overmind/scripts/project_mgmt/project_register_worker.sh`. Clock, UUID, and operator interaction SHALL be supplied through injected ports so registration is deterministic under test.

#### Scenario: Register a worker via the CLI verb

- **WHEN** an operator runs `overmind worker register --path <asdlc/projects/<project-id>>` and selects a worker class
- **THEN** a new worker entry with a unique lowercase UUID, the selected class, `status: active`, and a `registered_at` timestamp is appended to the project's `workers.yaml`, and the new UUID is reported for hand-off to the developer

#### Scenario: Shell registrar is absent

- **WHEN** the versioned production tree is inspected
- **THEN** `overmind/scripts/project_mgmt/project_register_worker.sh` and its shell test suite do not exist, and no packaged staging references them

### Requirement: Worker-class selection is validated

Registration SHALL accept only the supported worker classes `backend`, `frontend`, `mobile`, and `infrastructure`, resolved from either the class name or its menu number (`1` backend, `2` frontend, `3` mobile, `4` infrastructure). An unsupported selection SHALL be rejected and re-prompted rather than written.

#### Scenario: Menu number resolves to a class

- **WHEN** the operator selects `2`
- **THEN** the worker is registered with class `frontend`

#### Scenario: Unsupported class is rejected

- **WHEN** the operator enters a value that is neither a supported class name nor `1`–`4`
- **THEN** the selection is rejected, the operator is re-prompted, and no worker entry is written

### Requirement: Registry shape and project identity are enforced

Registration SHALL require the project definition's canonical `project_id` (`meta_info.project_id` in `init_progress_definition.yaml`). When `workers.yaml` is absent it SHALL be created with the top-level `project_id` and an empty `workers:` collection. When present, its top-level `project_id` SHALL match the project definition and it SHALL expose a top-level `workers:` collection; a legacy `workers: []` inline-empty form SHALL be normalized to a block collection before appending. A mismatched or missing `project_id`, or a missing `workers:` key, SHALL fail with a clear error and no mutation.

#### Scenario: Registry file is created on first registration

- **WHEN** `workers.yaml` does not yet exist for the project
- **THEN** it is created with the canonical `project_id` and a `workers:` collection containing the new entry

#### Scenario: project_id mismatch fails without mutation

- **WHEN** an existing `workers.yaml` has a top-level `project_id` different from the project definition's `project_id`
- **THEN** registration fails with a mismatch error and `workers.yaml` is left unchanged

### Requirement: Registration returns a typed result the CLI renders without scraping

The registration primitive SHALL return a typed result carrying its diagnostics and the set of changed paths, and the CLI SHALL render its output and exit code from that result rather than parsing printed text. On success the result SHALL report `workers.yaml` as a changed path and carry the new worker UUID; on validation failure (unsupported class, missing/mismatched `project_id`, malformed registry, or UUID-generation exhaustion) it SHALL carry a diagnostic and report no changed paths.

#### Scenario: Successful registration reports changed path and UUID

- **WHEN** a worker is registered
- **THEN** the returned result reports `workers.yaml` among its changed paths and carries the new worker UUID, and the CLI renders the hand-off message and success exit from that result

#### Scenario: Validation failure carries a diagnostic and no changed paths

- **WHEN** registration fails on class validation, `project_id` mismatch, malformed registry, or UUID exhaustion
- **THEN** the returned result carries a diagnostic describing the failure, reports no changed paths, and the CLI renders a non-success exit from it

### Requirement: Generated worker UUIDs are unique and content is preserved

Registration SHALL generate a version-agnostic lowercase UUID that is not already present in `workers.yaml`, retrying generation on collision and failing if a unique value cannot be produced. Appending an entry SHALL preserve all unrelated existing content and line structure of `workers.yaml`.

#### Scenario: Collision with an existing UUID is avoided

- **WHEN** a generated UUID already appears as a `uuid:` value in `workers.yaml`
- **THEN** registration regenerates until a unique UUID is found before writing the entry

#### Scenario: Existing entries are preserved

- **WHEN** a worker is appended to a `workers.yaml` that already contains worker entries
- **THEN** the prior entries and unrelated lines are byte-preserved and only the new entry is added
