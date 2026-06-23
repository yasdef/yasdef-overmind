import { readRequiredTextFile } from "./markdown.js";

import type { FeatureBrSummary } from "../types/index.js";

export function readFeatureBrSummary(filePath: string): FeatureBrSummary {
  return {
    path: filePath,
    content: readRequiredTextFile(filePath)
  };
}
