# Project History: Flutter Code Map

## Project Overview

- **Project Name**: Flutter Code Map
- **Repository**: [search-dev-tool on GitHub](https://github.com/Parasgiri5637/search-dev-tool)
- **Purpose**: A developer tool and VS Code extension for analyzing and understanding Dart/Flutter codebases without requiring AI for core functionality. Builds an AST-based knowledge graph with symbol resolution, dependency analysis, Flutter pattern detection, and interactive queries.
- **Tech Stack**: Dart (AST Analyzer, Knowledge Graph, Call Resolution, Native AOT Binary), TypeScript/HTML/CSS (VS Code Extension & Webview Panel), GitHub Actions (CI/CD .vsix Release Automation).
- **Important Architecture Decisions**:
  - Independent analyzer engine decoupled from VS Code extension.
  - Bundles self-contained native AOT binary inside extension package so VS Code doesn't require `dart` to be in system PATH.
  - Automatic fallback Dart/Flutter SDK discovery across all standard macOS, Linux, and Windows install paths.
  - Deterministic AST & symbol resolution using official Dart `analyzer` package as primary source of truth (zero regex dependency).
  - Natural phrase intent engine supporting multi-word terms (e.g. `find out where is cart page`, `where is login screen`).
  - Bidirectional knowledge graph data structure with shortest-path BFS and call-chain hierarchy traversal.
  - State management detectors for BLoC/Cubit, Provider, and Riverpod without folder assumptions.
  - GoRouter and Navigator route extraction with page mapping.
  - Automated GitHub Actions `.vsix` packaging workflow on git release tags.

---

## Current Status

- **Features Completed**:
  - All Milestones 1 through 12 implemented and tested (30/30 tests passing)
  - Precompiled native standalone binary bundled in `.vsix`
  - Extension installed and active in VS Code
  - Pushed to GitHub `main` branch
- **Features In Progress**:
  - None
- **Features Pending**:
  - None

---

## Daily Work Log

### Date: 2026-08-19

**Task**: Fix `spawn dart ENOENT` by bundling native AOT analyzer binary and upgrading query phrase matching.

**Files Modified / Created**:
- `analyzer/lib/src/query/query_engine.dart`
- `vscode-extension/src/analyzer_client.ts`
- `vscode-extension/bin/code_map`
- `vscode-extension/package.json`
- `flutter-code-map.vsix`
- `PROJECT_HISTORY.md`

**Changes Made**:
- Compiled Dart analyzer into native AOT standalone executable (`vscode-extension/bin/code_map`).
- Enhanced `AnalyzerClient` to prioritize native standalone binary, eliminating `ENOENT` / PATH errors in VS Code GUI.
- Upgraded `QueryEngine` with phrase normalization and candidate generator supporting multi-word queries like `find out where is cart page`.
- Re-packaged and re-installed `flutter-code-map.vsix` into VS Code.
- Pushed updates to GitHub.

**Issues Found**:
- None.

**Next Steps**:
- Reload VS Code window (`Developer: Reload Window`) and query any Flutter codebase!
