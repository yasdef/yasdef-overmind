## 1. Add staged support-asset mapping and copy logic

- [x] 1.1 Update `overmind/scripts/project_mgmt/project_setup_first_init_machine.sh` to define shared source-to-target mapping for `overmind/rules`, `overmind/templates`, `overmind/golden_examples`, `overmind/scripts/helper`, and `overmind/setup`.
- [x] 1.2 Extend bootstrap to create and populate `asdlc/.rules`, `asdlc/.templates`, `asdlc/.golden_examples`, `asdlc/.helper`, and `asdlc/.setup`, preserve helper executability, and keep `asdlc/templates/init_progress_definition_TEMPLATE.yaml` aligned with the canonical template source.
- [x] 1.3 Extend update mode to create missing staged support-asset directories and refresh managed support-asset files in place without changing existing `.commands` overwrite behavior.

## 2. Update tests and documentation

- [x] 2.1 Extend `tests/ai_scripts/project_setup_asdlc_tests.sh` to assert bootstrap staging for support-asset directories, file presence, and helper execute permissions.
- [x] 2.2 Add update-mode coverage for missing-directory creation, support-asset file refresh, visible template compatibility-path refresh, and preservation of metadata, projects, and existing staged commands.
- [x] 2.3 Update `overmind/README.md` to describe the staged `.rules`, `.templates`, `.golden_examples`, `.helper`, and `.setup` directories plus update-mode synchronization behavior.

## 3. Validate change readiness

- [x] 3.1 Run `bash tests/ai_scripts/project_setup_asdlc_tests.sh` from the repository root.
- [x] 3.2 Run `openspec status --change crp-092-first-init-machine-update-mode-asdlc-asset-sync` and confirm the change is apply-ready.
