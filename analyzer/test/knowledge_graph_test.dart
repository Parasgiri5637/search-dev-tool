import 'package:flutter_code_map_analyzer/flutter_code_map.dart';
import 'package:test/test.dart';

void main() {
  group('KnowledgeGraph', () {
    late KnowledgeGraph graph;

    setUp(() {
      graph = KnowledgeGraph();
    });

    test('adds nodes and edges and supports bidirectional queries', () {
      const nodeA = GraphNode(
        id: 'lib/login_page.dart#LoginPage',
        label: 'LoginPage',
        kind: NodeKind.widgetNode,
      );
      const nodeB = GraphNode(
        id: 'lib/auth_bloc.dart#AuthBloc',
        label: 'AuthBloc',
        kind: NodeKind.blocNode,
      );
      const nodeC = GraphNode(
        id: 'lib/auth_repository.dart#AuthRepository',
        label: 'AuthRepository',
        kind: NodeKind.classNode,
      );

      graph.addNode(nodeA);
      graph.addNode(nodeB);
      graph.addNode(nodeC);

      graph.addEdge(
        const GraphEdge(
          sourceId: 'lib/login_page.dart#LoginPage',
          targetId: 'lib/auth_bloc.dart#AuthBloc',
          kind: EdgeKind.calls,
        ),
      );
      graph.addEdge(
        const GraphEdge(
          sourceId: 'lib/auth_bloc.dart#AuthBloc',
          targetId: 'lib/auth_repository.dart#AuthRepository',
          kind: EdgeKind.calls,
        ),
      );

      expect(graph.nodeCount, equals(3));
      expect(graph.edgeCount, equals(2));

      // Dependencies (outgoing)
      final depsOfA = graph.getDependencies(nodeA.id, maxDepth: 2);
      expect(depsOfA.length, equals(2));
      expect(depsOfA, containsAll([nodeB, nodeC]));

      // Dependents (incoming: Who uses C?)
      final dependentsOfC = graph.getDependents(nodeC.id, maxDepth: 2);
      expect(dependentsOfC.length, equals(2));
      expect(dependentsOfC, containsAll([nodeA, nodeB]));

      // Single depth dependents
      final directDependentsOfC = graph.getDependents(nodeC.id, maxDepth: 1);
      expect(directDependentsOfC.length, equals(1));
      expect(directDependentsOfC.first, equals(nodeB));
    });

    test('findsPath computes shortest call path between components', () {
      const n1 = GraphNode(id: 'A', label: 'A', kind: NodeKind.classNode);
      const n2 = GraphNode(id: 'B', label: 'B', kind: NodeKind.classNode);
      const n3 = GraphNode(id: 'C', label: 'C', kind: NodeKind.classNode);

      graph.addNode(n1);
      graph.addNode(n2);
      graph.addNode(n3);

      graph.addEdge(const GraphEdge(sourceId: 'A', targetId: 'B', kind: EdgeKind.calls));
      graph.addEdge(const GraphEdge(sourceId: 'B', targetId: 'C', kind: EdgeKind.calls));

      final path = graph.findPath('A', 'C');
      expect(path, isNotNull);
      expect(path!.length, equals(2));
      expect(path[0].sourceId, equals('A'));
      expect(path[0].targetId, equals('B'));
      expect(path[1].sourceId, equals('B'));
      expect(path[1].targetId, equals('C'));
    });

    test('removes file nodes and connected edges', () {
      const nodeA = GraphNode(
        id: 'lib/login.dart#Login',
        label: 'Login',
        kind: NodeKind.classNode,
        metadata: {'filePath': 'lib/login.dart'},
      );
      const nodeB = GraphNode(
        id: 'lib/home.dart#Home',
        label: 'Home',
        kind: NodeKind.classNode,
        metadata: {'filePath': 'lib/home.dart'},
      );

      graph.addNode(nodeA);
      graph.addNode(nodeB);
      graph.addEdge(const GraphEdge(sourceId: 'lib/home.dart#Home', targetId: 'lib/login.dart#Login', kind: EdgeKind.calls));

      expect(graph.nodeCount, equals(2));
      expect(graph.edgeCount, equals(1));

      graph.removeFileNodes('lib/login.dart');
      expect(graph.nodeCount, equals(1));
      expect(graph.edgeCount, equals(0));
      expect(graph.getNode('lib/login.dart#Login'), isNull);
      expect(graph.getNode('lib/home.dart#Home'), isNotNull);
    });
  });
}
