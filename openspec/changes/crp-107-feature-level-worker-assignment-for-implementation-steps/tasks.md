## 1. Add the feature-level assignment command

- [x] 1.1 Add `overmind/scripts/feature_assing_workers.sh` with required `--feature_path <asdlc/projects/<project-id>/<feature-folder>>` parsing and fail-fast feature-path validation.
- [x] 1.2 Enforce implementation-plan readiness checks by requiring parseable `implementation_plan.md` step blocks with `### Step ...` and `#### Repo:` metadata before assignment can run.
- [x] 1.3 Load `<project-path>/workers.yaml`, resolve workers strictly by exact class match plus `status: active`, and reject malformed or missing worker-registry contracts with meaningful errors.
- [x] 1.4 Implement class-level assignment resolution: auto-assign when one worker exists, prompt until exactly one selection when multiple workers exist, and generate deterministic class-scoped error text when none exist.
- [x] 1.5 Rewrite `implementation_plan.md` non-destructively so every step has one `#### Assigned:` value set to worker UUID or deterministic error message while preserving all non-assignment content.

## 2. Stage and document the command

- [x] 2.1 Update `overmind/scripts/project_mgmt/project_setup_first_init_machine.sh` so bootstrap and update flows stage `feature_assing_workers.sh` into `<asdlc>/.commands/`.
- [x] 2.2 Update staged quickrun guidance and `overmind/README.md` with command usage, readiness preconditions, class-strict matching, multi-worker selection flow, and assignment-error behavior.

## 3. Add regression coverage

- [x] 3.1 Add a shell test suite under `tests/ai_scripts/` covering missing/invalid `--feature_path`, missing plan, malformed plan, and missing/invalid worker-registry readiness errors.
- [x] 3.2 Add tests covering strict class filtering (`backend`/`frontend`/`mobile`), exclusion of non-active workers, and class-level multi-worker interactive selection retry behavior.
- [x] 3.3 Add tests proving final `implementation_plan.md` output includes `#### Assigned:` on every step with UUID for staffed classes and deterministic error text for unstaffed classes, while preserving step structure and checklist content.

## 4. Validate change readiness

- [x] 4.1 Run relevant shell suites from repository root, including the new assignment suite plus impacted staging/setup suites.
- [x] 4.2 Run `openspec status --change crp-107-feature-level-worker-assignment-for-implementation-steps` and confirm the change is apply-ready.
