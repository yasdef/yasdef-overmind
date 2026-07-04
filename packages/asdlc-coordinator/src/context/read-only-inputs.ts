import { displayPath } from "../parse/index.js";

export interface ReadOnlyInputManifest {
  paths: string[];
  lines: string[];
}

export function buildReadOnlyInputManifest(
  paths: string[],
  workspaceRoot: string
): ReadOnlyInputManifest {
  const manifestPaths = paths.map((candidate) => displayPath(candidate, workspaceRoot));
  return {
    paths: manifestPaths,
    lines: manifestPaths.map((candidate) => `- read_only_input: ${candidate}`)
  };
}
