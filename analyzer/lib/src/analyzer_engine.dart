import 'dart:io';
import 'package:path/path.dart' as p;

import 'cache/project_cache.dart';
import 'graph/graph_builder.dart';
import 'graph/knowledge_graph.dart';
import 'models/file_analysis_result.dart';
import 'parser/ast_parser.dart';
import 'query/query_engine.dart';
import 'query/query_result.dart';
import 'resolver/symbol_table.dart';
import 'scanner/project_scanner.dart';

/// Top-level coordinator for scanning, parsing, graph building, and querying.
class AnalyzerEngine {
  final ProjectScanner scanner;
  final AstParser parser;
  final GraphBuilder graphBuilder;
  final ProjectCache cache;

  late SymbolTable symbolTable;
  late KnowledgeGraph graph;
  late QueryEngine queryEngine;

  String? _currentProjectPath;
  List<FileAnalysisResult> _fileResults = [];

  AnalyzerEngine({
    this.scanner = const ProjectScanner(),
    this.parser = const AstParser(),
    GraphBuilder? graphBuilder,
  })  : graphBuilder = graphBuilder ?? GraphBuilder(),
        cache = ProjectCache(parser: parser, graphBuilder: graphBuilder ?? GraphBuilder()) {
    symbolTable = SymbolTable();
    graph = KnowledgeGraph();
    queryEngine = QueryEngine(graph: graph, symbolTable: symbolTable);
  }

  String? get currentProjectPath => _currentProjectPath;
  List<FileAnalysisResult> get fileResults => _fileResults;

  /// Analyzes the Dart/Flutter project at [projectPath].
  Map<String, dynamic> analyzeProject(String projectPath) {
    final root = p.normalize(p.absolute(projectPath));
    _currentProjectPath = root;

    // 1. Scan files
    final dartFiles = scanner.scan(root);

    // 2. Read and parse file contents
    symbolTable.clear();
    graph.clear();

    final fileContents = <String, String>{};
    _fileResults = [];

    for (final file in dartFiles) {
      try {
        final content = File(file).readAsStringSync();
        fileContents[file] = content;
        final res = parser.parseSource(content, filePath: file);
        _fileResults.add(res);
      } catch (e) {
        _fileResults.add(
          parser.parseFile(file),
        );
      }
    }

    // 3. Build graph & populate symbols
    graph = graphBuilder.buildGraph(
      _fileResults,
      existingSymbolTable: symbolTable,
      fileContents: fileContents,
    );

    // 4. Update query engine
    queryEngine = QueryEngine(graph: graph, symbolTable: symbolTable);

    return getSummary();
  }

  /// Incremental update when a file changes.
  void updateFile(String filePath, [String? content]) {
    cache.updateFile(
      filePath,
      symbolTable: symbolTable,
      graph: graph,
      content: content,
    );
    queryEngine = QueryEngine(graph: graph, symbolTable: symbolTable);
  }

  /// Answers a developer query.
  QueryResult query(String queryText) {
    return queryEngine.execute(queryText);
  }

  /// Computes high-level summary metrics.
  Map<String, dynamic> getSummary() {
    int totalMethods = 0;
    int totalClasses = 0;
    int totalFunctions = 0;
    int totalErrors = 0;

    for (final f in _fileResults) {
      totalClasses += f.classes.length;
      totalFunctions += f.functions.length;
      totalErrors += f.errors.length;
      for (final c in f.classes) {
        totalMethods += c.methods.length;
      }
    }

    return {
      'project': _currentProjectPath ?? '',
      'summary': {
        'files': _fileResults.length,
        'classes': totalClasses,
        'methods': totalMethods,
        'functions': totalFunctions,
        'nodes': graph.nodeCount,
        'relationships': graph.edgeCount,
        'errors': totalErrors,
      },
    };
  }

  /// Complete JSON export of the project knowledge graph and summary.
  Map<String, dynamic> exportJson() {
    final summary = getSummary();
    return {
      'project': summary['project'],
      'summary': summary['summary'],
      'nodes': graph.nodes.map((n) => n.toJson()).toList(),
      'relationships': graph.allEdges.map((e) => e.toJson()).toList(),
    };
  }
}
