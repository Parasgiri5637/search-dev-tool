import '../models/graph_edge.dart';
import '../models/graph_node.dart';

/// The central graph representing project components and relationships.
class KnowledgeGraph {
  final Map<String, GraphNode> _nodes = {};
  final Map<String, List<GraphEdge>> _outgoing = {};
  final Map<String, List<GraphEdge>> _incoming = {};

  KnowledgeGraph();

  /// All nodes in the graph.
  Iterable<GraphNode> get nodes => _nodes.values;

  /// All edges in the graph.
  List<GraphEdge> get allEdges {
    final edges = <GraphEdge>[];
    for (final list in _outgoing.values) {
      edges.addAll(list);
    }
    return edges;
  }

  /// Total number of nodes.
  int get nodeCount => _nodes.length;

  /// Total number of edges.
  int get edgeCount => allEdges.length;

  /// Adds or updates a node.
  void addNode(GraphNode node) {
    _nodes[node.id] = node;
  }

  /// Adds a directed edge between source and target.
  void addEdge(GraphEdge edge) {
    _outgoing.putIfAbsent(edge.sourceId, () => []).add(edge);
    _incoming.putIfAbsent(edge.targetId, () => []).add(edge);
  }

  /// Retrieves a node by ID.
  GraphNode? getNode(String id) => _nodes[id];

  /// Finds nodes matching an exact label (e.g. `LoginPage`).
  List<GraphNode> findNodesByLabel(String label) {
    return _nodes.values.where((n) => n.label == label).toList();
  }

  /// Finds nodes matching a kind.
  List<GraphNode> findNodesByKind(NodeKind kind) {
    return _nodes.values.where((n) => n.kind == kind).toList();
  }

  /// Searches for nodes whose label contains [query] (case-insensitive).
  List<GraphNode> searchNodes(String query) {
    final lower = query.toLowerCase().trim();
    if (lower.isEmpty) return const [];
    return _nodes.values
        .where((n) => n.label.toLowerCase().contains(lower))
        .toList();
  }

  /// Gets outgoing edges from [nodeId].
  List<GraphEdge> getOutgoingEdges(String nodeId, {EdgeKind? kind}) {
    final list = _outgoing[nodeId] ?? const [];
    if (kind == null) return list;
    return list.where((e) => e.kind == kind).toList();
  }

  /// Gets incoming edges to [nodeId].
  List<GraphEdge> getIncomingEdges(String nodeId, {EdgeKind? kind}) {
    final list = _incoming[nodeId] ?? const [];
    if (kind == null) return list;
    return list.where((e) => e.kind == kind).toList();
  }

  /// Traverses outgoing edges to find all dependencies of [nodeId].
  Set<GraphNode> getDependencies(
    String nodeId, {
    int maxDepth = 1,
    Set<EdgeKind>? edgeKinds,
  }) {
    final results = <GraphNode>{};
    final visited = <String>{nodeId};
    final queue = <(String id, int depth)>[(nodeId, 0)];

    // If starting from a class, also check member dependencies
    final containedMembers = getOutgoingEdges(nodeId, kind: EdgeKind.contains);
    for (final m in containedMembers) {
      if (!visited.contains(m.targetId)) {
        visited.add(m.targetId);
        queue.add((m.targetId, 0));
      }
    }

    while (queue.isNotEmpty) {
      final (currentId, depth) = queue.removeAt(0);
      if (depth >= maxDepth) continue;

      final outgoing = getOutgoingEdges(currentId);
      for (final edge in outgoing) {
        if (edge.kind == EdgeKind.contains) continue;
        if (edgeKinds != null && !edgeKinds.contains(edge.kind)) {
          continue;
        }

        final targetNode = getNode(edge.targetId);
        if (targetNode != null && !visited.contains(edge.targetId)) {
          visited.add(edge.targetId);
          results.add(targetNode);
          queue.add((edge.targetId, depth + 1));
        }
      }
    }

    return results;
  }

  /// Traverses incoming edges to find all dependents of [nodeId] (Who uses X?).
  Set<GraphNode> getDependents(
    String nodeId, {
    int maxDepth = 1,
    Set<EdgeKind>? edgeKinds,
  }) {
    final results = <GraphNode>{};
    final visited = <String>{nodeId};
    final queue = <(String id, int depth)>[(nodeId, 0)];

    // If target is a class, also check callers of its member methods
    final containedMembers = getOutgoingEdges(nodeId, kind: EdgeKind.contains);
    for (final m in containedMembers) {
      if (!visited.contains(m.targetId)) {
        visited.add(m.targetId);
        queue.add((m.targetId, 0));
      }
    }

    while (queue.isNotEmpty) {
      final (currentId, depth) = queue.removeAt(0);
      if (depth >= maxDepth) continue;

      final incoming = getIncomingEdges(currentId);
      for (final edge in incoming) {
        if (edge.kind == EdgeKind.contains) continue;
        if (edgeKinds != null && !edgeKinds.contains(edge.kind)) {
          continue;
        }

        final sourceNode = getNode(edge.sourceId);
        if (sourceNode != null && !visited.contains(edge.sourceId)) {
          visited.add(edge.sourceId);
          results.add(sourceNode);
          queue.add((edge.sourceId, depth + 1));
        }
      }
    }

    return results;
  }

  /// Builds a call chain / hierarchy starting from [startId].
  List<GraphEdge> getCallHierarchy(
    String startId, {
    bool reverse = false,
    int maxDepth = 4,
  }) {
    final callEdges = <GraphEdge>[];
    final visited = <String>{startId};
    final queue = <(String id, int depth)>[(startId, 0)];

    // If starting from a class, also add contained methods to search call origins
    final containedMembers = getOutgoingEdges(startId, kind: EdgeKind.contains);
    for (final m in containedMembers) {
      if (!visited.contains(m.targetId)) {
        visited.add(m.targetId);
        queue.add((m.targetId, 0));
      }
    }

    while (queue.isNotEmpty) {
      final (currentId, depth) = queue.removeAt(0);
      if (depth >= maxDepth) continue;

      final edges = reverse
          ? getIncomingEdges(currentId, kind: EdgeKind.calls)
          : getOutgoingEdges(currentId, kind: EdgeKind.calls);

      for (final edge in edges) {
        final nextId = reverse ? edge.sourceId : edge.targetId;
        if (!visited.contains(nextId)) {
          visited.add(nextId);
          callEdges.add(edge);
          queue.add((nextId, depth + 1));
        }
      }
    }

    return callEdges;
  }

  /// Finds shortest path between two nodes using BFS.
  List<GraphEdge>? findPath(String startId, String endId) {
    if (startId == endId) return const [];
    final visited = <String>{startId};
    final parentEdge = <String, GraphEdge>{};
    final queue = <String>[startId];

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      if (current == endId) {
        final path = <GraphEdge>[];
        var curr = endId;
        while (curr != startId) {
          final edge = parentEdge[curr]!;
          path.insert(0, edge);
          curr = edge.sourceId;
        }
        return path;
      }

      for (final edge in getOutgoingEdges(current)) {
        if (!visited.contains(edge.targetId)) {
          visited.add(edge.targetId);
          parentEdge[edge.targetId] = edge;
          queue.add(edge.targetId);
        }
      }
    }

    return null;
  }

  /// Removes all nodes and connected edges associated with a file (for incremental updates).
  void removeFileNodes(String filePath) {
    final toRemove = _nodes.values
        .where((n) => n.filePath == filePath || n.id == filePath)
        .map((n) => n.id)
        .toList();

    for (final id in toRemove) {
      _nodes.remove(id);
      _outgoing.remove(id);
      _incoming.remove(id);

      for (final list in _outgoing.values) {
        list.removeWhere((e) => e.targetId == id);
      }
      for (final list in _incoming.values) {
        list.removeWhere((e) => e.sourceId == id);
      }
    }
  }

  /// Clears the graph.
  void clear() {
    _nodes.clear();
    _outgoing.clear();
    _incoming.clear();
  }

  Map<String, dynamic> toJson() => {
        'nodes': _nodes.values.map((n) => n.toJson()).toList(),
        'edges': allEdges.map((e) => e.toJson()).toList(),
      };

  factory KnowledgeGraph.fromJson(Map<String, dynamic> json) {
    final graph = KnowledgeGraph();
    final nodesJson = json['nodes'] as List<dynamic>? ?? const [];
    for (final n in nodesJson) {
      graph.addNode(GraphNode.fromJson(n as Map<String, dynamic>));
    }
    final edgesJson = json['edges'] as List<dynamic>? ?? const [];
    for (final e in edgesJson) {
      graph.addEdge(GraphEdge.fromJson(e as Map<String, dynamic>));
    }
    return graph;
  }
}
