import { mkdtempSync, mkdirSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";

export interface RunnerWorkspace {
  root: string;
  projectDir: string;
  featureDir: string;
  featurePath: string;
  backendRepoDir: string;
}

export async function withRunnerWorkspace(
  fn: (workspace: RunnerWorkspace) => Promise<void> | void
): Promise<void> {
  const root = mkdtempSync(path.join(tmpdir(), "overmind-runner-"));
  const projectDir = path.join(root, "projects", "project-a");
  const featureDir = path.join(projectDir, "feature-alpha");
  const backendRepoDir = path.join(root, "repos", "backend-service");

  mkdirSync(featureDir, { recursive: true });
  mkdirSync(backendRepoDir, { recursive: true });
  mkdirSync(path.join(root, ".setup"), { recursive: true });

  writeFileSync(path.join(root, "asdlc_metadata.yaml"), "project: overmind\n");
  writeFileSync(
    path.join(root, ".setup", "models.md"),
    [
      "repo_analyse | codex | gpt-5.4 | --config | model_reasoning_effort='high'",
      "project_stack_blueprint | codex | gpt-5.4",
      "common_contract_definition | codex | gpt-5.4",
      "task_to_br | codex | gpt-5.4",
      "user_br_clarification | codex | gpt-5.4",
      "br_to_ears | codex | gpt-5.4",
      "requirements_ears_review | codex | gpt-5.4",
      "feature_contract_delta | codex | gpt-5.4",
      "feature_repo_surface_and_exec_context | codex | gpt-5.4",
      "feature_surface_map_mcp_placeholder_enrichment | codex | gpt-5.4",
      "feature_technical_requirements | codex | gpt-5.4",
      "repository_implementation_slices | codex | gpt-5.4",
      "prerequisite_gap_trace | codex | gpt-5.4",
      "repository_implementation_plan | codex | gpt-5.4",
      "implementation_plan_semantic_review | codex | gpt-5.4"
    ].join("\n")
  );
  writeFileSync(
    path.join(root, ".setup", "external_sources.yaml"),
    `sources:
  - name: knowledge-base
    type: stack_knowledge_base
`
  );
  writeFileSync(
    path.join(projectDir, "init_progress_definition.yaml"),
    `meta_info:
  project_classes:
    - backend
  class_repo_paths:
    backend:
      state: ready
      path: ${backendRepoDir}
steps: {}
`
  );
  writeFileSync(path.join(projectDir, "common_contract_definition.md"), "# Common contract\n");
  writeFileSync(path.join(projectDir, "project_stack_blueprint_backend.md"), "# Blueprint\n");
  writeFileSync(path.join(featureDir, "feature_br_summary.md"), "# BR\n");
  writeFileSync(path.join(featureDir, "user_br_input.md"), "# Input\n");
  writeFileSync(path.join(featureDir, "missing_br_data.md"), "# Missing\n");
  writeFileSync(path.join(featureDir, "requirements_ears.md"), "# EARS\n");
  writeFileSync(path.join(featureDir, "requirements_ears_review.md"), "# Review\n");
  writeFileSync(path.join(featureDir, "feature_contract_delta.md"), "# Delta\n");
  writeFileSync(path.join(featureDir, "project_surface_struct_resp_map_backend.md"), "# Surface\n");
  writeFileSync(path.join(featureDir, "technical_requirements.md"), "# Technical\n");
  writeFileSync(path.join(featureDir, "implementation_slices.md"), "# Slices\n");
  writeFileSync(path.join(featureDir, "prerequisite_gaps.md"), "# Prerequisites\n");
  writeFileSync(path.join(featureDir, "implementation_plan.md"), "# Plan\n");
  writeFileSync(
    path.join(featureDir, "implementation_plan_semantic_review.md"),
    "# Semantic review\n"
  );

  const workspace = {
    root,
    projectDir,
    featureDir,
    featurePath: path.relative(root, featureDir),
    backendRepoDir
  };

  try {
    await fn(workspace);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
}
