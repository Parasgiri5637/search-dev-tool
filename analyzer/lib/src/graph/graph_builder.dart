import '../detectors/flutter_detector.dart';
import '../detectors/route_detector.dart';
import '../detectors/state_management_detector.dart';
import '../detectors/widget_detector.dart';
import '../models/file_analysis_result.dart';
import '../models/graph_edge.dart';
import '../models/graph_node.dart';
import '../resolver/call_resolver.dart';
import '../resolver/symbol_table.dart';
import 'knowledge_graph.dart';

/// Coordinates symbol indexing, call resolution, detectors, and graph assembly.
class GraphBuilder {
  final List<FlutterDetector> detectors;

  GraphBuilder({
    List<FlutterDetector>? customDetectors,
  }) : detectors = customDetectors ??
            [
              WidgetDetector(),
              StateManagementDetector(),
              RouteDetector(),
            ];

  /// Builds a complete [KnowledgeGraph] from parsed file analysis results.
  KnowledgeGraph buildGraph(
    List<FileAnalysisResult> fileResults, {
    SymbolTable? existingSymbolTable,
    Map<String, String>? fileContents,
  }) {
    final graph = KnowledgeGraph();
    final symbolTable = existingSymbolTable ?? SymbolTable();

    // 1. Register all AST symbols into SymbolTable
    for (final fileResult in fileResults) {
      symbolTable.registerFromAstElements(fileResult.elements);
    }

    // 2. Add File, Class, and Member nodes + structural edges
    for (final fileResult in fileResults) {
      final fileNodeId = fileResult.filePath;
      graph.addNode(
        GraphNode(
          id: fileNodeId,
          label: fileResult.filePath,
          kind: NodeKind.fileNode,
          metadata: {
            'hasErrors': fileResult.hasErrors,
            'errorCount': fileResult.errors.length,
          },
        ),
      );

      // Imports and exports
      for (final imp in fileResult.imports) {
        graph.addEdge(
          GraphEdge(
            sourceId: fileNodeId,
            targetId: imp.uri,
            kind: EdgeKind.imports,
            location: imp.location,
          ),
        );
      }

      for (final exp in fileResult.exports) {
        graph.addEdge(
          GraphEdge(
            sourceId: fileNodeId,
            targetId: exp.uri,
            kind: EdgeKind.exports,
            location: exp.location,
          ),
        );
      }

      // Classes
      for (final cls in fileResult.classes) {
        final classNodeId = '${cls.file}#${cls.name}';
        graph.addNode(
          GraphNode(
            id: classNodeId,
            label: cls.name,
            kind: NodeKind.classNode,
            location: cls.location,
            metadata: {
              'isAbstract': cls.isAbstract,
              'superclass': cls.superclass,
              'mixins': cls.mixins,
              'interfaces': cls.interfaces,
              'filePath': cls.file,
            },
          ),
        );

        // File contains class
        graph.addEdge(
          GraphEdge(
            sourceId: fileNodeId,
            targetId: classNodeId,
            kind: EdgeKind.contains,
          ),
        );

        // Inheritance edges
        if (cls.superclass != null) {
          final targetSymbols = symbolTable.findByName(cls.superclass!);
          final targetId = targetSymbols.isNotEmpty
              ? targetSymbols.first.id
              : cls.superclass!;
          graph.addEdge(
            GraphEdge(
              sourceId: classNodeId,
              targetId: targetId,
              kind: EdgeKind.extendsType,
              location: cls.location,
            ),
          );
        }

        for (final m in cls.mixins) {
          final targetSymbols = symbolTable.findByName(m);
          final targetId =
              targetSymbols.isNotEmpty ? targetSymbols.first.id : m;
          graph.addEdge(
            GraphEdge(
              sourceId: classNodeId,
              targetId: targetId,
              kind: EdgeKind.withMixin,
              location: cls.location,
            ),
          );
        }

        for (final iface in cls.interfaces) {
          final targetSymbols = symbolTable.findByName(iface);
          final targetId =
              targetSymbols.isNotEmpty ? targetSymbols.first.id : iface;
          graph.addEdge(
            GraphEdge(
              sourceId: classNodeId,
              targetId: targetId,
              kind: EdgeKind.implementsType,
              location: cls.location,
            ),
          );
        }

        // Methods
        for (final m in cls.methods) {
          final methodNodeId = '${cls.file}#${cls.name}.${m.name}';
          graph.addNode(
            GraphNode(
              id: methodNodeId,
              label: '${cls.name}.${m.name}()',
              kind: NodeKind.methodNode,
              location: m.location,
              metadata: {
                'parentClass': cls.name,
                'returnType': m.returnType,
                'isStatic': m.isStatic,
                'filePath': cls.file,
              },
            ),
          );
          graph.addEdge(
            GraphEdge(
              sourceId: classNodeId,
              targetId: methodNodeId,
              kind: EdgeKind.contains,
            ),
          );
        }

        // Constructors
        for (final ctor in cls.constructors) {
          final ctorNodeId = '${cls.file}#${ctor.displayName}';
          graph.addNode(
            GraphNode(
              id: ctorNodeId,
              label: ctor.displayName,
              kind: NodeKind.constructorNode,
              location: ctor.location,
              metadata: {
                'parentClass': cls.name,
                'isFactory': ctor.isFactory,
                'isConst': ctor.isConst,
                'filePath': cls.file,
              },
            ),
          );
          graph.addEdge(
            GraphEdge(
              sourceId: classNodeId,
              targetId: ctorNodeId,
              kind: EdgeKind.contains,
            ),
          );
        }
      }

      // Functions
      for (final f in fileResult.functions) {
        final funcNodeId = '${f.file}#${f.name}';
        graph.addNode(
          GraphNode(
            id: funcNodeId,
            label: '${f.name}()',
            kind: NodeKind.functionNode,
            location: f.location,
            metadata: {
              'returnType': f.returnType,
              'isAsync': f.isAsync,
              'filePath': f.file,
            },
          ),
        );
        graph.addEdge(
          GraphEdge(
            sourceId: fileNodeId,
            targetId: funcNodeId,
            kind: EdgeKind.contains,
          ),
        );
      }
    }

    // 3. Resolve Calls and Invocations across the workspace
    final callResolver = CallResolver(symbolTable: symbolTable);
    for (final fileResult in fileResults) {
      final content = fileContents?[fileResult.filePath];
      final calls = callResolver.resolveCalls(fileResult.filePath, content);
      for (final call in calls) {
        if (call.resolvedTargetId != null) {
          graph.addEdge(
            GraphEdge(
              sourceId: call.callerId,
              targetId: call.resolvedTargetId!,
              kind: call.kind,
              confidence: call.confidence,
              location: call.location,
              metadata: {
                'symbolName': call.targetSymbolName,
                'receiverType': call.targetReceiverType,
              },
            ),
          );
        }
      }
    }

    // 4. Run Flutter Detectors (Widgets, State Management, Routes)
    for (final detector in detectors) {
      detector.detect(
        fileResults: fileResults,
        symbolTable: symbolTable,
        graph: graph,
      );
    }

    return graph;
  }
}
