import * as vscode from "vscode";

import { DashboardViewProvider, type DashboardRow } from "./view-provider.js";

const VIEW_ID = "overmind.dashboard";

class ReadOnlyTreeProvider implements vscode.TreeDataProvider<DashboardRow> {
  private readonly changeEmitter = new vscode.EventEmitter<
    DashboardRow | DashboardRow[] | undefined | null | void
  >();
  public readonly onDidChangeTreeData = this.changeEmitter.event;

  public constructor(
    private readonly provider: DashboardViewProvider,
    private readonly workspacePath: string
  ) {}

  public getTreeItem(element: DashboardRow): vscode.TreeItem {
    const item = new vscode.TreeItem(element.label, vscode.TreeItemCollapsibleState.None);
    item.description = element.description;
    return item;
  }

  public getChildren(): DashboardRow[] {
    return this.provider.getRows(this.workspacePath);
  }

  public refresh(): void {
    this.changeEmitter.fire(undefined);
  }

  public dispose(): void {
    this.changeEmitter.dispose();
  }
}

function watchRefresh(
  context: vscode.ExtensionContext,
  watcher: vscode.FileSystemWatcher,
  provider: ReadOnlyTreeProvider
): void {
  context.subscriptions.push(
    watcher,
    watcher.onDidCreate(() => provider.refresh()),
    watcher.onDidChange(() => provider.refresh()),
    watcher.onDidDelete(() => provider.refresh())
  );
}

export function activate(context: vscode.ExtensionContext): void {
  const workspaceFolder = vscode.workspace.workspaceFolders?.[0];
  const workspacePath = workspaceFolder?.uri.fsPath ?? "";
  const provider = new DashboardViewProvider();
  const treeProvider = new ReadOnlyTreeProvider(provider, workspacePath);
  const view = vscode.window.createTreeView(VIEW_ID, {
    treeDataProvider: treeProvider
  });
  context.subscriptions.push(treeProvider, view);

  if (workspaceFolder) {
    watchRefresh(
      context,
      vscode.workspace.createFileSystemWatcher(
        new vscode.RelativePattern(workspaceFolder, "asdlc_metadata.yaml")
      ),
      treeProvider
    );
    watchRefresh(
      context,
      vscode.workspace.createFileSystemWatcher(
        new vscode.RelativePattern(workspaceFolder, "projects/**/*")
      ),
      treeProvider
    );
  }
}

export function deactivate(): void {}
