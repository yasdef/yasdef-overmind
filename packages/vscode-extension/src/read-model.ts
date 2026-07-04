import path from "node:path";

import type { Diagnostic } from "asdlc-coordinator/sequencing";
import {
  evaluate,
  type FeatureSummary,
  type ProgressReport,
  toFeatureSummary
} from "asdlc-coordinator/sequencing";
import { detectRuntimeRoot, discoverFeatures, discoverProjects } from "asdlc-coordinator/workspace";

export interface DashboardFeature {
  projectPath: string;
  featurePath: string;
  title: string;
  summary: FeatureSummary;
  diagnostics: Diagnostic[];
}

export interface DashboardModel {
  workspacePath: string;
  features: DashboardFeature[];
  diagnostics: Diagnostic[];
}

export function dashboardFeatureFromReport(report: ProgressReport): DashboardFeature {
  return {
    projectPath: report.projectRoot,
    featurePath: report.featureRoot ?? report.projectRoot,
    title: report.featureTitle,
    summary: toFeatureSummary(report),
    diagnostics: report.diagnostics
  };
}

export function readDashboard(startPath: string): DashboardModel {
  const runtime = detectRuntimeRoot(startPath);
  if (!runtime.path) {
    return { workspacePath: startPath, features: [], diagnostics: runtime.diagnostics };
  }

  const projects = discoverProjects(path.join(runtime.path, "projects"));
  const features: DashboardFeature[] = [];
  const diagnostics = [...runtime.diagnostics, ...projects.diagnostics];
  for (const projectPath of projects.paths) {
    const discovered = discoverFeatures(projectPath);
    diagnostics.push(...discovered.diagnostics);
    for (const featurePath of discovered.paths) {
      const feature = dashboardFeatureFromReport(evaluate(runtime.path, projectPath, featurePath));
      features.push(feature);
      diagnostics.push(...feature.diagnostics);
    }
  }
  return { workspacePath: runtime.path, features, diagnostics };
}
