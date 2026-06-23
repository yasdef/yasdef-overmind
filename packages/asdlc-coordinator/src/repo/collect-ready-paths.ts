import { existsSync, readdirSync, readFileSync, realpathSync, statSync } from "node:fs";
import path from "node:path";

export interface ClassRepoEntry {
  class: string;
  path: string;
}

interface ParsedEntry {
  class: string;
  state: string;
  path: string;
}

function stripYamlQuotes(value: string): string {
  const trimmed = value.trim();
  if (
    (trimmed.startsWith('"') && trimmed.endsWith('"')) ||
    (trimmed.startsWith("'") && trimmed.endsWith("'"))
  ) {
    return trimmed.slice(1, -1).trim();
  }
  return trimmed;
}

function parseClassRepoPaths(definitionPath: string): ParsedEntry[] {
  const content = readFileSync(definitionPath, "utf8");
  const lines = content.split(/\r?\n/);

  const entries: ParsedEntry[] = [];
  let inMeta = false;
  let inPaths = false;
  let currentClass = "";
  let currentState = "";
  let currentPath = "";

  const flushEntry = () => {
    if (currentClass !== "") {
      entries.push({ class: currentClass, state: currentState, path: currentPath });
    }
    currentClass = "";
    currentState = "";
    currentPath = "";
  };

  for (const rawLine of lines) {
    if (/^meta_info:\s*$/.test(rawLine)) {
      inMeta = true;
      continue;
    }
    if (/^steps:\s*$/.test(rawLine)) {
      if (inMeta) {
        flushEntry();
        break;
      }
    }
    if (!inMeta) {
      continue;
    }
    if (!inPaths) {
      if (/^\s{2}class_repo_paths:\s*\{\}\s*$/.test(rawLine)) {
        return [];
      }
      if (/^\s{2}class_repo_paths:\s*$/.test(rawLine)) {
        inPaths = true;
        continue;
      }
      continue;
    }
    if (/^\s{2}[A-Za-z0-9_.-]+:\s*$/.test(rawLine)) {
      flushEntry();
      break;
    }
    if (/^\s{4}[A-Za-z0-9_.-]+:\s*$/.test(rawLine)) {
      flushEntry();
      const match = rawLine.match(/^\s{4}([A-Za-z0-9_.-]+):\s*$/);
      if (match) {
        currentClass = match[1].trim();
      }
      continue;
    }
    if (currentClass !== "" && /^\s{6}state:\s*/.test(rawLine)) {
      const val = rawLine.replace(/^\s{6}state:\s*/, "");
      currentState = stripYamlQuotes(val);
      continue;
    }
    if (currentClass !== "" && /^\s{6}path:\s*/.test(rawLine)) {
      const val = rawLine.replace(/^\s{6}path:\s*/, "");
      currentPath = stripYamlQuotes(val);
      continue;
    }
  }
  flushEntry();
  return entries;
}

export function collectReadyRepoPaths(definitionPath: string, supportedClasses?: string[]): ClassRepoEntry[] {
  if (!definitionPath || definitionPath.trim() === "") {
    throw new Error("class_repo_paths ready path resolution failed: definition path is required");
  }
  if (!existsSync(definitionPath)) {
    throw new Error(
      `class_repo_paths ready path resolution failed: definition file not found: ${definitionPath}`
    );
  }

  let entries: ParsedEntry[];
  try {
    entries = parseClassRepoPaths(definitionPath);
  } catch {
    throw new Error(
      `class_repo_paths ready path resolution failed: could not read meta_info.class_repo_paths from ${definitionPath}`
    );
  }

  const seenPaths = new Set<string>();
  const result: ClassRepoEntry[] = [];
  const supported = supportedClasses === undefined
    ? undefined
    : new Set(supportedClasses.map((value) => value.toLowerCase()));

  for (const entry of entries) {
    if (supported && !supported.has(entry.class.toLowerCase())) {
      continue;
    }
    const normalizedState = entry.state.toLowerCase();
    if (normalizedState !== "ready") {
      continue;
    }
    const normalizedPath = entry.path.trim();
    if (normalizedPath === "") {
      throw new Error(
        `class_repo_paths ready path resolution failed for class '${entry.class}': ready state requires non-empty path`
      );
    }
    if (!existsSync(normalizedPath) || !statSync(normalizedPath).isDirectory()) {
      throw new Error(
        `class_repo_paths ready path resolution failed for class '${entry.class}': path is not an existing directory: ${normalizedPath}`
      );
    }
    let resolved: string;
    try {
      resolved = realpathSync(normalizedPath);
    } catch {
      throw new Error(
        `class_repo_paths ready path resolution failed for class '${entry.class}': failed to resolve path: ${normalizedPath}`
      );
    }
    if (seenPaths.has(resolved)) {
      continue;
    }
    seenPaths.add(resolved);
    result.push({ class: entry.class, path: resolved });
  }

  return result;
}
