## Why

Step 3 "Initialize and Enrich Business Requirements Structuring" currently requires users to provide a local `.txt` or `.md` file as the epic/story source, forcing teams using Jira to manually export ticket content before running the script. Adding a Jira MCP path lets users provide a ticket number instead, with the model fetching the content automatically when a Jira MCP is configured.

## What Changes

- `feature_task_to_br.sh`: new upfront input-source choice dialogue — user selects between "provide file path" or "use Jira MCP ticket number" before any further prompting.
- File path branch: preserves all current behaviour exactly (no changes to existing validation, prompts, or output).
- Jira MCP branch:
  - User is prompted for a Jira ticket number (e.g. `PROJ-123`).
  - Ticket number is recorded as `jira_ticket` metainfo in `user_br_input.md` (new field in `## 1. Capture Meta`).
  - `epic_story_source_file` is set to `jira:<ticket_number>` as the source marker.
  - The model prompt instructs the model to find and invoke a Jira-named MCP tool to fetch the ticket content, and — if MCP is unavailable, misconfigured, or lacks the ticket — to ask the user what to do and mention that a `.txt`/`.md` file path can be provided instead.
- `build_prompt` updated: includes a Jira MCP fetch instruction block when the Jira path is taken.
- `write_user_input_context` updated: writes `jira_ticket` field to `## 1. Capture Meta` when the Jira path is taken.
- Tests: new test cases covering the Jira MCP input-source choice path (ticket number capture, metainfo written to `user_br_input.md`, prompt contains Jira MCP instruction); existing tests are unaffected.

## Capabilities

### New Capabilities
- `jira-mcp-story-source`: Adds a Jira MCP ticket number as an alternative input source for the BR enrichment step, with model-driven MCP fetch and graceful fallback dialogue when MCP is not available or the ticket cannot be retrieved.

### Modified Capabilities

## References

- Jira: CRP-122

## Impact

- `overmind/scripts/feature_task_to_br.sh` — primary change: new choice prompt, Jira branch, prompt and output changes.
- `tests/ai_scripts/init_task_to_br_tests.sh` — new test cases for the Jira MCP path.
- No changes to `feature_br_scaffold.sh`, template files, rule files, or any other script.
- No changes to the `user_br_input.md` template structure beyond adding the optional `jira_ticket` field in `## 1. Capture Meta`.
