import { readFileSync } from "node:fs";

import { stripQuotes } from "./markdown.js";
export { readProjectDefinitionMetadata } from "./project-definition.js";
export type {
  ClassRepoPath,
  ProjectClassState,
  ProjectDefinitionMetadata
} from "./project-definition.js";

export function parseImplementationSlicesProjectClasses(definitionPath: string): string[] {
  const classes: string[] = [];
  let inMeta = false;
  let inClasses = false;
  const record = (raw: string): void => {
    const value = stripQuotes(raw).trim().toLowerCase();
    if (value !== "" && !classes.includes(value)) classes.push(value);
  };

  for (const rawLine of readFileSync(definitionPath, "utf8").split(/\r?\n/)) {
    if (/^meta_info:\s*$/.test(rawLine)) {
      inMeta = true;
      continue;
    }
    if (/^steps:\s*$/.test(rawLine) && inMeta) break;
    if (!inMeta) continue;
    const inline = rawLine.match(/^\s{2}project_classes:\s*\[([^\]]*)\]\s*$/);
    if (inline) {
      for (const item of inline[1]!.split(",")) record(item);
      inClasses = false;
      continue;
    }
    if (/^\s{2}project_classes:\s*$/.test(rawLine)) {
      inClasses = true;
      continue;
    }
    if (inClasses) {
      const item = rawLine.match(/^\s{4}-\s*(.*)$/);
      if (item) {
        record(item[1]!);
        continue;
      }
      inClasses = false;
    }
  }
  return classes;
}
