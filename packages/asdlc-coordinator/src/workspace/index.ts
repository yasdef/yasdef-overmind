import { existsSync, readdirSync, realpathSync, statSync } from "node:fs";
import path from "node:path";

import type { Diagnostic } from "../types/index.js";

export interface PathResult {
  path?: string;
  diagnostics: Diagnostic[];
}

function failure(source: string, reason: string): PathResult {
  return { diagnostics: [{ severity: "error", source, reason }] };
}

function directory(candidate: string): string | undefined {
  try {
    return statSync(candidate).isDirectory() ? realpathSync(candidate) : undefined;
  } catch {
    return undefined;
  }
}

export function detectRuntimeRoot(startPath: string): PathResult {
  let current = directory(startPath) ?? directory(path.dirname(startPath));
  while (current) {
    if (existsSync(path.join(current, "asdlc_metadata.yaml"))) {
      return { path: current, diagnostics: [] };
    }
    const parent = path.dirname(current);
    if (parent === current) break;
    current = parent;
  }
  return failure(startPath, "No ASDLC runtime root containing asdlc_metadata.yaml was found.");
}

export function discoverProjects(projectsRoot: string): {
  paths: string[];
  diagnostics: Diagnostic[];
} {
  try {
    const root = realpathSync(projectsRoot);
    const paths = readdirSync(root, { withFileTypes: true })
      .filter((entry) => entry.isDirectory())
      .map((entry) => path.join(root, entry.name))
      .filter((candidate) => existsSync(path.join(candidate, "init_progress_definition.yaml")))
      .sort();
    return { paths, diagnostics: [] };
  } catch (error) {
    return {
      paths: [],
      diagnostics: [
        {
          severity: "error",
          source: projectsRoot,
          reason: `Unable to discover projects: ${error instanceof Error ? error.message : String(error)}`
        }
      ]
    };
  }
}

export function resolveProjectPath(inputPath: string, projectsRoot: string): PathResult {
  const root = directory(projectsRoot);
  let current = directory(inputPath);
  if (!root || !current) return failure(inputPath, "Project path is not an existing directory.");
  while (current === root || current.startsWith(`${root}${path.sep}`)) {
    if (existsSync(path.join(current, "init_progress_definition.yaml"))) {
      return { path: current, diagnostics: [] };
    }
    if (current === root) break;
    current = path.dirname(current);
  }
  return failure(
    inputPath,
    "Path does not belong to a project containing init_progress_definition.yaml."
  );
}

export function resolveRepoPath(inputPath: string): PathResult {
  if (inputPath.trim() === "") return failure(inputPath, "Repo path cannot be empty.");
  let stat;
  try {
    stat = statSync(inputPath);
  } catch {
    return failure(inputPath, `Repo path does not exist: ${inputPath}`);
  }
  if (!stat.isDirectory()) return failure(inputPath, `Repo path is not a directory: ${inputPath}`);
  try {
    if (readdirSync(inputPath).length === 0) {
      return failure(inputPath, `Repo path must point to a non-empty directory: ${inputPath}`);
    }
    return { path: realpathSync(inputPath), diagnostics: [] };
  } catch (error) {
    return failure(
      inputPath,
      `Unable to resolve repo path: ${error instanceof Error ? error.message : String(error)}`
    );
  }
}

export function discoverFeatures(projectRoot: string): {
  paths: string[];
  diagnostics: Diagnostic[];
} {
  try {
    const root = realpathSync(projectRoot);
    return {
      paths: readdirSync(root, { withFileTypes: true })
        .filter((entry) => entry.isDirectory() && !entry.name.startsWith("."))
        .map((entry) => path.join(root, entry.name))
        .sort(),
      diagnostics: []
    };
  } catch (error) {
    return {
      paths: [],
      diagnostics: [
        {
          severity: "error",
          source: projectRoot,
          reason: `Unable to discover features: ${error instanceof Error ? error.message : String(error)}`
        }
      ]
    };
  }
}

export function inferProjectFromFeature(featurePath: string, projectsRoot: string): PathResult {
  const feature = directory(featurePath);
  if (!feature) return failure(featurePath, "Feature path is not an existing directory.");
  const project = resolveProjectPath(feature, projectsRoot);
  if (!project.path) return project;
  if (project.path === feature)
    return failure(
      featurePath,
      "Feature path must name a feature-level folder, not the project root."
    );
  return project;
}
