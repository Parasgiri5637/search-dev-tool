import 'package:meta/meta.dart';
import 'source_location.dart';

/// The kind of relationship represented by an edge.
enum EdgeKind {
  imports,
  exports,
  extendsType,
  implementsType,
  withMixin,
  references,
  calls,
  creates,
  contains,
  overrides,
  routeTo,
  provides,
  consumes,
}

/// Confidence rating for discovered relationships.
enum ConfidenceRating {
  confirmed,
  inferred,
  unknown,
}

/// Represents a directed relationship between two nodes in the knowledge graph.
@immutable
class GraphEdge {
  final String sourceId;
  final String targetId;
  final EdgeKind kind;
  final ConfidenceRating confidence;
  final SourceLocation? location;
  final Map<String, dynamic> metadata;

  const GraphEdge({
    required this.sourceId,
    required this.targetId,
    required this.kind,
    this.confidence = ConfidenceRating.confirmed,
    this.location,
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() => {
        'sourceId': sourceId,
        'targetId': targetId,
        'kind': kind.name,
        'confidence': confidence.name,
        'location': location?.toJson(),
        'metadata': metadata,
      };

  factory GraphEdge.fromJson(Map<String, dynamic> json) {
    return GraphEdge(
      sourceId: json['sourceId'] as String,
      targetId: json['targetId'] as String,
      kind: EdgeKind.values.firstWhere((k) => k.name == json['kind']),
      confidence: ConfidenceRating.values
          .firstWhere((c) => c.name == json['confidence']),
      location: json['location'] != null
          ? SourceLocation.fromJson(json['location'] as Map<String, dynamic>)
          : null,
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? const {},
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GraphEdge &&
          runtimeType == other.runtimeType &&
          sourceId == other.sourceId &&
          targetId == other.targetId &&
          kind == other.kind &&
          location == other.location;

  @override
  int get hashCode => Object.hash(sourceId, targetId, kind, location);

  @override
  String toString() => '$sourceId --[$kind ($confidence)]--> $targetId';
}
