/// Recognized categories of developer queries.
enum QueryIntentKind {
  whereIs,
  whoUses,
  whatDependsOn,
  whatCalls,
  whoCalls,
  showFlow,
  relatedTo,
  listComponents,
  explainLogic,
  generalSearch,
}

/// Parsed intent and parameters from a user question.
class QueryIntent {
  final QueryIntentKind kind;
  final String target;
  final String rawQuery;
  final Map<String, String> parameters;

  const QueryIntent({
    required this.kind,
    required this.target,
    required this.rawQuery,
    this.parameters = const {},
  });

  @override
  String toString() => '$kind(target: "$target")';
}
