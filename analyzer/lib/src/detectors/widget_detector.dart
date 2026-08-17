import '../graph/knowledge_graph.dart';
import '../models/ast_element.dart';
import '../models/file_analysis_result.dart';
import '../models/graph_node.dart';
import '../models/symbol.dart';
import '../resolver/symbol_table.dart';
import 'flutter_detector.dart';

/// Detects Flutter Widget classes (StatelessWidget, StatefulWidget, State, InheritedWidget).
class WidgetDetector implements FlutterDetector {
  @override
  String get name => 'WidgetDetector';

  static const Set<String> knownWidgetSuperclasses = {
    'StatelessWidget',
    'StatefulWidget',
    'InheritedWidget',
    'ConsumerWidget',
    'ConsumerStatefulWidget',
    'HookWidget',
  };

  @override
  DetectorResult detect({
    required List<FileAnalysisResult> fileResults,
    required SymbolTable symbolTable,
    required KnowledgeGraph graph,
  }) {
    final widgetsFound = <String>[];

    for (final fileResult in fileResults) {
      for (final cls in fileResult.classes) {
        final isWidget = _isWidgetClass(cls);
        if (isWidget) {
          final nodeId = '${cls.file}#${cls.name}';
          widgetsFound.add(cls.name);

          // Update or augment node in graph
          final existingNode = graph.getNode(nodeId);
          final updatedNode = GraphNode(
            id: nodeId,
            label: cls.name,
            kind: NodeKind.widgetNode,
            location: cls.location,
            metadata: {
              ...?existingNode?.metadata,
              'isWidget': true,
              'widgetType': cls.superclass ?? 'Widget',
              'filePath': cls.file,
            },
          );
          graph.addNode(updatedNode);

          // Re-index in symbol table
          final symbol = CodeSymbol(
            id: nodeId,
            name: cls.name,
            qualifiedName: cls.name,
            kind: SymbolKind.widgetSymbol,
            location: cls.location,
            metadata: {
              'isWidget': true,
              'widgetType': cls.superclass,
            },
          );
          symbolTable.register(symbol);
        }
      }
    }

    return DetectorResult(
      detectorName: name,
      detectedFeatures: widgetsFound,
      metadata: {'totalWidgets': widgetsFound.length},
    );
  }

  bool _isWidgetClass(ClassElement cls) {
    if (cls.superclass != null) {
      if (knownWidgetSuperclasses.contains(cls.superclass)) {
        return true;
      }
      if (cls.superclass!.startsWith('State<')) {
        return true;
      }
    }
    // Check if it has a build(BuildContext context) method
    final hasBuildMethod = cls.methods.any(
      (m) =>
          m.name == 'build' &&
          (m.returnType == 'Widget' || m.returnType == null),
    );
    return hasBuildMethod;
  }
}
