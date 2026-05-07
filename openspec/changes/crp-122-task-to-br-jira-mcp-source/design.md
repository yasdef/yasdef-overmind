## Context

`feature_task_to_br.sh` (step 3 of the ASDLC feature workflow) currently collects an epic/story source exclusively as a local `.txt`/`.md` file inside the feature folder. The relevant function is `prompt_epic_story_source_file` (lines 237–250), which loops until a valid file is provided, then reads its content with `cat` before writing `user_br_input.md` and invoking the model.

The change adds a Jira MCP alternative input path. Because the shell script has no access to MCP tools — MCP is a model-level capability — the approach is: the shell captures the ticket number from the user, writes it as metainfo, and injects a Jira MCP fetch instruction into the model prompt. The model then attempts the MCP call and handles fallback dialogue itself.

## Goals / Non-Goals

**Goals:**
- Add a two-option choice menu before any source-specific prompting.
- Preserve file path branch behaviour with zero changes.
- Capture Jira ticket number, record it in `user_br_input.md` capture meta, and pass MCP fetch instructions to the model.
- Model is responsible for attempting Jira MCP fetch and for fallback dialogue when MCP is unavailable or the ticket is not found.

**Non-Goals:**
- Shell-level Jira API or MCP invocation; the shell only reads `external_sources.yaml` and passes eligible names to the prompt.
- Pre-flight validation that a Jira MCP is reachable before the model runs.
- Changes to any script other than `feature_task_to_br.sh` and its test file.
- Changes to template files, rule files, or the `write_user_input_context` file format beyond adding one optional `jira_ticket` field.

## Decisions

### D1 — Shell resolves the Jira MCP name from `external_sources.yaml`; model does the fetch and fallback

**Decision:** Before building the model prompt, the shell reads `.setup/external_sources.yaml` and extracts entries whose `type` contains `jira`. The matching `name` value(s) are passed into the prompt as "Eligible Jira MCP source names". The model then uses those names to locate and invoke the correct MCP server, and handles fallback dialogue if none is reachable or the ticket is not found.

**Rationale:** This mirrors the exact pattern used by `feature_surface_map_mcp_placeholder_enrichment.sh` (step 7.1), which reads `EXTERNAL_SOURCES_FILE=".setup/external_sources.yaml"`, extracts eligible source names, and passes them to `build_prompt`. Using `external_sources.yaml` as the single source of truth for configured MCP servers keeps the script consistent with the rest of the ASDLC toolchain and avoids hardcoding MCP server names in the prompt.

**Alternative considered:** Shell makes an HTTP call to a local MCP proxy. Rejected — introduces a runtime dependency and network assumption that may not exist in all environments.

**Alternative considered:** Prompt tells model to search for any MCP with "jira" in its name (without consulting `external_sources.yaml`). Rejected — bypasses the canonical MCP registry and could match unintended servers.

### D2 — Choice menu is a numbered prompt printed to stderr

**Decision:** A new `prompt_input_source_choice` function prints a two-item numbered list to stderr and reads `1` or `2`. Invalid input loops back with an error message.

**Rationale:** Consistent with the existing `prompt_required_input` pattern. Avoids adding external tools (e.g. `select` builtin is bash-specific and less portable).

### D3 — Jira ticket number stored as `jira_ticket` in `## 1. Capture Meta`

**Decision:** `write_user_input_context` gains an optional `jira_ticket` parameter. When non-empty, it appends `- jira_ticket: <value>` to the Capture Meta section. `epic_story_source_file` is set to `jira:<ticket_number>`.

**Rationale:** Keeps all capture-time metainfo in the existing meta section. Downstream steps reading `user_br_input.md` can detect the source type from `epic_story_source_file` without a schema change.

### D4 — Ticket number validated as non-empty; no format enforcement in shell

**Decision:** The shell only rejects an empty ticket number. Format validation (e.g. `PROJ-123`) is left to the model.

**Rationale:** Jira project key formats vary. Enforcing a regex in shell risks false negatives without adding meaningful safety.

## Risks / Trade-offs

- **Model fallback mid-session creates partially written `user_br_input.md`**: When Jira MCP fails, the model asks what to do and may guide the user to provide a file path. `user_br_input.md` is already written with an empty `epic_or_story` block. The model must update the file on fallback — this is already its responsibility via the task-to-BR rule, so no new invariant is introduced.
  → Mitigation: the model prompt instruction for Jira MCP explicitly states the model must update `user_br_input.md` if it falls back to file input.

- **Users unfamiliar with Jira MCP may select it and hit dead ends**: The choice menu wording makes clear that MCP must be configured; the model fallback message reinforces this.
  → Mitigation: choice menu label includes a brief note: "requires Jira MCP configured in your model environment".
