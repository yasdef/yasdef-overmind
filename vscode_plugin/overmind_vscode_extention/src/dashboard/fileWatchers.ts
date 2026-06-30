import * as vscode from 'vscode';
import { ASDLC_METADATA_FILE, getWorkspaceDisplayPath } from '../scanner/workspaceDetection';

export const ASDLC_WATCH_PATTERNS: readonly string[] = [
  ASDLC_METADATA_FILE,
  'projects/*/init_progress_definition.yaml',
  'projects/*/step_state.md',
  'projects/*/step_state_*.md',
  'projects/*/*/feature_br_summary.md',
  'projects/*/*/user_br_input.md',
  'projects/*/*/feature_design.md',
  'projects/*/*/step_plan.md',
  'projects/*/*/step_state.md'
];

export type AsdlcWatcherEventKind = 'created' | 'changed' | 'deleted';

export interface AsdlcWatcherEvent {
  readonly kind: AsdlcWatcherEventKind;
  readonly uri: vscode.Uri;
  readonly pattern: string;
}

export function createAsdlcFileWatchers(
  workspaceUri: vscode.Uri,
  onEvent: (event: AsdlcWatcherEvent) => void
): vscode.Disposable {
  const watchers = ASDLC_WATCH_PATTERNS.map((pattern) => {
    const watcher = vscode.workspace.createFileSystemWatcher(new vscode.RelativePattern(workspaceUri, pattern));

    return vscode.Disposable.from(
      watcher,
      watcher.onDidCreate((uri) => onEvent({ kind: 'created', uri, pattern })),
      watcher.onDidChange((uri) => onEvent({ kind: 'changed', uri, pattern })),
      watcher.onDidDelete((uri) => onEvent({ kind: 'deleted', uri, pattern }))
    );
  });

  return vscode.Disposable.from(...watchers);
}

export function formatWatcherEvent(event: AsdlcWatcherEvent): string {
  return `${event.kind} ${getWorkspaceDisplayPath(event.uri)} (${event.pattern})`;
}
