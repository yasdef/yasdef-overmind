import { existsSync, mkdirSync, readFileSync, renameSync, rmSync, writeFileSync } from "node:fs";
import path from "node:path";

import type { ProjectInitGitPort, ProjectInitResult } from "../git/index.js";
import type { InteractionPort } from "../interaction/index.js";
import { escapeYamlDoubleQuoted } from "../parse/project-definition.js";
import type { Diagnostic } from "../types/index.js";
import { resolveRepoPath } from "../workspace/index.js";

export interface ProjectCreationClock {
  now(): string;
}

export interface ProjectCreationUuid {
  next(): string;
}

export interface TempFilePort {
  writeAtomic(targetPath: string, content: string): void;
}

export class FileSystemTempFilePort implements TempFilePort {
  private counter = 0;

  writeAtomic(targetPath: string, content: string): void {
    const dir = path.dirname(targetPath);
    const tmp = path.join(
      dir,
      `.${path.basename(targetPath)}.${process.pid}.${this.counter++}.tmp`
    );
    writeFileSync(tmp, content);
    renameSync(tmp, targetPath);
  }
}

export interface CreateProjectDeps {
  interaction: InteractionPort;
  clock: ProjectCreationClock;
  uuid: ProjectCreationUuid;
  temp: TempFilePort;
  git: ProjectInitGitPort;
  templatePath?: string;
  emitError?: (line: string) => void;
}

export interface ProjectCreationResult {
  projectId?: string;
  projectFolder?: string;
  definitionPath?: string;
  metadataPath?: string;
  diagnostics: Diagnostic[];
  changedPaths: string[];
}

export type ProjectClass = "backend" | "frontend" | "mobile" | "infrastructure";
export type ProjectTypeCode = "A" | "B" | "C";
export type RepoPathState = { state: "ready" | "deferred"; path: string };

export const PROJECT_CLASSES: readonly ProjectClass[] = [
  "backend",
  "frontend",
  "mobile",
  "infrastructure"
];

export const PROJECT_TYPE_LABELS: Record<ProjectTypeCode, string> = {
  A: "New project",
  B: "Existing project with partial context",
  C: "Existing project with code-first context"
};

const SOURCE = "project-create";
const TEMPLATE_RELATIVE = path.join(".templates", "init_progress_definition_TEMPLATE.yaml");
const DEFINITION_FILE = "init_progress_definition.yaml";

export async function createProject(
  runtimeRoot: string,
  deps: CreateProjectDeps
): Promise<ProjectCreationResult> {
  const fail = (reason: string, source = SOURCE): ProjectCreationResult => ({
    diagnostics: [{ severity: "error", source, reason }],
    changedPaths: []
  });

  const metadataPath = path.join(runtimeRoot, "asdlc_metadata.yaml");
  const projectsRoot = path.join(runtimeRoot, "projects");
  const templatePath = deps.templatePath ?? path.join(runtimeRoot, TEMPLATE_RELATIVE);

  if (!existsSync(metadataPath)) return fail(`Required file not found: ${metadataPath}`);
  if (!existsSync(templatePath)) return fail(`Required file not found: ${TEMPLATE_RELATIVE}`);
  if (!existsSync(projectsRoot)) return fail(`Required directory not found: ${projectsRoot}`);

  let metadata: string;
  let template: string;
  try {
    metadata = readFileSync(metadataPath, "utf8");
    template = readFileSync(templatePath, "utf8");
  } catch (error) {
    return fail(`Failed to read workspace inputs: ${message(error)}`);
  }
  const shape = assertMetadataShape(metadata);
  if (shape) return fail(shape, metadataPath);

  const rawName = (await deps.interaction.input({ message: "Define project name:" })).trim();
  if (rawName === "") return fail("Project name cannot be empty.");
  const normalizedName = normalizeProjectName(rawName);
  if (normalizedName === "") return fail("Project name must contain at least one letter or digit.");

  const classes = await collectProjectClasses(deps.interaction);
  const repoPathStates = await collectRepoPathStates(deps.interaction, classes, deps.emitError);
  const projectTypeCode = await selectProjectType(deps.interaction);
  const projectTypeLabel = PROJECT_TYPE_LABELS[projectTypeCode];

  const projectId = `${normalizedName}-${deps.uuid.next()}`;
  const projectFolder = path.join(projectsRoot, projectId);
  const definitionPath = path.join(projectFolder, DEFINITION_FILE);
  if (existsSync(projectFolder)) return fail(`Project folder already exists: ${projectFolder}`);

  const createdAt = deps.clock.now();
  const definitionContent = renderProjectDefinition(template, {
    projectId,
    classes,
    projectTypeCode,
    projectTypeLabel,
    repoPathStates
  });
  if (!definitionContent) {
    return fail(
      `Invalid project definition template: missing top-level steps block in ${templatePath}`
    );
  }
  const nextMetadata = appendProjectRecord(metadata, {
    projectId,
    name: rawName,
    internalFolder: projectId,
    createdAt
  });

  try {
    mkdirSync(projectFolder, { recursive: false });
    deps.temp.writeAtomic(definitionPath, definitionContent);
    const gitResult = deps.git.initAndCommitDefinition(projectFolder, DEFINITION_FILE);
    if (gitResult.kind !== "ok") {
      rmSync(projectFolder, { recursive: true, force: true });
      return fail(renderProjectGitFailure(gitResult));
    }
    deps.temp.writeAtomic(metadataPath, nextMetadata);
  } catch (error) {
    rmSync(projectFolder, { recursive: true, force: true });
    return fail(`Failed to create ASDLC project: ${message(error)}`);
  }

  return {
    projectId,
    projectFolder,
    definitionPath,
    metadataPath,
    diagnostics: [],
    changedPaths: [projectFolder, definitionPath, metadataPath]
  };
}

export function normalizeProjectName(raw: string): string {
  return raw
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "_")
    .replace(/^_+/, "")
    .replace(/_+$/, "")
    .replace(/_+/g, "_");
}

async function selectProjectType(interaction: InteractionPort): Promise<ProjectTypeCode> {
  for (;;) {
    const answer = (
      await interaction.input({
        message:
          "Select project type (mandatory): 1. A - New project; 2. B - Existing project with partial context; 3. C - Existing project with code-first context"
      })
    )
      .trim()
      .toUpperCase();
    if (answer === "1" || answer === "A") return "A";
    if (answer === "2" || answer === "B") return "B";
    if (answer === "3" || answer === "C") return "C";
  }
}

async function collectProjectClasses(interaction: InteractionPort): Promise<ProjectClass[]> {
  const selected = new Set<ProjectClass>();
  for (;;) {
    const options = PROJECT_CLASSES.filter((klass) => !selected.has(klass)).map((klass) => ({
      value: klass,
      label: klass
    }));
    const canFinish = selected.size > 0;
    const answer = await interaction.select<ProjectClass | "__done__">({
      message: "Select project class to add:",
      options: [
        ...options,
        {
          value: "__done__",
          label: canFinish ? "all done, nothing else to add" : "select at least one class first"
        }
      ]
    });
    if (answer === "__done__") {
      if (canFinish) return PROJECT_CLASSES.filter((klass) => selected.has(klass));
      continue;
    }
    selected.add(answer);
  }
}

async function collectRepoPathStates(
  interaction: InteractionPort,
  classes: ProjectClass[],
  emitError?: (line: string) => void
): Promise<Record<ProjectClass, RepoPathState>> {
  const result = {} as Record<ProjectClass, RepoPathState>;
  for (const klass of classes) {
    const state = await interaction.select<"ready" | "deferred">({
      message: `we need to add repo path in your system for ${klass}`,
      options: [
        { value: "ready", label: "yes, ready to add" },
        { value: "deferred", label: "no, I'll add it later" }
      ]
    });
    if (state === "deferred") {
      result[klass] = { state: "deferred", path: "" };
      continue;
    }
    for (;;) {
      const input = await interaction.input({ message: `Enter repo path for ${klass}:` });
      const resolved = resolveRepoPath(input);
      if (resolved.path) {
        result[klass] = { state: "ready", path: resolved.path };
        break;
      }
      for (const diagnostic of resolved.diagnostics) emitError?.(diagnostic.reason);
    }
  }
  return result;
}

function renderProjectDefinition(
  template: string,
  values: {
    projectId: string;
    classes: ProjectClass[];
    projectTypeCode: ProjectTypeCode;
    projectTypeLabel: string;
    repoPathStates: Record<ProjectClass, RepoPathState>;
  }
): string | undefined {
  const lines = template.split(/\r?\n/);
  const stepsIndex = lines.findIndex((line) => /^steps:\s*$/.test(line));
  if (stepsIndex < 0) return undefined;
  const metaInfo = [
    "meta_info:",
    `  project_id: "${escapeYamlDoubleQuoted(values.projectId)}"`,
    "  project_classes:",
    ...values.classes.map((klass) => `    - ${klass}`),
    `  project_type_code: "${escapeYamlDoubleQuoted(values.projectTypeCode)}"`,
    `  project_type_label: "${escapeYamlDoubleQuoted(values.projectTypeLabel)}"`,
    "  class_repo_paths:"
  ];
  for (const klass of values.classes) {
    const state = values.repoPathStates[klass];
    metaInfo.push(`    ${klass}:`);
    metaInfo.push(`      state: "${escapeYamlDoubleQuoted(state.state)}"`);
    metaInfo.push(`      path: "${escapeYamlDoubleQuoted(state.path)}"`);
  }

  const metaStart = lines.slice(0, stepsIndex).findIndex((line) => /^meta_info:\s*$/.test(line));
  if (metaStart < 0) {
    return [...lines.slice(0, stepsIndex), ...metaInfo, "", ...lines.slice(stepsIndex)].join("\n");
  }

  let metaEnd = stepsIndex;
  for (let index = metaStart + 1; index < stepsIndex; index += 1) {
    if (/^\S/.test(lines[index] ?? "")) {
      metaEnd = index;
      break;
    }
  }
  const out = [
    ...lines.slice(0, metaStart),
    ...metaInfo,
    ...lines.slice(metaEnd, stepsIndex),
    ...lines.slice(stepsIndex)
  ];
  return out.join("\n");
}

function assertMetadataShape(content: string): string | undefined {
  const lines = content.split(/\r?\n/);
  if (!lines.some((line) => /^meta:\s*$/.test(line))) {
    return "Invalid ASDLC metadata: missing top-level key 'meta'.";
  }
  if (!lines.some((line) => /^projects:\s*$/.test(line))) {
    return "Invalid ASDLC metadata: missing top-level key 'projects'.";
  }
  let lastTopKey: string | undefined;
  for (const line of lines) {
    const match = line.match(/^[^\s#][^:]*:\s*$/);
    if (match) lastTopKey = line.replace(/:\s*$/, "");
  }
  if (lastTopKey !== "projects") {
    return "Invalid ASDLC metadata: top-level key 'projects' must be the final section.";
  }
  return undefined;
}

function appendProjectRecord(
  metadata: string,
  record: { projectId: string; name: string; internalFolder: string; createdAt: string }
): string {
  const normalized = metadata.replace(/(?:\r?\n[ \t]*)*$/, "");
  return `${normalized}
  - project: ${record.projectId}
    name: "${escapeYamlDoubleQuoted(record.name)}"
    internal_folder: "${escapeYamlDoubleQuoted(record.internalFolder)}"
    created_at: "${escapeYamlDoubleQuoted(record.createdAt)}"
`;
}

function renderProjectGitFailure(result: Exclude<ProjectInitResult, { kind: "ok" }>): string {
  switch (result.kind) {
    case "unavailable":
      return "Failed to initialize project git repository: git not found in PATH.";
    case "initFailed":
      return `Failed to initialize project git repository: git init exited ${result.exitCode}.`;
    case "identityFailed":
      return `Failed to configure git ${result.field} for project repo: git config exited ${result.exitCode}.`;
    case "stageFailed":
      return `Failed to stage initial project definition for git bootstrap: git add exited ${result.exitCode}.`;
    case "commitFailed":
      return `Failed to create initial project git commit: git commit exited ${result.exitCode}.`;
  }
}

function message(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}
