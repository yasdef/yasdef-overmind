## 1. Input Source Choice Dialogue

- [x] 1.1 Add `prompt_input_source_choice` function that prints a two-option numbered menu to stderr and reads user input, looping on invalid input
- [x] 1.2 Integrate `prompt_input_source_choice` call in `main` before the existing `prompt_epic_story_source_file` call

## 2. Jira MCP Branch — Shell Side

- [x] 2.1 Add `prompt_jira_ticket_number` function that prompts for a non-empty ticket number, rejecting empty input with re-prompt
- [x] 2.2 Update `write_user_input_context` to accept an optional `jira_ticket` parameter and write `- jira_ticket: <value>` in `## 1. Capture Meta` when non-empty
- [x] 2.3 Set `epic_story_source_file` to `jira:<ticket_number>` when Jira path is taken

## 3. external_sources.yaml Lookup

- [x] 3.1 Add `EXTERNAL_SOURCES_FILE=".setup/external_sources.yaml"` variable to the script (consistent with step 7.1 pattern)
- [x] 3.2 Add `extract_jira_source_names` function that reads `.setup/external_sources.yaml`, filters entries whose `type` contains `jira`, and returns the matching `name` values as a newline-separated list (empty list is valid)
- [x] 3.3 Call `extract_jira_source_names` in `main` when the Jira path is taken and store the result for use in `build_prompt`

## 4. Model Prompt — Jira MCP Instruction

- [x] 4.1 Update `build_prompt` to accept a Jira source names parameter; when Jira path is taken, include `external_sources.yaml` as a read-only input reference and list the eligible Jira MCP source names; instruct the model to use one of those named MCPs to fetch the ticket, and to ask the user what to do (mentioning the file option) if MCP is unavailable, list is empty, or ticket not found

## 5. Tests

- [x] 5.1 Add test: user selects file path option (option `1`) → existing behaviour unchanged, no `jira_ticket` field in `user_br_input.md`, no Jira MCP instruction in prompt
- [x] 5.2 Add test: user selects Jira MCP option (option `2`) with a matching `external_sources.yaml` entry and valid ticket number → `jira_ticket` written in `user_br_input.md`, `epic_story_source_file` set to `jira:<ticket>`, model prompt contains the resolved MCP name and fetch instruction
- [x] 5.3 Add test: Jira path with no matching entry in `external_sources.yaml` → eligible source list is empty, prompt still contains Jira fetch instruction with empty source list and fallback guidance
- [x] 5.4 Add test: invalid choice input loops, then valid choice proceeds correctly
- [x] 5.5 Add test: empty ticket number rejected, non-empty accepted
