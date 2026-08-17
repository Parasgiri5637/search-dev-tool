import 'dart:convert';
import 'dart:io';
import 'package:flutter_code_map_analyzer/flutter_code_map.dart';

void main(List<String> args) {
  if (args.isEmpty) {
    _printUsage();
    exit(0);
  }

  final command = args[0];
  final engine = AnalyzerEngine();

  switch (command) {
    case 'analyze':
      final projectPath = args.length > 1 ? args[1] : Directory.current.path;
      final fullOutput = args.contains('--full');
      engine.analyzeProject(projectPath);
      final jsonOutput = fullOutput ? engine.exportJson() : engine.getSummary();
      stdout.writeln(jsonEncode(jsonOutput));
      break;

    case 'query':
      if (args.length < 3) {
        stderr.writeln('Usage: code_map query <project_path> <question>');
        exit(1);
      }
      final projectPath = args[1];
      final question = args.sublist(2).join(' ');
      engine.analyzeProject(projectPath);
      final result = engine.query(question);
      stdout.writeln(jsonEncode(result.toJson()));
      break;

    case 'graph':
      final projectPath = args.length > 1 ? args[1] : Directory.current.path;
      engine.analyzeProject(projectPath);
      stdout.writeln(jsonEncode(engine.exportJson()));
      break;

    case 'serve':
      // JSON RPC loop over stdin/stdout for VS Code extension
      _runServer(engine);
      break;

    default:
      _printUsage();
      exit(1);
  }
}

void _runServer(AnalyzerEngine engine) {
  stdin.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return;

    try {
      final req = jsonDecode(trimmed) as Map<String, dynamic>;
      final cmd = req['cmd'] as String?;

      switch (cmd) {
        case 'analyze':
          final path = req['path'] as String? ?? Directory.current.path;
          final summary = engine.analyzeProject(path);
          stdout.writeln(
            jsonEncode({'status': 'ok', 'type': 'summary', 'data': summary}),
          );
          break;

        case 'query':
          final question = req['query'] as String? ?? '';
          final result = engine.query(question);
          stdout.writeln(
            jsonEncode({'status': 'ok', 'type': 'queryResult', 'data': result.toJson()}),
          );
          break;

        case 'update':
          final path = req['path'] as String?;
          final content = req['content'] as String?;
          if (path != null) {
            engine.updateFile(path, content);
            stdout.writeln(
              jsonEncode({'status': 'ok', 'type': 'updated', 'path': path}),
            );
          }
          break;

        case 'graph':
          final graphData = engine.exportJson();
          stdout.writeln(
            jsonEncode({'status': 'ok', 'type': 'graph', 'data': graphData}),
          );
          break;

        default:
          stdout.writeln(
            jsonEncode({'status': 'error', 'message': 'Unknown command: $cmd'}),
          );
      }
    } catch (e) {
      stdout.writeln(
        jsonEncode({'status': 'error', 'message': e.toString()}),
      );
    }
  });
}

void _printUsage() {
  stdout.writeln('''
Flutter Code Map CLI
Usage:
  code_map analyze <path> [--full]  Scan and analyze a Dart/Flutter project
  code_map query <path> <question> Ask a question about the project
  code_map graph <path>             Export the full knowledge graph
  code_map serve                    Start JSON-RPC server for IDE extensions
''');
}
