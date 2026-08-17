import '../graph/knowledge_graph.dart';
import '../query/query_result.dart';

/// Optional AI augmentor interface for generating high-level summaries from graph context.
abstract class AiQueryAugmenter {
  /// Whether an AI provider (e.g. Gemini, OpenAI) is configured and active.
  bool get isAvailable;

  /// Augments deterministic [QueryResult] with an AI-generated explanation
  /// using ONLY relevant graph sub-contexts (no full project dump).
  Future<String> explainQueryResult({
    required QueryResult result,
    required KnowledgeGraph graph,
  });
}

/// Fallback implementation that operates strictly deterministically without AI.
class NoopAiAugmenter implements AiQueryAugmenter {
  const NoopAiAugmenter();

  @override
  bool get isAvailable => false;

  @override
  Future<String> explainQueryResult({
    required QueryResult result,
    required KnowledgeGraph graph,
  }) async {
    return result.summary;
  }
}
