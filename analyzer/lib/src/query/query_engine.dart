import '../graph/knowledge_graph.dart';
import '../models/graph_edge.dart';
import '../models/graph_node.dart';
import '../models/symbol.dart';
import '../resolver/symbol_table.dart';
import 'query_intent.dart';
import 'query_result.dart';

/// Deterministic query engine that answers questions without requiring AI.
class QueryEngine {
  final KnowledgeGraph graph;
  final SymbolTable symbolTable;

  QueryEngine({
    required this.graph,
    required this.symbolTable,
  });

  /// Parses user question into a structured [QueryIntent].
  QueryIntent parseIntent(String query) {
    final clean = query.trim();
    final lower = clean.toLowerCase();

    // 1. Where is X?
    final whereMatch = RegExp(
      r'^(?:where is|where is defined|locate|find)\s+([a-zA-Z0-9_.]+)\??$',
      caseSensitive: false,
    ).firstMatch(lower);
    if (whereMatch != null) {
      return QueryIntent(
        kind: QueryIntentKind.whereIs,
        target: whereMatch.group(1)!,
        rawQuery: query,
      );
    }

    // 2. Who uses X? / Who depends on X?
    final whoUsesMatch = RegExp(
      r'^(?:who uses|who depends on|what uses|where is used)\s+([a-zA-Z0-9_.]+)\??$',
      caseSensitive: false,
    ).firstMatch(lower);
    if (whoUsesMatch != null) {
      return QueryIntent(
        kind: QueryIntentKind.whoUses,
        target: whoUsesMatch.group(1)!,
        rawQuery: query,
      );
    }

    // 3. What does X depend on? / Show dependencies of X
    final depsMatch = RegExp(
      r'^(?:what does\s+([a-zA-Z0-9_.]+)\s+depend on|show dependencies of\s+([a-zA-Z0-9_.]+)|dependencies of\s+([a-zA-Z0-9_.]+))\??$',
      caseSensitive: false,
    ).firstMatch(lower);
    if (depsMatch != null) {
      final target = depsMatch.group(1) ??
          depsMatch.group(2) ??
          depsMatch.group(3)!;
      return QueryIntent(
        kind: QueryIntentKind.whatDependsOn,
        target: target,
        rawQuery: query,
      );
    }

    // 4. Who calls X? / What calls X?
    final whoCallsMatch = RegExp(
      r'^(?:who calls|what calls)\s+([a-zA-Z0-9_.]+)\??$',
      caseSensitive: false,
    ).firstMatch(lower);
    if (whoCallsMatch != null) {
      return QueryIntent(
        kind: QueryIntentKind.whoCalls,
        target: whoCallsMatch.group(1)!,
        rawQuery: query,
      );
    }

    // 5. What does X call?
    final whatCallsMatch = RegExp(
      r'^(?:what does\s+([a-zA-Z0-9_.]+)\s+call|what does\s+([a-zA-Z0-9_.]+)\s+invoke)\??$',
      caseSensitive: false,
    ).firstMatch(lower);
    if (whatCallsMatch != null) {
      final target = whatCallsMatch.group(1) ?? whatCallsMatch.group(2)!;
      return QueryIntent(
        kind: QueryIntentKind.whatCalls,
        target: target,
        rawQuery: query,
      );
    }

    // 6. Show flow / login flow
    final flowMatch = RegExp(
      r'^(?:show\s+(?:the\s+)?([a-zA-Z0-9_]+)\s+flow|([a-zA-Z0-9_]+)\s+flow)\??$',
      caseSensitive: false,
    ).firstMatch(lower);
    if (flowMatch != null) {
      final flowName = flowMatch.group(1) ?? flowMatch.group(2)!;
      return QueryIntent(
        kind: QueryIntentKind.showFlow,
        target: flowName,
        rawQuery: query,
      );
    }

    // 7. Show files related to X
    final relatedMatch = RegExp(
      r'^(?:show files related to|files related to|show related to|related to)\s+([a-zA-Z0-9_.]+)\??$',
      caseSensitive: false,
    ).firstMatch(lower);
    if (relatedMatch != null) {
      return QueryIntent(
        kind: QueryIntentKind.relatedTo,
        target: relatedMatch.group(1)!,
        rawQuery: query,
      );
    }

    // 8. List components (widgets / routes / blocs / providers)
    if (lower.contains('list widgets') || lower.contains('show widgets')) {
      return QueryIntent(
        kind: QueryIntentKind.listComponents,
        target: 'widget',
        rawQuery: query,
      );
    }
    if (lower.contains('list routes') || lower.contains('show routes')) {
      return QueryIntent(
        kind: QueryIntentKind.listComponents,
        target: 'route',
        rawQuery: query,
      );
    }
    if (lower.contains('list bloc') ||
        lower.contains('list state') ||
        lower.contains('show blocs')) {
      return QueryIntent(
        kind: QueryIntentKind.listComponents,
        target: 'bloc',
        rawQuery: query,
      );
    }

    // Fallback: general symbol search
    return QueryIntent(
      kind: QueryIntentKind.generalSearch,
      target: clean.replaceAll('?', '').trim(),
      rawQuery: query,
    );
  }

  /// Executes a query string and produces a [QueryResult].
  QueryResult execute(String query) {
    final intent = parseIntent(query);

    switch (intent.kind) {
      case QueryIntentKind.whereIs:
        return _handleWhereIs(intent);
      case QueryIntentKind.whoUses:
        return _handleWhoUses(intent);
      case QueryIntentKind.whatDependsOn:
        return _handleWhatDependsOn(intent);
      case QueryIntentKind.whatCalls:
        return _handleWhatCalls(intent);
      case QueryIntentKind.whoCalls:
        return _handleWhoCalls(intent);
      case QueryIntentKind.showFlow:
        return _handleShowFlow(intent);
      case QueryIntentKind.relatedTo:
        return _handleRelatedTo(intent);
      case QueryIntentKind.listComponents:
        return _handleListComponents(intent);
      case QueryIntentKind.generalSearch:
        return _handleGeneralSearch(intent);
    }
  }

  QueryResult _handleWhereIs(QueryIntent intent) {
    final target = intent.target;
    final symbols = symbolTable.findByName(target).isNotEmpty
        ? symbolTable.findByName(target)
        : symbolTable.findByQualifiedName(target);

    if (symbols.isEmpty) {
      final fuzzy = symbolTable.search(target);
      if (fuzzy.isNotEmpty) {
        final first = fuzzy.first;
        return QueryResult(
          query: intent.rawQuery,
          intent: 'where_is',
          title: first.qualifiedName,
          summary: 'Found matching symbol "${first.qualifiedName}" in ${first.location.displayString}',
          directAnswer: first.location.displayString,
          sourceLocation: first.location,
          suggestedFollowups: [
            'Who uses ${first.name}?',
            'What does ${first.name} depend on?',
          ],
        );
      }

      return QueryResult(
        query: intent.rawQuery,
        intent: 'where_is',
        title: 'Symbol Not Found',
        summary: 'No symbol matching "$target" was found in the workspace.',
      );
    }

    final symbol = symbols.first;
    final node = graph.getNode(symbol.id);
    final dependsOn = node != null ? graph.getDependencies(node.id).toList() : <GraphNode>[];
    final usedBy = node != null ? graph.getDependents(node.id).toList() : <GraphNode>[];

    return QueryResult(
      query: intent.rawQuery,
      intent: 'where_is',
      title: symbol.qualifiedName,
      summary: '${symbol.kind.name} defined in ${symbol.location.displayString}',
      directAnswer: symbol.location.displayString,
      sourceLocation: symbol.location,
      dependsOn: dependsOn,
      usedBy: usedBy,
      suggestedFollowups: [
        'Who uses ${symbol.name}?',
        'What does ${symbol.name} depend on?',
        'What does ${symbol.name} call?',
      ],
    );
  }

  QueryResult _handleWhoUses(QueryIntent intent) {
    final target = intent.target;
    final targetNodes = graph.findNodesByLabel(target).isNotEmpty
        ? graph.findNodesByLabel(target)
        : graph.searchNodes(target);

    if (targetNodes.isEmpty) {
      return QueryResult(
        query: intent.rawQuery,
        intent: 'who_uses',
        title: 'No Dependents Found',
        summary: 'No components found for "$target".',
      );
    }

    final primary = targetNodes.first;
    final dependents = graph.getDependents(primary.id, maxDepth: 2).toList();

    return QueryResult(
      query: intent.rawQuery,
      intent: 'who_uses',
      title: 'Who uses ${primary.label}',
      summary: dependents.isEmpty
          ? 'No incoming usages found for ${primary.label}.'
          : '${dependents.length} component(s) use or reference ${primary.label}.',
      sourceLocation: primary.location,
      usedBy: dependents,
      nodes: dependents,
      suggestedFollowups: [
        'Where is ${primary.label}?',
        'What does ${primary.label} depend on?',
      ],
    );
  }

  QueryResult _handleWhatDependsOn(QueryIntent intent) {
    final target = intent.target;
    final targetNodes = graph.findNodesByLabel(target).isNotEmpty
        ? graph.findNodesByLabel(target)
        : graph.searchNodes(target);

    if (targetNodes.isEmpty) {
      return QueryResult(
        query: intent.rawQuery,
        intent: 'dependencies_of',
        title: 'Component Not Found',
        summary: 'No components found for "$target".',
      );
    }

    final primary = targetNodes.first;
    final dependencies =
        graph.getDependencies(primary.id, maxDepth: 2).toList();

    final calls = graph
        .getOutgoingEdges(primary.id, kind: EdgeKind.calls)
        .map((e) => graph.getNode(e.targetId))
        .whereType<GraphNode>()
        .toList();

    return QueryResult(
      query: intent.rawQuery,
      intent: 'dependencies_of',
      title: 'Dependencies of ${primary.label}',
      summary: '${primary.label} depends on ${dependencies.length} component(s).',
      sourceLocation: primary.location,
      dependsOn: dependencies,
      calls: calls,
      nodes: dependencies,
      suggestedFollowups: [
        'Who uses ${primary.label}?',
        'What does ${primary.label} call?',
      ],
    );
  }

  QueryResult _handleWhatCalls(QueryIntent intent) {
    final target = intent.target;
    final targetNodes = graph.findNodesByLabel(target).isNotEmpty
        ? graph.findNodesByLabel(target)
        : graph.searchNodes(target);

    if (targetNodes.isEmpty) {
      return QueryResult(
        query: intent.rawQuery,
        intent: 'what_calls',
        title: 'Not Found',
        summary: 'Could not find target "$target".',
      );
    }

    final primary = targetNodes.first;
    final outgoingCallEdges =
        graph.getOutgoingEdges(primary.id, kind: EdgeKind.calls);
    final calledNodes = outgoingCallEdges
        .map((e) => graph.getNode(e.targetId))
        .whereType<GraphNode>()
        .toList();

    return QueryResult(
      query: intent.rawQuery,
      intent: 'what_calls',
      title: 'What ${primary.label} Calls',
      summary: '${primary.label} makes ${calledNodes.length} outgoing call(s).',
      sourceLocation: primary.location,
      calls: calledNodes,
      nodes: calledNodes,
      edges: outgoingCallEdges,
      suggestedFollowups: [
        'Who calls ${primary.label}?',
        'Where is ${primary.label}?',
      ],
    );
  }

  QueryResult _handleWhoCalls(QueryIntent intent) {
    final target = intent.target;
    final targetNodes = graph.findNodesByLabel(target).isNotEmpty
        ? graph.findNodesByLabel(target)
        : graph.searchNodes(target);

    if (targetNodes.isEmpty) {
      return QueryResult(
        query: intent.rawQuery,
        intent: 'who_calls',
        title: 'Not Found',
        summary: 'Could not find target "$target".',
      );
    }

    final primary = targetNodes.first;
    final incomingCallEdges =
        graph.getIncomingEdges(primary.id, kind: EdgeKind.calls);
    final callerNodes = incomingCallEdges
        .map((e) => graph.getNode(e.sourceId))
        .whereType<GraphNode>()
        .toList();

    return QueryResult(
      query: intent.rawQuery,
      intent: 'who_calls',
      title: 'Who calls ${primary.label}',
      summary: '${primary.label} is called by ${callerNodes.length} component(s).',
      sourceLocation: primary.location,
      usedBy: callerNodes,
      nodes: callerNodes,
      edges: incomingCallEdges,
      suggestedFollowups: [
        'What does ${primary.label} call?',
        'Where is ${primary.label}?',
      ],
    );
  }

  QueryResult _handleShowFlow(QueryIntent intent) {
    final flowName = intent.target.toLowerCase(); // e.g. 'login'
    final symbols = symbolTable.search(flowName);

    // Prioritize Page/Screen/View classes
    final pages = symbols.where((s) =>
        s.name.toLowerCase().endsWith('page') ||
        s.name.toLowerCase().endsWith('screen') ||
        s.name.toLowerCase().endsWith('view'));

    CodeSymbol? startSymbol;
    List<GraphEdge> callEdges = [];

    // Find first symbol with active outgoing call hierarchy
    final candidateSymbols = [
      ...pages,
      ...symbols.where((s) => s.kind == SymbolKind.widgetSymbol),
      ...symbols.where((s) => s.kind == SymbolKind.blocSymbol),
      ...symbols,
    ];

    for (final cand in candidateSymbols) {
      final edges = graph.getCallHierarchy(cand.id, maxDepth: 6);
      if (edges.isNotEmpty) {
        startSymbol = cand;
        callEdges = edges;
        break;
      }
    }

    startSymbol ??= candidateSymbols.isNotEmpty ? candidateSymbols.first : null;

    if (startSymbol == null) {
      return QueryResult(
        query: intent.rawQuery,
        intent: 'flow',
        title: 'Flow Not Found',
        summary: 'No symbols or entrypoints found related to "$flowName flow".',
      );
    }

    final startNode = graph.getNode(startSymbol.id);
    final chain = <String>[startSymbol.qualifiedName];
    final nodesInFlow = <GraphNode>[if (startNode != null) startNode];
    final edgesInFlow = <GraphEdge>[];

    for (final e in callEdges) {
      edgesInFlow.add(e);
      final target = graph.getNode(e.targetId);
      final label = target?.label ?? (e.metadata['symbolName'] as String? ?? e.targetId);
      if (!chain.contains(label)) {
        chain.add(label);
      }
      if (target != null && !nodesInFlow.contains(target)) {
        nodesInFlow.add(target);
      }
    }

    return QueryResult(
      query: intent.rawQuery,
      intent: 'flow',
      title: '${startSymbol.name} Flow',
      summary: 'Call flow traversing ${nodesInFlow.length} step(s): ${chain.join(" → ")}',
      sourceLocation: startSymbol.location,
      callChain: chain,
      nodes: nodesInFlow,
      edges: edgesInFlow,
      suggestedFollowups: [
        'Who uses ${startSymbol.name}?',
        'What does ${startSymbol.name} depend on?',
      ],
    );
  }

  QueryResult _handleRelatedTo(QueryIntent intent) {
    final target = intent.target;
    final matchingSymbols = symbolTable.search(target);
    final files = <String>{};

    for (final s in matchingSymbols) {
      files.add(s.filePath);
    }

    final nodes = matchingSymbols
        .map((s) => graph.getNode(s.id))
        .whereType<GraphNode>()
        .toList();

    return QueryResult(
      query: intent.rawQuery,
      intent: 'related_to',
      title: 'Files related to "$target"',
      summary: 'Found ${files.length} file(s) and ${matchingSymbols.length} symbol(s) related to "$target".',
      directAnswer: files.join('\n'),
      nodes: nodes,
      suggestedFollowups: matchingSymbols
          .take(3)
          .map((s) => 'Where is ${s.name}?')
          .toList(),
    );
  }

  QueryResult _handleListComponents(QueryIntent intent) {
    final type = intent.target;
    NodeKind kind;
    String title;

    switch (type) {
      case 'widget':
        kind = NodeKind.widgetNode;
        title = 'Flutter Widgets';
        break;
      case 'route':
        kind = NodeKind.routeNode;
        title = 'App Routes';
        break;
      case 'bloc':
        kind = NodeKind.blocNode;
        title = 'BLoCs & State Managers';
        break;
      default:
        kind = NodeKind.classNode;
        title = 'Classes';
        break;
    }

    final nodes = graph.findNodesByKind(kind);
    return QueryResult(
      query: intent.rawQuery,
      intent: 'list_components',
      title: title,
      summary: 'Found ${nodes.length} $title in project.',
      directAnswer: nodes.map((n) => n.label).join('\n'),
      nodes: nodes,
    );
  }

  QueryResult _handleGeneralSearch(QueryIntent intent) {
    final query = intent.target;
    final symbols = symbolTable.search(query);
    final nodes = graph.searchNodes(query);

    if (symbols.isEmpty && nodes.isEmpty) {
      return QueryResult(
        query: intent.rawQuery,
        intent: 'search',
        title: 'No Results',
        summary: 'No code symbols or graph nodes matched "$query".',
      );
    }

    final firstLoc = symbols.isNotEmpty ? symbols.first.location : nodes.first.location;

    return QueryResult(
      query: intent.rawQuery,
      intent: 'search',
      title: 'Search results for "$query"',
      summary: 'Found ${symbols.length} symbol(s) and ${nodes.length} node(s).',
      sourceLocation: firstLoc,
      nodes: nodes,
      suggestedFollowups: symbols
          .take(3)
          .map((s) => 'Where is ${s.name}?')
          .toList(),
    );
  }
}
