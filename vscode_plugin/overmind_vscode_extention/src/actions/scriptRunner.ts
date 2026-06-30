import * as vscode from 'vscode';

export interface ScriptTerminal {
  show(preserveFocus?: boolean): void;
  sendText(text: string, addNewLine?: boolean): void;
}

export interface ScriptTerminalServices {
  readonly createTerminal: (options: vscode.TerminalOptions) => ScriptTerminal;
}

export interface TerminalLaunchRequest {
  readonly actionTitle: string;
  readonly scriptPath: string;
  readonly scriptArguments?: readonly string[];
  readonly targetUri: vscode.Uri;
}

export interface TerminalLaunchResult {
  readonly command: string;
  readonly terminalName: string;
  readonly terminal: ScriptTerminal;
}

export function launchScriptInTerminal(
  request: TerminalLaunchRequest,
  services: ScriptTerminalServices = createDefaultTerminalServices()
): TerminalLaunchResult {
  const terminalName = `Overmind: ${request.actionTitle}`;
  const command = buildScriptCommand(request.scriptPath, request.scriptArguments ?? []);
  const terminal = services.createTerminal({
    name: terminalName,
    cwd: request.targetUri
  });

  terminal.show(false);
  terminal.sendText(command, true);

  return {
    command,
    terminalName,
    terminal
  };
}

export function buildScriptCommand(scriptPath: string, scriptArguments: readonly string[] = []): string {
  return [scriptPath, ...scriptArguments].map(quoteForPosixShell).join(' ');
}

export function quoteForPosixShell(value: string): string {
  return `'${value.replace(/'/g, `'\"'\"'`)}'`;
}

function createDefaultTerminalServices(): ScriptTerminalServices {
  return {
    createTerminal: (options) => vscode.window.createTerminal(options)
  };
}
