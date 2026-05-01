## 1. Optional Step 7.1 Workflow Wiring

- [x] 1.1 Update `overmind/templates/init_progress_definition_TEMPLATE.yaml` to add optional Step `7.1` after Step `7` and before Step `8`
- [x] 1.2 Update `overmind/init_progress_definition_sequence_diagram.md` to show Step `7.1` as optional MCP placeholder enrichment after surface-map generation
- [x] 1.3 Update `overmind/scripts/project_mgmt/project_add_feature_e2e.sh` phase mappings so Step `7.1` can be run or declined as an optional phase
- [x] 1.4 Update setup staging in `overmind/scripts/project_mgmt/project_setup_first_init_machine.sh` so the Step `7.1` command and rule are deployed into ASDLC workspaces
- [x] 1.5 Add a `feature_surface_map_mcp_placeholder_enrichment` model phase entry to `overmind/setup/models.md`

## 2. Enrichment Command And Rule

- [x] 2.1 Add `overmind/scripts/feature_surface_map_mcp_placeholder_enrichment.sh` with `--feature_path` handling consistent with existing feature commands
- [x] 2.2 Add `overmind/rules/feature_surface_map_mcp_placeholder_enrichment_rule.md` defining placeholder-only edits, MCP evidence boundaries, user confirmation, and no-audit-artifact behavior
- [x] 2.3 Make the command inspect existing backend, frontend, and mobile surface-map artifacts and skip absent class maps without failing
- [x] 2.4 Make the command scan for the exact literal `<to be defined during implementation>` before checking source configuration or MCP reachability
- [x] 2.5 Make the command snapshot read-only inputs and ensure unconfirmed or skipped enrichment leaves target surface maps unchanged

## 3. Knowledge-Base MCP Source Selection

- [x] 3.1 Parse staged `.setup/external_sources.yaml` for configured sources without introducing non-shell runtime dependencies
- [x] 3.2 Accept only source names that clearly identify a knowledge base, including case-insensitive `knowledge`, `knowledge-base`, `knowledge_base`, or `kb`
- [x] 3.3 Reject sources whose names do not clearly identify knowledge-base authority, even when their type contains knowledge-base wording
- [x] 3.4 Check MCP reachability only after placeholders exist and at least one configured source passes the knowledge-base name filter
- [x] 3.5 Leave placeholders unchanged when no eligible source exists, the source is unreachable, or MCP returns no useful confirmation

## 4. User Confirmation And In-Place Updates

- [x] 4.1 Build model prompt/context for the selected surface map, placeholder inventory, configured knowledge-base source, enrichment rule, and quality helper command
- [x] 4.2 Require a concise replacement summary with target fields, proposed values, and source/evidence before any edit is applied
- [x] 4.3 Require explicit user confirmation before replacing placeholders in a surface-map file
- [x] 4.4 Apply only user-confirmed placeholder replacements and avoid rewriting non-placeholder content
- [x] 4.5 Run `check_feature_repo_surface_and_exec_context_be_quality.sh` after backend edits and `check_feature_repo_surface_and_exec_context_fe_quality.sh` after frontend or mobile edits

## 5. Tests

- [x] 5.1 Add `tests/ai_scripts/feature_surface_map_mcp_placeholder_enrichment_tests.sh`
- [x] 5.2 Add tests proving absent surface maps and maps without placeholders no-op without MCP reachability checks
- [x] 5.3 Add tests proving empty `sources: []` and non-knowledge-base source names leave placeholders unchanged
- [x] 5.4 Add tests proving eligible knowledge-base source names are bound into the prompt only after placeholders are found
- [x] 5.5 Add tests proving user rejection leaves surface maps unchanged and user confirmation applies only selected placeholder replacements
- [x] 5.6 Add tests proving backend and frontend/mobile quality helpers are selected correctly after edits
- [x] 5.7 Update `tests/ai_scripts/init_progress_scanner_tests.sh` to prove optional Step `7.1` does not block Step `8`
- [x] 5.8 Update `tests/ai_scripts/project_add_feature_e2e_tests.sh` to prove optional Step `7.1` can be run or declined without blocking later required phases
- [x] 5.9 Update `tests/ai_scripts/project_setup_asdlc_tests.sh` to prove the Step `7.1` command, rule, setup file, and model phase are staged

## 6. Verification

- [x] 6.1 Run `bash tests/ai_scripts/feature_surface_map_mcp_placeholder_enrichment_tests.sh`
- [x] 6.2 Run `bash tests/ai_scripts/init_progress_scanner_tests.sh`
- [x] 6.3 Run `bash tests/ai_scripts/project_add_feature_e2e_tests.sh`
- [x] 6.4 Run `bash tests/ai_scripts/project_setup_asdlc_tests.sh`
- [x] 6.5 Run `openspec validate crp-118-step-7-mcp-placeholder-enrichment --strict`
