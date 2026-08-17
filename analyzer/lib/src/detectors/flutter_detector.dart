import '../graph/knowledge_graph.dart';
import '../models/file_analysis_result.dart';
import '../resolver/symbol_table.dart';

/// Result of running a Flutter detector.
class DetectorResult {
  final String detectorName;
  final List<String> detectedFeatures;
  final Map<String, dynamic> metadata;

  const DetectorResult({
    required this.detectorName,
    this.detectedFeatures = const [],
    this.metadata = const {},
  });
}

/// Base interface for specialized Flutter pattern detectors.
abstract class FlutterDetector {
  String get name;

  /// Detects patterns in [fileResults] and augments [graph] and [symbolTable].
  DetectorResult detect({
    required List<FileAnalysisResult> fileResults,
    required SymbolTable symbolTable,
    required KnowledgeGraph graph,
  });
}
