import type { ProjectDefinitionMetadata } from "../parse/project-definition.js";
import type { SurfaceMapClass } from "../validate/surface-map.js";

export const SHARED_PROJECT_DEFINITION_PATHS = [
  "init_progress_definition.yaml",
  "common_contract_definition.md"
] as const;

export interface ProjectInitOwnership {
  applicableStackClasses: SurfaceMapClass[];
  step11Paths: string[];
  initialBaselinePaths: string[];
  sharedProjectDefinitionPaths: string[];
}

const STACK_CLASSES: readonly SurfaceMapClass[] = ["backend", "frontend", "mobile"];

export function resolveProjectInitOwnership(
  metadata: Pick<ProjectDefinitionMetadata, "projectTypeCode" | "projectClasses">
): ProjectInitOwnership {
  const applicableStackClasses =
    metadata.projectTypeCode === "A"
      ? STACK_CLASSES.filter((klass) => metadata.projectClasses.includes(klass))
      : [];
  const step11Paths = applicableStackClasses.flatMap((klass) => [
    `project_stack_blueprint_${klass}.md`,
    `project_agents_md_claude_md_${klass}.md`
  ]);
  const sharedProjectDefinitionPaths = [...SHARED_PROJECT_DEFINITION_PATHS];
  return {
    applicableStackClasses,
    step11Paths,
    sharedProjectDefinitionPaths,
    initialBaselinePaths: [...sharedProjectDefinitionPaths, ...step11Paths]
  };
}
