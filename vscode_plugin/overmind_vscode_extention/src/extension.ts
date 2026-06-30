import * as vscode from 'vscode';
import {
  createConfirmationMessage,
  handleScriptActionMessage
} from './actions/actionController';
import { handleDashboardWebviewMessage } from './actions/artifactActions';
import {
  createTaskToBrCaptureConfirmationMessage,
  handleTaskToBrCaptureMessage,
  runOvermindTaskToBrCapture
} from './actions/taskToBrCapture';
import {
  DashboardScanSession,
  isRefreshDashboardMessage
} from './dashboard/dashboardScanSession';
import { createAsdlcFileWatchers } from './dashboard/fileWatchers';
import {
  ACTIVE_ASDLC_WORKSPACE_KEY,
  ActiveAsdlcWorkspaceResolution,
  AsdlcWorkspaceCandidate,
  AsdlcWorkspaceDiagnostic,
  getWorkspaceDisplayPath,
  resolveActiveAsdlcWorkspace
} from './scanner/workspaceDetection';
import { DashboardViewState, renderDashboardHtml } from './webview/dashboardView';

const DASHBOARD_VIEW_TYPE = 'overmind.dashboard';

export function activate(context: vscode.ExtensionContext): void {
  const outputChannel = vscode.window.createOutputChannel('Overmind');
  const dashboardCommand = vscode.commands.registerCommand('overmind.openDashboard', async () => {
    const panel = vscode.window.createWebviewPanel(
      DASHBOARD_VIEW_TYPE,
      'Overmind Dashboard',
      vscode.ViewColumn.One,
      {
        enableScripts: true,
        localResourceRoots: []
      }
    );
    let activeWorkspace: AsdlcWorkspaceCandidate | undefined;
    let scanSession: DashboardScanSession | undefined;
    const panelDisposables: vscode.Disposable[] = [];
    const messageSubscription = panel.webview.onDidReceiveMessage(async (message) => {
      if (isRefreshDashboardMessage(message)) {
        if (scanSession) {
          await scanSession.refresh('manual');
        } else {
          outputChannel.appendLine('[warning] scanner.refreshIgnored: dashboard scan session is not ready');
        }

        return;
      }

      const scriptActionResult = await handleScriptActionMessage(message, activeWorkspace
        ? {
            workspaceUri: activeWorkspace.workspaceUri,
            model: scanSession?.model
          }
        : undefined, {
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
            'Run Script'
          );

          return selected === 'Run Script';
        },
        showErrorMessage: (errorMessage) => vscode.window.showErrorMessage(errorMessage),
        log: (line) => outputChannel.appendLine(line)
      });

      if (scriptActionResult.status !== 'ignored') {
        if (scriptActionResult.status === 'launched' && scanSession) {
          const launchedTerminal = scriptActionResult.terminal.terminal;
          const terminalCloseSubscription = vscode.window.onDidCloseTerminal((closedTerminal) => {
            if (closedTerminal === launchedTerminal) {
              terminalCloseSubscription.dispose();
              outputChannel.appendLine(`[info] scriptAction.terminalClosed: ${scriptActionResult.actionId}`);
              void scanSession?.refresh('terminal');
            }
          });

          panelDisposables.push(terminalCloseSubscription);
        }

        return;
      }

      const captureResult = await handleTaskToBrCaptureMessage(message, activeWorkspace
        ? {
            workspaceUri: activeWorkspace.workspaceUri,
            model: scanSession?.model
          }
        : undefined, {
        fileSystem: vscode.workspace.fs,
        runCoreCapture: runOvermindTaskToBrCapture,
        confirm: async (request) => {
          const selected = await vscode.window.showWarningMessage(
            createTaskToBrCaptureConfirmationMessage(request),
            { modal: true },
            'Capture'
          );

          return selected === 'Capture';
        },
        showInformationMessage: (infoMessage) => vscode.window.showInformationMessage(infoMessage),
        showErrorMessage: (errorMessage) => vscode.window.showErrorMessage(errorMessage),
        log: (line) => outputChannel.appendLine(line)
      });

      if (captureResult.status !== 'ignored') {
        if (captureResult.status === 'captured' && scanSession) {
          await scanSession.refresh('capture');
        }

        await panel.webview.postMessage(toCaptureResultWebviewMessage(captureResult, message));
        return;
      }

      const result = await handleDashboardWebviewMessage(message, scanSession?.model, {
        fileSystem: vscode.workspace.fs,
        openTextDocument: (uri) => vscode.workspace.openTextDocument(uri),
        showTextDocument: (document) => vscode.window.showTextDocument(document),
        showWarningMessage: (warningMessage) => vscode.window.showWarningMessage(warningMessage),
        log: (line) => outputChannel.appendLine(line)
      });

      if (result === 'ignored') {
        outputChannel.appendLine('[warning] webview.message.ignored: unsupported dashboard message');
      }
    });

    panelDisposables.push(messageSubscription);
    panel.onDidDispose(() => {
      for (const disposable of panelDisposables) {
        disposable.dispose();
      }

      scanSession?.dispose();
    });

    panel.webview.html = renderDashboardHtml({
      kind: 'loading',
      title: 'Overmind Dashboard',
      message: 'Detecting ASDLC workspace and scanning dashboard data.'
    });

    try {
      const resolution = await resolveActiveAsdlcWorkspace(vscode.workspace.workspaceFolders, {
        fileSystem: vscode.workspace.fs,
        storedWorkspaceUri: context.workspaceState.get<string>(ACTIVE_ASDLC_WORKSPACE_KEY),
        chooseWorkspace: chooseAsdlcWorkspace,
        storeActiveWorkspaceUri: (workspaceUri) =>
          context.workspaceState.update(ACTIVE_ASDLC_WORKSPACE_KEY, workspaceUri)
      });

      writeWorkspaceDiagnostics(outputChannel, resolution);

      if (resolution.status !== 'selected' || !resolution.workspace) {
        panel.webview.html = renderDashboardHtml(toWorkspaceState(resolution));
        return;
      }

      activeWorkspace = resolution.workspace;
      scanSession = new DashboardScanSession({
        workspace: resolution.workspace,
        detectionDiagnostics: resolution.detection.diagnostics,
        fileSystem: vscode.workspace.fs,
        render: (state) => {
          panel.webview.html = renderDashboardHtml(state);
        },
        log: (line) => outputChannel.appendLine(line)
      });
      panelDisposables.push(createAsdlcFileWatchers(
        resolution.workspace.workspaceUri,
        (event) => scanSession?.handleWatchedFileEvent(event)
      ));

      await scanSession.refresh('initial');
    } catch (error) {
      outputChannel.appendLine(`[error] dashboard.failed: ${getErrorMessage(error)}`);
      panel.webview.html = renderDashboardHtml({
        kind: 'error',
        title: 'Dashboard Failed',
        message: 'The dashboard could not inspect the current VS Code workspace.',
        diagnostics: [
          {
            severity: 'error',
            code: 'dashboard.failed',
            path: '',
            message: getErrorMessage(error)
          }
        ]
      });
    }
  });

  context.subscriptions.push(outputChannel, dashboardCommand);
}

export function deactivate(): void {
  // No extension resources require explicit shutdown.
}

function toCaptureResultWebviewMessage(
  result: Awaited<ReturnType<typeof handleTaskToBrCaptureMessage>>,
  originalMessage: unknown
): Record<string, string> {
  if (result.status === 'captured') {
    return {
      type: 'captureTaskToBrResult',
      status: result.status,
      projectId: result.projectId,
      featureId: result.featureId,
      message: 'Task-to-BR input captured.'
    };
  }

  if (result.status === 'cancelled') {
    return {
      type: 'captureTaskToBrResult',
      status: result.status,
      projectId: result.projectId,
      featureId: result.featureId,
      message: 'Capture cancelled.'
    };
  }

  if (result.status === 'rejected') {
    const target = getMessageTargetIds(originalMessage);

    return {
      type: 'captureTaskToBrResult',
      status: result.status,
      projectId: target.projectId,
      featureId: target.featureId,
      message: result.message
    };
  }

  return {
    type: 'captureTaskToBrResult',
    status: 'ignored',
    projectId: '',
    featureId: '',
    message: ''
  };
}

function getMessageTargetIds(message: unknown): { readonly projectId: string; readonly featureId: string } {
  if (!isRecord(message)) {
    return {
      projectId: '',
      featureId: ''
    };
  }

  return {
    projectId: typeof message.projectId === 'string' ? message.projectId : '',
    featureId: typeof message.featureId === 'string' ? message.featureId : ''
  };
}

async function chooseAsdlcWorkspace(
  candidates: AsdlcWorkspaceCandidate[]
): Promise<AsdlcWorkspaceCandidate | undefined> {
  const items = candidates.map((candidate) => ({
    label: candidate.workspaceName,
    description: getWorkspaceDisplayPath(candidate.workspaceUri),
    detail: candidate.diagnostics.length > 0
      ? `${candidate.diagnostics.length} metadata diagnostic(s)`
      : 'ASDLC metadata detected',
    candidate
  }));

  const selected = await vscode.window.showQuickPick(items, {
    title: 'Select ASDLC Workspace',
    placeHolder: 'Multiple ASDLC workspaces were detected'
  });

  return selected?.candidate;
}

function toWorkspaceState(resolution: ActiveAsdlcWorkspaceResolution): DashboardViewState {
  switch (resolution.status) {
    case 'noWorkspaceFolders':
      return {
        kind: 'empty',
        title: 'No Folder Open',
        message: 'Open an ASDLC workspace folder that contains asdlc_metadata.yaml.',
        diagnostics: resolution.detection.diagnostics
      };

    case 'notFound':
      return {
        kind: 'empty',
        title: 'No ASDLC Workspace Detected',
        message: 'Open or add a folder that contains asdlc_metadata.yaml at its root.',
        diagnostics: resolution.detection.diagnostics
      };

    case 'selectionCancelled':
      return {
        kind: 'empty',
        title: 'No ASDLC Workspace Selected',
        message: 'Run Overmind: Open Dashboard again and select the ASDLC workspace to inspect.',
        diagnostics: resolution.detection.diagnostics
      };

    case 'selectionRequired':
      return {
        kind: 'empty',
        title: 'ASDLC Workspace Selection Required',
        message: 'Multiple ASDLC workspaces were detected. Select one before viewing dashboard data.',
        diagnostics: resolution.detection.diagnostics
      };

    case 'selected':
      return {
        kind: 'empty',
        title: 'ASDLC Workspace Detected',
        message: 'The selected workspace was not available for scanning.',
        diagnostics: resolution.detection.diagnostics
      };
  }
}

function writeWorkspaceDiagnostics(
  outputChannel: vscode.OutputChannel,
  resolution: ActiveAsdlcWorkspaceResolution
): void {
  outputChannel.appendLine(`[info] workspace.detection.status: ${resolution.status}`);

  if (resolution.workspace) {
    outputChannel.appendLine(
      `[info] workspace.detection.active: ${getWorkspaceDisplayPath(resolution.workspace.workspaceUri)}`
    );
  }

  for (const diagnostic of resolution.detection.diagnostics) {
    outputChannel.appendLine(formatDiagnostic(diagnostic));
  }
}

function formatDiagnostic(diagnostic: AsdlcWorkspaceDiagnostic): string {
  const diagnosticPath = diagnostic.path ? ` ${diagnostic.path}` : '';

  return `[${diagnostic.severity}] ${diagnostic.code}:${diagnosticPath} - ${diagnostic.message}`;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function getErrorMessage(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}
