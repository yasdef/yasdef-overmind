## 1. TypeScript Installer

- [x] 1.1 Update `packages/installer/src/init.ts` to define supported runner skill targets for `.codex/skills/overmind-task-to-br/` and `.claude/skills/overmind-task-to-br/`
- [x] 1.2 Copy the canonical `packages/installer/_data/skills/overmind-task-to-br/` folder into every supported runner target during `installProject`
- [x] 1.3 Keep `.overmind/overmind.js` as the only installed CLI path and avoid copying the CLI into runner skill directories
- [x] 1.4 Update installer return metadata so tests/callers can inspect all installed skill paths without losing the existing `skillPath` compatibility field if needed

## 2. ASDLC Setup Staging

- [x] 2.1 Add packaged skill source constants and supported runner target constants to `overmind/scripts/project_mgmt/project_setup_first_init_machine.sh`
- [x] 2.2 Add preflight validation that fails clearly when `packages/installer/_data/skills/overmind-task-to-br/` or its `SKILL.md`/`assets/` payload is missing
- [x] 2.3 Add a staging function that copies the canonical skill folder into `<asdlc>/.codex/skills/overmind-task-to-br/` and `<asdlc>/.claude/skills/overmind-task-to-br/`
- [x] 2.4 Wire skill staging into both fresh setup and update mode without changing `.overmind/overmind.js` staging behavior
- [x] 2.5 Ensure update mode repairs missing or stale runner skill folders from canonical source

## 3. Tests

- [x] 3.1 Update `packages/installer/test/init.test.ts` to assert both `.codex/skills/overmind-task-to-br/SKILL.md` and `.claude/skills/overmind-task-to-br/SKILL.md` are installed with assets
- [x] 3.2 Add or update installer tests proving `.overmind/overmind.js` remains the shared CLI and no runner skill folder contains a runner-specific CLI copy
- [x] 3.3 Update `tests/ai_scripts/project_setup_asdlc_tests.sh` to assert fresh ASDLC setup stages Codex and Claude skill folders
- [x] 3.4 Update setup/update tests to assert update mode repairs a missing `.codex/skills/overmind-task-to-br/` folder and preserves `.overmind/overmind.js`
- [x] 3.5 Add a setup failure test for a missing canonical skill source or missing required skill payload file

## 4. Documentation

- [x] 4.1 Update `README.md` setup notes to say setup stages `.overmind/overmind.js` plus `.codex/skills/overmind-task-to-br/` and `.claude/skills/overmind-task-to-br/`
- [x] 4.2 Update `QUICKRUN.md` to show the same runtime workspace outputs and keep the `npm install` / `npm run build` prerequisite
- [x] 4.3 Update migration/distribution design docs if needed to distinguish supported CRP-130 runner targets from deferred `.github/.agents` fan-out

## 5. Verification

- [x] 5.1 Run `npm test`
- [x] 5.2 Run `bash tests/ai_scripts/project_setup_asdlc_tests.sh`
- [x] 5.3 Run any focused setup/update shell suite touched by this change
- [x] 5.4 Run `git diff --check`
- [x] 5.5 Run `openspec validate crp-130-correct-runner-skill-installation --strict`
