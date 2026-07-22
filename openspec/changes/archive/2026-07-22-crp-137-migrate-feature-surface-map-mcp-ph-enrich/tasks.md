## 1. Context Module (asdlc-coordinator)

- [x] 1.1 Add `packages/asdlc-coordinator/src/context/surface-map-enrich.ts` — scan surface maps for placeholder literal, collect KB source names from `external_sources.yaml`, emit no-op block or full enrichment context
- [x] 1.2 Export `buildSurfaceMapEnrichContext` from `packages/asdlc-coordinator/src/context/index.ts`
- [x] 1.3 Register `surface-map-enrich` in `contextRegistry` in `packages/asdlc-coordinator/src/cli/run.ts`

## 2. TS Tests (asdlc-coordinator)

- [x] 2.1 Add context tests: no-op when no surface maps contain placeholder — assert exit 0 and `no_op: true` in output
- [x] 2.2 Add context tests: no-op when no eligible KB sources configured — assert exit 0 and `no_op: true` in output
- [x] 2.3 Add context tests: full context emitted with backend map path, gate command, and KB source name when both present
- [x] 2.4 Add context tests: multiple class maps listed when multiple classes have placeholders
- [x] 2.5 Add context tests: exit 2 when `external_sources.yaml` is missing and surface maps have placeholders
- [x] 2.6 Add context tests: exit 2 when feature path does not resolve under `projects/<id>/<feature>/`
- [x] 2.7 Run `npm test --workspace packages/asdlc-coordinator` and confirm all tests pass

## 3. Skill Package

- [x] 3.1 Create `packages/installer/_data/skills/overmind-surface-map-enrich/SKILL.md` with YAML frontmatter, Required Invocation section (context command, allowed write surface, per-class gate command, gate exit-code handling), final response line, and inlined enrichment rule (from `feature_surface_map_mcp_placeholder_enrichment_rule.md`)
- [x] 3.2 Verify no `assets/` directory is needed (enrichment step patches existing files; no template or golden example required)

## 4. Installer

- [x] 4.1 Add `"overmind-surface-map-enrich"` to `PACKAGED_SKILLS` array in `packages/installer/src/init.ts`
- [x] 4.2 Add installer tests: fresh install copies `overmind-surface-map-enrich` to `.codex/skills/` and `.claude/skills/`
- [x] 4.3 Add installer tests: install fails before writing runner targets when `SKILL.md` is missing from packaged skill
- [x] 4.4 Run `npm test --workspace packages/installer` and confirm all tests pass

## 5. Setup Staging (project_setup_first_init_machine.sh)

- [x] 5.1 Add `"overmind-surface-map-enrich"` to `SKILL_NAMES` array
- [x] 5.2 Remove `FEATURE_SURFACE_MAP_MCP_PLACEHOLDER_ENRICHMENT_SCRIPT` constant and all references to `feature_surface_map_mcp_placeholder_enrichment.sh` from staging arrays
- [x] 5.3 Remove `feature_surface_map_mcp_placeholder_enrichment_rule.md` from rule staging constants and arrays
- [x] 5.4 Update quickrun docs block in the setup script to reflect the new skill and remove old bash references

## 6. E2e Runner (project_add_feature_e2e.sh)

- [x] 6.1 Add `SURFACE_MAP_ENRICH_SKILL_FILE` constant pointing to `.codex/skills/overmind-surface-map-enrich/SKILL.md`
- [x] 6.2 Add `build_surface_map_enrich_prompt` function: prompt includes skill name, workspace root, feature path, `context surface-map-enrich` command, per-class `gate surface-map` commands, and OVERMIND_CLI_FILE path; must not include literal final-response lines from SKILL.md
- [x] 6.3 Add `run_surface_map_enrich_skill` function: snapshot `external_sources.yaml` and `init_progress_definition.yaml` before session, launch Codex with the skill prompt, `cmp`-assert both files are byte-unchanged after session
- [x] 6.4 Replace phase `7.1` legacy bash invocation in `run_phase_by_index` with a `confirm_start` + `run_surface_map_enrich_skill` block (optional phase pattern matching `5.1`)
- [x] 6.5 Ensure the e2e does NOT run the gate itself for phase 7.1 — only the model/skill owns the gate loop

## 7. E2e Tests (project_add_feature_e2e_tests.sh)

- [x] 7.1 Add test: phase 7.1 prompts to load `overmind-surface-map-enrich` skill and includes exact `context surface-map-enrich` command
- [x] 7.2 Add test: phase 7.1 prompt includes a `gate surface-map` command with `--class` argument (not `gate surface-map-enrich`)
- [x] 7.3 Add test: phase 7.1 prompt does not duplicate literal final-response lines from SKILL.md
- [x] 7.4 Add test: phase 7.1 asserts that the e2e does not shell out to the gate command itself (model-only)
- [x] 7.5 Run `bash tests/ai_scripts/project_add_feature_e2e_tests.sh` and confirm all tests pass

## 8. Delete Old Bash Artifacts

- [x] 8.1 Delete `overmind/scripts/feature_surface_map_mcp_placeholder_enrichment.sh`
- [x] 8.2 Delete `overmind/rules/feature_surface_map_mcp_placeholder_enrichment_rule.md`
- [x] 8.3 Delete `tests/ai_scripts/feature_surface_map_mcp_placeholder_enrichment_tests.sh`
- [x] 8.4 Remove `feature_surface_map_mcp_placeholder_enrichment_tests.sh` from `CLAUDE.md` test listing

## 9. Documentation and Final Checks

- [x] 9.1 Update `overmind/README.md` step 7.1 entry: reference the `overmind-surface-map-enrich` skill and `overmind context surface-map-enrich` command; remove the old bash command reference
- [x] 9.2 Update `design_docs/to_skills_migration/migration_to_skill_architecture_overview.md` step 7.1 row: mark as **done** (CRP-137)
- [x] 9.3 Run `bash tests/ai_scripts/project_setup_asdlc_tests.sh` and confirm all tests pass
- [x] 9.4 Run `git diff --check` — no whitespace errors
