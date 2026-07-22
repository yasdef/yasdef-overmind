## ADDED Requirements

### Requirement: Input source choice dialogue
Before collecting any epic/story source, `feature_task_to_br.sh` SHALL present the user with a numbered choice menu offering two options: (1) provide a local file path, and (2) use a Jira MCP ticket number. The menu SHALL be printed to stderr. Invalid input SHALL loop with an error message until a valid choice is entered.

#### Scenario: User selects file path option
- **WHEN** user enters `1` at the input source choice prompt
- **THEN** the script proceeds with the existing file path prompting flow with no behaviour change

#### Scenario: User selects Jira MCP option
- **WHEN** user enters `2` at the input source choice prompt
- **THEN** the script proceeds to prompt for a Jira ticket number

#### Scenario: User enters invalid choice
- **WHEN** user enters anything other than `1` or `2`
- **THEN** the script prints an error to stderr and re-prompts the choice menu

---

### Requirement: Jira ticket number capture
When the Jira MCP path is selected, the script SHALL prompt the user for a Jira ticket number. An empty value SHALL be rejected and re-prompted. Any non-empty string SHALL be accepted.

#### Scenario: Valid ticket number provided
- **WHEN** user enters a non-empty string (e.g. `CRP-122`) at the ticket number prompt
- **THEN** the value is stored for use as metainfo and in the model prompt

#### Scenario: Empty ticket number rejected
- **WHEN** user enters an empty string at the ticket number prompt
- **THEN** the script prints an error to stderr and re-prompts

---

### Requirement: Jira ticket stored as capture metainfo
When the Jira MCP path is taken, `write_user_input_context` SHALL write `- jira_ticket: <ticket_number>` in the `## 1. Capture Meta` section of `user_br_input.md`, and SHALL set `epic_story_source_file` to `jira:<ticket_number>`.

#### Scenario: user_br_input.md written with Jira metainfo
- **WHEN** the Jira MCP path is taken and the ticket number is captured
- **THEN** `user_br_input.md` contains `jira_ticket: <ticket_number>` in `## 1. Capture Meta`
- **THEN** `user_br_input.md` contains `epic_story_source_file: jira:<ticket_number>`

#### Scenario: File path branch does not write jira_ticket field
- **WHEN** the file path branch is taken
- **THEN** `user_br_input.md` does NOT contain a `jira_ticket` field

---

### Requirement: Shell resolves eligible Jira MCP names from external_sources.yaml
Before building the model prompt, the script SHALL read `.setup/external_sources.yaml` and extract the `name` field of every entry whose `type` contains `jira`. The extracted names SHALL be passed to `build_prompt` as the eligible Jira MCP source list. When no matching entry exists, the list SHALL be empty (not an error).

#### Scenario: One matching Jira entry in external_sources.yaml
- **WHEN** `external_sources.yaml` contains an entry with `type: jira` and `name: my-jira`
- **THEN** the eligible Jira source list passed to `build_prompt` contains `my-jira`

#### Scenario: No matching Jira entry in external_sources.yaml
- **WHEN** `external_sources.yaml` has no entry whose `type` contains `jira`
- **THEN** the eligible Jira source list is empty

#### Scenario: Multiple matching entries
- **WHEN** `external_sources.yaml` contains multiple entries with `type` containing `jira`
- **THEN** all matching `name` values are included in the eligible source list

---

### Requirement: Model prompt includes Jira MCP fetch instruction with resolved source names
When the Jira MCP path is taken, the model prompt built by `build_prompt` SHALL include: the path to `external_sources.yaml` as a read-only input; the eligible Jira MCP source names resolved by the shell; and an instruction telling the model to use one of those named MCP servers to fetch the ticket content. If the eligible source list is empty, or the named MCP is unavailable, or the ticket is not found, the model SHALL ask the user what to do and mention that a `.txt` or `.md` file path can be provided instead. When the file path branch is taken, no Jira MCP instruction SHALL appear in the prompt.

#### Scenario: Jira MCP instruction present with source names for Jira path
- **WHEN** the Jira MCP path is taken with ticket number `T-1` and eligible source list `["my-jira"]`
- **THEN** the model prompt contains the eligible Jira source name `my-jira`
- **THEN** the model prompt contains a fetch instruction referencing ticket `T-1`
- **THEN** the prompt instructs the model to ask the user what to do if the MCP is unavailable or ticket not found

#### Scenario: Jira MCP instruction absent for file path
- **WHEN** the file path branch is taken
- **THEN** the model prompt does NOT contain any Jira MCP fetch instruction

---

### Requirement: File path branch behaviour is unchanged
The file path branch SHALL produce identical behaviour to the current script: same prompts, same validation, same `user_br_input.md` structure, same model prompt content.

#### Scenario: File path branch is functionally identical to pre-change behaviour
- **WHEN** user selects option `1` and provides a valid `.txt` or `.md` file inside the feature path root
- **THEN** `user_br_input.md` is written with the file content under `epic_or_story`
- **THEN** the model is invoked with the same prompt structure as before this change
