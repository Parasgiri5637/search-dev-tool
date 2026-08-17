"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.CodeMapPanel = void 0;
const fs = require("fs");
const path = require("path");
const vscode = require("vscode");
class CodeMapPanel {
    client;
    static currentPanel;
    panel;
    extensionUri;
    disposables = [];
    static createOrShow(extensionUri, client) {
        const column = vscode.window.activeTextEditor
            ? vscode.window.activeTextEditor.viewColumn
            : undefined;
        if (CodeMapPanel.currentPanel) {
            CodeMapPanel.currentPanel.panel.reveal(column);
            return;
        }
        const panel = vscode.window.createWebviewPanel('flutterCodeMap', 'Flutter Code Map', column || vscode.ViewColumn.One, {
            enableScripts: true,
            retainContextWhenHidden: true,
            localResourceRoots: [
                vscode.Uri.joinPath(extensionUri, 'webview'),
                vscode.Uri.joinPath(extensionUri, 'media'),
            ],
        });
        CodeMapPanel.currentPanel = new CodeMapPanel(panel, extensionUri, client);
    }
    constructor(panel, extensionUri, client) {
        this.client = client;
        this.panel = panel;
        this.extensionUri = extensionUri;
        this.updateWebviewHtml();
        this.panel.onDidDispose(() => this.dispose(), null, this.disposables);
        this.panel.webview.onDidReceiveMessage(async (message) => {
            switch (message.command) {
                case 'ready':
                    await this.handleReady();
                    break;
                case 'query':
                    await this.handleQuery(message.query);
                    break;
                case 'openFile':
                    await this.handleOpenFile(message.filePath, message.line, message.column);
                    break;
                case 'refresh':
                    await this.handleRefresh();
                    break;
            }
        }, null, this.disposables);
    }
    async handleReady() {
        const workspaceFolders = vscode.workspace.workspaceFolders;
        if (!workspaceFolders || workspaceFolders.length === 0) {
            this.panel.webview.postMessage({
                type: 'status',
                status: 'No Dart/Flutter workspace open.',
            });
            return;
        }
        const projectPath = workspaceFolders[0].uri.fsPath;
        this.panel.webview.postMessage({
            type: 'indexing',
            message: 'Indexing Flutter project...',
        });
        try {
            const summary = await this.client.analyze(projectPath);
            this.panel.webview.postMessage({
                type: 'indexed',
                data: summary.data,
            });
        }
        catch (e) {
            this.panel.webview.postMessage({
                type: 'error',
                message: e.message || 'Analysis failed.',
            });
        }
    }
    async handleQuery(queryText) {
        try {
            this.panel.webview.postMessage({ type: 'queryLoading' });
            const result = await this.client.query(queryText);
            this.panel.webview.postMessage({
                type: 'queryResult',
                result,
            });
        }
        catch (e) {
            this.panel.webview.postMessage({
                type: 'queryError',
                message: e.message || 'Query failed.',
            });
        }
    }
    async handleOpenFile(filePath, line, column) {
        try {
            let resolvedPath = filePath;
            if (!path.isAbsolute(filePath)) {
                const root = vscode.workspace.workspaceFolders?.[0].uri.fsPath || '';
                resolvedPath = path.join(root, filePath);
            }
            const uri = vscode.Uri.file(resolvedPath);
            const document = await vscode.workspace.openTextDocument(uri);
            const targetLine = Math.max(0, (line ?? 1) - 1);
            const targetCol = Math.max(0, (column ?? 1) - 1);
            const position = new vscode.Position(targetLine, targetCol);
            await vscode.window.showTextDocument(document, {
                selection: new vscode.Range(position, position),
                preview: false,
            });
        }
        catch (e) {
            vscode.window.showErrorMessage(`Could not open file: ${e.message}`);
        }
    }
    async handleRefresh() {
        await this.handleReady();
    }
    updateWebviewHtml() {
        const webview = this.panel.webview;
        const webviewPath = path.join(this.extensionUri.fsPath, 'webview');
        let html = fs.readFileSync(path.join(webviewPath, 'index.html'), 'utf-8');
        const styleUri = webview.asWebviewUri(vscode.Uri.joinPath(this.extensionUri, 'webview', 'style.css'));
        const scriptUri = webview.asWebviewUri(vscode.Uri.joinPath(this.extensionUri, 'webview', 'app.js'));
        html = html.replace('{{styleUri}}', styleUri.toString());
        html = html.replace('{{scriptUri}}', scriptUri.toString());
        this.panel.webview.html = html;
    }
    dispose() {
        CodeMapPanel.currentPanel = undefined;
        this.panel.dispose();
        while (this.disposables.length) {
            const x = this.disposables.pop();
            if (x) {
                x.dispose();
            }
        }
    }
}
exports.CodeMapPanel = CodeMapPanel;
//# sourceMappingURL=code_map_panel.js.map