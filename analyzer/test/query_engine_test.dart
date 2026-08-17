import 'package:flutter_code_map_analyzer/flutter_code_map.dart';
import 'package:test/test.dart';

void main() {
  group('QueryEngine', () {
    late KnowledgeGraph graph;
    late SymbolTable symbolTable;
    late QueryEngine engine;

    setUp(() {
      graph = KnowledgeGraph();
      symbolTable = SymbolTable();
      engine = QueryEngine(graph: graph, symbolTable: symbolTable);

      const locLogin = SourceLocation(
        filePath: 'lib/features/auth/login_page.dart',
        line: 24,
        column: 1,
        offset: 500,
        length: 200,
        endLine: 40,
        endColumn: 1,
      );

      const locBloc = SourceLocation(
        filePath: 'lib/features/auth/auth_bloc.dart',
        line: 15,
        column: 1,
        offset: 300,
        length: 200,
        endLine: 35,
        endColumn: 1,
      );

      const loginNode = GraphNode(
        id: 'lib/features/auth/login_page.dart#LoginPage',
        label: 'LoginPage',
        kind: NodeKind.widgetNode,
        location: locLogin,
      );

      const blocNode = GraphNode(
        id: 'lib/features/auth/auth_bloc.dart#AuthBloc',
        label: 'AuthBloc',
        kind: NodeKind.blocNode,
        location: locBloc,
      );

      graph.addNode(loginNode);
      graph.addNode(blocNode);

      graph.addEdge(
        const GraphEdge(
          sourceId: 'lib/features/auth/login_page.dart#LoginPage',
          targetId: 'lib/features/auth/auth_bloc.dart#AuthBloc',
          kind: EdgeKind.calls,
        ),
      );

      symbolTable.register(
        const CodeSymbol(
          id: 'lib/features/auth/login_page.dart#LoginPage',
          name: 'LoginPage',
          qualifiedName: 'LoginPage',
          kind: SymbolKind.widgetSymbol,
          location: locLogin,
        ),
      );

      symbolTable.register(
        const CodeSymbol(
          id: 'lib/features/auth/auth_bloc.dart#AuthBloc',
          name: 'AuthBloc',
          qualifiedName: 'AuthBloc',
          kind: SymbolKind.blocSymbol,
          location: locBloc,
        ),
      );
    });

    test('answers "Where is LoginPage?"', () {
      final res = engine.execute('Where is LoginPage?');
      expect(res.intent, equals('where_is'));
      expect(res.directAnswer, equals('lib/features/auth/login_page.dart:24:1'));
      expect(res.sourceLocation?.line, equals(24));
    });

    test('answers "Who uses AuthBloc?"', () {
      final res = engine.execute('Who uses AuthBloc?');
      expect(res.intent, equals('who_uses'));
      expect(res.usedBy.any((n) => n.label == 'LoginPage'), isTrue);
    });

    test('answers "What does LoginPage depend on?"', () {
      final res = engine.execute('What does LoginPage depend on?');
      expect(res.intent, equals('dependencies_of'));
      expect(res.dependsOn.any((n) => n.label == 'AuthBloc'), isTrue);
    });

    test('answers "Show login flow"', () {
      final res = engine.execute('Show login flow');
      expect(res.intent, equals('flow'));
      expect(res.callChain.isNotEmpty, isTrue);
    });

    test('answers "List widgets"', () {
      final res = engine.execute('List widgets');
      expect(res.intent, equals('list_components'));
      expect(res.nodes.any((n) => n.label == 'LoginPage'), isTrue);
    });
  });
}
