## ADDED Requirements

### Requirement: Install result reports skills only through the fan-out list

The installer's `InstallResult` SHALL expose installed runner skills solely through the
`skillPaths` array covering every supported runner × packaged skill. It SHALL NOT expose
a singular `skillPath` compatibility field for any individual skill. The `overmind init`
CLI output SHALL derive its reported skill count and per-skill lines from `skillPaths`.

#### Scenario: InstallResult has no singular skillPath field

- **WHEN** `installProject` returns an `InstallResult`
- **THEN** the result exposes `skillPaths` for all installed runner skills and exposes no
  `skillPath` field

#### Scenario: CLI install output lists skills from skillPaths

- **WHEN** `overmind init` completes a fresh install
- **THEN** the output reports `Skills: <n> installed` where `<n>` equals `skillPaths.length`
  and lists one line per entry in `skillPaths`
