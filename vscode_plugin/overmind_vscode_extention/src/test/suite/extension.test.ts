import * as assert from 'assert';
import * as vscode from 'vscode';

suite('Overmind extension scaffold', () => {
  test('registers the dashboard command', async () => {
    const extension = vscode.extensions.getExtension('specific-group.overmind-vscode-extension');

    assert.ok(extension);
    await extension.activate();

    const commands = await vscode.commands.getCommands(true);

    assert.ok(commands.includes('overmind.openDashboard'));
  });
});
