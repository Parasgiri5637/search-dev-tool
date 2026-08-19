"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.AnalyzerClient = void 0;
const cp = require("child_process");
const fs = require("fs");
const os = require("os");
const path = require("path");
const readline = require("readline");
const vscode = require("vscode");
class AnalyzerClient {
    extensionPath;
    process = null;
    pendingRequests = new Map();
    requestId = 0;
    standaloneBinaryPath = null;
    analyzerScriptPath = null;
    dartExecutable = 'dart';
    constructor(extensionPath) {
        this.extensionPath = extensionPath;
        this.discoverExecutables();
    }
    discoverExecutables() {
        const home = os.homedir();
        // 1. Check for standalone compiled binary inside extension
        const binName = process.platform === 'win32' ? 'code_map.exe' : 'code_map';
        const localBin = path.join(this.extensionPath, 'bin', binName);
        if (fs.existsSync(localBin)) {
            try {
                fs.chmodSync(localBin, 0o755);
            }
            catch (_) { }
            this.standaloneBinaryPath = localBin;
        }
        // 2. Check for analyzer script path
        const candidateScriptPaths = [
            path.join(this.extensionPath, 'analyzer', 'bin', 'code_map.dart'),
            path.resolve(this.extensionPath, '..', 'analyzer', 'bin', 'code_map.dart'),
        ];
        for (const p of candidateScriptPaths) {
            if (fs.existsSync(p)) {
                this.analyzerScriptPath = p;
                break;
            }
        }
        // 3. Discover Dart/Flutter SDK executable
        const customDartSdk = vscode.workspace.getConfiguration('dart').get('sdkPath');
        const customFlutterSdk = vscode.workspace.getConfiguration('dart').get('flutterSdkPath');
        const candidateDartPaths = [
            customDartSdk ? path.join(customDartSdk, 'bin', 'dart') : null,
            customFlutterSdk ? path.join(customFlutterSdk, 'bin', 'dart') : null,
            customFlutterSdk ? path.join(customFlutterSdk, 'bin', 'cache', 'dart-sdk', 'bin', 'dart') : null,
            '/opt/homebrew/bin/dart',
            '/usr/local/bin/dart',
            path.join(home, 'Developement', 'flutter', 'bin', 'dart'),
            path.join(home, 'Development', 'flutter', 'bin', 'dart'),
            path.join(home, 'flutter', 'bin', 'dart'),
            path.join(home, 'fvm', 'default', 'bin', 'dart'),
            path.join(home, '.pub-cache', 'bin', 'dart'),
        ].filter((p) => Boolean(p && fs.existsSync(p)));
        if (candidateDartPaths.length > 0) {
            this.dartExecutable = candidateDartPaths[0];
        }
    }
    getSpawnCommandAndArgs(subCommand, subArgs = []) {
        this.discoverExecutables();
        if (this.standaloneBinaryPath && fs.existsSync(this.standaloneBinaryPath)) {
            return {
                cmd: this.standaloneBinaryPath,
                args: [subCommand, ...subArgs],
                cwd: this.extensionPath,
            };
        }
        const scriptPath = this.analyzerScriptPath || path.resolve(this.extensionPath, '..', 'analyzer', 'bin', 'code_map.dart');
        const analyzerDir = path.dirname(path.dirname(scriptPath));
        return {
            cmd: this.dartExecutable,
            args: ['run', scriptPath, subCommand, ...subArgs],
            cwd: analyzerDir,
        };
    }
    async startServer(projectPath) {
        if (this.process) {
            this.stopServer();
        }
        const { cmd, args, cwd } = this.getSpawnCommandAndArgs('serve');
        const env = {
            ...process.env,
            PATH: `${path.dirname(this.dartExecutable)}:/opt/homebrew/bin:/usr/local/bin:${process.env.PATH || ''}`,
        };
        this.process = cp.spawn(cmd, args, {
            cwd,
            env,
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
            const workspaceFolders = vscode.workspace.workspaceFolders;
            const root = workspaceFolders ? workspaceFolders[0].uri.fsPath : '.';
            let subCmd = 'analyze';
            let subArgs = [payload.path || root];
            if (payload.cmd === 'query') {
                subCmd = 'query';
                subArgs = [root, payload.query];
            }
            else if (payload.cmd === 'graph') {
                subCmd = 'graph';
                subArgs = [root];
            }
            else if (payload.cmd === 'update') {
                resolve({ status: 'ok' });
                return;
            }
            const { cmd, args, cwd } = this.getSpawnCommandAndArgs(subCmd, subArgs);
            const env = {
                ...process.env,
                PATH: `${path.dirname(this.dartExecutable)}:/opt/homebrew/bin:/usr/local/bin:${process.env.PATH || ''}`,
            };
            cp.execFile(cmd, args, { cwd, env, maxBuffer: 10 * 1024 * 1024 }, (error, stdout, stderr) => {
                if (error) {
                    reject(new Error(stderr || error.message));
                }
                else {
                    try {
                        const data = JSON.parse(stdout.trim());
                        resolve({ status: 'ok', data });
                    }
                    catch (e) {
                        reject(new Error(`Failed to parse analyzer output: ${stdout}`));
                    }
                }
            });
        });
    }
}
exports.AnalyzerClient = AnalyzerClient;
//# sourceMappingURL=analyzer_client.js.map