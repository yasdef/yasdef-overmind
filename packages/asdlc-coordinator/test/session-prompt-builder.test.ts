import assert from "node:assert/strict";
import test from "node:test";

import { STEP_CATALOG } from "../src/sequencing/index.js";
import { buildSessionPrompt } from "../src/runner/index.js";

const BASE_BINDINGS = {
  runtimeRoot: "/runtime",
  featurePath: "projects/project-a/feature-alpha",
  overmindCliPath: ".overmind/overmind.js"
} as const;

const EXPECTED_PROMPTS: Record<string, string> = {
  "task-to-br": `Use the overmind-task-to-br skill for this feature.

Runtime bindings:
- ASDLC workspace root: /runtime
- Current working directory for all commands: /runtime
- Feature path: projects/project-a/feature-alpha
- Feature BR summary artifact: projects/project-a/feature-alpha/feature_br_summary.md
- Captured user input artifact: projects/project-a/feature-alpha/user_br_input.md
- Missing-data artifact: projects/project-a/feature-alpha/missing_br_data.md
- Overmind CLI: .overmind/overmind.js

Required flow:
- Load and follow the overmind-task-to-br skill.
- If projects/project-a/feature-alpha/user_br_input.md is missing, ask the operator for exactly one source: either a local .txt/.md source file inside the feature folder, or a Jira ticket.
- If projects/project-a/feature-alpha/user_br_input.md already exists, do not ask for a new source unless the skill requires recovery.
- Use exactly one capture command only when capture is needed:
  node .overmind/overmind.js capture task-to-br projects/project-a/feature-alpha --source-file <path-to-story.md-or.txt>
  node .overmind/overmind.js capture task-to-br projects/project-a/feature-alpha --jira <ticket>
- Then assemble deterministic context with:
  node .overmind/overmind.js context task-to-br projects/project-a/feature-alpha
- Update only the artifacts allowed by the skill.
- Validate after every write or repair with:
  node .overmind/overmind.js gate task-to-br projects/project-a/feature-alpha
- Handle gate exit codes exactly as the skill defines.`,
  "repo-br-scan": `Load and follow the overmind-repo-br-scan skill for this feature.

Runtime bindings:
- ASDLC workspace root: /runtime
- Current working directory for all commands: /runtime
- Feature path: projects/project-a/feature-alpha
- Feature BR summary artifact: projects/project-a/feature-alpha/feature_br_summary.md
- Overmind CLI: .overmind/overmind.js

Required flow:
- Load and follow the overmind-repo-br-scan skill.
- Assemble deterministic context with:
  node .overmind/overmind.js context repo-br-scan projects/project-a/feature-alpha
- Follow the skill's instructions exactly.
- Validate after every write or repair with:
  node .overmind/overmind.js gate repo-br-scan projects/project-a/feature-alpha
- Handle gate exit codes as defined in the skill.`,
  "br-clarification": `Load and follow the overmind-br-clarification skill for this feature.

Runtime bindings:
- ASDLC workspace root: /runtime
- Current working directory for all commands: /runtime
- Feature path: projects/project-a/feature-alpha
- Feature BR summary artifact: projects/project-a/feature-alpha/feature_br_summary.md
- Missing-data artifact: projects/project-a/feature-alpha/missing_br_data.md
- Overmind CLI: .overmind/overmind.js

Required flow:
- Load and follow the overmind-br-clarification skill.
- Assemble deterministic context with:
  node .overmind/overmind.js context br-clarification projects/project-a/feature-alpha
- Use the exact gate command below when the skill tells you to validate:
  node .overmind/overmind.js gate br-clarification projects/project-a/feature-alpha`,
  "requirements-ears": `Load and follow the overmind-requirements-ears skill for this feature.

Runtime bindings:
- ASDLC workspace root: /runtime
- Current working directory for all commands: /runtime
- Feature path: projects/project-a/feature-alpha
- Read-only BR summary artifact: projects/project-a/feature-alpha/feature_br_summary.md
- Target EARS artifact: projects/project-a/feature-alpha/requirements_ears.md
- Overmind CLI: .overmind/overmind.js

Required flow:
- Load and follow the overmind-requirements-ears skill.
- Assemble deterministic context with:
  node .overmind/overmind.js context requirements-ears projects/project-a/feature-alpha
- Use the exact gate command below when the skill tells you to validate:
  node .overmind/overmind.js gate requirements-ears projects/project-a/feature-alpha`,
  "ears-review": `Load and follow the overmind-ears-review skill for this feature.

Runtime bindings:
- ASDLC workspace root: /runtime
- Current working directory for all commands: /runtime
- Feature path: projects/project-a/feature-alpha
- Read-only authoritative BR summary artifact: projects/project-a/feature-alpha/feature_br_summary.md
- Read-only raw capture source artifact: projects/project-a/feature-alpha/user_br_input.md
- Read-only clarification ledger artifact: projects/project-a/feature-alpha/missing_br_data.md
- Mutable EARS artifact: projects/project-a/feature-alpha/requirements_ears.md
- Review ledger artifact: projects/project-a/feature-alpha/requirements_ears_review.md
- Overmind CLI: .overmind/overmind.js

Required flow:
- Load and follow the overmind-ears-review skill.
- Assemble deterministic context with:
  node .overmind/overmind.js context ears-review projects/project-a/feature-alpha
- Use the exact gate command below when the skill tells you to validate:
  node .overmind/overmind.js gate ears-review projects/project-a/feature-alpha`,
  "contract-delta": `Load and follow the overmind-contract-delta skill for this feature.

Runtime bindings:
- ASDLC workspace root: /runtime
- Current working directory for all commands: /runtime
- Feature path: projects/project-a/feature-alpha
- Target contract delta artifact: projects/project-a/feature-alpha/feature_contract_delta.md
- Overmind CLI: .overmind/overmind.js

Required flow:
- Load and follow the overmind-contract-delta skill.
- Assemble deterministic context with:
  node .overmind/overmind.js context contract-delta projects/project-a/feature-alpha
- Use the exact gate command below when the skill tells you to validate:
  node .overmind/overmind.js gate contract-delta projects/project-a/feature-alpha`,
  "stack-blueprint": `Load and follow the overmind-stack-blueprint skill for this project class.

Runtime bindings:
- ASDLC workspace root: /runtime
- Current working directory for all commands: /runtime
- Project path: projects/project-a/feature-alpha
- Target class: backend
- Target stack blueprint artifact: projects/project-a/feature-alpha/project_stack_blueprint_backend.md
- Overmind CLI: .overmind/overmind.js

Required flow:
- Load and follow the overmind-stack-blueprint skill.
- Assemble deterministic context with:
  node .overmind/overmind.js context stack-blueprint projects/project-a/feature-alpha --class backend
- Use the exact gate command below when the skill tells you to validate:
  node .overmind/overmind.js gate stack-blueprint projects/project-a/feature-alpha/project_stack_blueprint_backend.md
- The model owns the gate loop; this orchestrator does not run the gate.`,
  "agents-md": `Load and follow the overmind-agents-md skill for this project class.

Runtime bindings:
- ASDLC workspace root: /runtime
- Current working directory for all commands: /runtime
- Project path: projects/project-a/feature-alpha
- Target class: backend
- Target agents-md artifact: projects/project-a/feature-alpha/project_agents_md_claude_md_backend.md
- Read-only source blueprint: projects/project-a/feature-alpha/project_stack_blueprint_backend.md
- Overmind CLI: .overmind/overmind.js

Required flow:
- Load and follow the overmind-agents-md skill.
- Assemble deterministic context with:
  node .overmind/overmind.js context agents-md projects/project-a/feature-alpha --class backend
- Use the exact gate command below when the skill tells you to validate:
  node .overmind/overmind.js gate agents-md projects/project-a/feature-alpha/project_agents_md_claude_md_backend.md
- Treat the source blueprint as read-only.
- The model owns the gate loop; this orchestrator does not run the gate.`,
  "common-contract": `Load and follow the overmind-common-contract skill for this project.

Runtime bindings:
- ASDLC workspace root: /runtime
- Current working directory for all commands: /runtime
- Project path: projects/project-a/feature-alpha
- Target common contract artifact: projects/project-a/feature-alpha/common_contract_definition.md
- Overmind CLI: .overmind/overmind.js

Required flow:
- Load and follow the overmind-common-contract skill.
- Assemble deterministic context with:
  node .overmind/overmind.js context common-contract projects/project-a/feature-alpha
- Write only common_contract_definition.md; never modify init_progress_definition.yaml, stack blueprints, or attached repos.
- Use the exact gate command below when the skill tells you to validate:
  node .overmind/overmind.js gate common-contract projects/project-a/feature-alpha
- The model owns the gate loop; this orchestrator does not run the gate.`,
  "surface-map": `Load and follow the overmind-surface-map skill for this feature and class.

Runtime bindings:
- ASDLC workspace root: /runtime
- Current working directory for all commands: /runtime
- Feature path: projects/project-a/feature-alpha
- Target class: backend
- Target surface map artifact: projects/project-a/feature-alpha/project_surface_struct_resp_map_backend.md
- Overmind CLI: .overmind/overmind.js

Required flow:
- Load and follow the overmind-surface-map skill.
- Assemble deterministic context with:
  node .overmind/overmind.js context surface-map projects/project-a/feature-alpha --class backend
- Use the exact gate command below when the skill tells you to validate:
  node .overmind/overmind.js gate surface-map projects/project-a/feature-alpha --class backend`,
  "surface-map-enrich": `Load and follow the overmind-surface-map-enrich skill for this feature.

Runtime bindings:
- ASDLC workspace root: /runtime
- Current working directory for all commands: /runtime
- Feature path: projects/project-a/feature-alpha
- Overmind CLI: .overmind/overmind.js

Required flow:
- Load and follow the overmind-surface-map-enrich skill.
- Assemble deterministic context with:
  node .overmind/overmind.js context surface-map-enrich projects/project-a/feature-alpha
- When the skill tells you to validate, use the per-class gate command:
  node .overmind/overmind.js gate surface-map projects/project-a/feature-alpha --class <backend|frontend|mobile>
- The model owns the gate loop; this orchestrator does not run the gate.`,
  "technical-requirements": `Load and follow the overmind-technical-requirements skill for this feature.

Runtime bindings:
- ASDLC workspace root: /runtime
- Current working directory for all commands: /runtime
- Feature path: projects/project-a/feature-alpha
- Target artifact: projects/project-a/feature-alpha/technical_requirements.md
- Overmind CLI: .overmind/overmind.js

Required flow:
- Load and follow the overmind-technical-requirements skill.
- Assemble deterministic context with:
  node .overmind/overmind.js context technical-requirements projects/project-a/feature-alpha
- Use the exact gate command below when the skill tells you to validate:
  node .overmind/overmind.js gate technical-requirements projects/project-a/feature-alpha
- The model owns the gate loop; this orchestrator does not run the gate.`,
  "implementation-slices": `Load and follow the overmind-implementation-slices skill for this feature.

Runtime bindings:
- ASDLC workspace root: /runtime
- Current working directory for all commands: /runtime
- Feature path: projects/project-a/feature-alpha
- Target artifact: projects/project-a/feature-alpha/implementation_slices.md
- Overmind CLI: .overmind/overmind.js

Required flow:
- Load and follow the overmind-implementation-slices skill.
- Assemble deterministic context with:
  node .overmind/overmind.js context implementation-slices projects/project-a/feature-alpha
- Use the exact gate command below when the skill tells you to validate:
  node .overmind/overmind.js gate implementation-slices projects/project-a/feature-alpha
- The model owns the gate loop; this orchestrator does not run the gate.`,
  "prerequisite-gaps": `Load and follow the overmind-prerequisite-gaps skill for this feature.

Runtime bindings:
- ASDLC workspace root: /runtime
- Current working directory for all commands: /runtime
- Feature path: projects/project-a/feature-alpha
- Target artifact: projects/project-a/feature-alpha/prerequisite_gaps.md
- Overmind CLI: .overmind/overmind.js

Required flow:
- Load and follow the overmind-prerequisite-gaps skill.
- Assemble deterministic context with:
  node .overmind/overmind.js context prerequisite-gaps projects/project-a/feature-alpha
- Use the exact gate command below when the skill tells you to validate:
  node .overmind/overmind.js gate prerequisite-gaps projects/project-a/feature-alpha
- The model owns the gate loop; this orchestrator does not run the gate.`,
  "implementation-plan": `Load and follow the overmind-implementation-plan skill for this feature.

Runtime bindings:
- ASDLC workspace root: /runtime
- Current working directory for all commands: /runtime
- Feature path: projects/project-a/feature-alpha
- Target artifact: projects/project-a/feature-alpha/implementation_plan.md
- Overmind CLI: .overmind/overmind.js

Required flow:
- Load and follow the overmind-implementation-plan skill.
- Assemble deterministic context with:
  node .overmind/overmind.js context implementation-plan projects/project-a/feature-alpha
- Use the exact gate command below when the skill tells you to validate:
  node .overmind/overmind.js gate implementation-plan projects/project-a/feature-alpha
- The model owns the gate loop; this orchestrator does not run the gate.`,
  "plan-semantic-review": `Load and follow the overmind-plan-semantic-review skill for this feature.

Runtime bindings:
- ASDLC workspace root: /runtime
- Current working directory for all commands: /runtime
- Feature path: projects/project-a/feature-alpha
- Overmind CLI: .overmind/overmind.js

Required flow:
- Load and follow the overmind-plan-semantic-review skill.
- Assemble deterministic context with:
  node .overmind/overmind.js context plan-semantic-review projects/project-a/feature-alpha
- Use the exact review-ledger gate command when the skill tells you to validate the review ledger:
  node .overmind/overmind.js gate plan-semantic-review projects/project-a/feature-alpha
- Use the exact implementation-plan gate command when the skill tells you to validate the plan:
  node .overmind/overmind.js gate implementation-plan projects/project-a/feature-alpha
- The model owns both gate loops; this orchestrator does not run either gate.`
};

test("buildSessionPrompt preserves parity across all session phases", () => {
  const actions = STEP_CATALOG.flatMap((step) => step.actions).filter(
    (
      action
    ): action is Extract<(typeof STEP_CATALOG)[number]["actions"][number], { kind: "session" }> =>
      action.kind === "session"
  );

  assert.equal(actions.length, 16);

  for (const action of actions) {
    const prompt = buildSessionPrompt(action, {
      ...BASE_BINDINGS,
      targetClass:
        action.skillName === "surface-map" ||
        action.skillName === "stack-blueprint" ||
        action.skillName === "agents-md"
          ? "backend"
          : undefined
    });
    assert.equal(prompt, EXPECTED_PROMPTS[action.skillName]);
    assert.doesNotMatch(prompt, /final response/i);
  }
});
