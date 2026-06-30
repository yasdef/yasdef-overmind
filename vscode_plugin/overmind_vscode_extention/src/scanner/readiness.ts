import type {
  ArtifactSummary,
  DashboardModel,
  FeatureReadiness,
  FeatureSummary,
  ProjectClassState,
  ProjectReadiness,
  ProjectSummary
} from './asdlcScanner';
import type { AsdlcWorkspaceDiagnostic } from './workspaceDetection';

export type ReadinessState = 'ready' | 'in_progress' | 'blocked' | 'deferred' | 'unknown';

export function computeDashboardReadiness(model: DashboardModel): DashboardModel {
  return {
    ...model,
    projects: model.projects.map((project) => computeProjectReadiness(project, model.diagnostics))
  };
}

export function computeFeatureReadiness(feature: FeatureSummary): FeatureReadiness {
  if (hasMissingRequiredArtifact(feature.artifacts)) {
    return 'blocked';
  }

  if (feature.totalSteps === 0) {
    return 'unknown';
  }

  if (feature.completedSteps >= feature.totalSteps) {
    return 'ready';
  }

  return 'in_progress';
}

export function computeProjectReadiness(
  project: ProjectSummary,
  diagnostics: readonly AsdlcWorkspaceDiagnostic[] = []
): ProjectSummary {
  const projectDiagnostics = diagnostics.filter((diagnostic) =>
    diagnostic.path.length > 0 && isSameOrChildPath(diagnostic.path, project.folderPath)
  );
  const features = project.features.map((feature) => ({
    ...feature,
    readiness: computeFeatureReadiness(feature)
  }));
  const projectReadiness = deriveProjectReadiness({
    project,
    projectDiagnostics,
    features
  });

  return {
    ...project,
    classes: project.classes.map(normalizeProjectClassReadiness),
    features,
    projectReadiness
  };
}

function deriveProjectReadiness({
  project,
  projectDiagnostics,
  features
}: {
  readonly project: ProjectSummary;
  readonly projectDiagnostics: readonly AsdlcWorkspaceDiagnostic[];
  readonly features: readonly FeatureSummary[];
}): ProjectReadiness {
  if (project.projectReadiness === 'blocked' || hasMissingRequiredArtifact(project.artifacts)) {
    return 'blocked';
  }

  if (features.some((feature) => feature.readiness === 'blocked')) {
    return 'blocked';
  }

  if (projectDiagnostics.some((diagnostic) => isInvalidProjectDiagnostic(diagnostic.code))) {
    return 'unknown';
  }

  if (project.classes.some((projectClass) => projectClass.state === 'unknown')) {
    return 'unknown';
  }

  if (features.some((feature) => feature.readiness === 'unknown')) {
    return 'unknown';
  }

  if (project.totalSteps === 0) {
    return 'unknown';
  }

  if (project.completedSteps < project.totalSteps) {
    return 'partial';
  }

  if (features.some((feature) => feature.readiness === 'in_progress')) {
    return 'partial';
  }

  return 'complete';
}

function normalizeProjectClassReadiness(projectClass: {
  readonly className: string;
  readonly repoPath?: string;
  readonly state: ProjectClassState;
}): {
  readonly className: string;
  readonly repoPath?: string;
  readonly state: ProjectClassState;
} {
  if (projectClass.state === 'deferred') {
    return projectClass;
  }

  if (projectClass.repoPath && projectClass.repoPath.trim().length > 0) {
    return {
      ...projectClass,
      state: 'ready'
    };
  }

  return {
    ...projectClass,
    state: 'unknown'
  };
}

function hasMissingRequiredArtifact(artifacts: readonly ArtifactSummary[]): boolean {
  return artifacts.some((artifact) => artifact.required && !artifact.exists);
}

function isInvalidProjectDiagnostic(code: string): boolean {
  return code === 'project.init.parseFailed' ||
    code === 'project.init.invalid' ||
    code === 'project.init.unreadable' ||
    code === 'project.directory.unreadable';
}

function isSameOrChildPath(candidatePath: string, parentPath: string): boolean {
  const normalizedCandidate = normalizePath(candidatePath);
  const normalizedParent = normalizePath(parentPath);

  return normalizedCandidate === normalizedParent ||
    normalizedCandidate.startsWith(`${normalizedParent}/`);
}

function normalizePath(value: string): string {
  return value.replace(/\\/g, '/').replace(/\/+$/, '');
}
