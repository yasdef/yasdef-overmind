import { readFileSync } from "node:fs";

import type { Diagnostic } from "../types/index.js";

export type ProjectClassState = "ready" | "deferred";
export type ProjectClassPolicy = "A" | "B" | "C";

export const CANONICAL_PROJECT_CLASSES = [
  "backend",
  "frontend",
  "mobile",
  "infrastructure"
] as const;

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
 * set the target class to `state: "ready"`, canonical `path`, selected policy, and clear any
 * `contract_reconciled` field so repo identity changes invalidate reconciliation.
 * Unrelated definition content (other classes, steps, formatting) is preserved. Returns
 * an error string when the class is not present in `class_repo_paths`.
 */
export function applyClassAttachment(
  content: string,
  className: string,
  resolvedRepoPath: string,
  policy: ProjectClassPolicy
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
          out.push(`      policy: "${policy}"`);
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

export function applyDeferredClassPolicy(
  content: string,
  className: string,
  policy: ProjectClassPolicy
): { content: string } | { error: string } {
  const target = className.toLowerCase();
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
          out.push('      state: "deferred"');
          out.push('      path: ""');
          out.push(`      policy: "${policy}"`);
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

export type ProjectClassMembershipAction = "added" | "reset";

export function applyProjectClassMembership(
  content: string,
  className: string
): { content: string; action: ProjectClassMembershipAction } | { error: string } {
  const target = className.toLowerCase();
  if (!(CANONICAL_PROJECT_CLASSES as readonly string[]).includes(target)) {
    return { error: `Unsupported project class '${className}'.` };
  }

  const lines = content.split(/\r?\n/);
  const metaStart = lines.findIndex((line) => /^meta_info:\s*$/.test(line));
  const stepsStart = lines.findIndex((line) => /^steps:\s*$/.test(line));
  if (metaStart < 0 || stepsStart <= metaStart) {
    return { error: "Malformed definition: missing meta_info or steps block." };
  }

  const meta = lines.slice(metaStart + 1, stepsStart);
  const existingClasses = parseProjectClasses(meta);
  const action: ProjectClassMembershipAction = existingClasses.includes(target) ? "reset" : "added";
  const nextClasses = canonicalizeClasses([...existingClasses, target]);
  const classIndex = meta.findIndex((line) => /^\s{2}project_classes:/.test(line));
  const reposIndex = meta.findIndex((line) => /^\s{2}class_repo_paths:/.test(line));
  if (classIndex < 0) return { error: "Malformed metadata: project_classes is missing." };
  if (reposIndex < 0) return { error: "Malformed metadata: class_repo_paths is missing." };

  const renderedClasses = renderProjectClasses(nextClasses);
  const withClasses = replaceMetaBlock(meta, classIndex, renderedClasses);
  const adjustedReposIndex = adjustMetaBlockIndex(meta, classIndex, renderedClasses, reposIndex);
  const renderedMeta = replaceClassRepoPathsBlock(
    withClasses,
    adjustedReposIndex,
    nextClasses,
    target
  );

  return {
    action,
    content: [...lines.slice(0, metaStart + 1), ...renderedMeta, ...lines.slice(stepsStart)].join(
      "\n"
    )
  };
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

function canonicalizeClasses(classes: string[]): string[] {
  const wanted = new Set(classes.map((klass) => klass.toLowerCase()));
  return CANONICAL_PROJECT_CLASSES.filter((klass) => wanted.has(klass));
}

function parseProjectClasses(meta: string[]): string[] {
  const inlineClasses = meta.find((line) => /^\s{2}project_classes:\s*\[/.test(line));
  if (inlineClasses) {
    const match = inlineClasses.match(/\[([^\]]*)\]/);
    return canonicalizeClasses((match?.[1] ?? "").split(",").map(scalar).filter(Boolean));
  }
  const classIndex = meta.findIndex((line) => /^\s{2}project_classes:\s*$/.test(line));
  if (classIndex < 0) return [];
  const classes: string[] = [];
  for (const line of meta.slice(classIndex + 1)) {
    const item = line.match(/^\s{4}-\s*(.+)$/);
    if (item) classes.push(scalar(item[1]!));
    else if (/^\s{2}\S/.test(line)) break;
  }
  return canonicalizeClasses(classes);
}

function renderProjectClasses(classes: string[]): string[] {
  return ["  project_classes:", ...classes.map((klass) => `    - ${klass}`)];
}

function renderDeferredClassRepoBlock(className: string): string[] {
  return [`    ${className}:`, '      state: "deferred"', '      path: ""', '      policy: "A"'];
}

function replaceClassRepoPathsBlock(
  meta: string[],
  reposIndex: number,
  classes: string[],
  target: string
): string[] {
  if (classes.length === 0) {
    return replaceMetaBlock(meta, reposIndex, ["  class_repo_paths: {}"]);
  }

  const endIndex = metaBlockEnd(meta, reposIndex);
  const body = meta.slice(reposIndex + 1, endIndex);
  const { prefix, blocks } = collectClassRepoBlocks(body);
  const lines = ["  class_repo_paths:"];
  lines.push(...prefix);
  for (const klass of classes) {
    lines.push(
      ...(klass === target
        ? renderDeferredClassRepoBlock(klass)
        : (blocks.get(klass) ?? renderDeferredClassRepoBlock(klass)))
    );
  }
  return [...meta.slice(0, reposIndex), ...lines, ...meta.slice(endIndex)];
}

function collectClassRepoBlocks(body: string[]): {
  prefix: string[];
  blocks: Map<string, string[]>;
} {
  const blocks = new Map<string, string[]>();
  const prefix: string[] = [];
  let index = 0;
  while (index < body.length && !/^ {4}[A-Za-z][A-Za-z0-9_-]*:\s*$/.test(body[index] ?? "")) {
    prefix.push(body[index]!);
    index += 1;
  }
  while (index < body.length) {
    const header = body[index]?.match(/^ {4}([A-Za-z][A-Za-z0-9_-]*):\s*$/);
    if (!header) {
      index += 1;
      continue;
    }
    const start = index;
    index += 1;
    while (index < body.length && !/^ {4}[A-Za-z][A-Za-z0-9_-]*:\s*$/.test(body[index] ?? "")) {
      index += 1;
    }
    blocks.set(header[1]!.toLowerCase(), body.slice(start, index));
  }
  return { prefix, blocks };
}

function replaceMetaBlock(meta: string[], startIndex: number, replacement: string[]): string[] {
  const endIndex = metaBlockEnd(meta, startIndex);
  return [...meta.slice(0, startIndex), ...replacement, ...meta.slice(endIndex)];
}

function metaBlockEnd(meta: string[], startIndex: number): number {
  let endIndex = startIndex + 1;
  while (endIndex < meta.length && !/^\s{2}\S/.test(meta[endIndex] ?? "")) {
    endIndex += 1;
  }
  return endIndex;
}

function adjustMetaBlockIndex(
  originalMeta: string[],
  classIndex: number,
  renderedClasses: string[],
  originalReposIndex: number
): number {
  if (originalReposIndex < classIndex) return originalReposIndex;
  const originalClassEnd = metaBlockEnd(originalMeta, classIndex);
  const delta = renderedClasses.length - (originalClassEnd - classIndex);
  return originalReposIndex + delta;
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
