import { execFile } from 'child_process';
import * as fs from 'fs/promises';
import * as path from 'path';
import * as vscode from 'vscode';
import type { DashboardModel, FeatureSummary, ProjectSummary } from '../scanner/asdlcScanner';
import { getWorkspaceDisplayPath } from '../scanner/workspaceDetection';

export const CAPTURE_TASK_TO_BR_MESSAGE_TYPE = 'captureTaskToBr';

const CAPTURE_CONFIRMATION = 'Capture';
const OVERMIND_CORE_RELATIVE_PATH = ['.overmind', 'overmind.js'] as const;

export type TaskToBrCaptureSource =
  | {
      readonly kind: 'localFile';
      readonly sourceFilePath: string;
    }
  | {
      readonly kind: 'jira';
      readonly jiraTicket: string;
    };

export interface CaptureTaskToBrMessage {
  readonly type: typeof CAPTURE_TASK_TO_BR_MESSAGE_TYPE;
  readonly projectId?: string;
  readonly featureId?: string;
  readonly sourceFile?: string;
  readonly jiraTicket?: string;
}

export interface TaskToBrCaptureContext {
  readonly workspaceUri: vscode.Uri;
  readonly model?: DashboardModel;
}

export interface TaskToBrCoreCaptureRequest {
  readonly workspacePath: string;
  readonly featurePath: string;
  readonly source: TaskToBrCaptureSource;
}

export interface TaskToBrCaptureConfirmationRequest extends TaskToBrCoreCaptureRequest {
  readonly projectId: string;
  readonly featureId: string;
}

export interface TaskToBrCaptureServices {
  readonly fileSystem: {
    stat(uri: vscode.Uri): Thenable<vscode.FileStat>;
  };
  readonly runCoreCapture: (request: TaskToBrCoreCaptureRequest) => Promise<void>;
  readonly confirm?: (request: TaskToBrCaptureConfirmationRequest) => Thenable<boolean> | Promise<boolean>;
  readonly showInformationMessage?: (message: string) => Thenable<unknown>;
  readonly showErrorMessage?: (message: string) => Thenable<unknown>;
  readonly log?: (message: string) => void;
}

export type TaskToBrCaptureResult =
  | { readonly status: 'ignored' }
  | {
      readonly status: 'captured';
      readonly projectId: string;
      readonly featureId: string;
      readonly featurePath: string;
      readonly sourceKind: TaskToBrCaptureSource['kind'];
    }
  | { readonly status: 'cancelled'; readonly projectId: string; readonly featureId: string }
  | { readonly status: 'rejected'; readonly code: string; readonly message: string };

interface ValidatedFeatureTarget {
  readonly projectId: string;
  readonly featureId: string;
  readonly featureUri: vscode.Uri;
  readonly featurePath: string;
}

export async function handleTaskToBrCaptureMessage(
  message: unknown,
  context: TaskToBrCaptureContext | undefined,
  services: TaskToBrCaptureServices = createDefaultServices()
): Promise<TaskToBrCaptureResult> {
  if (!isCaptureTaskToBrMessage(message)) {
    return { status: 'ignored' };
  }

  return captureTaskToBr(message, context, services);
}

export async function captureTaskToBr(
  message: CaptureTaskToBrMessage,
  context: TaskToBrCaptureContext | undefined,
  services: TaskToBrCaptureServices = createDefaultServices()
): Promise<TaskToBrCaptureResult> {
  if (!context || !context.model) {
    return reject(services, 'taskToBrCapture.noDashboardModel', 'Dashboard data is required before capturing task-to-BR input.');
  }

  const target = validateFeatureTarget(message, context);

  if ('code' in target) {
    return reject(services, target.code, target.message);
  }

  const source = await validateSource(message, target, services);

  if ('code' in source) {
    return reject(services, source.code, source.message);
  }

  const request: TaskToBrCaptureConfirmationRequest = {
    workspacePath: getWorkspaceDisplayPath(context.workspaceUri),
    featurePath: target.featurePath,
    projectId: target.projectId,
    featureId: target.featureId,
    source
  };
  const confirmed = await (services.confirm ?? defaultConfirm)(request);

  if (!confirmed) {
    services.log?.(`[info] taskToBrCapture.cancelled: ${target.projectId}/${target.featureId}`);

    return {
      status: 'cancelled',
      projectId: target.projectId,
      featureId: target.featureId
    };
  }

  try {
    await services.runCoreCapture(request);
  } catch (error) {
    return reject(
      services,
      'taskToBrCapture.coreFailed',
      `Task-to-BR capture failed: ${getErrorMessage(error)}`
    );
  }

  services.log?.(`[info] taskToBrCapture.captured: ${target.projectId}/${target.featureId}`);
  await services.showInformationMessage?.('Task-to-BR input captured.');

  return {
    status: 'captured',
    projectId: target.projectId,
    featureId: target.featureId,
    featurePath: target.featurePath,
    sourceKind: source.kind
  };
}

export function createTaskToBrCaptureConfirmationMessage(
  request: TaskToBrCaptureConfirmationRequest
): string {
  const source = request.source.kind === 'localFile'
    ? request.source.sourceFilePath
    : `jira:${request.source.jiraTicket}`;

  return [
    'Capture task-to-BR input through the shared Overmind core.',
    `Feature: ${request.featurePath}`,
    `Source: ${source}`
  ].join('\n');
}

export function buildTaskToBrCaptureArgs(request: TaskToBrCoreCaptureRequest): string[] {
  const sourceArgs = request.source.kind === 'localFile'
    ? ['--source-file', request.source.sourceFilePath]
    : ['--jira', request.source.jiraTicket];

  return [
    'capture',
    'task-to-br',
    '--feature-path',
    request.featurePath,
    ...sourceArgs
  ];
}

export async function runOvermindTaskToBrCapture(
  request: TaskToBrCoreCaptureRequest
): Promise<void> {
  const coreCommand = await resolveCoreCommand(request.workspacePath);
  const args = [...coreCommand.argsPrefix, ...buildTaskToBrCaptureArgs(request)];

  await execFileAsync(coreCommand.command, args, request.workspacePath);
}

function validateFeatureTarget(
  message: CaptureTaskToBrMessage,
  context: TaskToBrCaptureContext
): ValidatedFeatureTarget | { readonly code: string; readonly message: string } {
  const projectId = normalizePathId(message.projectId);
  const featureId = normalizePathId(message.featureId);

  if (!projectId) {
    return {
      code: 'taskToBrCapture.projectMissing',
      message: 'Task-to-BR capture requires a valid project id.'
    };
  }

  if (!featureId) {
    return {
      code: 'taskToBrCapture.featureMissing',
      message: 'Task-to-BR capture requires a valid feature id.'
    };
  }

  const project = context.model?.projects.find((candidate) => candidate.projectId === projectId);

  if (!project) {
    return {
      code: 'taskToBrCapture.projectUnknown',
      message: `Project is not present in the current dashboard scan: ${projectId}`
    };
  }

  const feature = project.features.find((candidate) => candidate.featureId === featureId);

  if (!feature) {
    return {
      code: 'taskToBrCapture.featureUnknown',
      message: `Feature is not present in the current dashboard scan: ${featureId}`
    };
  }

  const featureUri = vscode.Uri.joinPath(context.workspaceUri, 'projects', project.projectId, feature.featureId);
  const featurePath = getWorkspaceDisplayPath(featureUri);
  const pathError = validateTargetPath(project, feature, featurePath);

  if (pathError) {
    return pathError;
  }

  return {
    projectId,
    featureId,
    featureUri,
    featurePath
  };
}

function validateTargetPath(
  project: ProjectSummary,
  feature: FeatureSummary,
  expectedFeaturePath: string
): { readonly code: string; readonly message: string } | undefined {
  if (!isSamePath(expectedFeaturePath, feature.folderPath)) {
    return {
      code: 'taskToBrCapture.featurePathMismatch',
      message: `Feature path does not match current dashboard data: ${feature.featureId}`
    };
  }

  if (!isSameOrChildPath(expectedFeaturePath, project.folderPath)) {
    return {
      code: 'taskToBrCapture.projectPathMismatch',
      message: `Feature path is not inside the current project path: ${feature.featureId}`
    };
  }

  return undefined;
}

async function validateSource(
  message: CaptureTaskToBrMessage,
  target: ValidatedFeatureTarget,
  services: TaskToBrCaptureServices
): Promise<TaskToBrCaptureSource | { readonly code: string; readonly message: string }> {
  const sourceFile = getTrimmedString(message.sourceFile);
  const jiraTicket = getTrimmedString(message.jiraTicket);
  const sourceCount = (sourceFile ? 1 : 0) + (jiraTicket ? 1 : 0);

  if (sourceCount !== 1) {
    return {
      code: 'taskToBrCapture.sourceInvalid',
      message: 'Choose exactly one task-to-BR source: a story file or a Jira ticket.'
    };
  }

  if (sourceFile) {
    return validateLocalSourceFile(sourceFile, target, services);
  }

  return validateJiraTicket(jiraTicket ?? '');
}

async function validateLocalSourceFile(
  rawSourceFile: string,
  target: ValidatedFeatureTarget,
  services: TaskToBrCaptureServices
): Promise<TaskToBrCaptureSource | { readonly code: string; readonly message: string }> {
  if (hasControlCharacters(rawSourceFile) || isAbsoluteOrUriPath(rawSourceFile)) {
    return {
      code: 'taskToBrCapture.sourceFileInvalid',
      message: 'Story file must be a relative .txt or .md file inside the selected feature folder.'
    };
  }

  const normalizedPath = rawSourceFile.replace(/\\/g, '/');
  const segments = normalizedPath.split('/');

  if (segments.some((segment) => segment.length === 0 || segment === '.' || segment === '..')) {
    return {
      code: 'taskToBrCapture.sourceFileInvalid',
      message: 'Story file path must stay inside the selected feature folder.'
    };
  }

  const fileName = segments[segments.length - 1].toLowerCase();

  if (!fileName.endsWith('.txt') && !fileName.endsWith('.md')) {
    return {
      code: 'taskToBrCapture.sourceFileInvalid',
      message: 'Story file must use a .txt or .md extension.'
    };
  }

  const sourceUri = vscode.Uri.joinPath(target.featureUri, ...segments);
  const sourcePath = getWorkspaceDisplayPath(sourceUri);

  if (!isSameOrChildPath(sourcePath, target.featurePath)) {
    return {
      code: 'taskToBrCapture.sourceFileOutsideFeature',
      message: 'Story file must be inside the selected feature folder.'
    };
  }

  try {
    const stat = await services.fileSystem.stat(sourceUri);

    if ((stat.type & vscode.FileType.File) === 0) {
      return {
        code: 'taskToBrCapture.sourceFileNotFile',
        message: `Story file is not a file: ${sourcePath}`
      };
    }
  } catch (error) {
    return {
      code: 'taskToBrCapture.sourceFileMissing',
      message: `Story file is not available: ${sourcePath} (${getErrorMessage(error)})`
    };
  }

  return {
    kind: 'localFile',
    sourceFilePath: sourcePath
  };
}

function validateJiraTicket(
  rawJiraTicket: string
): TaskToBrCaptureSource | { readonly code: string; readonly message: string } {
  if (
    rawJiraTicket.length === 0 ||
    rawJiraTicket.length > 128 ||
    hasControlCharacters(rawJiraTicket) ||
    /[\\/\s]/.test(rawJiraTicket)
  ) {
    return {
      code: 'taskToBrCapture.jiraInvalid',
      message: 'Jira ticket must be a single ticket identifier.'
    };
  }

  return {
    kind: 'jira',
    jiraTicket: rawJiraTicket
  };
}

async function defaultConfirm(request: TaskToBrCaptureConfirmationRequest): Promise<boolean> {
  const selected = await vscode.window.showWarningMessage(
    createTaskToBrCaptureConfirmationMessage(request),
    { modal: true },
    CAPTURE_CONFIRMATION
  );

  return selected === CAPTURE_CONFIRMATION;
}

function createDefaultServices(): TaskToBrCaptureServices {
  return {
    fileSystem: vscode.workspace.fs,
    runCoreCapture: runOvermindTaskToBrCapture,
    showInformationMessage: (message) => vscode.window.showInformationMessage(message),
    showErrorMessage: (message) => vscode.window.showErrorMessage(message)
  };
}

async function resolveCoreCommand(
  workspacePath: string
): Promise<{ readonly command: string; readonly argsPrefix: readonly string[] }> {
  const workspaceCorePath = path.join(workspacePath, ...OVERMIND_CORE_RELATIVE_PATH);

  try {
    await fs.access(workspaceCorePath);

    return {
      command: process.execPath,
      argsPrefix: [workspaceCorePath]
    };
  } catch {
    return {
      command: 'overmind',
      argsPrefix: []
    };
  }
}

function execFileAsync(command: string, args: readonly string[], cwd: string): Promise<void> {
  return new Promise((resolve, reject) => {
    execFile(command, [...args], { cwd, windowsHide: true }, (error, _stdout, stderr) => {
      if (error) {
        reject(new Error(formatCoreError(error.message, stderr)));
        return;
      }

      resolve();
    });
  });
}

async function reject(
  services: TaskToBrCaptureServices,
  code: string,
  message: string
): Promise<TaskToBrCaptureResult> {
  services.log?.(`[warning] ${code}: ${message}`);
  await services.showErrorMessage?.(message);

  return {
    status: 'rejected',
    code,
    message
  };
}

function formatCoreError(message: string, stderr: string): string {
  const trimmedStderr = stderr.trim();

  return trimmedStderr.length > 0 ? trimmedStderr : message;
}

function normalizePathId(value: string | undefined): string | undefined {
  if (!value) {
    return undefined;
  }

  const trimmed = value.trim();

  if (trimmed.length === 0 || trimmed === '.' || trimmed === '..') {
    return undefined;
  }

  return /[\\/]/.test(trimmed) ? undefined : trimmed;
}

function getTrimmedString(value: string | undefined): string | undefined {
  if (typeof value !== 'string') {
    return undefined;
  }

  const trimmed = value.trim();

  return trimmed.length > 0 ? trimmed : undefined;
}

function hasControlCharacters(value: string): boolean {
  return /[\x00-\x1F\x7F]/.test(value);
}

function isAbsoluteOrUriPath(value: string): boolean {
  return value.startsWith('/') ||
    value.startsWith('\\') ||
    /^[A-Za-z]:[\\/]/.test(value) ||
    /^[A-Za-z][A-Za-z0-9+.-]*:/.test(value);
}

function isSameOrChildPath(candidatePath: string, parentPath: string): boolean {
  const normalizedCandidate = normalizeComparablePath(candidatePath);
  const normalizedParent = normalizeComparablePath(parentPath);

  return normalizedCandidate === normalizedParent ||
    normalizedCandidate.startsWith(`${normalizedParent}/`);
}

function isSamePath(left: string, right: string): boolean {
  return normalizeComparablePath(left) === normalizeComparablePath(right);
}

function normalizeComparablePath(value: string): string {
  return value.replace(/\\/g, '/').replace(/\/+$/, '').toLowerCase();
}

function isCaptureTaskToBrMessage(message: unknown): message is CaptureTaskToBrMessage {
  return isRecord(message) && message.type === CAPTURE_TASK_TO_BR_MESSAGE_TYPE;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function getErrorMessage(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}
