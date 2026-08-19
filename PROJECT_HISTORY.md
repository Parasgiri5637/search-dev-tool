# Project History: Flutter Code Map

## Project Overview

- **Project Name**: Flutter Code Map
- **Repository**: [search-dev-tool on GitHub](https://github.com/Parasgiri5637/search-dev-tool)
- **Purpose**: A developer tool and VS Code extension for analyzing and understanding Dart/Flutter codebases without requiring AI for core functionality. Builds an AST-based knowledge graph with symbol resolution, dependency analysis, Flutter pattern detection, code logic explanation, and interactive queries.
- **Tech Stack**: Dart (AST Analyzer, Knowledge Graph, Call Resolution, Logic Extractor, Native AOT Binary), TypeScript/HTML/CSS (VS Code Extension & Webview Panel), GitHub Actions (CI/CD .vsix Release Automation).
- **Important Architecture Decisions**:
  - Independent analyzer engine decoupled from VS Code extension.
  - Bundles self-contained native AOT binary inside extension package so VS Code doesn't require `dart` to be in system PATH.
  - Automatic fallback Dart/Flutter SDK discovery across all standard macOS, Linux, and Windows install paths.
  - Deterministic AST & symbol resolution using official Dart `analyzer` package as primary source of truth (zero regex dependency).
  - Deterministic Code Logic Explainer: extracts class/method structure, external invocations, state containers, and actual source code snippets from disk without requiring an AI model.
  - Natural phrase intent engine supporting multi-word terms (e.g. `what is logic in CartPage`, `how does AuthBloc work`, `find out where is cart page`).
  - Bidirectional knowledge graph data structure with shortest-path BFS and call-chain hierarchy traversal.
  - State management detectors for BLoC/Cubit, Provider, and Riverpod without folder assumptions.
  - GoRouter and Navigator route extraction with page mapping.
  - Automated GitHub Actions `.vsix` packaging workflow on git release tags.

---

## Current Status

- **Features Completed**:
  - All Milestones 1 through 12 implemented and tested (31/31 tests passing)
  - Deterministic Code Logic Breakdown & Architecture Explainer
  - Source Code Snippet Viewer with copy button
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

**Task**: Implement deterministic code logic explanation, source snippet viewer, and re-package extension.

**Files Modified / Created**:
- `analyzer/lib/src/query/query_intent.dart`
- `analyzer/lib/src/query/query_result.dart`
- `analyzer/lib/src/query/query_engine.dart`
- `analyzer/test/query_engine_test.dart`
- `analyzer/test/integration_test.dart`
- `vscode-extension/src/analyzer_client.ts`
- `vscode-extension/webview/index.html`
- `vscode-extension/webview/style.css`
- `vscode-extension/webview/app.js`
- `vscode-extension/bin/code_map`
- `flutter-code-map.vsix`
- `PROJECT_HISTORY.md`

**Changes Made**:
- Added `explainLogic` intent and extraction logic in `QueryEngine` to analyze inheritance, methods, external calls, state modifications, and extract real source code snippets directly from disk.
- Added UI components in Webview: Code Logic & Architecture breakdown list and Source Code snippet viewer with one-click copy.
- Tested and verified with unit and integration tests (31 passing tests).
- Re-packaged and re-installed `flutter-code-map.vsix` into VS Code.
- Pushed updates to GitHub repository.

**Issues Found**:
- None.

**Next Steps**:
- Reload VS Code window (`Developer: Reload Window`) and ask *"what is logic in CartPage"* or *"how does AuthBloc work"*.
