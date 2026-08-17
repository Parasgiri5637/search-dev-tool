import 'package:flutter_code_map_analyzer/flutter_code_map.dart';
import 'package:test/test.dart';

void main() {
  group('Flutter Detectors', () {
    const parser = AstParser();

    test('WidgetDetector tags StatelessWidget and StatefulWidget', () {
      const source = '''
class LoginPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container();
}

class CustomButton extends StatefulWidget {
  @override
  State<CustomButton> createState() => _CustomButtonState();
}

class PlainHelper {}
''';

      final res = parser.parseSource(source, filePath: 'lib/widgets.dart');
      final graph = KnowledgeGraph();
      final symbolTable = SymbolTable();
      symbolTable.registerFromAstElements(res.elements);

      final detector = WidgetDetector();
      final result = detector.detect(
        fileResults: [res],
        symbolTable: symbolTable,
        graph: graph,
      );

      expect(result.detectedFeatures, containsAll(['LoginPage', 'CustomButton']));
      expect(result.detectedFeatures.contains('PlainHelper'), isFalse);

      final widgetNode = graph.getNode('lib/widgets.dart#LoginPage');
      expect(widgetNode, isNotNull);
      expect(widgetNode!.kind, equals(NodeKind.widgetNode));
    });

    test('StateManagementDetector tags Bloc and Cubit patterns', () {
      const source = '''
class AuthBloc extends Bloc<AuthEvent, AuthState> {}
class CounterCubit extends Cubit<int> {}
class UserNotifier extends ChangeNotifier {}
''';

      final res = parser.parseSource(source, filePath: 'lib/state.dart');
      final graph = KnowledgeGraph();
      final symbolTable = SymbolTable();
      symbolTable.registerFromAstElements(res.elements);

      final detector = StateManagementDetector();
      detector.detect(
        fileResults: [res],
        symbolTable: symbolTable,
        graph: graph,
      );

      final blocNode = graph.getNode('lib/state.dart#AuthBloc');
      expect(blocNode, isNotNull);
      expect(blocNode!.kind, equals(NodeKind.blocNode));

      final cubitNode = graph.getNode('lib/state.dart#CounterCubit');
      expect(cubitNode, isNotNull);
      expect(cubitNode!.kind, equals(NodeKind.cubitNode));

      final providerNode = graph.getNode('lib/state.dart#UserNotifier');
      expect(providerNode, isNotNull);
      expect(providerNode!.kind, equals(NodeKind.providerNode));
    });
  });
}
