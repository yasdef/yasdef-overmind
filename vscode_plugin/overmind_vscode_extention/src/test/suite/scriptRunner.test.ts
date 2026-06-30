import * as assert from 'assert';
import * as vscode from 'vscode';
import {
  buildScriptCommand,
  launchScriptInTerminal,
  quoteForPosixShell
} from '../../actions/scriptRunner';

suite('Script runner', () => {
  test('quotes script paths for POSIX shell execution', () => {
    assert.strictEqual(buildScriptCommand('/tmp/asdlc/.commands/init_progress_scanner.sh'), '\'/tmp/asdlc/.commands/init_progress_scanner.sh\'');
    assert.strictEqual(
      buildScriptCommand('/tmp/asdlc/.commands/init_progress_scanner.sh', ['--path', '/tmp/asdlc/projects/alpha/feature one']),
      '\'/tmp/asdlc/.commands/init_progress_scanner.sh\' \'--path\' \'/tmp/asdlc/projects/alpha/feature one\''
    );
    assert.strictEqual(quoteForPosixShell('/tmp/asdlc/feature one/run\'scan.sh'), '\'/tmp/asdlc/feature one/run\'"\'"\'scan.sh\'');
  });

  test('launches scripts in a visible integrated terminal with target cwd', () => {
    const targetUri = vscode.Uri.file('/tmp/asdlc/projects/alpha/feature-one');
    let createdOptions: vscode.TerminalOptions | undefined;
    let shown = false;
    let sentText: { text: string; addNewLine?: boolean } | undefined;
    const result = launchScriptInTerminal({
      actionTitle: 'Run Scanner',
      scriptPath: '/tmp/asdlc/.commands/init_progress_scanner.sh',
      targetUri
    }, {
      createTerminal: (options) => {
        createdOptions = options;

        return {
          show: (preserveFocus) => {
            shown = preserveFocus === false;
          },
          sendText: (text, addNewLine) => {
            sentText = { text, addNewLine };
          }
        };
      }
    });

    assert.strictEqual(createdOptions?.name, 'Overmind: Run Scanner');
    assert.strictEqual(createdOptions?.cwd?.toString(), targetUri.toString());
    assert.strictEqual(shown, true);
    assert.deepStrictEqual(sentText, {
      text: '\'/tmp/asdlc/.commands/init_progress_scanner.sh\'',
      addNewLine: true
    });
    assert.strictEqual(result.command, '\'/tmp/asdlc/.commands/init_progress_scanner.sh\'');
    assert.strictEqual(result.terminalName, 'Overmind: Run Scanner');
    assert.ok(result.terminal);
  });
});
