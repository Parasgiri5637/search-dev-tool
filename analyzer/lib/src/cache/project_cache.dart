import 'dart:io';
import 'package:path/path.dart' as p;

import '../graph/graph_builder.dart';
import '../graph/knowledge_graph.dart';
import '../models/file_analysis_result.dart';
import '../parser/ast_parser.dart';
import '../resolver/symbol_table.dart';

/// Manages cached file hashes and incremental graph updates.
class ProjectCache {
  final Map<String, int> _fileTimestamps = {};
  final Map<String, FileAnalysisResult> _fileResults = {};
  final AstParser parser;
  final GraphBuilder graphBuilder;

  ProjectCache({
    this.parser = const AstParser(),
    GraphBuilder? graphBuilder,
  }) : graphBuilder = graphBuilder ?? GraphBuilder();

  /// Gets all cached file analysis results.
  List<FileAnalysisResult> get cachedResults => _fileResults.values.toList();

  /// Checks if a file has changed on disk since last cached.
  bool hasFileChanged(String filePath) {
    final file = File(p.normalize(filePath));
    if (!file.existsSync()) return true;
    final lastModified = file.lastModifiedSync().millisecondsSinceEpoch;
    return _fileTimestamps[file.path] != lastModified;
  }

  /// Indexes or updates an entire list of files.
  void indexFiles(
    List<String> filePaths, {
    required SymbolTable symbolTable,
    required KnowledgeGraph graph,
  }) {
    for (final path in filePaths) {
      final file = File(p.normalize(path));
      if (!file.existsSync()) continue;

      final lastModified = file.lastModifiedSync().millisecondsSinceEpoch;
      _fileTimestamps[file.path] = lastModified;

      final result = parser.parseFile(file.path);
      _fileResults[file.path] = result;
    }

    // Rebuild graph from results
    final newGraph = graphBuilder.buildGraph(
      _fileResults.values.toList(),
      existingSymbolTable: symbolTable,
    );

    // Merge or replace graph contents
    graph.clear();
    for (final node in newGraph.nodes) {
      graph.addNode(node);
    }
    for (final edge in newGraph.allEdges) {
      graph.addEdge(edge);
    }
  }

  /// Incrementally updates a single file in the symbol table and graph.
  void updateFile(
    String filePath, {
    required SymbolTable symbolTable,
    required KnowledgeGraph graph,
    String? content,
  }) {
    final normalized = p.normalize(filePath);
    final file = File(normalized);

    if (!file.existsSync() && content == null) {
      // File was deleted
      _fileTimestamps.remove(normalized);
      _fileResults.remove(normalized);
      symbolTable.removeFile(normalized);
      graph.removeFileNodes(normalized);
      return;
    }

    if (file.existsSync()) {
      _fileTimestamps[normalized] =
          file.lastModifiedSync().millisecondsSinceEpoch;
    }

    // Remove old symbols and graph nodes for this file
    symbolTable.removeFile(normalized);
    graph.removeFileNodes(normalized);

    // Parse newly updated content
    final newResult = content != null
        ? parser.parseSource(content, filePath: normalized)
        : parser.parseFile(normalized);

    _fileResults[normalized] = newResult;

    // Incrementally re-build full graph
    final updatedGraph = graphBuilder.buildGraph(
      _fileResults.values.toList(),
      existingSymbolTable: symbolTable,
    );

    graph.clear();
    for (final node in updatedGraph.nodes) {
      graph.addNode(node);
    }
    for (final edge in updatedGraph.allEdges) {
      graph.addEdge(edge);
    }
  }
}
