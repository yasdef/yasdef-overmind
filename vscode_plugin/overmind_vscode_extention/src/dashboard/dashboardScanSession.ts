import * as vscode from 'vscode';
import type { DashboardModel, ScannerFileSystem } from '../scanner/asdlcScanner';
import { scanAsdlcWorkspace } from '../scanner/asdlcScanner';
import type { DashboardViewState } from '../webview/dashboardView';
import {
  AsdlcWorkspaceCandidate,
  AsdlcWorkspaceDiagnostic,
  DiagnosticSeverity,
  getWorkspaceDisplayPath
} from '../scanner/workspaceDetection';
import { AsdlcWatcherEvent, formatWatcherEvent } from './fileWatchers';

export const REFRESH_DASHBOARD_MESSAGE_TYPE = 'refreshDashboard';

export type DashboardScanReason = 'initial' | 'manual' | 'watcher' | 'queued' | 'terminal' | 'capture';

export interface RefreshDashboardMessage {
  readonly type: typeof REFRESH_DASHBOARD_MESSAGE_TYPE;
}

export interface DashboardRefreshTimer {
  dispose(): void;
}

export interface DashboardScanSessionOptions {
  readonly workspace: AsdlcWorkspaceCandidate;
  readonly detectionDiagnostics: readonly AsdlcWorkspaceDiagnostic[];
  readonly fileSystem: ScannerFileSystem;
  readonly render: (state: DashboardViewState) => void;
  readonly log: (line: string) => void;
  readonly scanWorkspace?: (
    workspaceUri: vscode.Uri,
    fileSystem: ScannerFileSystem
  ) => Promise<DashboardModel>;
  readonly scheduleRefresh?: (
    callback: () => Promise<void>,
    delayMs: number
  ) => DashboardRefreshTimer;
  readonly refreshDebounceMs?: number;
}

const DEFAULT_REFRESH_DEBOUNCE_MS = 250;

export class DashboardScanSession {
  private readonly workspace: AsdlcWorkspaceCandidate;
  private readonly detectionDiagnostics: readonly AsdlcWorkspaceDiagnostic[];
  private readonly fileSystem: ScannerFileSystem;
  private readonly renderState: (state: DashboardViewState) => void;
  private readonly logLine: (line: string) => void;
  private readonly scanWorkspace: (
    workspaceUri: vscode.Uri,
    fileSystem: ScannerFileSystem
  ) => Promise<DashboardModel>;
  private readonly scheduleRefresh: (
    callback: () => Promise<void>,
    delayMs: number
  ) => DashboardRefreshTimer;
  private readonly refreshDebounceMs: number;

  private currentModel: DashboardModel | undefined;
  private refreshTimer: DashboardRefreshTimer | undefined;
  private scanInProgress = false;
  private queuedRefresh = false;

  constructor(options: DashboardScanSessionOptions) {
    this.workspace = options.workspace;
    this.detectionDiagnostics = options.detectionDiagnostics;
    this.fileSystem = options.fileSystem;
    this.renderState = options.render;
    this.logLine = options.log;
    this.scanWorkspace = options.scanWorkspace ?? scanAsdlcWorkspace;
    this.scheduleRefresh = options.scheduleRefresh ?? defaultScheduleRefresh;
    this.refreshDebounceMs = options.refreshDebounceMs ?? DEFAULT_REFRESH_DEBOUNCE_MS;
  }

  get model(): DashboardModel | undefined {
    return this.currentModel;
  }

  async refresh(reason: DashboardScanReason): Promise<void> {
    this.clearScheduledRefresh();

    if (this.scanInProgress) {
      this.queuedRefresh = true;
      this.logLine(`[info] scanner.refreshQueued: ${reason}`);
      return;
    }

    await this.runScan(reason);

    while (this.queuedRefresh) {
      this.queuedRefresh = false;
      await this.runScan('queued');
    }
  }

  handleWatchedFileEvent(event: AsdlcWatcherEvent): void {
    this.logLine(`[info] watcher.${event.kind}: ${formatWatcherEvent(event)}`);

    if (this.currentModel) {
      this.currentModel = createModelWithStatus(this.currentModel, 'stale', [
        createDiagnostic(
          'info',
          'scanner.stale',
          getWorkspaceDisplayPath(event.uri),
          `Dashboard data may be stale after ${event.kind} event.`
        )
      ]);
      this.renderDashboard(this.currentModel, 'ASDLC files changed. Refreshing dashboard data.');
    }

    if (this.scanInProgress) {
      this.queuedRefresh = true;
      this.logLine(`[info] scanner.refreshQueued: watcher event during active scan ${getWorkspaceDisplayPath(event.uri)}`);
      return;
    }

    this.clearScheduledRefresh();
    this.refreshTimer = this.scheduleRefresh(async () => {
      this.refreshTimer = undefined;
      await this.refresh('watcher');
    }, this.refreshDebounceMs);
  }

  dispose(): void {
    this.clearScheduledRefresh();
  }

  private async runScan(reason: DashboardScanReason): Promise<void> {
    const previousModel = this.currentModel;

    this.scanInProgress = true;
    this.logLine(`[info] scanner.start: ${reason} ${getWorkspaceDisplayPath(this.workspace.workspaceUri)}`);

    if (previousModel) {
      this.currentModel = createModelWithStatus(previousModel, 'scanning');
      this.renderDashboard(this.currentModel, 'Refreshing read-only ASDLC state.');
    } else {
      this.renderState({
        kind: 'loading',
        title: 'Overmind Dashboard',
        message: 'Detecting ASDLC workspace and scanning dashboard data.'
      });
    }

    try {
      const model = await this.scanWorkspace(this.workspace.workspaceUri, this.fileSystem);

      if (model.scanStatus === 'failed' && previousModel) {
        this.currentModel = createModelWithStatus(previousModel, 'stale', [
          ...model.diagnostics,
          createDiagnostic(
            'warning',
            'scanner.lastUsableDataKept',
            model.workspacePath,
            'Latest scan failed; showing the last usable dashboard data.'
          )
        ]);
        this.renderDashboard(
          this.currentModel,
          'Showing last usable dashboard data because the latest scan failed.'
        );
        this.writeScanFinishDiagnostics(reason, model);
        return;
      }

      this.currentModel = model;
      this.renderScanResult(model);
      this.writeScanFinishDiagnostics(reason, model);
    } catch (error) {
      const diagnostic = createDiagnostic(
        'error',
        'scanner.failed',
        getWorkspaceDisplayPath(this.workspace.workspaceUri),
        getErrorMessage(error)
      );

      if (previousModel) {
        this.currentModel = createModelWithStatus(previousModel, 'stale', [
          diagnostic,
          createDiagnostic(
            'warning',
            'scanner.lastUsableDataKept',
            previousModel.workspacePath,
            'Latest scan threw an error; showing the last usable dashboard data.'
          )
        ]);
        this.renderDashboard(
          this.currentModel,
          'Showing last usable dashboard data because the latest scan failed.'
        );
      } else {
        this.renderState({
          kind: 'error',
          title: 'Dashboard Failed',
          message: 'The dashboard could not inspect the current VS Code workspace.',
          diagnostics: [diagnostic]
        });
      }

      this.logLine(`[error] scanner.failed: ${getErrorMessage(error)}`);
    } finally {
      this.scanInProgress = false;
    }
  }

  private renderScanResult(model: DashboardModel): void {
    if (model.scanStatus === 'failed') {
      this.renderState({
        kind: 'error',
        title: 'ASDLC Scan Failed',
        message: 'The dashboard could not parse the ASDLC workspace metadata.',
        metadataPath: getWorkspaceDisplayPath(this.workspace.metadataUri),
        model,
        diagnostics: this.combineDiagnostics(model.diagnostics)
      });
      return;
    }

    this.renderDashboard(model, `Showing read-only ASDLC state from ${model.workspacePath}.`);
  }

  private renderDashboard(model: DashboardModel, message: string): void {
    this.renderState({
      kind: 'dashboard',
      title: 'Overmind Dashboard',
      message,
      metadataPath: getWorkspaceDisplayPath(this.workspace.metadataUri),
      model,
      diagnostics: this.combineDiagnostics(model.diagnostics)
    });
  }

  private combineDiagnostics(
    modelDiagnostics: readonly AsdlcWorkspaceDiagnostic[]
  ): AsdlcWorkspaceDiagnostic[] {
    return [...this.detectionDiagnostics, ...modelDiagnostics];
  }

  private writeScanFinishDiagnostics(reason: DashboardScanReason, model: DashboardModel): void {
    this.logLine(`[info] scanner.finish: ${reason} ${model.scanStatus} ${model.diagnostics.length} diagnostic(s)`);

    for (const diagnostic of model.diagnostics) {
      this.logLine(formatDiagnostic(diagnostic));
    }
  }

  private clearScheduledRefresh(): void {
    this.refreshTimer?.dispose();
    this.refreshTimer = undefined;
  }
}

export function isRefreshDashboardMessage(message: unknown): message is RefreshDashboardMessage {
  return isRecord(message) && message.type === REFRESH_DASHBOARD_MESSAGE_TYPE;
}

export function createModelWithStatus(
  model: DashboardModel,
  scanStatus: DashboardModel['scanStatus'],
  diagnosticsToAppend: readonly AsdlcWorkspaceDiagnostic[] = []
): DashboardModel {
  return {
    ...model,
    scanStatus,
    diagnostics: [...model.diagnostics, ...diagnosticsToAppend]
  };
}

function defaultScheduleRefresh(
  callback: () => Promise<void>,
  delayMs: number
): DashboardRefreshTimer {
  const handle = setTimeout(() => {
    void callback();
  }, delayMs);

  return {
    dispose: () => clearTimeout(handle)
  };
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
