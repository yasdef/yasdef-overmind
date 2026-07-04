## ADDED Requirements

### Requirement: `overmind status <path>` CLI verb

The system SHALL add a `status` verb to the existing `cli/run.ts` dispatch (alongside `gate|context|capture|sync|readiness`) that accepts a project or feature path as a **positional argument** — `overmind status <path>`, consistent with the existing positional dispatch (`overmind <command> <step> <path>`) and mirroring the *behavior* of the scanner's path handling (accepts project or feature path), not its literal `--path` flag (`04_migration_plan.md ## Slice 1`; `02_responsibility_translation_map.md` row 22). The verb SHALL be a thin, read-only adapter: resolve the workspace, call `sequencing/`'s `evaluate`, render the checklist to stdout, and render `diagnostics[]` to stderr with an appropriate exit code. It SHALL NOT write a `step_state_<feature>.md` file (unlike the old scanner); `status` is read-only compute to stdout.

#### Scenario: Status on a feature path prints the checklist

- **WHEN** `overmind status <feature-path>` runs against a valid project/feature
- **THEN** it prints the `# Overmind Bootstrap Checklist` output (project and feature scope) with the byte-exact trailing `next step:` line and exits zero

#### Scenario: Status on a project path prints project-scope checklist

- **WHEN** `overmind status <project-path>` runs against a valid project
- **THEN** it prints the checklist covering project-scope steps, using the feature-title fallback where no feature is initialized

#### Scenario: Status on an invalid path degrades with diagnostics

- **WHEN** `overmind status <path>` is given a path that resolves to no valid project
- **THEN** it writes the core-produced diagnostic (path and reason) to stderr and exits non-zero, without throwing an unhandled error

### Requirement: Canonical-line contract test

The system SHALL include a TypeScript contract test that asserts the canonical next-step line byte-for-byte — `next step: <num> (<name>)` and the literal `next step: none` — because the shell e2e's regex parser (`parse_scanner_next_step_line`) remains a consumer of `overmind status` output until Slice 3.

#### Scenario: Contract test pins the canonical line

- **WHEN** the contract test renders status output for a fixture with a known pending step and for a fully-complete fixture
- **THEN** it asserts the exact `next step: <num> (<name>)` line and the exact `next step: none` line, failing on any byte drift

### Requirement: Transitional rewire of the shell e2e onto `overmind status`

The system SHALL rewire `overmind/scripts/project_mgmt/project_add_feature_e2e.sh` so that `scanner_status_line_for_feature` and `run_scanner_and_get_next_step` invoke `node .overmind/overmind.js status` instead of `.commands/init_progress_scanner.sh`. Because the new scanner reports precise definition step ids, the rewire SHALL also correct **both** shell mapping points — `map_scanner_step_to_phase` and the `fail_project_prerequisite_step` case labels — whose compensating remaps (e.g. legacy `4` → `5`, name-substring fallbacks) become dead. This is the only transitional shell edit in the migration plan.

#### Scenario: e2e reads next step from overmind status

- **WHEN** the rewired e2e runs its scanner step
- **THEN** it obtains the checklist and canonical `next step:` line from `node .overmind/overmind.js status <feature>` (positional path) and parses it with the unchanged regex parser

#### Scenario: Dead compensation removed

- **WHEN** the mapping points are reviewed after the rewire
- **THEN** `map_scanner_step_to_phase` maps precise definition ids to phases without the legacy `4 → 5` remap or name-substring fallbacks, and `fail_project_prerequisite_step` case labels reference the precise project-step ids

### Requirement: e2e fixture correction for the precision change

The system SHALL update every expectation in `tests/ai_scripts/project_add_feature_e2e_tests.sh` that shifts from a joined/omitted scanner id to a precise definition id. The change's tasks SHALL include an audit step enumerating those fixtures before editing. Fixture breakage MUST NOT be resolved by making the new scanner mimic the old imprecision.

#### Scenario: Shifted fixtures updated to precise ids

- **WHEN** a fixture previously asserted a joined scanner id (e.g. `4`) that the definition-as-spec scanner now reports precisely (e.g. `4.1`/`4.2`/`5`)
- **THEN** the fixture is updated to the precise id and the e2e suite passes under `npm run verify`

#### Scenario: Precision preserved over fixture convenience

- **WHEN** a fixture would only pass if the scanner joined or omitted steps
- **THEN** the scanner is not changed to mimic the old imprecision; the fixture is corrected instead

### Requirement: Delete the shell scanner and de-stage it

The system SHALL delete `overmind/scripts/project_mgmt/init_progress_scanner.sh` and its shell tests `tests/ai_scripts/init_progress_scanner_tests.sh`, and SHALL stop staging the scanner in `project_setup_first_init_machine.sh`. Deletion happens in this slice because this slice proves parity of the replacement.

#### Scenario: Scanner script and tests removed

- **WHEN** the change is applied
- **THEN** `init_progress_scanner.sh` and `init_progress_scanner_tests.sh` no longer exist and no staging step copies the scanner into the runtime workspace

#### Scenario: Repo stays green after deletion

- **WHEN** `npm run verify` runs after deletion
- **THEN** typecheck, lint, format-check, build, and all tests (TS workspaces plus the surviving `tests/ai_scripts/*.sh` suites, including the updated e2e suite) pass
