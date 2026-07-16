import { copyFileSync, mkdirSync, readFileSync, readdirSync, writeFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

/** Source of the shared valid-feature fixture; see its README for the contract. */
export function validFeatureFixtureDir(): string {
  return fileURLToPath(new URL("../../test/fixtures/valid-feature", import.meta.url));
}

export const VALID_FEATURE_PROJECT_FILE = "init_progress_definition.yaml";

/**
 * Materialize the shared valid-feature fixture into `<projectDir>/<name>`, with
 * the project definition written one level up. By default the plan keeps the
 * measured missing header, so the terminal chain fails at step `8.3` and every
 * earlier gate passes or skips; `withPlanHeader` restores the template heading
 * for the all-pass variant.
 */
export function materializeValidFeature(
  projectDir: string,
  name: string,
  options: { withPlanHeader?: boolean } = {}
): string {
  const source = validFeatureFixtureDir();
  const featureDir = path.join(projectDir, name);
  mkdirSync(featureDir, { recursive: true });

  for (const entry of readdirSync(source)) {
    if (entry === "README.md") continue;
    if (entry === VALID_FEATURE_PROJECT_FILE) {
      copyFileSync(path.join(source, entry), path.join(projectDir, entry));
      continue;
    }
    copyFileSync(path.join(source, entry), path.join(featureDir, entry));
  }

  if (options.withPlanHeader) {
    const planPath = path.join(featureDir, "implementation_plan.md");
    writeFileSync(planPath, `# Implementation Plan\n${readFileSync(planPath, "utf8")}`);
  }
  return featureDir;
}
