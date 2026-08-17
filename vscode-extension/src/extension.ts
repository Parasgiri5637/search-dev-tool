import * as vscode from 'vscode';
import { AnalyzerClient } from './analyzer_client';
import { CodeMapPanel } from './code_map_panel';

export function activate(context: vscode.ExtensionContext) {
  const analyzerClient = new AnalyzerClient(context.extensionPath);

  // Register Open Command
  const openCommand = vscode.commands.registerCommand(
    'flutter-code-map.open',
    () => {
      CodeMapPanel.createOrShow(context.extensionUri, analyzerClient);
    }
  );

  // Status Bar Item
  const statusBarItem = vscode.window.createStatusBarItem(
    vscode.StatusBarAlignment.Right,
    100
  );
  statusBarItem.command = 'flutter-code-map.open';
  statusBarItem.text = '$(map) Code Map';
  statusBarItem.tooltip = 'Open Flutter Code Map Tab';
  statusBarItem.show();

  // File system watcher for incremental updates (Milestone 10)
  const watcher = vscode.workspace.createFileSystemWatcher('**/*.dart');

  watcher.onDidChange(async (uri) => {
    try {
      const doc = await vscode.workspace.openTextDocument(uri);
      await analyzerClient.updateFile(uri.fsPath, doc.getText());
    } catch (_) {}
  });

  watcher.onDidCreate(async (uri) => {
    try {
      const doc = await vscode.workspace.openTextDocument(uri);
      await analyzerClient.updateFile(uri.fsPath, doc.getText());
    } catch (_) {}
  });

  watcher.onDidDelete(async (uri) => {
    try {
      await analyzerClient.updateFile(uri.fsPath);
    } catch (_) {}
  });

  context.subscriptions.push(
    openCommand,
    statusBarItem,
    watcher,
    new vscode.Disposable(() => analyzerClient.stopServer())
  );
}

export function deactivate() {}
