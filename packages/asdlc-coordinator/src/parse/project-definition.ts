import { readFileSync } from "node:fs";

import type { Diagnostic } from "../types/index.js";

export type ProjectClassState = "ready" | "deferred";

export interface ClassRepoPath {
  state?: ProjectClassState;
  path?: string;
  policy?: string;
  /** Target reconciliation field (decision 9); Slice 4 owns writing it. */
  contractReconciled?: boolean;
}

export interface ProjectDefinitionMetadata {
  projectId?: string;
  projectTypeCode?: string;
  projectClasses: string[];
  classRepoPaths: Record<string, ClassRepoPath>;
  diagnostics: Diagnostic[];
  parsed: boolean;
}

/** Escape a value for a YAML double-quoted scalar (backslash and double-quote). */
export function escapeYamlDoubleQuoted(value: string): string {
  return value.replace(/\\/g, "\\\\").replace(/"/g, '\\"');
}

/**
 * Deterministic line-based attach mutation (D3): within `meta_info.class_repo_paths`,
 * set the target class to `state: "ready"`, canonical `path`, `policy: "C"`, and clear
 * any `contract_reconciled` field so repo identity changes invalidate reconciliation.
 * Unrelated definition content (other classes, steps, formatting) is preserved. Returns
 * an error string when the class is not present in `class_repo_paths`.
 */
export function applyClassAttachment(
  content: string,
  className: string,
  resolvedRepoPath: string
): { content: string } | { error: string } {
  const target = className.toLowerCase();
  const escaped = escapeYamlDoubleQuoted(resolvedRepoPath);
  const lines = content.split(/\r?\n/);
  const out: string[] = [];
  let inRepos = false;
  let inTarget = false;
  let found = false;

  for (const line of lines) {
    if (!inRepos && /^ {2}class_repo_paths:\s*$/.test(line)) {
      inRepos = true;
      out.push(line);
      continue;
    }
    if (inRepos && /^[^ ]/.test(line)) {
      inRepos = false;
      inTarget = false;
      out.push(line);
      continue;
    }
    if (inRepos) {
      const header = line.match(/^ {4}([A-Za-z][A-Za-z0-9_-]*):\s*$/);
      if (header) {
        inTarget = header[1]!.toLowerCase() === target;
        out.push(line);
        if (inTarget) {
          found = true;
          out.push('      state: "ready"');
          out.push(`      path: "${escaped}"`);
          out.push('      policy: "C"');
        }
        continue;
      }
      if (inTarget && /^ {6}(state|path|policy|contract_reconciled):/.test(line)) {
        continue;
      }
    }
    out.push(line);
  }

  if (!found) {
    return { error: `Class '${className}' not found in class_repo_paths.` };
  }
  return { content: out.join("\n") };
}

/**
 * Set (or clear) `contract_reconciled` for the named classes inside
 * `meta_info.class_repo_paths`, preserving unrelated content. Exactly one
 * `contract_reconciled` line results per targeted class. Success-bound flags are the
 * sole completion source (D8); a failed batch never calls this.
 */
export function applyContractReconciledFlags(
  content: string,
  classNames: string[],
  value: boolean
): string {
  const targets = new Set(classNames.map((name) => name.toLowerCase()));
  const lines = content.split(/\r?\n/);
  const out: string[] = [];
  let inRepos = false;
  let inTarget = false;

  for (const line of lines) {
    if (!inRepos && /^ {2}class_repo_paths:\s*$/.test(line)) {
      inRepos = true;
      out.push(line);
      continue;
    }
    if (inRepos && /^[^ ]/.test(line)) {
      inRepos = false;
      inTarget = false;
      out.push(line);
      continue;
    }
    if (inRepos) {
      const header = line.match(/^ {4}([A-Za-z][A-Za-z0-9_-]*):\s*$/);
      if (header) {
        inTarget = targets.has(header[1]!.toLowerCase());
        out.push(line);
        if (inTarget) out.push(`      contract_reconciled: ${value}`);
        continue;
      }
      if (inTarget && /^ {6}contract_reconciled:/.test(line)) {
        continue;
      }
    }
    out.push(line);
  }
  return out.join("\n");
}

function scalar(value: string): string {
  const trimmed = value.trim().replace(/\s+#.*$/, "");
  if (
    (trimmed.startsWith('"') && trimmed.endsWith('"')) ||
    (trimmed.startsWith("'") && trimmed.endsWith("'"))
  ) {
    return trimmed.slice(1, -1);
  }
  return trimmed;
}

function diagnostic(source: string, reason: string): Diagnostic {
  return { severity: "error", source, reason };
}

export function readProjectDefinitionMetadata(definitionPath: string): ProjectDefinitionMetadata {
  const result: ProjectDefinitionMetadata = {
    projectClasses: [],
    classRepoPaths: {},
    diagnostics: [],
    parsed: false
  };
  let content: string;
  try {
    content = readFileSync(definitionPath, "utf8");
  } catch (error) {
    result.diagnostics.push(
      diagnostic(
        definitionPath,
        `Unable to read init progress definition: ${error instanceof Error ? error.message : String(error)}`
      )
    );
    return result;
  }

  const lines = content.split(/\r?\n/);
  const metaStart = lines.findIndex((line) => /^meta_info:\s*$/.test(line));
  const stepsStart = lines.findIndex((line) => /^steps:\s*$/.test(line));
  if (metaStart < 0 || stepsStart <= metaStart) {
    result.diagnostics.push(
      diagnostic(definitionPath, "Malformed definition: missing meta_info or steps block.")
    );
    return result;
  }

  const meta = lines.slice(metaStart + 1, stepsStart);
  const projectIdLine = meta.find((line) => /^\s{2}project_id:\s*/.test(line));
  if (projectIdLine) result.projectId = scalar(projectIdLine.replace(/^\s{2}project_id:\s*/, ""));

  const typeLine = meta.find((line) => /^\s{2}project_type_code:\s*/.test(line));
  if (typeLine)
    result.projectTypeCode = scalar(typeLine.replace(/^\s{2}project_type_code:\s*/, ""));

  const inlineClasses = meta.find((line) => /^\s{2}project_classes:\s*\[/.test(line));
  if (inlineClasses) {
    const match = inlineClasses.match(/\[([^\]]*)\]/);
    result.projectClasses = (match?.[1] ?? "")
      .split(",")
      .map(scalar)
      .map((value) => value.toLowerCase())
      .filter(Boolean);
  } else {
    const classIndex = meta.findIndex((line) => /^\s{2}project_classes:\s*$/.test(line));
    if (classIndex >= 0) {
      for (const line of meta.slice(classIndex + 1)) {
        const item = line.match(/^\s{4}-\s*(.+)$/);
        if (item) result.projectClasses.push(scalar(item[1]!).toLowerCase());
        else if (/^\s{2}\S/.test(line)) break;
      }
    }
  }

  const reposIndex = meta.findIndex((line) => /^\s{2}class_repo_paths:\s*(?:\{\})?\s*$/.test(line));
  if (reposIndex >= 0) {
    let current: string | undefined;
    for (const line of meta.slice(reposIndex + 1)) {
      const classMatch = line.match(/^\s{4}([A-Za-z0-9_-]+):\s*$/);
      if (classMatch) {
        current = classMatch[1]!.toLowerCase();
        result.classRepoPaths[current] = {};
        continue;
      }
      if (/^\s{2}\S/.test(line)) break;
      const field = line.match(/^\s{6}(state|path|policy|contract_reconciled):\s*(.*)$/);
      if (current && field) {
        const value = scalar(field[2]!);
        const entry = result.classRepoPaths[current]!;
        if (field[1] === "state") {
          if (value === "ready" || value === "deferred") entry.state = value;
          else
            result.diagnostics.push(
              diagnostic(definitionPath, `Invalid class_repo_paths.${current}.state: ${value}`)
            );
        } else if (field[1] === "path") entry.path = value;
        else if (field[1] === "contract_reconciled") entry.contractReconciled = value === "true";
        else entry.policy = value;
      }
    }
  }

  if (!result.projectTypeCode) {
    result.diagnostics.push(
      diagnostic(definitionPath, "Malformed metadata: project_type_code is missing.")
    );
  }
  if (!meta.some((line) => /^\s{2}project_classes:/.test(line))) {
    result.diagnostics.push(
      diagnostic(definitionPath, "Malformed metadata: project_classes is missing.")
    );
  }
  if (reposIndex < 0) {
    result.diagnostics.push(
      diagnostic(definitionPath, "Malformed metadata: class_repo_paths is missing.")
    );
  }
  result.parsed = result.diagnostics.length === 0;
  return result;
}
