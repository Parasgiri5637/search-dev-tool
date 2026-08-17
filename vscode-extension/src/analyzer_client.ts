import * as cp from 'child_process';
import * as path from 'path';
import * as vscode from 'vscode';
import * as readline from 'readline';

export interface ProjectSummary {
  files: number;
  classes: number;
  methods: number;
  functions: number;
  nodes: number;
  relationships: number;
  errors: number;
}

export interface QueryResultPayload {
  query: string;
  intent: string;
  title: string;
  summary: string;
  directAnswer?: string;
  sourceLocation?: {
    filePath: string;
    line: number;
    column: number;
    endLine: number;
    endColumn: number;
  };
  dependsOn?: Array<{ id: string; label: string; kind: string; location?: any }>;
  calls?: Array<{ id: string; label: string; kind: string; location?: any }>;
  usedBy?: Array<{ id: string; label: string; kind: string; location?: any }>;
  callChain?: string[];
  nodes?: Array<{ id: string; label: string; kind: string; location?: any }>;
  suggestedFollowups?: string[];
}

export class AnalyzerClient {
  private process: cp.ChildProcess | null = null;
  private pendingRequests = new Map<number, (res: any) => void>();
  private requestId = 0;
  private analyzerPath: string;

  constructor(private extensionPath: string) {
    // Find analyzer/bin/code_map.dart relative to extension or monorepo root
    this.analyzerPath = path.resolve(extensionPath, '..', 'analyzer', 'bin', 'code_map.dart');
  }

  public async startServer(projectPath: string): Promise<void> {
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
      input: this.process.stdout!,
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
      } catch (_) {}
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

  public stopServer(): void {
    if (this.process) {
      this.process.kill();
      this.process = null;
    }
  }

  public async analyze(projectPath: string): Promise<any> {
    return this.sendRequest({ cmd: 'analyze', path: projectPath });
  }

  public async query(queryText: string): Promise<QueryResultPayload> {
    const res = await this.sendRequest({ cmd: 'query', query: queryText });
    return res.data as QueryResultPayload;
  }

  public async updateFile(filePath: string, content?: string): Promise<void> {
    await this.sendRequest({ cmd: 'update', path: filePath, content });
  }

  public async getGraph(): Promise<any> {
    const res = await this.sendRequest({ cmd: 'graph' });
    return res.data;
  }

  private sendRequest(payload: any): Promise<any> {
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

  private runOneOffCommand(payload: any): Promise<any> {
    return new Promise((resolve, reject) => {
      let args: string[] = [];
      const cwd = path.resolve(this.extensionPath, '..', 'analyzer');

      if (payload.cmd === 'analyze') {
        args = ['run', this.analyzerPath, 'analyze', payload.path || '.'];
      } else if (payload.cmd === 'query') {
        const workspaceFolders = vscode.workspace.workspaceFolders;
        const root = workspaceFolders ? workspaceFolders[0].uri.fsPath : '.';
        args = ['run', this.analyzerPath, 'query', root, payload.query];
      } else if (payload.cmd === 'graph') {
        const workspaceFolders = vscode.workspace.workspaceFolders;
        const root = workspaceFolders ? workspaceFolders[0].uri.fsPath : '.';
        args = ['run', this.analyzerPath, 'graph', root];
      } else {
        resolve({ status: 'ok' });
        return;
      }

      cp.execFile('dart', args, { cwd }, (error, stdout) => {
        if (error) {
          reject(error);
        } else {
          try {
            const data = JSON.parse(stdout.trim());
            resolve({ status: 'ok', data });
          } catch (e) {
            reject(e);
          }
        }
      });
    });
  }
}
