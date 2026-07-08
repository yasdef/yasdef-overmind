import type { Action } from "../sequencing/step-catalog.js";
import type { Diagnostic } from "../types/index.js";

import type { SessionBindings } from "./bindings.js";

interface PromptRecipe {
  intro: (bindings: SessionBindings) => string;
  runtimeBindings: (bindings: SessionBindings) => string[];
  requiredFlow: (bindings: SessionBindings) => string[];
}

const PROMPT_RECIPES: Record<string, PromptRecipe> = {
  "task-to-br": {
    intro: () => "Use the overmind-task-to-br skill for this feature.",
    runtimeBindings: (bindings) => [
      `- ASDLC workspace root: ${bindings.runtimeRoot}`,
      `- Current working directory for all commands: ${bindings.runtimeRoot}`,
      `- Feature path: ${bindings.featurePath}`,
      `- Feature BR summary artifact: ${bindings.featurePath}/feature_br_summary.md`,
      `- Captured user input artifact: ${bindings.featurePath}/user_br_input.md`,
      `- Missing-data artifact: ${bindings.featurePath}/missing_br_data.md`,
      `- Overmind CLI: ${bindings.overmindCliPath}`
    ],
    requiredFlow: (bindings) => [
      "- Load and follow the overmind-task-to-br skill.",
      `- If ${bindings.featurePath}/user_br_input.md is missing, ask the operator for exactly one source: either a local .txt/.md source file inside the feature folder, or a Jira ticket.`,
      `- If ${bindings.featurePath}/user_br_input.md already exists, do not ask for a new source unless the skill requires recovery.`,
      "- Use exactly one capture command only when capture is needed:",
      `  node ${bindings.overmindCliPath} capture task-to-br ${bindings.featurePath} --source-file <path-to-story.md-or.txt>`,
      `  node ${bindings.overmindCliPath} capture task-to-br ${bindings.featurePath} --jira <ticket>`,
      "- Then assemble deterministic context with:",
      `  node ${bindings.overmindCliPath} context task-to-br ${bindings.featurePath}`,
      "- Update only the artifacts allowed by the skill.",
      "- Validate after every write or repair with:",
      `  node ${bindings.overmindCliPath} gate task-to-br ${bindings.featurePath}`,
      "- Handle gate exit codes exactly as the skill defines."
    ]
  },
  "repo-br-scan": {
    intro: () => "Load and follow the overmind-repo-br-scan skill for this feature.",
    runtimeBindings: (bindings) => [
      `- ASDLC workspace root: ${bindings.runtimeRoot}`,
      `- Current working directory for all commands: ${bindings.runtimeRoot}`,
      `- Feature path: ${bindings.featurePath}`,
      `- Feature BR summary artifact: ${bindings.featurePath}/feature_br_summary.md`,
      `- Overmind CLI: ${bindings.overmindCliPath}`
    ],
    requiredFlow: (bindings) => [
      "- Load and follow the overmind-repo-br-scan skill.",
      "- Assemble deterministic context with:",
      `  node ${bindings.overmindCliPath} context repo-br-scan ${bindings.featurePath}`,
      "- Follow the skill's instructions exactly.",
      "- Validate after every write or repair with:",
      `  node ${bindings.overmindCliPath} gate repo-br-scan ${bindings.featurePath}`,
      "- Handle gate exit codes as defined in the skill."
    ]
  },
  "br-clarification": {
    intro: () => "Load and follow the overmind-br-clarification skill for this feature.",
    runtimeBindings: (bindings) => [
      `- ASDLC workspace root: ${bindings.runtimeRoot}`,
      `- Current working directory for all commands: ${bindings.runtimeRoot}`,
      `- Feature path: ${bindings.featurePath}`,
      `- Feature BR summary artifact: ${bindings.featurePath}/feature_br_summary.md`,
      `- Missing-data artifact: ${bindings.featurePath}/missing_br_data.md`,
      `- Overmind CLI: ${bindings.overmindCliPath}`
    ],
    requiredFlow: (bindings) => [
      "- Load and follow the overmind-br-clarification skill.",
      "- Assemble deterministic context with:",
      `  node ${bindings.overmindCliPath} context br-clarification ${bindings.featurePath}`,
      "- Use the exact gate command below when the skill tells you to validate:",
      `  node ${bindings.overmindCliPath} gate br-clarification ${bindings.featurePath}`
    ]
  },
  "requirements-ears": {
    intro: () => "Load and follow the overmind-requirements-ears skill for this feature.",
    runtimeBindings: (bindings) => [
      `- ASDLC workspace root: ${bindings.runtimeRoot}`,
      `- Current working directory for all commands: ${bindings.runtimeRoot}`,
      `- Feature path: ${bindings.featurePath}`,
      `- Read-only BR summary artifact: ${bindings.featurePath}/feature_br_summary.md`,
      `- Target EARS artifact: ${bindings.featurePath}/requirements_ears.md`,
      `- Overmind CLI: ${bindings.overmindCliPath}`
    ],
    requiredFlow: (bindings) => [
      "- Load and follow the overmind-requirements-ears skill.",
      "- Assemble deterministic context with:",
      `  node ${bindings.overmindCliPath} context requirements-ears ${bindings.featurePath}`,
      "- Use the exact gate command below when the skill tells you to validate:",
      `  node ${bindings.overmindCliPath} gate requirements-ears ${bindings.featurePath}`
    ]
  },
  "ears-review": {
    intro: () => "Load and follow the overmind-ears-review skill for this feature.",
    runtimeBindings: (bindings) => [
      `- ASDLC workspace root: ${bindings.runtimeRoot}`,
      `- Current working directory for all commands: ${bindings.runtimeRoot}`,
      `- Feature path: ${bindings.featurePath}`,
      `- Read-only BR summary artifact: ${bindings.featurePath}/feature_br_summary.md`,
      `- Mutable EARS artifact: ${bindings.featurePath}/requirements_ears.md`,
      `- Review ledger artifact: ${bindings.featurePath}/requirements_ears_review.md`,
      `- Overmind CLI: ${bindings.overmindCliPath}`
    ],
    requiredFlow: (bindings) => [
      "- Load and follow the overmind-ears-review skill.",
      "- Assemble deterministic context with:",
      `  node ${bindings.overmindCliPath} context ears-review ${bindings.featurePath}`,
      "- Use the exact gate command below when the skill tells you to validate:",
      `  node ${bindings.overmindCliPath} gate ears-review ${bindings.featurePath}`
    ]
  },
  "contract-delta": {
    intro: () => "Load and follow the overmind-contract-delta skill for this feature.",
    runtimeBindings: (bindings) => [
      `- ASDLC workspace root: ${bindings.runtimeRoot}`,
      `- Current working directory for all commands: ${bindings.runtimeRoot}`,
      `- Feature path: ${bindings.featurePath}`,
      `- Target contract delta artifact: ${bindings.featurePath}/feature_contract_delta.md`,
      `- Overmind CLI: ${bindings.overmindCliPath}`
    ],
    requiredFlow: (bindings) => [
      "- Load and follow the overmind-contract-delta skill.",
      "- Assemble deterministic context with:",
      `  node ${bindings.overmindCliPath} context contract-delta ${bindings.featurePath}`,
      "- Use the exact gate command below when the skill tells you to validate:",
      `  node ${bindings.overmindCliPath} gate contract-delta ${bindings.featurePath}`
    ]
  },
  "stack-blueprint": {
    intro: () => "Load and follow the overmind-stack-blueprint skill for this project class.",
    runtimeBindings: (bindings) => [
      `- ASDLC workspace root: ${bindings.runtimeRoot}`,
      `- Current working directory for all commands: ${bindings.runtimeRoot}`,
      `- Project path: ${bindings.featurePath}`,
      `- Target class: ${bindings.targetClass ?? "<missing-class>"}`,
      `- Target stack blueprint artifact: ${bindings.featurePath}/project_stack_blueprint_${bindings.targetClass ?? "<missing-class>"}.md`,
      `- Overmind CLI: ${bindings.overmindCliPath}`
    ],
    requiredFlow: (bindings) => [
      "- Load and follow the overmind-stack-blueprint skill.",
      "- Assemble deterministic context with:",
      `  node ${bindings.overmindCliPath} context stack-blueprint ${bindings.featurePath} --class ${bindings.targetClass ?? "<missing-class>"}`,
      "- Use the exact gate command below when the skill tells you to validate:",
      `  node ${bindings.overmindCliPath} gate stack-blueprint ${bindings.featurePath}/project_stack_blueprint_${bindings.targetClass ?? "<missing-class>"}.md`,
      "- The model owns the gate loop; this orchestrator does not run the gate."
    ]
  },
  "common-contract": {
    intro: () => "Load and follow the overmind-common-contract skill for this project.",
    runtimeBindings: (bindings) => [
      `- ASDLC workspace root: ${bindings.runtimeRoot}`,
      `- Current working directory for all commands: ${bindings.runtimeRoot}`,
      `- Project path: ${bindings.featurePath}`,
      `- Target common contract artifact: ${bindings.featurePath}/common_contract_definition.md`,
      `- Overmind CLI: ${bindings.overmindCliPath}`
    ],
    requiredFlow: (bindings) => [
      "- Load and follow the overmind-common-contract skill.",
      "- Assemble deterministic context with:",
      `  node ${bindings.overmindCliPath} context common-contract ${bindings.featurePath}${(
        bindings.classes ?? []
      )
        .map((klass) => ` --class ${klass}`)
        .join("")}`,
      "- Write only common_contract_definition.md; never modify init_progress_definition.yaml, stack blueprints, or attached repos.",
      "- Use the exact gate command below when the skill tells you to validate:",
      `  node ${bindings.overmindCliPath} gate common-contract ${bindings.featurePath}`,
      "- The model owns the gate loop; this orchestrator does not run the gate."
    ]
  },
  "surface-map": {
    intro: () => "Load and follow the overmind-surface-map skill for this feature and class.",
    runtimeBindings: (bindings) => [
      `- ASDLC workspace root: ${bindings.runtimeRoot}`,
      `- Current working directory for all commands: ${bindings.runtimeRoot}`,
      `- Feature path: ${bindings.featurePath}`,
      `- Target class: ${bindings.targetClass ?? "<missing-class>"}`,
      `- Target surface map artifact: ${bindings.featurePath}/project_surface_struct_resp_map_${bindings.targetClass ?? "<missing-class>"}.md`,
      `- Overmind CLI: ${bindings.overmindCliPath}`
    ],
    requiredFlow: (bindings) => [
      "- Load and follow the overmind-surface-map skill.",
      "- Assemble deterministic context with:",
      `  node ${bindings.overmindCliPath} context surface-map ${bindings.featurePath} --class ${bindings.targetClass ?? "<missing-class>"}`,
      "- Use the exact gate command below when the skill tells you to validate:",
      `  node ${bindings.overmindCliPath} gate surface-map ${bindings.featurePath} --class ${bindings.targetClass ?? "<missing-class>"}`
    ]
  },
  "surface-map-enrich": {
    intro: () => "Load and follow the overmind-surface-map-enrich skill for this feature.",
    runtimeBindings: (bindings) => [
      `- ASDLC workspace root: ${bindings.runtimeRoot}`,
      `- Current working directory for all commands: ${bindings.runtimeRoot}`,
      `- Feature path: ${bindings.featurePath}`,
      `- Overmind CLI: ${bindings.overmindCliPath}`
    ],
    requiredFlow: (bindings) => [
      "- Load and follow the overmind-surface-map-enrich skill.",
      "- Assemble deterministic context with:",
      `  node ${bindings.overmindCliPath} context surface-map-enrich ${bindings.featurePath}`,
      "- When the skill tells you to validate, use the per-class gate command:",
      `  node ${bindings.overmindCliPath} gate surface-map ${bindings.featurePath} --class <backend|frontend|mobile>`,
      "- The model owns the gate loop; this orchestrator does not run the gate."
    ]
  },
  "technical-requirements": {
    intro: () => "Load and follow the overmind-technical-requirements skill for this feature.",
    runtimeBindings: (bindings) => [
      `- ASDLC workspace root: ${bindings.runtimeRoot}`,
      `- Current working directory for all commands: ${bindings.runtimeRoot}`,
      `- Feature path: ${bindings.featurePath}`,
      `- Target artifact: ${bindings.featurePath}/technical_requirements.md`,
      `- Overmind CLI: ${bindings.overmindCliPath}`
    ],
    requiredFlow: (bindings) => [
      "- Load and follow the overmind-technical-requirements skill.",
      "- Assemble deterministic context with:",
      `  node ${bindings.overmindCliPath} context technical-requirements ${bindings.featurePath}`,
      "- Use the exact gate command below when the skill tells you to validate:",
      `  node ${bindings.overmindCliPath} gate technical-requirements ${bindings.featurePath}`,
      "- The model owns the gate loop; this orchestrator does not run the gate."
    ]
  },
  "implementation-slices": {
    intro: () => "Load and follow the overmind-implementation-slices skill for this feature.",
    runtimeBindings: (bindings) => [
      `- ASDLC workspace root: ${bindings.runtimeRoot}`,
      `- Current working directory for all commands: ${bindings.runtimeRoot}`,
      `- Feature path: ${bindings.featurePath}`,
      `- Target artifact: ${bindings.featurePath}/implementation_slices.md`,
      `- Overmind CLI: ${bindings.overmindCliPath}`
    ],
    requiredFlow: (bindings) => [
      "- Load and follow the overmind-implementation-slices skill.",
      "- Assemble deterministic context with:",
      `  node ${bindings.overmindCliPath} context implementation-slices ${bindings.featurePath}`,
      "- Use the exact gate command below when the skill tells you to validate:",
      `  node ${bindings.overmindCliPath} gate implementation-slices ${bindings.featurePath}`,
      "- The model owns the gate loop; this orchestrator does not run the gate."
    ]
  },
  "prerequisite-gaps": {
    intro: () => "Load and follow the overmind-prerequisite-gaps skill for this feature.",
    runtimeBindings: (bindings) => [
      `- ASDLC workspace root: ${bindings.runtimeRoot}`,
      `- Current working directory for all commands: ${bindings.runtimeRoot}`,
      `- Feature path: ${bindings.featurePath}`,
      `- Target artifact: ${bindings.featurePath}/prerequisite_gaps.md`,
      `- Overmind CLI: ${bindings.overmindCliPath}`
    ],
    requiredFlow: (bindings) => [
      "- Load and follow the overmind-prerequisite-gaps skill.",
      "- Assemble deterministic context with:",
      `  node ${bindings.overmindCliPath} context prerequisite-gaps ${bindings.featurePath}`,
      "- Use the exact gate command below when the skill tells you to validate:",
      `  node ${bindings.overmindCliPath} gate prerequisite-gaps ${bindings.featurePath}`,
      "- The model owns the gate loop; this orchestrator does not run the gate."
    ]
  },
  "implementation-plan": {
    intro: () => "Load and follow the overmind-implementation-plan skill for this feature.",
    runtimeBindings: (bindings) => [
      `- ASDLC workspace root: ${bindings.runtimeRoot}`,
      `- Current working directory for all commands: ${bindings.runtimeRoot}`,
      `- Feature path: ${bindings.featurePath}`,
      `- Target artifact: ${bindings.featurePath}/implementation_plan.md`,
      `- Overmind CLI: ${bindings.overmindCliPath}`
    ],
    requiredFlow: (bindings) => [
      "- Load and follow the overmind-implementation-plan skill.",
      "- Assemble deterministic context with:",
      `  node ${bindings.overmindCliPath} context implementation-plan ${bindings.featurePath}`,
      "- Use the exact gate command below when the skill tells you to validate:",
      `  node ${bindings.overmindCliPath} gate implementation-plan ${bindings.featurePath}`,
      "- The model owns the gate loop; this orchestrator does not run the gate."
    ]
  },
  "contract-reconciliation": {
    intro: () =>
      "Load and follow the overmind-contract-reconciliation skill for this project reconciliation.",
    runtimeBindings: (bindings) => [
      `- ASDLC workspace root: ${bindings.runtimeRoot}`,
      `- Current working directory for all commands: ${bindings.runtimeRoot}`,
      `- Project path: ${bindings.featurePath}`,
      `- Pending classes: ${(bindings.classes ?? []).join(", ") || "<none>"}`,
      `- Target common contract artifact: ${bindings.featurePath}/common_contract_definition.md`,
      `- Read-only project definition: ${bindings.featurePath}/init_progress_definition.yaml`,
      `- Overmind CLI: ${bindings.overmindCliPath}`
    ],
    requiredFlow: (bindings) => [
      "- Load and follow the overmind-contract-reconciliation skill.",
      "- Assemble deterministic context with:",
      `  node ${bindings.overmindCliPath} context contract-reconciliation ${bindings.featurePath}${(
        bindings.classes ?? []
      )
        .map((klass) => ` --class ${klass}`)
        .join("")}`,
      "- Write only the common contract; never modify init_progress_definition.yaml or attached repos.",
      "- Use the exact gate command below when the skill tells you to validate:",
      `  node ${bindings.overmindCliPath} gate contract-reconciliation ${bindings.featurePath}`,
      "- The model owns the gate loop; this orchestrator does not run the gate."
    ]
  },
  "plan-semantic-review": {
    intro: () => "Load and follow the overmind-plan-semantic-review skill for this feature.",
    runtimeBindings: (bindings) => [
      `- ASDLC workspace root: ${bindings.runtimeRoot}`,
      `- Current working directory for all commands: ${bindings.runtimeRoot}`,
      `- Feature path: ${bindings.featurePath}`,
      `- Overmind CLI: ${bindings.overmindCliPath}`
    ],
    requiredFlow: (bindings) => [
      "- Load and follow the overmind-plan-semantic-review skill.",
      "- Assemble deterministic context with:",
      `  node ${bindings.overmindCliPath} context plan-semantic-review ${bindings.featurePath}`,
      "- Use the exact review-ledger gate command when the skill tells you to validate the review ledger:",
      `  node ${bindings.overmindCliPath} gate plan-semantic-review ${bindings.featurePath}`,
      "- Use the exact implementation-plan gate command when the skill tells you to validate the plan:",
      `  node ${bindings.overmindCliPath} gate implementation-plan ${bindings.featurePath}`,
      "- The model owns both gate loops; this orchestrator does not run either gate."
    ]
  }
};

export function buildSessionPrompt(
  sessionAction: Extract<Action, { kind: "session" }>,
  bindings: SessionBindings
): string {
  const recipe = PROMPT_RECIPES[sessionAction.skillName];
  if (!recipe) {
    throw new Error(`No prompt recipe registered for skill '${sessionAction.skillName}'`);
  }

  return [
    recipe.intro(bindings),
    "",
    "Runtime bindings:",
    ...recipe.runtimeBindings(bindings),
    "",
    "Required flow:",
    ...recipe.requiredFlow(bindings)
  ].join("\n");
}

export function buildUnknownPromptRecipeDiagnostic(skillName: string): Diagnostic {
  return {
    severity: "error",
    source: "session-prompt-builder",
    reason: `No prompt recipe registered for skill '${skillName}'.`
  };
}
