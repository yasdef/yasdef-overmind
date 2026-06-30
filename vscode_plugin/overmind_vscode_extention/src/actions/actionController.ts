import * as fs from 'fs/promises';
import * as vscode from 'vscode';
import type { DashboardModel, FeatureSummary, ProjectSummary } from '../scanner/asdlcScanner';
import { getWorkspaceDisplayPath } from '../scanner/workspaceDetection';
import {
  launchScriptInTerminal,
  ScriptTerminalServices,
  TerminalLaunchResult
} from './scriptRunner';

export const RUN_SCRIPT_ACTION_MESSAGE_TYPE = 'runScriptAction';

const COMMANDS_FOLDER = '.commands';
const RUN_SCRIPT_CONFIRMATION = 'Run Script';

export type ScriptActionId =
  | 'runInitProgressScanner'
  | 'createOrContinueFeature'
  | 'createProject';
export type ScriptActionScope = 'workspace' | 'project' | 'feature';

export interface ScriptActionDefinition {
  readonly id: ScriptActionId;
  readonly title: string;
  readonly scriptName: string;
  readonly scope: ScriptActionScope;
  readonly mutatesWorkspace: boolean;
  readonly interactive: boolean;
  readonly targetPathArgument?: string;
}

export const SCRIPT_ACTION_DEFINITIONS: Readonly<Record<ScriptActionId, ScriptActionDefinition>> = {
  runInitProgressScanner: {
    id: 'runInitProgressScanner',
    title: 'Run Scanner',
    scriptName: 'init_progress_scanner.sh',
    scope: 'feature',
    mutatesWorkspace: true,
    interactive: true,
    targetPathArgument: '--path'
  },
  createOrContinueFeature: {
    id: 'createOrContinueFeature',
    title: 'Create Feature / Continue E2E',
    scriptName: 'project_add_feature_e2e.sh',
    scope: 'project',
    mutatesWorkspace: true,
    interactive: true,
    targetPathArgument: '--path'
  },
  createProject: {
    id: 'createProject',
    title: 'Create Project',
    scriptName: 'project_setup_add_new_project.sh',
    scope: 'workspace',
    mutatesWorkspace: true,
    interactive: true
  }
};

export interface RunScriptActionMessage {
  readonly type: typeof RUN_SCRIPT_ACTION_MESSAGE_TYPE;
  readonly actionId: string;
  readonly projectId?: string;
  readonly featureId?: string;
}

export interface ScriptActionContext {
  readonly workspaceUri: vscode.Uri;
  readonly model?: DashboardModel;
}

export interface ScriptActionRuntime {
  readonly platform: NodeJS.Platform;
  readonly remoteName?: string;
}

export interface ScriptActionServices extends ScriptTerminalServices {
  readonly fileSystem: {
    stat(uri: vscode.Uri): Thenable<vscode.FileStat>;
  };
  readonly runtime: ScriptActionRuntime;
  readonly confirm: (request: ScriptActionConfirmationRequest) => Thenable<boolean> | Promise<boolean>;
  readonly showErrorMessage?: (message: string) => Thenable<unknown>;
  readonly checkExecutable?: (uri: vscode.Uri, runtime: ScriptActionRuntime) => Promise<boolean>;
  readonly log?: (message: string) => void;
}

export interface ScriptActionConfirmationRequest {
  readonly action: ScriptActionDefinition;
  readonly scriptPath: string;
  readonly targetPath: string;
}

export type ScriptActionResult =
  | { readonly status: 'ignored' }
  | {
      readonly status: 'launched';
      readonly actionId: ScriptActionId;
      readonly scriptPath: string;
      readonly targetPath: string;
      readonly terminal: TerminalLaunchResult;
    }
  | { readonly status: 'cancelled'; readonly actionId: ScriptActionId }
  | { readonly status: 'rejected'; readonly code: string; readonly message: string };

interface ValidatedScriptTarget {
  readonly action: ScriptActionDefinition;
  readonly scriptUri: vscode.Uri;
  readonly scriptPath: string;
  readonly scriptArguments: readonly string[];
  readonly targetUri: vscode.Uri;
  readonly targetPath: string;
}

export async function handleScriptActionMessage(
  message: unknown,
  context: ScriptActionContext | undefined,
  services: ScriptActionServices = createDefaultScriptActionServices()
): Promise<ScriptActionResult> {
  if (!isRunScriptActionMessage(message)) {
    return { status: 'ignored' };
  }

  return runScriptAction(message, context, services);
}

export async function runScriptAction(
  request: RunScriptActionMessage,
  context: ScriptActionContext | undefined,
  services: ScriptActionServices = createDefaultScriptActionServices()
): Promise<ScriptActionResult> {
  const action = getScriptActionDefinition(request.actionId);

  if (!action) {
    return reject(services, 'scriptAction.unknown', `Script action is not allow-listed: ${request.actionId}`);
  }

  if (!context) {
    return reject(services, 'scriptAction.noWorkspace', 'No active ASDLC workspace is available for script actions.');
  }

  const runtimeError = validateShellRuntime(services.runtime);

  if (runtimeError) {
    return reject(services, 'scriptAction.runtimeUnsupported', runtimeError);
  }

  const target = validateScriptTarget(action, request, context);

  if ('code' in target) {
    return reject(services, target.code, target.message);
  }

  const scriptValidation = await validateScriptFile(target.scriptUri, services);

  if (scriptValidation) {
    return reject(services, scriptValidation.code, scriptValidation.message);
  }

  if (action.mutatesWorkspace) {
    const confirmed = await services.confirm({
      action,
      scriptPath: target.scriptPath,
      targetPath: target.targetPath
    });

    if (!confirmed) {
      services.log?.(`[info] scriptAction.cancelled: ${action.id} ${target.targetPath}`);

      return {
        status: 'cancelled',
        actionId: action.id
      };
    }
  }

  const terminal = launchScriptInTerminal({
    actionTitle: action.title,
    scriptPath: target.scriptPath,
    scriptArguments: target.scriptArguments,
    targetUri: target.targetUri
  }, services);

  services.log?.(`[info] scriptAction.launched: ${action.id} ${target.targetPath}`);

  return {
    status: 'launched',
    actionId: action.id,
    scriptPath: target.scriptPath,
    targetPath: target.targetPath,
    terminal
  };
}

export function getScriptActionDefinition(actionId: string): ScriptActionDefinition | undefined {
  return Object.values(SCRIPT_ACTION_DEFINITIONS).find((action) => action.id === actionId);
}

export function createConfirmationMessage(request: ScriptActionConfirmationRequest): string {
  return [
    `${request.action.title} will run an Overmind script.`,
    `Script: ${request.scriptPath}`,
    `Target: ${request.targetPath}`
  ].join('\n');
}

function validateScriptTarget(
  action: ScriptActionDefinition,
  request: RunScriptActionMessage,
  context: ScriptActionContext
): ValidatedScriptTarget | { readonly code: string; readonly message: string } {
  const scriptUri = vscode.Uri.joinPath(context.workspaceUri, COMMANDS_FOLDER, action.scriptName);
  const scriptPath = getWorkspaceDisplayPath(scriptUri);
  const scopeTarget = resolveScopeTarget(action, request, context);

  if ('code' in scopeTarget) {
    return scopeTarget;
  }

  return {
    action,
    scriptUri,
    scriptPath,
    scriptArguments: buildScriptArguments(action, scopeTarget.targetPath),
    targetUri: scopeTarget.targetUri,
    targetPath: scopeTarget.targetPath
  };
}

function buildScriptArguments(
  action: ScriptActionDefinition,
  targetPath: string
): readonly string[] {
  return action.targetPathArgument ? [action.targetPathArgument, targetPath] : [];
}

function resolveScopeTarget(
  action: ScriptActionDefinition,
  request: RunScriptActionMessage,
  context: ScriptActionContext
): { readonly targetUri: vscode.Uri; readonly targetPath: string } | { readonly code: string; readonly message: string } {
  if (action.scope === 'workspace') {
    return {
      targetUri: context.workspaceUri,
      targetPath: getWorkspaceDisplayPath(context.workspaceUri)
    };
  }

  if (!context.model) {
    return {
      code: 'scriptAction.noDashboardModel',
      message: 'Dashboard data is required before running project or feature script actions.'
    };
  }

  const projectId = normalizePathId(request.projectId);

  if (!projectId) {
    return {
      code: 'scriptAction.projectMissing',
      message: 'Script action requires a valid project id.'
    };
  }

  const project = context.model.projects.find((candidate) => candidate.projectId === projectId);

  if (!project) {
    return {
      code: 'scriptAction.projectUnknown',
      message: `Project is not present in the current dashboard scan: ${projectId}`
    };
  }

  const projectUri = vscode.Uri.joinPath(context.workspaceUri, 'projects', project.projectId);
  const projectPath = getWorkspaceDisplayPath(projectUri);

  if (!isSamePath(projectPath, project.folderPath)) {
    return {
      code: 'scriptAction.projectPathMismatch',
      message: `Project path does not match current dashboard data: ${project.projectId}`
    };
  }

  if (action.scope === 'project') {
    return {
      targetUri: projectUri,
      targetPath: projectPath
    };
  }

  return resolveFeatureTarget(context.workspaceUri, project, request.featureId);
}

function resolveFeatureTarget(
  workspaceUri: vscode.Uri,
  project: ProjectSummary,
  rawFeatureId: string | undefined
): { readonly targetUri: vscode.Uri; readonly targetPath: string } | { readonly code: string; readonly message: string } {
  const featureId = normalizePathId(rawFeatureId);

  if (!featureId) {
    return {
      code: 'scriptAction.featureMissing',
      message: 'Script action requires a valid feature id.'
    };
  }

  const feature = project.features.find((candidate) => candidate.featureId === featureId);

  if (!feature) {
    return {
      code: 'scriptAction.featureUnknown',
      message: `Feature is not present in the current dashboard scan: ${featureId}`
    };
  }

  const featureUri = vscode.Uri.joinPath(workspaceUri, 'projects', project.projectId, feature.featureId);
  const featurePath = getWorkspaceDisplayPath(featureUri);

  if (!isSameFeaturePath(featurePath, feature)) {
    return {
      code: 'scriptAction.featurePathMismatch',
      message: `Feature path does not match current dashboard data: ${feature.featureId}`
    };
  }

  return {
    targetUri: featureUri,
    targetPath: featurePath
  };
}

function isSameFeaturePath(expectedPath: string, feature: FeatureSummary): boolean {
  return isSamePath(expectedPath, feature.folderPath);
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

async function validateScriptFile(
  scriptUri: vscode.Uri,
  services: ScriptActionServices
): Promise<{ readonly code: string; readonly message: string } | undefined> {
  let stat: vscode.FileStat;

  try {
    stat = await services.fileSystem.stat(scriptUri);
  } catch (error) {
    return {
      code: 'scriptAction.scriptMissing',
      message: `Required script is missing: ${getWorkspaceDisplayPath(scriptUri)} (${getErrorMessage(error)})`
    };
  }

  if ((stat.type & vscode.FileType.File) === 0) {
    return {
      code: 'scriptAction.scriptNotFile',
      message: `Required script is not a file: ${getWorkspaceDisplayPath(scriptUri)}`
    };
  }

  const executable = await (services.checkExecutable ?? checkExecutable)(scriptUri, services.runtime);

  if (!executable) {
    return {
      code: 'scriptAction.scriptNotExecutable',
      message: `Required script is not executable: ${getWorkspaceDisplayPath(scriptUri)}`
    };
  }

  return undefined;
}

function validateShellRuntime(runtime: ScriptActionRuntime): string | undefined {
  if (runtime.platform !== 'win32') {
    return undefined;
  }

  if (runtime.remoteName?.toLowerCase() === 'wsl') {
    return undefined;
  }

  return 'Shell script actions require WSL or another Unix-like execution context on Windows.';
}

async function checkExecutable(uri: vscode.Uri, runtime: ScriptActionRuntime): Promise<boolean> {
  if (runtime.platform === 'win32') {
    return false;
  }

  if (uri.scheme !== 'file') {
    return true;
  }

  try {
    const stat = await fs.stat(uri.fsPath);

    return (stat.mode & 0o111) !== 0;
  } catch {
    return false;
  }
}

function isRunScriptActionMessage(message: unknown): message is RunScriptActionMessage {
  return isRecord(message) &&
    message.type === RUN_SCRIPT_ACTION_MESSAGE_TYPE &&
    typeof message.actionId === 'string' &&
    message.actionId.trim().length > 0;
}

async function reject(
  services: ScriptActionServices,
  code: string,
  message: string
): Promise<ScriptActionResult> {
  services.log?.(`[warning] ${code}: ${message}`);
  await services.showErrorMessage?.(message);

  return {
    status: 'rejected',
    code,
    message
  };
}

function createDefaultScriptActionServices(): ScriptActionServices {
  return {
    fileSystem: vscode.workspace.fs,
    runtime: {
      platform: process.platform,
      remoteName: vscode.env.remoteName
    },
    createTerminal: (options) => vscode.window.createTerminal(options),
    confirm: async (request) => {
      const selected = await vscode.window.showWarningMessage(
        createConfirmationMessage(request),
        { modal: true },
        RUN_SCRIPT_CONFIRMATION
      );

      return selected === RUN_SCRIPT_CONFIRMATION;
    },
    showErrorMessage: (message) => vscode.window.showErrorMessage(message)
  };
}

function isSamePath(left: string, right: string): boolean {
  return normalizeComparablePath(left) === normalizeComparablePath(right);
}

function normalizeComparablePath(value: string): string {
  return value.replace(/\\/g, '/').replace(/\/+$/, '').toLowerCase();
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function getErrorMessage(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}
