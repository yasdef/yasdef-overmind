import { readFileSync } from "node:fs";

import type { Diagnostic } from "../types/index.js";

export interface ArtifactCheck {
  file: string;
  specialFolder?: string;
  projectTypeCode?: string;
  projectClassesAnyOf?: string[];
  checkKeyValue?: { key: string; equals: string; section: string };
}

export interface DeclaredStep {
  id: string;
  phase: "init" | "feature";
  name: string;
  optional: boolean;
  artifacts: ArtifactCheck[];
}

const scalar = (value: string): string => {
  const result = value.trim();
  return (result.startsWith('"') && result.endsWith('"')) ||
    (result.startsWith("'") && result.endsWith("'"))
    ? result.slice(1, -1)
    : result;
};

export function parseDeclaredSteps(definitionPath: string): {
  steps: DeclaredStep[];
  diagnostics: Diagnostic[];
  parsed: boolean;
} {
  let content: string;
  try {
    content = readFileSync(definitionPath, "utf8");
  } catch (error) {
    return {
      steps: [],
      parsed: false,
      diagnostics: [
        {
          severity: "error",
          source: definitionPath,
          reason: `Unable to read init progress definition: ${error instanceof Error ? error.message : String(error)}`
        }
      ]
    };
  }
  const lines = content.split(/\r?\n/);
  const starts = lines
    .map((line, index) => (/^\s{2}- step_number:\s*(\S+)\s*$/.test(line) ? index : -1))
    .filter((index) => index >= 0);
  if (starts.length === 0)
    return {
      steps: [],
      parsed: false,
      diagnostics: [
        {
          severity: "error",
          source: definitionPath,
          reason: "Malformed definition: no declared steps."
        }
      ]
    };
  const steps: DeclaredStep[] = [];
  for (let position = 0; position < starts.length; position += 1) {
    const start = starts[position]!;
    const block = lines.slice(start, starts[position + 1] ?? lines.length);
    const id = block[0]!.match(/step_number:\s*(\S+)/)?.[1];
    const phase = block
      .find((line) => /^\s{4}phase_name:/.test(line))
      ?.replace(/^\s{4}phase_name:\s*/, "");
    const name = block
      .find((line) => /^\s{4}step_name:/.test(line))
      ?.replace(/^\s{4}step_name:\s*/, "");
    if (!id || !phase || !name || !["init", "feature", '"init"', '"feature"'].includes(phase)) {
      return {
        steps: [],
        parsed: false,
        diagnostics: [
          {
            severity: "error",
            source: definitionPath,
            reason: `Malformed definition near step ${id ?? "unknown"}.`
          }
        ]
      };
    }
    const artifacts: ArtifactCheck[] = [];
    const artifactStarts = block
      .map((line, index) => (/^\s{6}- file:\s*/.test(line) ? index : -1))
      .filter((index) => index >= 0);
    for (
      let artifactPosition = 0;
      artifactPosition < artifactStarts.length;
      artifactPosition += 1
    ) {
      const artifactStart = artifactStarts[artifactPosition]!;
      const artifactBlock = block.slice(
        artifactStart,
        artifactStarts[artifactPosition + 1] ?? block.length
      );
      const file = scalar(artifactBlock[0]!.replace(/^\s{6}- file:\s*/, ""));
      const artifact: ArtifactCheck = { file };
      for (const line of artifactBlock) {
        if (/^\s{8}special_folder:/.test(line))
          artifact.specialFolder = scalar(line.replace(/^\s{8}special_folder:\s*/, ""));
        if (
          /^\s{14}equals:/.test(line) &&
          artifactBlock.some((candidate) => /project_type_code:/.test(candidate))
        )
          artifact.projectTypeCode = scalar(line.replace(/^\s{14}equals:\s*/, ""));
        const anyOf = line.match(/^\s{14}any_of:\s*\[([^\]]*)\]/);
        if (anyOf) artifact.projectClassesAnyOf = anyOf[1]!.split(",").map(scalar).filter(Boolean);
      }
      const key = artifactBlock.find((line) => /^\s{10}key:/.test(line));
      const equals = artifactBlock.find((line) => /^\s{10}equals:/.test(line));
      const section = artifactBlock.find((line) => /^\s{10}section:/.test(line));
      if (key && equals && section)
        artifact.checkKeyValue = {
          key: scalar(key.replace(/^\s{10}key:\s*/, "")),
          equals: scalar(equals.replace(/^\s{10}equals:\s*/, "")),
          section: scalar(section.replace(/^\s{10}section:\s*/, ""))
        };
      artifacts.push(artifact);
    }
    steps.push({
      id,
      phase: scalar(phase) as "init" | "feature",
      name: scalar(name),
      optional: block.some((line) => /^\s{4}optional:\s*true\s*$/.test(line)),
      artifacts
    });
  }
  return { steps, diagnostics: [], parsed: true };
}
