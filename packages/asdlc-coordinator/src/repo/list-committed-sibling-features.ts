import { existsSync, readdirSync, realpathSync, statSync } from "node:fs";
import path from "node:path";

export function listCommittedSiblingFeatures(featureDir: string): string[] {
  if (!featureDir || featureDir.trim() === "") {
    throw new Error("feature path is required");
  }
  if (!existsSync(featureDir) || !statSync(featureDir).isDirectory()) {
    throw new Error(`Feature path directory not found: ${featureDir}`);
  }

  const resolvedFeatureDir = realpathSync(featureDir);
  const projectDir = path.dirname(resolvedFeatureDir);

  return readdirSync(projectDir, { withFileTypes: true })
    .filter((entry) => entry.isDirectory())
    .map((entry) => entry.name)
    .sort()
    .filter((name) => realpathSync(path.join(projectDir, name)) !== resolvedFeatureDir)
    .filter((name) => existsSync(path.join(projectDir, name, "implementation_plan.md")));
}
