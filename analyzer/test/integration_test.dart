import 'package:flutter_code_map_analyzer/flutter_code_map.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('End-to-End Integration Test on Sample Flutter Project', () {
    final sampleProjectPath = p.normalize(
      p.join(p.current, '..', 'examples', 'sample_flutter_project'),
    );

    late AnalyzerEngine engine;

    setUp(() {
      engine = AnalyzerEngine();
    });

    test('analyzes full project and builds knowledge graph', () {
      final summary = engine.analyzeProject(sampleProjectPath);

      expect(summary['summary']['files'], greaterThanOrEqualTo(6));
      expect(summary['summary']['classes'], greaterThanOrEqualTo(8));

      // Check symbol registry
      expect(engine.symbolTable.findByName('LoginPage').isNotEmpty, isTrue);
      expect(engine.symbolTable.findByName('AuthBloc').isNotEmpty, isTrue);
      expect(engine.symbolTable.findByName('AuthRepository').isNotEmpty, isTrue);
      expect(engine.symbolTable.findByName('ApiService').isNotEmpty, isTrue);
      expect(engine.symbolTable.findByName('LoginForm').isNotEmpty, isTrue);

      // Check Flutter widget detection
      final loginPageSymbols = engine.symbolTable.findByName('LoginPage');
      expect(loginPageSymbols.first.kind, equals(SymbolKind.widgetSymbol));

      // Check Route detection
      final routeNodes = engine.graph.findNodesByKind(NodeKind.routeNode);
      expect(routeNodes.any((r) => r.label.contains('/login')), isTrue);
    });

    test('verifies call chain: LoginPage -> AuthBloc.login -> AuthRepository.login -> ApiService.post', () {
      engine.analyzeProject(sampleProjectPath);

      // Check outgoing calls from LoginPage.login
      final loginCalls = engine.graph.allEdges.where(
        (e) => e.kind == EdgeKind.calls && e.sourceId.contains('LoginPage'),
      );
      expect(loginCalls.any((e) => e.targetId.contains('AuthBloc.login')), isTrue);

      // Check outgoing calls from AuthBloc.login
      final blocCalls = engine.graph.allEdges.where(
        (e) => e.kind == EdgeKind.calls && e.sourceId.contains('AuthBloc.login'),
      );
      expect(blocCalls.any((e) => e.targetId.contains('AuthRepository.login')), isTrue);

      // Check outgoing calls from AuthRepository.login
      final repoCalls = engine.graph.allEdges.where(
        (e) => e.kind == EdgeKind.calls && e.sourceId.contains('AuthRepository.login'),
      );
      expect(repoCalls.any((e) => e.targetId.contains('ApiService.post')), isTrue);
    });

    test('executes deterministic natural queries', () {
      engine.analyzeProject(sampleProjectPath);

      // 1. Where is LoginPage?
      final q1 = engine.query('Where is LoginPage?');
      expect(q1.intent, equals('where_is'));
      expect(q1.directAnswer, contains('login_page.dart'));

      // 2. Who uses AuthBloc?
      final q2 = engine.query('Who uses AuthBloc?');
      expect(q2.intent, equals('who_uses'));
      expect(q2.usedBy.isNotEmpty, isTrue);

      // 3. What does LoginPage depend on?
      final q3 = engine.query('What does LoginPage depend on?');
      expect(q3.intent, equals('dependencies_of'));
      expect(q3.dependsOn.isNotEmpty, isTrue);

      // 4. Show login flow
      final q4 = engine.query('Show login flow');
      expect(q4.intent, equals('flow'));
      expect(q4.callChain.length, greaterThanOrEqualTo(2));
    });
  });
}
