import * as assert from 'assert';
import * as path from 'path';
import * as vscode from 'vscode';
import {
  createConfirmationMessage,
  handleScriptActionMessage,
  RUN_SCRIPT_ACTION_MESSAGE_TYPE,
  runScriptAction,
  ScriptActionConfirmationRequest,
  ScriptActionServices
} from '../../actions/actionController';
import { scanAsdlcWorkspace } from '../../scanner/asdlcScanner';

suite('Script action controller', () => {
  test('allow-lists scanner action and launches it after explicit confirmation', async () => {
    const context = await createContext();
    const confirmations: ScriptActionConfirmationRequest[] = [];
    const terminals: vscode.TerminalOptions[] = [];
    const sentCommands: string[] = [];
    const services = createServices({
      confirm: async (request) => {
        confirmations.push(request);

        return true;
      },
      createTerminal: (options) => {
        terminals.push(options);

        return {
          show: () => undefined,
          sendText: (text) => {
            sentCommands.push(text);
          }
        };
      }
    });

    const result = await runScriptAction({
      type: RUN_SCRIPT_ACTION_MESSAGE_TYPE,
      actionId: 'runInitProgressScanner',
      projectId: 'alpha',
      featureId: 'feature-complete'
    }, context, services);

    assert.strictEqual(result.status, 'launched');
    assert.strictEqual(confirmations.length, 1);
    assert.ok(confirmations[0].scriptPath.endsWith(path.join('.commands', 'init_progress_scanner.sh')));
    assert.ok(confirmations[0].targetPath.endsWith(path.join('projects', 'alpha', 'feature-complete')));
    assert.strictEqual(terminals.length, 1);
    assert.strictEqual(terminals[0].cwd?.toString(), vscode.Uri.joinPath(
      context.workspaceUri,
      'projects',
      'alpha',
      'feature-complete'
    ).toString());
    assert.strictEqual(sentCommands.length, 1);
    assert.ok(sentCommands[0].includes('init_progress_scanner.sh'));
    assert.ok(sentCommands[0].includes("'--path'"));
    assert.ok(sentCommands[0].includes(path.join('projects', 'alpha', 'feature-complete')));
  });

  test('allow-lists create or continue feature action for selected projects', async () => {
    const context = await createContext();
    const confirmations: ScriptActionConfirmationRequest[] = [];
    const terminals: vscode.TerminalOptions[] = [];
    const sentCommands: string[] = [];
    const result = await runScriptAction({
      type: RUN_SCRIPT_ACTION_MESSAGE_TYPE,
      actionId: 'createOrContinueFeature',
      projectId: 'alpha'
    }, context, createServices({
      confirm: async (request) => {
        confirmations.push(request);

        return true;
      },
      createTerminal: (options) => {
        terminals.push(options);

        return {
          show: () => undefined,
          sendText: (text) => {
            sentCommands.push(text);
          }
        };
      }
    }));

    assert.strictEqual(result.status, 'launched');
    assert.strictEqual(confirmations.length, 1);
    assert.ok(confirmations[0].scriptPath.endsWith(path.join('.commands', 'project_add_feature_e2e.sh')));
    assert.ok(confirmations[0].targetPath.endsWith(path.join('projects', 'alpha')));
    assert.strictEqual(terminals[0].cwd?.toString(), vscode.Uri.joinPath(
      context.workspaceUri,
      'projects',
      'alpha'
    ).toString());
    assert.ok(sentCommands[0].includes('project_add_feature_e2e.sh'));
    assert.ok(sentCommands[0].includes("'--path'"));
    assert.ok(sentCommands[0].includes(path.join('projects', 'alpha')));
  });

  test('allow-lists create project action at workspace scope', async () => {
    const context = await createContext();
    const terminals: vscode.TerminalOptions[] = [];
    const sentCommands: string[] = [];
    const result = await runScriptAction({
      type: RUN_SCRIPT_ACTION_MESSAGE_TYPE,
      actionId: 'createProject'
    }, context, createServices({
      createTerminal: (options) => {
        terminals.push(options);

        return {
          show: () => undefined,
          sendText: (text) => {
            sentCommands.push(text);
          }
        };
      }
    }));

    assert.strictEqual(result.status, 'launched');
    assert.strictEqual(terminals[0].cwd?.toString(), context.workspaceUri.toString());
    assert.ok(sentCommands[0].includes('project_setup_add_new_project.sh'));
    assert.ok(!sentCommands[0].includes("'--path'"));
  });

  test('requires confirmation for mutating script actions', async () => {
    const context = await createContext();
    let terminalCreated = false;
    const result = await runScriptAction({
      type: RUN_SCRIPT_ACTION_MESSAGE_TYPE,
      actionId: 'runInitProgressScanner',
      projectId: 'alpha',
      featureId: 'feature-complete'
    }, context, createServices({
      confirm: async () => false,
      createTerminal: () => {
        terminalCreated = true;

        return {
          show: () => undefined,
          sendText: () => undefined
        };
      }
    }));

    assert.strictEqual(result.status, 'cancelled');
    assert.strictEqual(terminalCreated, false);
  });

  test('rejects unknown actions and invalid target ids', async () => {
    const context = await createContext();
    const unknown = await runScriptAction({
      type: RUN_SCRIPT_ACTION_MESSAGE_TYPE,
      actionId: 'deleteEverything',
      projectId: 'alpha',
      featureId: 'feature-complete'
    }, context, createServices());
    const invalidProject = await runScriptAction({
      type: RUN_SCRIPT_ACTION_MESSAGE_TYPE,
      actionId: 'runInitProgressScanner',
      projectId: '../alpha',
      featureId: 'feature-complete'
    }, context, createServices());
    const invalidFeature = await runScriptAction({
      type: RUN_SCRIPT_ACTION_MESSAGE_TYPE,
      actionId: 'runInitProgressScanner',
      projectId: 'alpha',
      featureId: '..\\feature-complete'
    }, context, createServices());

    assert.deepStrictEqual([unknown.status, unknown.status === 'rejected' ? unknown.code : undefined], ['rejected', 'scriptAction.unknown']);
    assert.deepStrictEqual([invalidProject.status, invalidProject.status === 'rejected' ? invalidProject.code : undefined], ['rejected', 'scriptAction.projectMissing']);
    assert.deepStrictEqual([invalidFeature.status, invalidFeature.status === 'rejected' ? invalidFeature.code : undefined], ['rejected', 'scriptAction.featureMissing']);
  });

  test('blocks shell scripts on local Windows without WSL', async () => {
    const context = await createContext();
    const result = await runScriptAction({
      type: RUN_SCRIPT_ACTION_MESSAGE_TYPE,
      actionId: 'runInitProgressScanner',
      projectId: 'alpha',
      featureId: 'feature-complete'
    }, context, createServices({
      runtime: {
        platform: 'win32',
        remoteName: undefined
      }
    }));

    assert.strictEqual(result.status, 'rejected');
    assert.strictEqual(result.status === 'rejected' ? result.code : undefined, 'scriptAction.runtimeUnsupported');
  });

  test('rejects missing and non-executable scripts before confirmation', async () => {
    const context = await createContext();
    let confirmed = false;
    const missing = await runScriptAction({
      type: RUN_SCRIPT_ACTION_MESSAGE_TYPE,
      actionId: 'runInitProgressScanner',
      projectId: 'alpha',
      featureId: 'feature-complete'
    }, context, createServices({
      fileSystem: {
        stat: async () => {
          throw new Error('missing');
        }
      },
      confirm: async () => {
        confirmed = true;

        return true;
      }
    }));
    const notExecutable = await runScriptAction({
      type: RUN_SCRIPT_ACTION_MESSAGE_TYPE,
      actionId: 'runInitProgressScanner',
      projectId: 'alpha',
      featureId: 'feature-complete'
    }, context, createServices({
      checkExecutable: async () => false,
      confirm: async () => {
        confirmed = true;

        return true;
      }
    }));

    assert.deepStrictEqual([missing.status, missing.status === 'rejected' ? missing.code : undefined], ['rejected', 'scriptAction.scriptMissing']);
    assert.deepStrictEqual([notExecutable.status, notExecutable.status === 'rejected' ? notExecutable.code : undefined], ['rejected', 'scriptAction.scriptNotExecutable']);
    assert.strictEqual(confirmed, false);
  });

  test('recognizes script action Webview messages and ignores other messages', async () => {
    const ignored = await handleScriptActionMessage({ type: 'openArtifact' }, undefined, createServices());
    const rejected = await handleScriptActionMessage({
      type: RUN_SCRIPT_ACTION_MESSAGE_TYPE,
      actionId: 'runInitProgressScanner',
      projectId: 'alpha',
      featureId: 'feature-complete'
    }, undefined, createServices());

    assert.strictEqual(ignored.status, 'ignored');
    assert.deepStrictEqual([rejected.status, rejected.status === 'rejected' ? rejected.code : undefined], ['rejected', 'scriptAction.noWorkspace']);
  });

  test('confirmation text shows exact script and target paths', () => {
    const message = createConfirmationMessage({
      action: {
        id: 'runInitProgressScanner',
        title: 'Run Scanner',
        scriptName: 'init_progress_scanner.sh',
        scope: 'feature',
        mutatesWorkspace: true,
        interactive: true,
        targetPathArgument: '--path'
      },
      scriptPath: '/tmp/asdlc/.commands/init_progress_scanner.sh',
      targetPath: '/tmp/asdlc/projects/alpha/feature-one'
    });

    assert.ok(message.includes('Script: /tmp/asdlc/.commands/init_progress_scanner.sh'));
    assert.ok(message.includes('Target: /tmp/asdlc/projects/alpha/feature-one'));
  });
});

async function createContext() {
  const workspaceUri = scannerFixture('asdlc');

  return {
    workspaceUri,
    model: await scanAsdlcWorkspace(workspaceUri)
  };
}

function createServices(overrides: Partial<ScriptActionServices> = {}): ScriptActionServices {
  return {
    fileSystem: {
      stat: async () => ({
        type: vscode.FileType.File,
        ctime: 0,
        mtime: 0,
        size: 0
      }),
      ...overrides.fileSystem
    },
    runtime: {
      platform: 'linux',
      remoteName: undefined,
      ...overrides.runtime
    },
    confirm: async () => true,
    checkExecutable: async () => true,
    createTerminal: () => ({
      show: () => undefined,
      sendText: () => undefined
    }),
    showErrorMessage: async () => undefined,
    ...overrides
  };
}

function scannerFixture(name: string): vscode.Uri {
  return vscode.Uri.file(path.resolve(__dirname, '../../../src/test/fixtures/scanner', name));
}
