import * as vscode from 'vscode';
import {
  ASDLC_METADATA_FILE,
  AsdlcWorkspaceDiagnostic,
  DiagnosticSeverity,
  getWorkspaceDisplayPath,
  WorkspaceFileSystem
} from './workspaceDetection';
import { parseSimpleYaml } from './simpleYaml';
import { computeDashboardReadiness } from './readiness';

const PROJECTS_FOLDER = 'projects';
const PROJECT_INIT_FILE = 'init_progress_definition.yaml';
const PROJECT_STEP_STATE_FILE = 'step_state.md';
const PROJECT_FEATURE_STEP_STATE_FILE_PREFIX = 'step_state_';
const PROJECT_FEATURE_STEP_STATE_FILE_SUFFIX = '.md';
const FEATURE_MARKER_FILE = 'feature_br_summary.md';
const FEATURE_STEP_STATE_FILE = 'step_state.md';

export const PROJECT_ARTIFACT_DEFINITIONS: readonly ArtifactDefinition[] = [
  { name: PROJECT_INIT_FILE, required: true },
  { name: PROJECT_STEP_STATE_FILE, required: false }
];

export const FEATURE_ARTIFACT_DEFINITIONS: readonly ArtifactDefinition[] = [
  { name: FEATURE_MARKER_FILE, required: true },
  { name: 'user_br_input.md', required: true },
  { name: 'feature_design.md', required: true },
  { name: 'step_plan.md', required: true }
];

export type DashboardScanStatus = 'ready' | 'stale' | 'scanning' | 'failed';
export type ProjectReadiness = 'complete' | 'partial' | 'blocked' | 'unknown';
export type FeatureReadiness = 'ready' | 'in_progress' | 'blocked' | 'unknown';
export type ProjectClassState = 'ready' | 'deferred' | 'unknown';
export type ArtifactScope = 'project' | 'feature';

export interface ScannerFileSystem extends WorkspaceFileSystem {
  readDirectory(uri: vscode.Uri): Thenable<[string, vscode.FileType][]>;
}

export interface ArtifactDefinition {
  readonly name: string;
  readonly required: boolean;
}

export interface DashboardModel {
  readonly workspacePath: string;
  readonly scanStatus: DashboardScanStatus;
  readonly projects: ProjectSummary[];
  readonly diagnostics: AsdlcWorkspaceDiagnostic[];
}

export interface ProjectSummary {
  readonly projectId: string;
  readonly name: string;
  readonly folderPath: string;
  readonly createdAt?: string;
  readonly projectTypeCode?: string;
  readonly classes: ProjectClassSummary[];
  readonly projectReadiness: ProjectReadiness;
  readonly completedSteps: number;
  readonly totalSteps: number;
  readonly artifacts: ArtifactSummary[];
  readonly missingArtifacts: string[];
  readonly features: FeatureSummary[];
}

export interface ProjectClassSummary {
  readonly className: string;
  readonly repoPath?: string;
  readonly state: ProjectClassState;
}

export interface FeatureSummary {
  readonly featureId: string;
  readonly name: string;
  readonly folderPath: string;
  readonly readiness: FeatureReadiness;
  readonly completedSteps: number;
  readonly totalSteps: number;
  readonly missingArtifacts: string[];
  readonly artifacts: ArtifactSummary[];
}

export interface ArtifactSummary {
  readonly name: string;
  readonly uri: string;
  readonly path: string;
  readonly scope: ArtifactScope;
  readonly exists: boolean;
  readonly required: boolean;
}

interface ProjectMetadataEntry {
  readonly projectId: string;
  readonly name: string;
  readonly createdAt?: string;
}

interface ParsedYamlFile {
  readonly value?: Record<string, unknown>;
  readonly parsed: boolean;
}

export async function scanAsdlcWorkspace(
  workspaceUri: vscode.Uri,
  fileSystem: ScannerFileSystem = vscode.workspace.fs
): Promise<DashboardModel> {
  const diagnostics: AsdlcWorkspaceDiagnostic[] = [];
  const metadataUri = vscode.Uri.joinPath(workspaceUri, ASDLC_METADATA_FILE);
  const metadata = await readYamlMapping(metadataUri, fileSystem, diagnostics, 'asdlc.metadata');

  if (!metadata.parsed || !metadata.value) {
    return {
      workspacePath: getWorkspaceDisplayPath(workspaceUri),
      scanStatus: 'failed',
      projects: [],
      diagnostics
    };
  }

  const projects = await scanProjects(
    workspaceUri,
    extractProjects(metadata.value, diagnostics, metadataUri),
    fileSystem,
    diagnostics
  );

  return computeDashboardReadiness({
    workspacePath: getWorkspaceDisplayPath(workspaceUri),
    scanStatus: 'ready',
    projects,
    diagnostics
  });
}

async function scanProjects(
  workspaceUri: vscode.Uri,
  projectEntries: readonly ProjectMetadataEntry[],
  fileSystem: ScannerFileSystem,
  diagnostics: AsdlcWorkspaceDiagnostic[]
): Promise<ProjectSummary[]> {
  const projects = await Promise.all(
    projectEntries.map((projectEntry) => scanProject(workspaceUri, projectEntry, fileSystem, diagnostics))
  );

  return projects;
}

async function scanProject(
  workspaceUri: vscode.Uri,
  projectEntry: ProjectMetadataEntry,
  fileSystem: ScannerFileSystem,
  diagnostics: AsdlcWorkspaceDiagnostic[]
): Promise<ProjectSummary> {
  const projectUri = vscode.Uri.joinPath(workspaceUri, PROJECTS_FOLDER, projectEntry.projectId);
  const folderPath = getWorkspaceDisplayPath(projectUri);
  const projectFolderExists = await isDirectory(projectUri, fileSystem);
  const artifacts = await scanArtifacts(projectUri, 'project', PROJECT_ARTIFACT_DEFINITIONS, fileSystem);
  const missingArtifacts = artifacts.filter((artifact) => !artifact.exists).map((artifact) => artifact.name);
  let projectTypeCode: string | undefined;
  let classes: ProjectClassSummary[] = [];
  let features: FeatureSummary[] = [];
  let stepCounts = { completed: 0, total: 0 };

  if (!projectFolderExists) {
    diagnostics.push(createDiagnostic(
      'error',
      'project.folder.missing',
      folderPath,
      `Project folder "${projectEntry.projectId}" is listed in ${ASDLC_METADATA_FILE} but is missing.`
    ));

    return {
      projectId: projectEntry.projectId,
      name: projectEntry.name,
      folderPath,
      createdAt: projectEntry.createdAt,
      classes,
      projectReadiness: 'blocked',
      completedSteps: stepCounts.completed,
      totalSteps: stepCounts.total,
      artifacts,
      missingArtifacts,
      features
    };
  }

  const initUri = vscode.Uri.joinPath(projectUri, PROJECT_INIT_FILE);

  if (artifacts.some((artifact) => artifact.name === PROJECT_INIT_FILE && artifact.exists)) {
    const initDefinition = await readYamlMapping(initUri, fileSystem, diagnostics, 'project.init');

    if (initDefinition.value) {
      projectTypeCode = extractProjectTypeCode(initDefinition.value);
      classes = extractProjectClasses(initDefinition.value);
    }
  } else {
    diagnostics.push(createDiagnostic(
      'error',
      'project.init.missing',
      getWorkspaceDisplayPath(initUri),
      `${PROJECT_INIT_FILE} is missing for project "${projectEntry.projectId}".`
    ));
  }

  stepCounts = await readStepCounts(vscode.Uri.joinPath(projectUri, PROJECT_STEP_STATE_FILE), fileSystem, diagnostics, 'project');
  features = await scanFeatures(projectUri, projectEntry.projectId, fileSystem, diagnostics);

  return {
    projectId: projectEntry.projectId,
    name: projectEntry.name,
    folderPath,
    createdAt: projectEntry.createdAt,
    projectTypeCode,
    classes,
    projectReadiness: 'unknown',
    completedSteps: stepCounts.completed,
    totalSteps: stepCounts.total,
    artifacts,
    missingArtifacts,
    features
  };
}

async function scanFeatures(
  projectUri: vscode.Uri,
  projectId: string,
  fileSystem: ScannerFileSystem,
  diagnostics: AsdlcWorkspaceDiagnostic[]
): Promise<FeatureSummary[]> {
  let entries: [string, vscode.FileType][];

  try {
    entries = await fileSystem.readDirectory(projectUri);
  } catch (error) {
    diagnostics.push(createDiagnostic(
      'error',
      'project.directory.unreadable',
      getWorkspaceDisplayPath(projectUri),
      `Could not list feature folders for project "${projectId}": ${getErrorMessage(error)}`
    ));

    return [];
  }

  const featureFolders = entries
    .filter(([, type]) => (type & vscode.FileType.Directory) !== 0)
    .map(([name]) => name)
    .sort((left, right) => left.localeCompare(right));
  const features: FeatureSummary[] = [];

  for (const featureId of featureFolders) {
    const featureUri = vscode.Uri.joinPath(projectUri, featureId);
    const markerUri = vscode.Uri.joinPath(featureUri, FEATURE_MARKER_FILE);

    if (!await isFile(markerUri, fileSystem)) {
      continue;
    }

    features.push(await scanFeature(projectUri, featureUri, featureId, fileSystem, diagnostics));
  }

  return features;
}

async function scanFeature(
  projectUri: vscode.Uri,
  featureUri: vscode.Uri,
  featureId: string,
  fileSystem: ScannerFileSystem,
  diagnostics: AsdlcWorkspaceDiagnostic[]
): Promise<FeatureSummary> {
  const artifacts = await scanArtifacts(featureUri, 'feature', FEATURE_ARTIFACT_DEFINITIONS, fileSystem);
  const missingArtifacts = artifacts.filter((artifact) => !artifact.exists).map((artifact) => artifact.name);
  const markerUri = vscode.Uri.joinPath(featureUri, FEATURE_MARKER_FILE);
  const stepStateUri = await resolveFeatureStepStateUri(projectUri, featureUri, featureId, fileSystem);
  const name = await readFeatureName(markerUri, featureId, fileSystem, diagnostics);
  const stepCounts = await readStepCounts(stepStateUri, fileSystem, diagnostics, 'feature');

  return {
    featureId,
    name,
    folderPath: getWorkspaceDisplayPath(featureUri),
    readiness: 'unknown',
    completedSteps: stepCounts.completed,
    totalSteps: stepCounts.total,
    missingArtifacts,
    artifacts
  };
}

async function resolveFeatureStepStateUri(
  projectUri: vscode.Uri,
  featureUri: vscode.Uri,
  featureId: string,
  fileSystem: ScannerFileSystem
): Promise<vscode.Uri> {
  const scannerOutputUri = vscode.Uri.joinPath(
    projectUri,
    `${PROJECT_FEATURE_STEP_STATE_FILE_PREFIX}${featureId}${PROJECT_FEATURE_STEP_STATE_FILE_SUFFIX}`
  );

  if (await isFile(scannerOutputUri, fileSystem)) {
    return scannerOutputUri;
  }

  return vscode.Uri.joinPath(featureUri, FEATURE_STEP_STATE_FILE);
}

async function scanArtifacts(
  parentUri: vscode.Uri,
  scope: ArtifactScope,
  definitions: readonly ArtifactDefinition[],
  fileSystem: ScannerFileSystem
): Promise<ArtifactSummary[]> {
  const artifacts = await Promise.all(
    definitions.map(async (definition) => {
      const artifactUri = vscode.Uri.joinPath(parentUri, definition.name);

      return {
        name: definition.name,
        uri: artifactUri.toString(),
        path: getWorkspaceDisplayPath(artifactUri),
        scope,
        exists: await isFile(artifactUri, fileSystem),
        required: definition.required
      };
    })
  );

  return artifacts;
}

async function readYamlMapping(
  uri: vscode.Uri,
  fileSystem: ScannerFileSystem,
  diagnostics: AsdlcWorkspaceDiagnostic[],
  codePrefix: string
): Promise<ParsedYamlFile> {
  let content: string;

  try {
    content = Buffer.from(await fileSystem.readFile(uri)).toString('utf8');
  } catch (error) {
    diagnostics.push(createDiagnostic(
      'error',
      `${codePrefix}.unreadable`,
      getWorkspaceDisplayPath(uri),
      `Could not read YAML file: ${getErrorMessage(error)}`
    ));

    return { parsed: false };
  }

  try {
    const parsed = parseSimpleYaml(content);

    if (!isRecord(parsed)) {
      diagnostics.push(createDiagnostic(
        'error',
        `${codePrefix}.invalid`,
        getWorkspaceDisplayPath(uri),
        'Expected YAML mapping content.'
      ));

      return { parsed: false };
    }

    return { parsed: true, value: parsed };
  } catch (error) {
    diagnostics.push(createDiagnostic(
      'error',
      `${codePrefix}.parseFailed`,
      getWorkspaceDisplayPath(uri),
      `Could not parse YAML file: ${getErrorMessage(error)}`
    ));

    return { parsed: false };
  }
}

function extractProjects(
  metadata: Record<string, unknown>,
  diagnostics: AsdlcWorkspaceDiagnostic[],
  metadataUri: vscode.Uri
): ProjectMetadataEntry[] {
  const rawProjects = metadata.projects;

  if (rawProjects === undefined) {
    diagnostics.push(createDiagnostic(
      'warning',
      'asdlc.metadata.projectsMissing',
      getWorkspaceDisplayPath(metadataUri),
      `${ASDLC_METADATA_FILE} does not define a projects collection.`
    ));

    return [];
  }

  if (Array.isArray(rawProjects)) {
    return rawProjects.flatMap((project, index) => {
      const entry = extractProjectFromArrayItem(project);

      if (!entry) {
        diagnostics.push(createDiagnostic(
          'warning',
          'asdlc.metadata.projectInvalid',
          getWorkspaceDisplayPath(metadataUri),
          `Project entry at index ${index} is missing a project id.`
        ));
      }

      return entry ? [entry] : [];
    });
  }

  if (isRecord(rawProjects)) {
    return Object.entries(rawProjects).flatMap(([projectId, project]) => {
      const projectRecord = isRecord(project) ? project : {};
      const normalizedProjectId = getFirstString(projectRecord, ['project_id', 'projectId', 'id']) ?? projectId;

      if (!normalizedProjectId) {
        return [];
      }

      return [{
        projectId: normalizedProjectId,
        name: getFirstString(projectRecord, ['name', 'project_name', 'display_name']) ?? normalizedProjectId,
        createdAt: getFirstString(projectRecord, ['created_at', 'createdAt', 'created'])
      }];
    });
  }

  diagnostics.push(createDiagnostic(
    'error',
    'asdlc.metadata.projectsInvalid',
    getWorkspaceDisplayPath(metadataUri),
    `${ASDLC_METADATA_FILE} projects must be a list or mapping.`
  ));

  return [];
}

function extractProjectFromArrayItem(project: unknown): ProjectMetadataEntry | undefined {
  if (typeof project === 'string' && project.trim().length > 0) {
    return {
      projectId: project.trim(),
      name: project.trim()
    };
  }

  if (!isRecord(project)) {
    return undefined;
  }

  const projectId = getFirstString(project, ['project_id', 'projectId', 'id']);

  if (!projectId) {
    return undefined;
  }

  return {
    projectId,
    name: getFirstString(project, ['name', 'project_name', 'display_name']) ?? projectId,
    createdAt: getFirstString(project, ['created_at', 'createdAt', 'created'])
  };
}

function extractProjectTypeCode(initDefinition: Record<string, unknown>): string | undefined {
  const metaInfo = getRecord(initDefinition, 'meta_info');

  return getFirstString(initDefinition, ['project_type_code', 'projectTypeCode']) ??
    (metaInfo ? getFirstString(metaInfo, ['project_type_code', 'projectTypeCode']) : undefined);
}

function extractProjectClasses(initDefinition: Record<string, unknown>): ProjectClassSummary[] {
  const metaInfo = getRecord(initDefinition, 'meta_info') ?? initDefinition;
  const rawProjectClasses = metaInfo.project_classes;
  const rawRepoPaths = getRecord(metaInfo, 'class_repo_paths') ?? {};
  const classNames = new Set<string>();

  for (const className of extractClassNames(rawProjectClasses)) {
    classNames.add(className);
  }

  for (const className of Object.keys(rawRepoPaths)) {
    classNames.add(className);
  }

  return [...classNames]
    .sort((left, right) => left.localeCompare(right))
    .map((className) => {
      const repoPath = getStringValue(rawRepoPaths[className]);
      const state = repoPath === undefined
        ? 'unknown'
        : repoPath.toLowerCase() === 'deferred'
          ? 'deferred'
          : repoPath.length > 0
            ? 'ready'
            : 'unknown';

      return {
        className,
        repoPath: repoPath && state !== 'deferred' ? repoPath : undefined,
        state
      };
    });
}

function extractClassNames(value: unknown): string[] {
  if (Array.isArray(value)) {
    return value.flatMap((item) => {
      if (typeof item === 'string') {
        return item.trim().length > 0 ? [item.trim()] : [];
      }

      if (isRecord(item)) {
        const className = getFirstString(item, ['class_name', 'className', 'name', 'id']);

        return className ? [className] : [];
      }

      return [];
    });
  }

  if (isRecord(value)) {
    return Object.keys(value);
  }

  if (typeof value === 'string') {
    return value
      .split(',')
      .map((item) => item.trim())
      .filter((item) => item.length > 0);
  }

  return [];
}

async function readFeatureName(
  markerUri: vscode.Uri,
  fallbackName: string,
  fileSystem: ScannerFileSystem,
  diagnostics: AsdlcWorkspaceDiagnostic[]
): Promise<string> {
  try {
    const content = Buffer.from(await fileSystem.readFile(markerUri)).toString('utf8');
    const heading = content
      .split(/\r?\n/)
      .map((line) => /^#\s+(.+)$/.exec(line.trim())?.[1]?.trim())
      .find((value) => value !== undefined && value.length > 0);

    return heading ?? fallbackName;
  } catch (error) {
    diagnostics.push(createDiagnostic(
      'warning',
      'feature.summary.unreadable',
      getWorkspaceDisplayPath(markerUri),
      `Could not read feature summary heading: ${getErrorMessage(error)}`
    ));

    return fallbackName;
  }
}

async function readStepCounts(
  stepStateUri: vscode.Uri,
  fileSystem: ScannerFileSystem,
  diagnostics: AsdlcWorkspaceDiagnostic[],
  scope: 'project' | 'feature'
): Promise<{ completed: number; total: number }> {
  if (!await isFile(stepStateUri, fileSystem)) {
    return { completed: 0, total: 0 };
  }

  try {
    const content = Buffer.from(await fileSystem.readFile(stepStateUri)).toString('utf8');
    const checkboxes = content.match(/^\s*[-*]\s+\[[ xX]\]/gm) ?? [];
    const completed = checkboxes.filter((checkbox) => /\[[xX]\]/.test(checkbox)).length;

    return {
      completed,
      total: checkboxes.length
    };
  } catch (error) {
    diagnostics.push(createDiagnostic(
      'warning',
      `${scope}.stepState.unreadable`,
      getWorkspaceDisplayPath(stepStateUri),
      `Could not read ${scope} step state: ${getErrorMessage(error)}`
    ));

    return { completed: 0, total: 0 };
  }
}

async function isFile(uri: vscode.Uri, fileSystem: ScannerFileSystem): Promise<boolean> {
  try {
    const stat = await fileSystem.stat(uri);

    return (stat.type & vscode.FileType.File) !== 0;
  } catch {
    return false;
  }
}

async function isDirectory(uri: vscode.Uri, fileSystem: ScannerFileSystem): Promise<boolean> {
  try {
    const stat = await fileSystem.stat(uri);

    return (stat.type & vscode.FileType.Directory) !== 0;
  } catch {
    return false;
  }
}

function getRecord(record: Record<string, unknown>, key: string): Record<string, unknown> | undefined {
  const value = record[key];

  return isRecord(value) ? value : undefined;
}

function getFirstString(record: Record<string, unknown>, keys: readonly string[]): string | undefined {
  for (const key of keys) {
    const value = getStringValue(record[key]);

    if (value !== undefined) {
      return value;
    }
  }

  return undefined;
}

function getStringValue(value: unknown): string | undefined {
  if (typeof value === 'string') {
    const trimmed = value.trim();

    return trimmed.length > 0 ? trimmed : undefined;
  }

  if (typeof value === 'number') {
    return String(value);
  }

  return undefined;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function createDiagnostic(
  severity: DiagnosticSeverity,
  code: string,
  diagnosticPath: string,
  message: string
): AsdlcWorkspaceDiagnostic {
  return {
    severity,
    code,
    path: diagnosticPath,
    message
  };
}

function getErrorMessage(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}
