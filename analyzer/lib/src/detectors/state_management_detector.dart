import '../graph/knowledge_graph.dart';
import '../models/ast_element.dart';
import '../models/file_analysis_result.dart';
import '../models/graph_node.dart';
import '../models/symbol.dart';
import '../resolver/symbol_table.dart';
import 'flutter_detector.dart';

/// Detects State Management patterns: BLoC, Cubit, Provider, Riverpod.
class StateManagementDetector implements FlutterDetector {
  @override
  String get name => 'StateManagementDetector';

  @override
  DetectorResult detect({
    required List<FileAnalysisResult> fileResults,
    required SymbolTable symbolTable,
    required KnowledgeGraph graph,
  }) {
    final stateManagers = <String>[];

    for (final fileResult in fileResults) {
      for (final cls in fileResult.classes) {
        final statePattern = _detectClassStatePattern(cls);
        if (statePattern != null) {
          final nodeId = '${cls.file}#${cls.name}';
          stateManagers.add('${cls.name} ($statePattern)');

          NodeKind nodeKind;
          SymbolKind symbolKind;

          switch (statePattern) {
            case 'bloc':
              nodeKind = NodeKind.blocNode;
              symbolKind = SymbolKind.blocSymbol;
              break;
            case 'cubit':
              nodeKind = NodeKind.cubitNode;
              symbolKind = SymbolKind.cubitSymbol;
              break;
            case 'provider':
            case 'riverpod':
            default:
              nodeKind = NodeKind.providerNode;
              symbolKind = SymbolKind.providerSymbol;
              break;
          }

          final existingNode = graph.getNode(nodeId);
          final updatedNode = GraphNode(
            id: nodeId,
            label: cls.name,
            kind: nodeKind,
            location: cls.location,
            metadata: {
              ...?existingNode?.metadata,
              'stateManagement': statePattern,
              'stateSuperclass': cls.superclass,
              'filePath': cls.file,
            },
          );
          graph.addNode(updatedNode);

          final symbol = CodeSymbol(
            id: nodeId,
            name: cls.name,
            qualifiedName: cls.name,
            kind: symbolKind,
            location: cls.location,
            metadata: {
              'stateManagement': statePattern,
              'stateSuperclass': cls.superclass,
            },
          );
          symbolTable.register(symbol);
        }
      }
    }

    return DetectorResult(
      detectorName: name,
      detectedFeatures: stateManagers,
      metadata: {'totalStateManagers': stateManagers.length},
    );
  }

  String? _detectClassStatePattern(ClassElement cls) {
    final superclass = cls.superclass ?? '';
    final mixins = cls.mixins;

    if (superclass.startsWith('Bloc<') || superclass == 'Bloc') {
      return 'bloc';
    }
    if (superclass.startsWith('Cubit<') || superclass == 'Cubit') {
      return 'cubit';
    }
    if (superclass.contains('StateNotifier<') ||
        superclass.contains('Notifier<') ||
        superclass.contains('AsyncNotifier<')) {
      return 'riverpod';
    }
    if (superclass == 'ChangeNotifier' || mixins.contains('ChangeNotifier')) {
      return 'provider';
    }

    return null;
  }
}
