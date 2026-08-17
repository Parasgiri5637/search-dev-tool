import 'package:meta/meta.dart';
import 'source_location.dart';

/// Node classification in the project knowledge graph.
enum NodeKind {
  fileNode,
  classNode,
  enumNode,
  mixinNode,
  extensionNode,
  methodNode,
  functionNode,
  constructorNode,
  variableNode,
  widgetNode,
  blocNode,
  cubitNode,
  providerNode,
  routeNode,
}

/// Represents a node in the project knowledge graph.
@immutable
class GraphNode {
  /// Unique identifier of the node.
  final String id;

  /// Readable display label (e.g., `LoginPage` or `AuthBloc.login()`).
  final String label;

  /// The category/kind of this node.
  final NodeKind kind;

  /// Source location if applicable.
  final SourceLocation? location;

  /// Arbitrary node properties (e.g. isWidget, routePath, returnType, etc.).
  final Map<String, dynamic> metadata;

  const GraphNode({
    required this.id,
    required this.label,
    required this.kind,
    this.location,
    this.metadata = const {},
  });

  /// The file path containing this node if available.
  String? get filePath => location?.filePath ?? metadata['filePath'] as String?;

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'kind': kind.name,
        'location': location?.toJson(),
        'metadata': metadata,
      };

  factory GraphNode.fromJson(Map<String, dynamic> json) {
    return GraphNode(
      id: json['id'] as String,
      label: json['label'] as String,
      kind: NodeKind.values.firstWhere((k) => k.name == json['kind']),
      location: json['location'] != null
          ? SourceLocation.fromJson(json['location'] as Map<String, dynamic>)
          : null,
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? const {},
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GraphNode && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => '$label ($kind)';
}
