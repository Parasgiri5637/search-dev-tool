# Flutter Code Map for VS Code

AST-based code map, knowledge graph, and query engine for Flutter & Dart codebases without requiring AI.

## Features

- **AST Knowledge Graph**: Scans and parses Flutter/Dart projects to build a complete symbol registry and call hierarchy.
- **Flutter Detection**: Automatic detection of Widgets, BLoC, Cubit, Provider, Riverpod, and GoRouter/Navigator routes.
- **Deterministic Question Answering**: Query your codebase (e.g. *Where is LoginPage?*, *Who uses AuthBloc?*, *Show login flow*).
- **Clickable Source Navigation**: Jump directly to source definitions with precise line/column accuracy.

## Usage

1. Open a Flutter/Dart project in VS Code.
2. Run `Cmd+Shift+P` -> `Flutter Code Map: Open`.
3. Use the dedicated Code Map tab to explore your project.
