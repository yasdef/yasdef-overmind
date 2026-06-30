import * as assert from 'assert';
import * as path from 'path';
import * as vscode from 'vscode';
import {
  DashboardRefreshTimer,
  DashboardScanSession,
  isRefreshDashboardMessage
} from '../../dashboard/dashboardScanSession';
import { AsdlcWatcherEvent } from '../../dashboard/fileWatchers';
import { DashboardModel, scanAsdlcWorkspace, ScannerFileSystem } from '../../scanner/asdlcScanner';
import { AsdlcWorkspaceCandidate, AsdlcWorkspaceDiagnostic } from '../../scanner/workspaceDetection';
import { DashboardViewState } from '../../webview/dashboardView';

suite('Dashboard scan session', () => {
  test('runs manual refresh asynchronously and renders scanning state over last usable data', async () => {
    const firstModel = await scanAsdlcWorkspace(scannerFixture('asdlc'));
    const secondModel: DashboardModel = {
      ...firstModel,
      diagnostics: [
        ...firstModel.diagnostics,
        {
          severity: 'info',
          code: 'test.secondScan',
          path: firstModel.workspacePath,
          message: 'second scan'
        }
      ]
    };
    const renders: DashboardViewState[] = [];
    const logs: string[] = [];
    const models = [firstModel, secondModel];
    const session = createSession({
      render: (state) => renders.push(state),
      log: (line) => logs.push(line),
      scanWorkspace: async () => models.shift() ?? secondModel
    });

    await session.refresh('initial');
    await session.refresh('manual');

    assert.strictEqual(session.model?.scanStatus, 'ready');
    assert.ok(renders.some((state) => state.model?.scanStatus === 'scanning'));
    assert.ok(renders.at(-1)?.diagnostics?.some((diagnostic) => diagnostic.code === 'test.secondScan'));
    assert.ok(logs.some((line) => line.includes('scanner.start: manual')));
    assert.ok(logs.some((line) => line.includes('scanner.finish: manual ready')));
  });

  test('marks data stale on watched file changes and schedules a watcher refresh', async () => {
    const firstModel = await scanAsdlcWorkspace(scannerFixture('asdlc'));
    const secondModel: DashboardModel = {
      ...firstModel,
      diagnostics: []
    };
    let scheduledRefresh: (() => Promise<void>) | undefined;
    const renders: DashboardViewState[] = [];
    const logs: string[] = [];
    const models = [firstModel, secondModel];
    const session = createSession({
      render: (state) => renders.push(state),
      log: (line) => logs.push(line),
      scanWorkspace: async () => models.shift() ?? secondModel,
      scheduleRefresh: (callback) => {
        scheduledRefresh = callback;

        return disposableTimer();
      }
    });

    await session.refresh('initial');
    session.handleWatchedFileEvent(createWatcherEvent('changed', 'projects/alpha/step_state.md'));

    assert.strictEqual(session.model?.scanStatus, 'stale');
    assert.ok(renders.at(-1)?.model?.diagnostics.some((diagnostic) => diagnostic.code === 'scanner.stale'));
    assert.ok(logs.some((line) => line.includes('watcher.changed')));
    assert.ok(scheduledRefresh);

    await scheduledRefresh();

    assert.strictEqual(session.model?.scanStatus, 'ready');
    assert.ok(logs.some((line) => line.includes('scanner.start: watcher')));
  });

  test('marks data stale and queues another refresh when watched files change during a scan', async () => {
    const firstModel = await scanAsdlcWorkspace(scannerFixture('asdlc'));
    const secondModel: DashboardModel = {
      ...firstModel,
      diagnostics: [
        {
          severity: 'info',
          code: 'test.inFlightScan',
          path: firstModel.workspacePath,
          message: 'in-flight scan'
        }
      ]
    };
    const queuedModel: DashboardModel = {
      ...firstModel,
      diagnostics: [
        {
          severity: 'info',
          code: 'test.queuedScan',
          path: firstModel.workspacePath,
          message: 'queued scan'
        }
      ]
    };
    let resolveSecondScan!: (model: DashboardModel) => void;
    const secondScan = new Promise<DashboardModel>((resolve) => {
      resolveSecondScan = resolve;
    });
    let scanCount = 0;
    const logs: string[] = [];
    const session = createSession({
      log: (line) => logs.push(line),
      scanWorkspace: async () => {
        scanCount += 1;

        if (scanCount === 1) {
          return firstModel;
        }

        if (scanCount === 2) {
          return secondScan;
        }

        return queuedModel;
      }
    });

    await session.refresh('initial');

    const manualRefresh = session.refresh('manual');

    session.handleWatchedFileEvent(createWatcherEvent('changed', 'projects/alpha/feature-complete/step_plan.md'));

    assert.strictEqual(session.model?.scanStatus, 'stale');
    assert.ok(logs.some((line) => line.includes('scanner.refreshQueued: watcher event during active scan')));

    resolveSecondScan(secondModel);
    await manualRefresh;

    assert.strictEqual(scanCount, 3);
    assert.strictEqual(session.model?.scanStatus, 'ready');
    assert.ok(session.model?.diagnostics.some((diagnostic) => diagnostic.code === 'test.queuedScan'));
  });

  test('keeps last usable dashboard data when a later scan fails', async () => {
    const firstModel = await scanAsdlcWorkspace(scannerFixture('asdlc'));
    const failedModel: DashboardModel = {
      workspacePath: firstModel.workspacePath,
      scanStatus: 'failed',
      projects: [],
      diagnostics: [
        {
          severity: 'error',
          code: 'asdlc.metadata.parseFailed',
          path: path.join(firstModel.workspacePath, 'asdlc_metadata.yaml'),
          message: 'parse failed'
        }
      ]
    };
    const renders: DashboardViewState[] = [];
    const models = [firstModel, failedModel];
    const session = createSession({
      render: (state) => renders.push(state),
      scanWorkspace: async () => models.shift() ?? failedModel
    });

    await session.refresh('initial');
    await session.refresh('manual');

    assert.strictEqual(session.model?.scanStatus, 'stale');
    assert.strictEqual(session.model?.projects.length, firstModel.projects.length);
    assert.ok(session.model?.diagnostics.some((diagnostic) => diagnostic.code === 'asdlc.metadata.parseFailed'));
    assert.ok(session.model?.diagnostics.some((diagnostic) => diagnostic.code === 'scanner.lastUsableDataKept'));
    assert.strictEqual(renders.at(-1)?.kind, 'dashboard');
  });

  test('recognizes refresh Webview messages', () => {
    assert.strictEqual(isRefreshDashboardMessage({ type: 'refreshDashboard' }), true);
    assert.strictEqual(isRefreshDashboardMessage({ type: 'openArtifact' }), false);
  });
});

function createSession(options: {
  readonly render?: (state: DashboardViewState) => void;
  readonly log?: (line: string) => void;
  readonly scanWorkspace?: (
    workspaceUri: vscode.Uri,
    fileSystem: ScannerFileSystem
  ) => Promise<DashboardModel>;
  readonly scheduleRefresh?: (
    callback: () => Promise<void>,
    delayMs: number
  ) => DashboardRefreshTimer;
}): DashboardScanSession {
  return new DashboardScanSession({
    workspace: workspaceCandidate(),
    detectionDiagnostics: [],
    fileSystem: vscode.workspace.fs,
    render: options.render ?? (() => undefined),
    log: options.log ?? (() => undefined),
    scanWorkspace: options.scanWorkspace,
    scheduleRefresh: options.scheduleRefresh,
    refreshDebounceMs: 1
  });
}

function workspaceCandidate(): AsdlcWorkspaceCandidate {
  const workspaceUri = scannerFixture('asdlc');

  return {
    workspaceUri,
    workspaceName: 'asdlc',
    metadataUri: vscode.Uri.joinPath(workspaceUri, 'asdlc_metadata.yaml'),
    diagnostics: [] satisfies AsdlcWorkspaceDiagnostic[]
  };
}

function createWatcherEvent(kind: AsdlcWatcherEvent['kind'], relativePath: string): AsdlcWatcherEvent {
  return {
    kind,
    uri: vscode.Uri.joinPath(scannerFixture('asdlc'), ...relativePath.split('/')),
    pattern: 'projects/*/step_state.md'
  };
}

function disposableTimer(): DashboardRefreshTimer {
  return {
    dispose: () => undefined
  };
}

function scannerFixture(name: string): vscode.Uri {
  return vscode.Uri.file(path.resolve(__dirname, '../../../src/test/fixtures/scanner', name));
}
