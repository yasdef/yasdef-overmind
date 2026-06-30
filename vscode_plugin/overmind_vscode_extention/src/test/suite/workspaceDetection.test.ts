import * as assert from 'assert';
import * as path from 'path';
import * as vscode from 'vscode';
import {
  ACTIVE_ASDLC_WORKSPACE_KEY,
  ASDLC_METADATA_FILE,
  AsdlcWorkspaceCandidate,
  WorkspaceFolderLike,
  detectAsdlcWorkspaceFolders,
  resolveActiveAsdlcWorkspace
} from '../../scanner/workspaceDetection';

suite('ASDLC workspace detection', () => {
  test('reports no workspace folders', async () => {
    const detection = await detectAsdlcWorkspaceFolders([]);

    assert.strictEqual(detection.candidates.length, 0);
    assert.strictEqual(detection.diagnostics.length, 1);
    assert.strictEqual(detection.diagnostics[0].code, 'workspace.none');
  });

  test('reports workspace folders missing ASDLC metadata', async () => {
    const detection = await detectAsdlcWorkspaceFolders([fixtureFolder('plain-workspace')]);

    assert.strictEqual(detection.candidates.length, 0);
    assert.strictEqual(detection.diagnostics.length, 1);
    assert.strictEqual(detection.diagnostics[0].code, 'asdlc.metadata.missing');
    assert.ok(detection.diagnostics[0].path.endsWith(ASDLC_METADATA_FILE));
  });

  test('detects a single ASDLC workspace folder', async () => {
    const resolution = await resolveActiveAsdlcWorkspace([fixtureFolder('valid-asdlc')]);

    assert.strictEqual(resolution.status, 'selected');
    assert.strictEqual(resolution.selectionReason, 'single');
    assert.strictEqual(resolution.workspace?.workspaceName, 'valid-asdlc');
    assert.strictEqual(resolution.workspace?.diagnostics.length, 0);
  });

  test('uses a stored workspace selection when multiple ASDLC workspaces exist', async () => {
    const folders = [fixtureFolder('valid-asdlc'), fixtureFolder('second-asdlc')];
    const storedUri = folders[1].uri.toString();
    let pickerCalled = false;

    const resolution = await resolveActiveAsdlcWorkspace(folders, {
      storedWorkspaceUri: storedUri,
      chooseWorkspace: async () => {
        pickerCalled = true;
        return undefined;
      }
    });

    assert.strictEqual(resolution.status, 'selected');
    assert.strictEqual(resolution.selectionReason, 'stored');
    assert.strictEqual(resolution.workspace?.workspaceName, 'second-asdlc');
    assert.strictEqual(pickerCalled, false);
  });

  test('prompts and stores selection when multiple ASDLC workspaces exist without a stored match', async () => {
    const folders = [fixtureFolder('valid-asdlc'), fixtureFolder('second-asdlc')];
    let storedUri: string | undefined;

    const resolution = await resolveActiveAsdlcWorkspace(folders, {
      storedWorkspaceUri: 'file:///missing-asdlc',
      chooseWorkspace: async (candidates: AsdlcWorkspaceCandidate[]) => candidates[0],
      storeActiveWorkspaceUri: (workspaceUri: string) => {
        storedUri = workspaceUri;
      }
    });

    assert.strictEqual(resolution.status, 'selected');
    assert.strictEqual(resolution.selectionReason, 'prompted');
    assert.strictEqual(resolution.workspace?.workspaceName, 'valid-asdlc');
    assert.strictEqual(storedUri, folders[0].uri.toString());
  });

  test('reports cancelled selection when multiple ASDLC workspaces are not selected', async () => {
    const folders = [fixtureFolder('valid-asdlc'), fixtureFolder('second-asdlc')];

    const resolution = await resolveActiveAsdlcWorkspace(folders, {
      chooseWorkspace: async () => undefined
    });

    assert.strictEqual(resolution.status, 'selectionCancelled');
    assert.strictEqual(resolution.workspace, undefined);
  });

  test('keeps invalid metadata candidates but reports diagnostics', async () => {
    const detection = await detectAsdlcWorkspaceFolders([
      fixtureFolder('invalid-asdlc'),
      fixtureFolder('empty-asdlc')
    ]);

    assert.strictEqual(detection.candidates.length, 2);
    assert.ok(detection.diagnostics.some((diagnostic) => diagnostic.code === 'asdlc.metadata.unrecognized'));
    assert.ok(detection.diagnostics.some((diagnostic) => diagnostic.code === 'asdlc.metadata.empty'));
  });

  test('exports the active workspace preference key', () => {
    assert.strictEqual(ACTIVE_ASDLC_WORKSPACE_KEY, 'overmind.activeAsdlcWorkspaceUri');
  });
});

function fixtureFolder(name: string, index = 0): WorkspaceFolderLike {
  return {
    uri: vscode.Uri.file(path.join(fixturesRoot(), name)),
    name,
    index
  };
}

function fixturesRoot(): string {
  return path.resolve(__dirname, '../../../src/test/fixtures/workspaces');
}
