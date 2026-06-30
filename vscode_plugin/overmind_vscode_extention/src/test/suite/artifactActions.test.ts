import * as assert from 'assert';
import * as path from 'path';
import * as vscode from 'vscode';
import { ArtifactOpenServices, handleDashboardWebviewMessage } from '../../actions/artifactActions';
import { scanAsdlcWorkspace } from '../../scanner/asdlcScanner';

suite('Artifact actions', () => {
  test('opens existing artifacts from Webview messages through VS Code file APIs', async () => {
    const model = await scanAsdlcWorkspace(scannerFixture('asdlc'));
    const artifact = requiredProject(model, 'alpha').features[0].artifacts
      .find((candidate) => candidate.name === 'feature_br_summary.md');
    let openedUri: vscode.Uri | undefined;
    let shownDocument = false;
    const services = createServices({
      openTextDocument: async (uri) => {
        openedUri = uri;

        return { uri } as vscode.TextDocument;
      },
      showTextDocument: async () => {
        shownDocument = true;

        return {} as vscode.TextEditor;
      }
    });

    assert.ok(artifact);

    const result = await handleDashboardWebviewMessage({
      type: 'openArtifact',
      artifactUri: artifact.uri
    }, model, services);

    assert.strictEqual(result, 'opened');
    assert.strictEqual(openedUri?.toString(), artifact.uri);
    assert.strictEqual(shownDocument, true);
  });

  test('rejects missing artifacts without opening a document', async () => {
    const model = await scanAsdlcWorkspace(scannerFixture('asdlc'));
    const artifact = requiredProject(model, 'beta').features[0].artifacts
      .find((candidate) => candidate.name === 'user_br_input.md');
    let statCalls = 0;
    let opened = false;
    const warnings: string[] = [];
    const services = createServices({
      fileSystem: {
        stat: async (uri: vscode.Uri) => {
          statCalls += 1;

          return vscode.workspace.fs.stat(uri);
        }
      },
      openTextDocument: async (uri) => {
        opened = true;

        return { uri } as vscode.TextDocument;
      },
      showWarningMessage: async (message) => {
        warnings.push(message);

        return undefined;
      }
    });

    assert.ok(artifact);

    const result = await handleDashboardWebviewMessage({
      type: 'openArtifact',
      artifactUri: artifact.uri
    }, model, services);

    assert.strictEqual(result, 'rejected');
    assert.strictEqual(statCalls, 0);
    assert.strictEqual(opened, false);
    assert.ok(warnings.some((message) => message.includes('Artifact is missing')));
  });

  test('ignores unsupported Webview messages', async () => {
    const result = await handleDashboardWebviewMessage({ type: 'refresh' }, undefined, createServices());

    assert.strictEqual(result, 'ignored');
  });
});

function createServices(overrides: Partial<ArtifactOpenServices> = {}): ArtifactOpenServices {
  return {
    fileSystem: {
      stat: (uri) => vscode.workspace.fs.stat(uri),
      ...overrides.fileSystem
    },
    openTextDocument: async (uri) => ({ uri } as vscode.TextDocument),
    showTextDocument: async () => ({} as vscode.TextEditor),
    showWarningMessage: async () => undefined,
    ...overrides
  };
}

function requiredProject(
  model: Awaited<ReturnType<typeof scanAsdlcWorkspace>>,
  projectId: string
) {
  const project = model.projects.find((candidate) => candidate.projectId === projectId);

  assert.ok(project, `Expected project ${projectId} to be scanned.`);

  return project;
}

function scannerFixture(name: string): vscode.Uri {
  return vscode.Uri.file(path.resolve(__dirname, '../../../src/test/fixtures/scanner', name));
}
