import * as assert from 'assert';
import * as path from 'path';
import * as vscode from 'vscode';
import {
  buildTaskToBrCaptureArgs,
  captureTaskToBr,
  CAPTURE_TASK_TO_BR_MESSAGE_TYPE,
  createTaskToBrCaptureConfirmationMessage,
  handleTaskToBrCaptureMessage,
  TaskToBrCaptureConfirmationRequest,
  TaskToBrCaptureServices,
  TaskToBrCoreCaptureRequest
} from '../../actions/taskToBrCapture';
import { scanAsdlcWorkspace } from '../../scanner/asdlcScanner';

suite('Task-to-BR capture action', () => {
  test('validates a local story file and delegates to the shared core contract', async () => {
    const context = await createContext();
    const coreRequests: TaskToBrCoreCaptureRequest[] = [];
    const confirmations: TaskToBrCaptureConfirmationRequest[] = [];
    const infos: string[] = [];
    const result = await captureTaskToBr({
      type: CAPTURE_TASK_TO_BR_MESSAGE_TYPE,
      projectId: 'beta',
      featureId: 'feature-incomplete',
      sourceFile: 'story.md'
    }, context, createServices({
      confirm: async (request) => {
        confirmations.push(request);

        return true;
      },
      runCoreCapture: async (request) => {
        coreRequests.push(request);
      },
      showInformationMessage: async (message) => {
        infos.push(message);

        return undefined;
      }
    }));

    assert.strictEqual(result.status, 'captured');
    assert.strictEqual(confirmations.length, 1);
    assert.strictEqual(coreRequests.length, 1);
    assert.ok(coreRequests[0].featurePath.endsWith(path.join('projects', 'beta', 'feature-incomplete')));
    assert.deepStrictEqual(coreRequests[0].source.kind, 'localFile');
    assert.ok(coreRequests[0].source.kind === 'localFile' && coreRequests[0].source.sourceFilePath.endsWith(path.join('feature-incomplete', 'story.md')));
    assert.ok(infos.includes('Task-to-BR input captured.'));
  });

  test('validates a Jira ticket and does not require story-file filesystem access', async () => {
    const context = await createContext();
    let statCalled = false;
    const coreRequests: TaskToBrCoreCaptureRequest[] = [];
    const result = await captureTaskToBr({
      type: CAPTURE_TASK_TO_BR_MESSAGE_TYPE,
      projectId: 'beta',
      featureId: 'feature-incomplete',
      jiraTicket: 'ASDLC-42'
    }, context, createServices({
      fileSystem: {
        stat: async () => {
          statCalled = true;

          throw new Error('unexpected stat');
        }
      },
      runCoreCapture: async (request) => {
        coreRequests.push(request);
      }
    }));

    assert.strictEqual(result.status, 'captured');
    assert.strictEqual(statCalled, false);
    assert.strictEqual(coreRequests.length, 1);
    assert.deepStrictEqual(coreRequests[0].source, {
      kind: 'jira',
      jiraTicket: 'ASDLC-42'
    });
  });

  test('rejects invalid source combinations and unsafe local file paths before core capture', async () => {
    const context = await createContext();
    let coreCalled = false;
    const errors: string[] = [];
    const services = createServices({
      runCoreCapture: async () => {
        coreCalled = true;
      },
      showErrorMessage: async (message) => {
        errors.push(message);

        return undefined;
      }
    });
    const bothSources = await captureTaskToBr({
      type: CAPTURE_TASK_TO_BR_MESSAGE_TYPE,
      projectId: 'beta',
      featureId: 'feature-incomplete',
      sourceFile: 'story.md',
      jiraTicket: 'ASDLC-42'
    }, context, services);
    const outsidePath = await captureTaskToBr({
      type: CAPTURE_TASK_TO_BR_MESSAGE_TYPE,
      projectId: 'beta',
      featureId: 'feature-incomplete',
      sourceFile: '../story.md'
    }, context, services);
    const invalidExtension = await captureTaskToBr({
      type: CAPTURE_TASK_TO_BR_MESSAGE_TYPE,
      projectId: 'beta',
      featureId: 'feature-incomplete',
      sourceFile: 'story.pdf'
    }, context, services);
    const invalidJira = await captureTaskToBr({
      type: CAPTURE_TASK_TO_BR_MESSAGE_TYPE,
      projectId: 'beta',
      featureId: 'feature-incomplete',
      jiraTicket: 'ASDLC/42'
    }, context, services);

    assert.deepStrictEqual([bothSources.status, bothSources.status === 'rejected' ? bothSources.code : undefined], ['rejected', 'taskToBrCapture.sourceInvalid']);
    assert.deepStrictEqual([outsidePath.status, outsidePath.status === 'rejected' ? outsidePath.code : undefined], ['rejected', 'taskToBrCapture.sourceFileInvalid']);
    assert.deepStrictEqual([invalidExtension.status, invalidExtension.status === 'rejected' ? invalidExtension.code : undefined], ['rejected', 'taskToBrCapture.sourceFileInvalid']);
    assert.deepStrictEqual([invalidJira.status, invalidJira.status === 'rejected' ? invalidJira.code : undefined], ['rejected', 'taskToBrCapture.jiraInvalid']);
    assert.strictEqual(coreCalled, false);
    assert.ok(errors.length >= 4);
  });

  test('rejects missing local story files before core capture', async () => {
    const context = await createContext();
    let coreCalled = false;
    const result = await captureTaskToBr({
      type: CAPTURE_TASK_TO_BR_MESSAGE_TYPE,
      projectId: 'beta',
      featureId: 'feature-incomplete',
      sourceFile: 'missing.md'
    }, context, createServices({
      runCoreCapture: async () => {
        coreCalled = true;
      }
    }));

    assert.deepStrictEqual([result.status, result.status === 'rejected' ? result.code : undefined], ['rejected', 'taskToBrCapture.sourceFileMissing']);
    assert.strictEqual(coreCalled, false);
  });

  test('supports cancellation before invoking the core and surfaces core errors', async () => {
    const context = await createContext();
    let coreCalls = 0;
    const cancelled = await captureTaskToBr({
      type: CAPTURE_TASK_TO_BR_MESSAGE_TYPE,
      projectId: 'beta',
      featureId: 'feature-incomplete',
      sourceFile: 'story.md'
    }, context, createServices({
      confirm: async () => false,
      runCoreCapture: async () => {
        coreCalls += 1;
      }
    }));
    const failed = await captureTaskToBr({
      type: CAPTURE_TASK_TO_BR_MESSAGE_TYPE,
      projectId: 'beta',
      featureId: 'feature-incomplete',
      sourceFile: 'story.md'
    }, context, createServices({
      runCoreCapture: async () => {
        throw new Error('core rejected input');
      }
    }));

    assert.strictEqual(cancelled.status, 'cancelled');
    assert.strictEqual(coreCalls, 0);
    assert.deepStrictEqual([failed.status, failed.status === 'rejected' ? failed.code : undefined], ['rejected', 'taskToBrCapture.coreFailed']);
    assert.ok(failed.status === 'rejected' && failed.message.includes('core rejected input'));
  });

  test('recognizes capture Webview messages and ignores other messages', async () => {
    const ignored = await handleTaskToBrCaptureMessage({ type: 'openArtifact' }, undefined, createServices());
    const rejected = await handleTaskToBrCaptureMessage({
      type: CAPTURE_TASK_TO_BR_MESSAGE_TYPE,
      projectId: 'beta',
      featureId: 'feature-incomplete',
      sourceFile: 'story.md'
    }, undefined, createServices());

    assert.strictEqual(ignored.status, 'ignored');
    assert.deepStrictEqual([rejected.status, rejected.status === 'rejected' ? rejected.code : undefined], ['rejected', 'taskToBrCapture.noDashboardModel']);
  });

  test('builds core capture arguments without rendering canonical user_br_input content', () => {
    const args = buildTaskToBrCaptureArgs({
      workspacePath: '/tmp/asdlc',
      featurePath: '/tmp/asdlc/projects/beta/feature-incomplete',
      source: {
        kind: 'localFile',
        sourceFilePath: '/tmp/asdlc/projects/beta/feature-incomplete/story.md'
      }
    });
    const message = createTaskToBrCaptureConfirmationMessage({
      workspacePath: '/tmp/asdlc',
      featurePath: '/tmp/asdlc/projects/beta/feature-incomplete',
      projectId: 'beta',
      featureId: 'feature-incomplete',
      source: {
        kind: 'jira',
        jiraTicket: 'ASDLC-42'
      }
    });

    assert.deepStrictEqual(args, [
      'capture',
      'task-to-br',
      '--feature-path',
      '/tmp/asdlc/projects/beta/feature-incomplete',
      '--source-file',
      '/tmp/asdlc/projects/beta/feature-incomplete/story.md'
    ]);
    assert.ok(message.includes('Feature: /tmp/asdlc/projects/beta/feature-incomplete'));
    assert.ok(message.includes('Source: jira:ASDLC-42'));
  });
});

async function createContext() {
  const workspaceUri = scannerFixture('asdlc');

  return {
    workspaceUri,
    model: await scanAsdlcWorkspace(workspaceUri)
  };
}

function createServices(overrides: Partial<TaskToBrCaptureServices> = {}): TaskToBrCaptureServices {
  return {
    fileSystem: {
      stat: (uri) => vscode.workspace.fs.stat(uri),
      ...overrides.fileSystem
    },
    confirm: async () => true,
    runCoreCapture: async () => undefined,
    showInformationMessage: async () => undefined,
    showErrorMessage: async () => undefined,
    ...overrides
  };
}

function scannerFixture(name: string): vscode.Uri {
  return vscode.Uri.file(path.resolve(__dirname, '../../../src/test/fixtures/scanner', name));
}
