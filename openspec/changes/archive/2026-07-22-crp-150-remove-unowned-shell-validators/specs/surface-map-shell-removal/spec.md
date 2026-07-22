## ADDED Requirements

### Requirement: Surface-map quality has a single TypeScript owner

Surface-map structural quality validation SHALL be provided by `packages/asdlc-coordinator/src/validate/surface-map.ts`. The repository SHALL NOT contain `overmind/scripts/helper/check_feature_repo_surface_and_exec_context_be_quality.sh` or `overmind/scripts/helper/check_feature_repo_surface_and_exec_context_fe_quality.sh`. These validators are dead code with no runtime consumer; a no-consumer audit is sufficient to remove them.

#### Scenario: Audit confirms no remaining consumer

- **WHEN** production scripts, packaged skills, CLI gates, and staged command/helper/lib paths are inspected
- **THEN** neither validator is invoked, sourced, required, or staged, and the `surface-map` CLI gate resolves to `validateSurfaceMap`

#### Scenario: Validator scripts are absent

- **WHEN** the versioned production tree is inspected
- **THEN** neither surface-map shell validator exists under `overmind/scripts/helper/`

#### Scenario: Surface-map validation uses the TypeScript gate

- **WHEN** the installed `overmind-surface-map` skill validates a backend, frontend, or mobile map
- **THEN** it invokes `node .overmind/overmind.js gate surface-map <feature-path> --class <class>` backed by `validate/surface-map.ts`, preserving `0` success, `1` recoverable content failure, and `2` blocking runtime failure

### Requirement: Shell removal targets fresh installation only

Overmind has never been installed and no persistent ASDLC workspace exists. The shell-removal effort SHALL therefore treat the surviving `.sh` files as pre-TypeScript scaffolding to delete alongside their tests, not as a deployed surface to preserve. It SHALL NOT carry a deployed-shell cleanup manifest, a historically-staged helper inventory, a direct-upgrade fixture, or a transitional shell allow-list guard. The final zero-shell state is asserted once, when the TypeScript installer cutover lands.

#### Scenario: No deployment-history compatibility artifacts

- **WHEN** the shell-removal change payload is inspected
- **THEN** it contains no deployed-shell cleanup manifest, historical staging inventory, direct-upgrade fixture, or transitional shell allow-list guard

#### Scenario: Installer migration baseline is fresh install

- **WHEN** shell-removal work evaluates installer migration requirements
- **THEN** it requires only fresh workspace bootstrap coverage from the TypeScript package payload
