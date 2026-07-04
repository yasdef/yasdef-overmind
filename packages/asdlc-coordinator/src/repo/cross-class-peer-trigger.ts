import { readFileSync } from "node:fs";

export type CrossClassPeerTrigger = "active" | "inactive";

function stripQuotes(value: string): string {
  const trimmed = value.trim();
  if (
    (trimmed.startsWith('"') && trimmed.endsWith('"')) ||
    (trimmed.startsWith("'") && trimmed.endsWith("'"))
  ) {
    return trimmed.slice(1, -1).trim();
  }
  return trimmed;
}

export function computeCrossClassPeerTrigger(definitionPath: string): CrossClassPeerTrigger {
  const lines = readFileSync(definitionPath, "utf8").split(/\r?\n/);
  let inMeta = false;
  let inClasses = false;
  let projectTypeCode = "";
  let backendCount = 0;
  let hasOtherClass = false;

  const recordClass = (value: string): void => {
    const normalized = stripQuotes(value);
    if (normalized === "backend") {
      backendCount += 1;
    } else if (normalized === "frontend" || normalized === "mobile") {
      hasOtherClass = true;
    }
  };

  for (const rawLine of lines) {
    if (/^meta_info:\s*$/.test(rawLine)) {
      inMeta = true;
      continue;
    }
    if (/^steps:\s*$/.test(rawLine) && inMeta) {
      break;
    }
    if (!inMeta) {
      continue;
    }

    const projectTypeMatch = rawLine.match(/^\s{2}project_type_code:\s*(.*)$/);
    if (projectTypeMatch) {
      projectTypeCode = stripQuotes(projectTypeMatch[1]!);
      inClasses = false;
      continue;
    }

    const inlineClassesMatch = rawLine.match(/^\s{2}project_classes:\s*\[([^\]]*)\]\s*$/);
    if (inlineClassesMatch) {
      for (const value of inlineClassesMatch[1]!.split(",")) {
        recordClass(value);
      }
      inClasses = false;
      continue;
    }

    if (/^\s{2}project_classes:\s*$/.test(rawLine)) {
      inClasses = true;
      continue;
    }

    if (inClasses) {
      const itemMatch = rawLine.match(/^\s{4}-\s*(.*)$/);
      if (itemMatch) {
        recordClass(itemMatch[1]!);
        continue;
      }
      inClasses = false;
    }
  }

  return projectTypeCode === "A" && backendCount > 0 && (hasOtherClass || backendCount > 1)
    ? "active"
    : "inactive";
}
