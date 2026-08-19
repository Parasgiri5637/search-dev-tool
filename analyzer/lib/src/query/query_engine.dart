import 'dart:io';
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

  /// Generates identifier permutations from a multi-word phrase (e.g. "cart page" -> ["CartPage", "cart_page", "cart", "Cart"]).
  List<String> _generateCandidates(String raw) {
    final clean = raw.trim();
    if (clean.isEmpty) return const [];

    final candidates = <String>{clean};

    final words = clean
        .split(RegExp(r'[\s_.\-]+'))
        .where((w) => w.isNotEmpty)
        .toList();

    if (words.isNotEmpty) {
      // PascalCase: "cart page" -> "CartPage"
      final pascal = words
          .map((w) => w.substring(0, 1).toUpperCase() + w.substring(1).toLowerCase())
          .join('');
      candidates.add(pascal);

      // camelCase: "cart page" -> "cartPage"
      if (words.length > 1) {
        final camel = words.first.toLowerCase() +
            words
                .skip(1)
                .map((w) => w.substring(0, 1).toUpperCase() + w.substring(1).toLowerCase())
                .join('');
        candidates.add(camel);
      }

      // snake_case: "cart page" -> "cart_page"
      candidates.add(words.map((w) => w.toLowerCase()).join('_'));

      // Individual words
      for (final w in words) {
        candidates.add(w);
        candidates.add(w.substring(0, 1).toUpperCase() + w.substring(1).toLowerCase());
      }
    }

    return candidates.toList();
  }

  /// Parses user question into a structured [QueryIntent].
  QueryIntent parseIntent(String query) {
    var clean = query.trim();
    final lower = clean.toLowerCase();

    // Strip leading conversational fillers
    final stripped = lower
        .replaceFirst(RegExp(r'^(?:can you\s+|please\s+|kindly\s+)', caseSensitive: false), '')
        .replaceFirst(RegExp(r'^(?:find out\s+|tell me\s+|show me\s+)', caseSensitive: false), '')
        .trim();

    // 1. What does X depend on? / Show dependencies of X
    final depsMatch = RegExp(
      r'^(?:what does\s+(.+?)\s+depend on|show dependencies of\s+(.+?)|dependencies of\s+(.+?))\??$',
      caseSensitive: false,
    ).firstMatch(stripped);
    if (depsMatch != null) {
      final target = depsMatch.group(1) ??
          depsMatch.group(2) ??
          depsMatch.group(3)!;
      return QueryIntent(
        kind: QueryIntentKind.whatDependsOn,
        target: target.trim(),
        rawQuery: query,
      );
    }

    // 2. What does X call?
    final whatCallsMatch = RegExp(
      r'^(?:what does\s+(.+?)\s+call|what does\s+(.+?)\s+invoke)\??$',
      caseSensitive: false,
    ).firstMatch(stripped);
    if (whatCallsMatch != null) {
      final target = whatCallsMatch.group(1) ?? whatCallsMatch.group(2)!;
      return QueryIntent(
        kind: QueryIntentKind.whatCalls,
        target: target.trim(),
        rawQuery: query,
      );
    }

    // 3. Explain logic / How does X work / What is logic in X / What does X do
    final logicMatch = RegExp(
      r'^(?:what is(?: the)? logic (?:in|of)|how does\s+(.+?)\s+work|what does\s+(.+?)\s+do|explain(?: the logic of)?)\s+(.+?)\??$',
      caseSensitive: false,
    ).firstMatch(stripped);
    if (logicMatch != null) {
      final target = logicMatch.group(1) ?? logicMatch.group(2) ?? logicMatch.group(3)!;
      return QueryIntent(
        kind: QueryIntentKind.explainLogic,
        target: target.trim(),
        rawQuery: query,
      );
    }

    // 4. Where is X? / Locate X / Find X
    final whereMatch = RegExp(
      r'^(?:where is(?:\s+the)?|where is defined|locate|find(?:\s+the)?)\s+(.+?)\??$',
      caseSensitive: false,
    ).firstMatch(stripped);
    if (whereMatch != null) {
      return QueryIntent(
        kind: QueryIntentKind.whereIs,
        target: whereMatch.group(1)!.trim(),
        rawQuery: query,
      );
    }

    // 5. Who uses X? / Who depends on X?
    final whoUsesMatch = RegExp(
      r'^(?:who uses(?:\s+the)?|who depends on(?:\s+the)?|what uses(?:\s+the)?)\s+(.+?)\??$',
      caseSensitive: false,
    ).firstMatch(stripped);
    if (whoUsesMatch != null) {
      return QueryIntent(
        kind: QueryIntentKind.whoUses,
        target: whoUsesMatch.group(1)!.trim(),
        rawQuery: query,
      );
    }

    final whereUsedMatch = RegExp(
      r'^(?:where is(?:\s+the)?)\s+(.+?)\s+used\??$',
      caseSensitive: false,
    ).firstMatch(stripped);
    if (whereUsedMatch != null) {
      return QueryIntent(
        kind: QueryIntentKind.whoUses,
        target: whereUsedMatch.group(1)!.trim(),
        rawQuery: query,
      );
    }

    // 6. Show flow / login flow
    final flowMatch = RegExp(
      r'^(?:show\s+(?:the\s+)?(.+?)\s+flow|(.+?)\s+flow)\??$',
      caseSensitive: false,
    ).firstMatch(stripped);
    if (flowMatch != null) {
      final flowName = flowMatch.group(1) ?? flowMatch.group(2)!;
      return QueryIntent(
        kind: QueryIntentKind.showFlow,
        target: flowName.trim(),
        rawQuery: query,
      );
    }

    // 7. Show files related to X
    final relatedMatch = RegExp(
      r'^(?:show files related to|files related to|show related to|related to)\s+(.+?)\??$',
      caseSensitive: false,
    ).firstMatch(stripped);
    if (relatedMatch != null) {
      return QueryIntent(
        kind: QueryIntentKind.relatedTo,
        target: relatedMatch.group(1)!.trim(),
        rawQuery: query,
      );
    }

    // 8. List components
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
      case QueryIntentKind.explainLogic:
        return _handleExplainLogic(intent);
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

  List<CodeSymbol> _lookupSymbolsForTarget(String target) {
    final candidates = _generateCandidates(target);
    for (final cand in candidates) {
      final direct = symbolTable.findByName(cand);
      if (direct.isNotEmpty) return direct;

      final byQ = symbolTable.findByQualifiedName(cand);
      if (byQ.isNotEmpty) return byQ;
    }

    for (final cand in candidates) {
      final fuzzy = symbolTable.search(cand);
      if (fuzzy.isNotEmpty) return fuzzy;
    }

    return const [];
  }

  List<GraphNode> _lookupNodesForTarget(String target) {
    final candidates = _generateCandidates(target);
    for (final cand in candidates) {
      final direct = graph.findNodesByLabel(cand);
      if (direct.isNotEmpty) return direct;
    }

    for (final cand in candidates) {
      final fuzzy = graph.searchNodes(cand);
      if (fuzzy.isNotEmpty) return fuzzy;
    }

    return const [];
  }

  String? _readSourceSnippet(String filePath, int offset, int length) {
    try {
      final file = File(filePath);
      if (!file.existsSync()) return null;
      final text = file.readAsStringSync();
      if (offset >= 0 && offset + length <= text.length) {
        return text.substring(offset, offset + length);
      }
    } catch (_) {}
    return null;
  }

  QueryResult _handleExplainLogic(QueryIntent intent) {
    final target = intent.target;
    final symbols = _lookupSymbolsForTarget(target);

    if (symbols.isEmpty) {
      final nodes = _lookupNodesForTarget(target);
      if (nodes.isEmpty) {
        return QueryResult(
          query: intent.rawQuery,
          intent: 'explain_logic',
          title: 'Code Logic Not Found',
          summary: 'Could not find component or symbol matching "$target" to explain.',
        );
      }
      final node = nodes.first;
      return _buildLogicResultForNode(node, intent.rawQuery);
    }

    final symbol = symbols.first;
    final node = graph.getNode(symbol.id);

    final logicBreakdown = <String>[];
    String? snippet;

    if (symbol.location.length > 0) {
      snippet = _readSourceSnippet(
        symbol.location.filePath,
        symbol.location.offset,
        symbol.location.length,
      );
    }

    // Breakdown structure
    final meta = symbol.metadata;
    final superclass = meta['superclass'] as String?;
    final mixins = meta['mixins'] as List<dynamic>?;
    final interfaces = meta['interfaces'] as List<dynamic>?;

    if (superclass != null) {
      logicBreakdown.add('Inheritance: Extends $superclass${mixins != null && mixins.isNotEmpty ? ' with ${mixins.join(", ")}' : ''}${interfaces != null && interfaces.isNotEmpty ? ' implementing ${interfaces.join(", ")}' : ''}.');
    }

    // Calls and interactions
    final outgoingCalls = node != null
        ? graph.getOutgoingEdges(node.id, kind: EdgeKind.calls)
        : <GraphEdge>[];

    final containedMembers = node != null
        ? graph.getOutgoingEdges(node.id, kind: EdgeKind.contains)
        : <GraphEdge>[];

    for (final member in containedMembers) {
      final memberCalls = graph.getOutgoingEdges(member.targetId, kind: EdgeKind.calls);
      outgoingCalls.addAll(memberCalls);
    }

    if (outgoingCalls.isNotEmpty) {
      final calledNames = outgoingCalls
          .map((e) => (e.metadata['symbolName'] as String?) ?? e.targetId.split('#').last)
          .toSet()
          .toList();
      logicBreakdown.add('Execution & Invocations: Makes external calls to: ${calledNames.join(', ')}.');
    }

    final createdInstances = node != null
        ? graph.getOutgoingEdges(node.id, kind: EdgeKind.creates)
        : <GraphEdge>[];
    if (createdInstances.isNotEmpty) {
      final createdNames = createdInstances
          .map((e) => (e.metadata['symbolName'] as String?) ?? e.targetId.split('#').last)
          .toSet()
          .toList();
      logicBreakdown.add('Instantiations: Creates child instances of: ${createdNames.join(', ')}.');
    }

    if (meta['stateManagement'] != null) {
      logicBreakdown.add('State Management: Operates as a ${meta['stateManagement']} state container.');
    }

    final summary = logicBreakdown.isNotEmpty
        ? '${symbol.qualifiedName} logic overview:\n• ${logicBreakdown.join('\n• ')}'
        : '${symbol.qualifiedName} is declared at ${symbol.location.displayString}.';

    return QueryResult(
      query: intent.rawQuery,
      intent: 'explain_logic',
      title: 'Logic Breakdown: ${symbol.qualifiedName}',
      summary: summary,
      directAnswer: summary,
      sourceLocation: symbol.location,
      codeSnippet: snippet,
      logicBreakdown: logicBreakdown,
      calls: outgoingCalls.map((e) => graph.getNode(e.targetId)).whereType<GraphNode>().toList(),
      suggestedFollowups: [
        'Who uses ${symbol.name}?',
        'What does ${symbol.name} depend on?',
        'Show ${symbol.name.toLowerCase()} flow',
      ],
    );
  }

  QueryResult _buildLogicResultForNode(GraphNode node, String rawQuery) {
    final calls = graph.getOutgoingEdges(node.id, kind: EdgeKind.calls);
    final logicBreakdown = <String>[
      'Node Kind: ${node.kind.name}',
      if (node.metadata['widgetType'] != null) 'Widget Type: ${node.metadata['widgetType']}',
      if (calls.isNotEmpty) 'Calls: ${calls.map((e) => e.targetId).join(', ')}',
    ];

    return QueryResult(
      query: rawQuery,
      intent: 'explain_logic',
      title: 'Logic Breakdown: ${node.label}',
      summary: logicBreakdown.join('\n• '),
      sourceLocation: node.location,
      logicBreakdown: logicBreakdown,
    );
  }

  QueryResult _handleWhereIs(QueryIntent intent) {
    final target = intent.target;
    final symbols = _lookupSymbolsForTarget(target);

    if (symbols.isEmpty) {
      final nodes = _lookupNodesForTarget(target);
      if (nodes.isNotEmpty) {
        final node = nodes.first;
        final loc = node.location;
        final disp = loc != null ? loc.displayString : (node.filePath ?? node.label);
        return QueryResult(
          query: intent.rawQuery,
          intent: 'where_is',
          title: node.label,
          summary: 'Found matching node "${node.label}" in $disp',
          directAnswer: disp,
          sourceLocation: loc,
          nodes: nodes,
          suggestedFollowups: [
            'Who uses ${node.label}?',
            'What does ${node.label} depend on?',
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

    String? snippet;
    if (symbol.location.length > 0) {
      snippet = _readSourceSnippet(
        symbol.location.filePath,
        symbol.location.offset,
        symbol.location.length,
      );
    }

    return QueryResult(
      query: intent.rawQuery,
      intent: 'where_is',
      title: symbol.qualifiedName,
      summary: '${symbol.kind.name} defined in ${symbol.location.displayString}',
      directAnswer: symbol.location.displayString,
      sourceLocation: symbol.location,
      codeSnippet: snippet,
      dependsOn: dependsOn,
      usedBy: usedBy,
      suggestedFollowups: [
        'What is logic in ${symbol.name}?',
        'Who uses ${symbol.name}?',
        'What does ${symbol.name} depend on?',
      ],
    );
  }

  QueryResult _handleWhoUses(QueryIntent intent) {
    final target = intent.target;
    final targetNodes = _lookupNodesForTarget(target);

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
        'What is logic in ${primary.label}?',
        'Where is ${primary.label}?',
        'What does ${primary.label} depend on?',
      ],
    );
  }

  QueryResult _handleWhatDependsOn(QueryIntent intent) {
    final target = intent.target;
    final targetNodes = _lookupNodesForTarget(target);

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
        'What is logic in ${primary.label}?',
        'Who uses ${primary.label}?',
        'What does ${primary.label} call?',
      ],
    );
  }

  QueryResult _handleWhatCalls(QueryIntent intent) {
    final target = intent.target;
    final targetNodes = _lookupNodesForTarget(target);

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
        'What is logic in ${primary.label}?',
        'Who calls ${primary.label}?',
        'Where is ${primary.label}?',
      ],
    );
  }

  QueryResult _handleWhoCalls(QueryIntent intent) {
    final target = intent.target;
    final targetNodes = _lookupNodesForTarget(target);

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
        'What is logic in ${primary.label}?',
        'What does ${primary.label} call?',
        'Where is ${primary.label}?',
      ],
    );
  }

  QueryResult _handleShowFlow(QueryIntent intent) {
    final flowName = intent.target.toLowerCase();
    final symbols = _lookupSymbolsForTarget(flowName);

    final pages = symbols.where((s) =>
        s.name.toLowerCase().endsWith('page') ||
        s.name.toLowerCase().endsWith('screen') ||
        s.name.toLowerCase().endsWith('view'));

    CodeSymbol? startSymbol;
    List<GraphEdge> callEdges = [];

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
        'What is logic in ${startSymbol.name}?',
        'Who uses ${startSymbol.name}?',
        'What does ${startSymbol.name} depend on?',
      ],
    );
  }

  QueryResult _handleRelatedTo(QueryIntent intent) {
    final target = intent.target;
    final matchingSymbols = _lookupSymbolsForTarget(target);
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
          .map((s) => 'What is logic in ${s.name}?')
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
    final symbols = _lookupSymbolsForTarget(query);
    final nodes = _lookupNodesForTarget(query);

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
          .map((s) => 'What is logic in ${s.name}?')
          .toList(),
    );
  }
}
