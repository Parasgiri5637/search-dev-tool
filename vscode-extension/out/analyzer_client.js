"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.AnalyzerClient = void 0;
const cp = require("child_process");
const path = require("path");
const vscode = require("vscode");
const readline = require("readline");
class AnalyzerClient {
    extensionPath;
    process = null;
    pendingRequests = new Map();
    requestId = 0;
    analyzerPath;
    constructor(extensionPath) {
        this.extensionPath = extensionPath;
        // Find analyzer/bin/code_map.dart relative to extension or monorepo root
        this.analyzerPath = path.resolve(extensionPath, '..', 'analyzer', 'bin', 'code_map.dart');
    }
    async startServer(projectPath) {
        if (this.process) {
            this.stopServer();
        }
        const dartCmd = 'dart';
        const args = ['run', this.analyzerPath, 'serve'];
        this.process = cp.spawn(dartCmd, args, {
            cwd: path.resolve(this.extensionPath, '..', 'analyzer'),
            stdio: ['pipe', 'pipe', 'pipe'],
        });
        const rl = readline.createInterface({
            input: this.process.stdout,
            terminal: false,
        });
        rl.on('line', (line) => {
            try {
                const msg = JSON.parse(line.trim());
                if (this.pendingRequests.size > 0) {
                    const firstKey = this.pendingRequests.keys().next().value;
                    if (firstKey !== undefined) {
                        const resolver = this.pendingRequests.get(firstKey);
                        this.pendingRequests.delete(firstKey);
                        resolver?.(msg);
                    }
                }
            }
            catch (_) { }
        });
        this.process.stderr?.on('data', (data) => {
            console.error(`[Analyzer stderr]: ${data}`);
        });
        this.process.on('close', () => {
            this.process = null;
        });
        // Initial analysis
        await this.analyze(projectPath);
    }
    stopServer() {
        if (this.process) {
            this.process.kill();
            this.process = null;
        }
    }
    async analyze(projectPath) {
        return this.sendRequest({ cmd: 'analyze', path: projectPath });
    }
    async query(queryText) {
        const res = await this.sendRequest({ cmd: 'query', query: queryText });
        return res.data;
    }
    async updateFile(filePath, content) {
        await this.sendRequest({ cmd: 'update', path: filePath, content });
    }
    async getGraph() {
        const res = await this.sendRequest({ cmd: 'graph' });
        return res.data;
    }
    sendRequest(payload) {
        return new Promise((resolve, reject) => {
            if (!this.process || !this.process.stdin) {
                // Fallback: spawn one-off CLI command
                this.runOneOffCommand(payload).then(resolve).catch(reject);
                return;
            }
            const id = ++this.requestId;
            this.pendingRequests.set(id, resolve);
            const jsonStr = JSON.stringify(payload) + '\n';
            this.process.stdin.write(jsonStr, 'utf-8', (err) => {
                if (err) {
                    this.pendingRequests.delete(id);
                    reject(err);
                }
            });
        });
    }
    runOneOffCommand(payload) {
        return new Promise((resolve, reject) => {
            let args = [];
            const cwd = path.resolve(this.extensionPath, '..', 'analyzer');
            if (payload.cmd === 'analyze') {
                args = ['run', this.analyzerPath, 'analyze', payload.path || '.'];
            }
            else if (payload.cmd === 'query') {
                const workspaceFolders = vscode.workspace.workspaceFolders;
                const root = workspaceFolders ? workspaceFolders[0].uri.fsPath : '.';
                args = ['run', this.analyzerPath, 'query', root, payload.query];
            }
            else if (payload.cmd === 'graph') {
                const workspaceFolders = vscode.workspace.workspaceFolders;
                const root = workspaceFolders ? workspaceFolders[0].uri.fsPath : '.';
                args = ['run', this.analyzerPath, 'graph', root];
            }
            else {
                resolve({ status: 'ok' });
                return;
            }
            cp.execFile('dart', args, { cwd }, (error, stdout) => {
                if (error) {
                    reject(error);
                }
                else {
                    try {
                        const data = JSON.parse(stdout.trim());
                        resolve({ status: 'ok', data });
                    }
                    catch (e) {
                        reject(e);
                    }
                }
            });
        });
    }
}
exports.AnalyzerClient = AnalyzerClient;
//# sourceMappingURL=analyzer_client.js.map