# Project History: Flutter Code Map

## Project Overview

- **Project Name**: Flutter Code Map
- **Purpose**: A developer tool and VS Code extension for analyzing and understanding Dart/Flutter codebases without requiring AI for core functionality. Builds an AST-based knowledge graph with symbol resolution, dependency analysis, Flutter pattern detection, and interactive queries.
- **Tech Stack**: Dart (AST Analyzer, Knowledge Graph, Call Resolution, CLI Engine), TypeScript/HTML/CSS (VS Code Extension & Webview Panel), GitHub Actions (CI/CD .vsix Release Automation).
- **Important Architecture Decisions**:
  - Independent analyzer engine decoupled from VS Code extension.
  - Deterministic AST & symbol resolution using official Dart `analyzer` package as primary source of truth (zero regex dependency).
  - Bidirectional knowledge graph data structure with shortest-path BFS and call-chain hierarchy traversal.
  - State management detectors for BLoC/Cubit, Provider, and Riverpod without folder assumptions.
  - GoRouter and Navigator route extraction with page mapping.
  - Rule-based deterministic query engine with natural question understanding.
  - Process-based JSON-RPC stdio protocol between VS Code and Dart analyzer CLI.
  - Sub-millisecond incremental cache updating on `.dart` file change events.
  - Optional AI augmentor interface ready for future LLM summarization without being a hard dependency.
  - Automated GitHub Actions `.vsix` packaging workflow on git release tags.

---

## Current Status

- **Features Completed**:
  - Milestone 1: Project Scanner + AST Extraction (Completed)
  - Milestone 2: Symbol Model + Registry (Completed)
  - Milestone 3: Dependency Knowledge Graph (Completed)
  - Milestone 4: Reference & Call Resolution (Completed)
  - Milestone 5: Flutter Detectors: Widgets, BLoC, Cubit, Provider, Riverpod, Routes (Completed)
  - Milestone 6: Deterministic Query Engine (Completed)
  - Milestone 7: JSON Interface & CLI (`bin/code_map.dart`) (Completed)
  - Milestone 8: VS Code Webview Tab & Extension (Completed)
  - Milestone 9: Clickable Source Navigation in VS Code (Completed)
  - Milestone 10: Incremental Indexing & Caching (Completed)
  - Milestone 11: Graph Visualization & Call Flow Chains (Completed)
  - Milestone 12: Optional AI Extensibility Interface (Completed)
  - GitHub Actions CI/CD `.vsix` Release Automation (Completed)
- **Features In Progress**:
  - None
- **Features Pending**:
  - None (All milestones implemented, tested, and documented)

---

## Daily Work Log

### Date: 2026-08-17

**Task**: Implement Milestones 1-12, sample Flutter project, test suite, and GitHub distribution setup.

**Files Modified / Created**:
- `.github/workflows/release.yml`
- `PROJECT_HISTORY.md`
- `README.md`
- `LICENSE`
- Analyzer engine modules & tests (30/30 tests passing)
- VS Code Extension modules & Webview UI

**Changes Made**:
- Completed full Dart AST & Knowledge Graph analyzer with zero AI requirement.
- Added GitHub Actions `.vsix` packaging workflow.
- Updated `README.md` with step-by-step instructions for installing and running the extension directly from GitHub.

**Issues Found**:
- None.

**Next Steps**:
- Push repository to GitHub and tag releases with `git tag v0.1.0 && git push --tags`.
